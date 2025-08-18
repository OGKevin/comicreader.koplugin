local ReaderView = require("apps/reader/modules/readerview")

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local IconWidget = require("ui/widget/iconwidget")
local ReaderDogear = require("readerdogear")
local ReaderFlipping = require("apps/reader/modules/readerflipping")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local Screen = Device.screen
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local logger = require("logger")

function ReaderView:addWidgets()
    self.dogear = ReaderDogear:new({
        view = self,
        ui = self.ui,
    })
    self.footer = ReaderFooter:new({
        view = self,
        ui = self.ui,
    })
    self.flipping = ReaderFlipping:new({
        view = self,
        ui = self.ui,
    })
    local arrow_size = Screen:scaleBySize(16)
    self.arrow = IconWidget:new({
        icon = "control.expand.alpha",
        width = arrow_size,
        height = arrow_size,
        alpha = true, -- Keep the alpha layer intact, the fill opacity is set at 75%
    })

    self[1] = self.dogear
    self[2] = self.footer
    self[3] = self.flipping
end

function ReaderView:paintTo(bb, x, y)
    logger.dbg("ComicReaderView:paintTo", self.visible_area, "to", x, y)
    if self.page_scroll then
        self:drawPageBackground(bb, x, y)
    else
        self:drawPageSurround(bb, x, y)
    end

    -- draw page content
    if self.ui.paging then
        if self.page_scroll then
            self:drawScrollPages(bb, x, y)
        elseif self.ui.paging:isDualPageEnabled() then
            self:drawPageBackground(bb, x, y)
            self:draw2Pages(bb, x, y)
        else
            self:drawSinglePage(bb, x, y)
        end
    else
        if self.view_mode == "page" then
            self:drawPageView(bb, x, y)
        elseif self.view_mode == "scroll" then
            self:drawScrollView(bb, x, y)
        end
        local should_repaint = self.ui.rolling:handlePartialRerendering()
        if should_repaint then
            -- ReaderRolling may have repositionned on another page containing
            -- the xpointer of the top of the original page: recalling this is
            -- all there is to do.
            self:paintTo(bb, x, y)
            return
        end
    end

    -- mark last read area of overlapped pages
    if not self.dim_area:isEmpty() and self:isOverlapAllowed() then
        if self.page_overlap_style == "dim" then
            -- NOTE: "dim", as in make black text fainter, e.g., lighten the rect
            bb:lightenRect(self.dim_area.x, self.dim_area.y, self.dim_area.w, self.dim_area.h)
        else
            -- Paint at the proper y origin depending on whether we paged forward (dim_area.y == 0) or backward
            local paint_y = self.dim_area.y == 0 and self.dim_area.h or self.dim_area.y
            if self.page_overlap_style == "arrow" then
                local center_offset = bit.rshift(self.arrow.height, 1)
                self.arrow:paintTo(bb, 0, paint_y - center_offset)
            elseif self.page_overlap_style == "line" then
                bb:paintRect(0, paint_y, self.dim_area.w, Size.line.medium, Blitbuffer.COLOR_DARK_GRAY)
            elseif self.page_overlap_style == "dashed_line" then
                for i = 0, self.dim_area.w - 20, 20 do
                    bb:paintRect(i, paint_y, 14, Size.line.medium, Blitbuffer.COLOR_DARK_GRAY)
                end
            end
        end
    end

    -- draw saved highlight (will return true if any of them are in color)
    local colorful
    if self.highlight_visible then
        colorful = self:drawSavedHighlight(bb, x, y)
    end
    -- draw temporary highlight
    if self.highlight.temp then
        self:drawTempHighlight(bb, x, y)
    end
    -- draw highlight position indicator for non-touch
    if self.highlight.indicator then
        self:drawHighlightIndicator(bb, x, y)
    end
    -- paint dogear
    if self.dogear_visible then
        logger.dbg("ReaderView: painting dogear")
        self.dogear:paintTo(bb, x, y)
    end
    -- paint footer
    if self.footer_visible then
        self.footer:paintTo(bb, x, y)
    end
    -- paint top left corner indicator
    self.flipping:paintTo(bb, x, y)
    -- paint view modules
    for _, m in pairs(self.view_modules) do
        m:paintTo(bb, x, y)
    end
    -- stop activity indicator
    self.ui:handleEvent(Event:new("StopActivityIndicator"))

    -- Most pages should not require dithering, but the dithering flag is also used to engage Kaleido waveform modes,
    -- so we'll set the flag to true if any of our drawn highlights were in color.
    self.dialog.dithered = colorful
    -- For KOpt, let the user choose.
    if self.ui.paging then
        if self.document.hw_dithering then
            self.dialog.dithered = true
        end
    else
        -- Whereas for CRe,
        -- If we're attempting to show a large enough amount of image data, request dithering (without triggering another repaint ;)).
        local img_count, img_coverage = self.document:getDrawnImagesStatistics()
        -- We also want to deal with paging *away* from image content, which would have adverse effect on ghosting.
        local coverage_diff = math.abs(img_coverage - self.img_coverage)
        -- Which is why we remember the stats of the *previous* page.
        self.img_count, self.img_coverage = img_count, img_coverage
        if img_coverage >= 0.075 or coverage_diff >= 0.075 then
            -- Request dithering on the actual page with image content
            if img_coverage >= 0.075 then
                self.dialog.dithered = true
            end
            -- Request a flashing update while we're at it, but only if it's the first time we're painting it
            if self.state.drawn == false and G_reader_settings:nilOrTrue("refresh_on_pages_with_images") then
                UIManager:setDirty(nil, "full")
            end
        end
        self.state.drawn = true
    end
end

--[[
Given coordinates on the screen return position in original page
]]
--
function ReaderView:screenToPageTransform(pos)
    logger.dbg(
        "ComicReaderView:screenToPageTransform pos x,y",
        pos.x,
        pos.y,
        "with area",
        self.visible_area.x,
        self.visible_area.y
    )
    if self.ui.paging then
        if self.page_scroll then
            return self:getScrollPagePosition(pos)
        elseif self.ui.paging:isDualPageEnabled() then
            return self:getDualPagePosition(pos)
        else
            return self:getSinglePagePosition(pos)
        end
    else
        pos.page = self.document:getCurrentPage()
        return pos
    end
end

function ReaderView:pageToScreenTransform(page, rect)
    logger.dbg("ComicReaderView:pageToScreenTransform", page, rect)
    if self.ui.paging then
        if self.page_scroll then
            return self:getScrollPageRect(page, rect)
        elseif self.ui.paging:isDualPageEnabled() then
            return self:getDualPageRect(page, rect)
        else
            return self:getSinglePageRect(rect)
        end
    else
        return rect
    end
end

-- This method draws 2 pages next to each other.
-- Useful for PDF or CBZ etc
--
-- It does this by scaling based on H
function ReaderView:draw2Pages(bb, x, y)
    local visible_area = self.visible_area

    local total_width = 0
    local max_height = 0

    local states = self.page_states

    for _, state in ipairs(states) do
        total_width = total_width + state.dimen.w
        -- both pages are sacled to same h
        max_height = state.dimen.h
    end

    local x_offset = x
    if visible_area.w > total_width then
        x_offset = x_offset + (visible_area.w - total_width) / 2
    end

    local y_offset = y
    if visible_area.h > max_height then
        y_offset = y_offset + (visible_area.h - max_height) / 2
    end

    -- Update offset for ReaderView:*Transform
    self.state.offset.y = y_offset
    self.state.offset.x = x_offset

    local start_i, end_i, step
    if self.ui.paging.document_settings.dual_page_mode_rtl then
        start_i, end_i, step = #states, 1, -1
    else
        start_i, end_i, step = 1, #states, 1
    end

    for i = start_i, end_i, step do
        local page = states[i].page
        local zoom = states[i].zoom
        local area = visible_area:copy()

        self.document:drawPage(bb, x_offset, y_offset, area, page, zoom, self.state.rotation, self.state.gamma)

        x_offset = x_offset + states[i].dimen.w
    end

    UIManager:nextTick(self.emitHintPageEvent)
end

function ReaderView:getCurrentPageList()
    local pages = {}
    if self.ui.paging then
        if self.page_scroll or self.ui.paging:isDualPageEnabled() then
            for _, state in ipairs(self.page_states) do
                table.insert(pages, state.page)
            end
        else
            table.insert(pages, self.state.page)
        end
    end
    return pages
end

-- @param pos Geom the screen coordinates
function ReaderView:getDualPagePosition(pos)
    logger.dbg("ComicReaderView:getDualPagePosition", pos)
    local x_s, y_s = pos.x - self.state.offset.x, pos.y - self.state.offset.y
    local states = self.page_states
    local zoom = 1
    local page = 1

    local start_i, end_i, step
    if self.ui.paging.document_settings.dual_page_mode_rtl then
        start_i, end_i, step = #states, 1, -1
    else
        start_i, end_i, step = 1, #states, 1
    end

    for i = start_i, end_i, step do
        local state = states[i]
        if x_s > state.dimen.w then
            x_s = x_s - state.dimen.w
        else
            zoom = state.zoom
            page = state.page

            break
        end
    end

    return {
        x = x_s / zoom,
        y = y_s / zoom,
        zoom = zoom,
        page = page,
        rotation = self.state.rotation,
    }
end

-- @param page number
-- @param rect_p Geom the coordinates on the page
function ReaderView:getDualPageRect(page, rect_p)
    local rect_s = Geom:new({ x = self.state.offset.x, y = self.state.offset.y })
    local states = self.page_states

    local start_i, end_i, step
    if self.ui.paging.document_settings.dual_page_mode_rtl then
        start_i, end_i, step = #states, 1, -1
    else
        start_i, end_i, step = 1, #states, 1
    end

    for i = start_i, end_i, step do
        local state = states[i]
        local trans_p = rect_p:copy()
        trans_p:transformByScale(state.zoom, state.zoom)

        if state.page == page then
            rect_s.x = rect_s.x + trans_p.x
            rect_s.y = rect_s.y + trans_p.y
            rect_s.w = trans_p.w
            rect_s.h = trans_p.h

            break
        end

        rect_s.x = rect_s.x + state.dimen.w
    end

    return rect_s
end

-- If this becomes dual page aware, panning in dual page mode is unlocked.
-- However, there is a chicken and egg problem. To calculate page area, zoom
-- is required. To calculate dual page, visible are is required.
-- For now, cheat and return the visible_area as atm it's the same as page_area
--
-- This could potentially also solve/simplify the zooming issues, as page area would be bigger
-- then visible area, and so we get panning.
-- The other issue that needs solving is calculating the correct zoom factor.
-- Mostlikey, refactoring ReaderPaging:calculateZoomFactorForPagePair should then be moved
-- to ReaderZooming, and ReaderZooming.disabled potentially removed all together.
function ReaderView:getPageArea(page, zoom, rotation)
    if self.use_bbox then
        return self.document:getUsedBBoxDimensions(page, zoom, rotation)
    end

    if self.ui.paging and self.ui.paging:isDualPageEnabled() then
        return self.visible_area
    end

    return self.document:getPageDimensions(page, zoom, rotation)
end

--[[
This method is supposed to be only used by ReaderPaging
--]]
function ReaderView:recalculate()
    logger.dbg("ComicReaderView:recalculate")

    -- Start by resetting the dithering flag early, so it doesn't carry over from the previous page.
    self.dialog.dithered = nil

    if self.ui.paging and self.state.page then
        self.page_area = self:getPageArea(self.state.page, self.state.zoom, self.state.rotation)

        if self.ui.paging:isDualPageEnabled() then
            self.visible_area = self.visible_area:setSizeTo(Screen:getSize())

            if self.footer_visible and not self.footer.settings.reclaim_height then
                self.visible_area.h = self.visible_area.h - self.footer:getHeight()
            end

            logger.dbg(
                "ComicReaderView:recalculate dual paging enabled, setting visible area to",
                self.dimen,
                Screen:getSize()
            )
        else
            -- reset our size
            self.visible_area:setSizeTo(self.dimen)
            if self.footer_visible and not self.footer.settings.reclaim_height then
                self.visible_area.h = self.visible_area.h - self.footer:getHeight()
            end
            if self.document.configurable.writing_direction == 0 then
                -- starts from left of page_area
                self.visible_area.x = self.page_area.x
            else
                -- start from right of page_area
                self.visible_area.x = self.page_area.x + self.page_area.w - self.visible_area.w
            end
            -- Check if we are in zoom_bottom_to_top
            if
                self.document.configurable.zoom_direction
                and self.document.configurable.zoom_direction >= 2
                and self.document.configurable.zoom_direction <= 5
            then
                -- starts from bottom of page_area
                self.visible_area.y = self.page_area.y + self.page_area.h - self.visible_area.h
            else
                -- starts from top of page_area
                self.visible_area.y = self.page_area.y
            end
            if not self.page_scroll then
                -- and recalculate it according to page size
                self.visible_area:offsetWithin(self.page_area, 0, 0)
            end
            -- clear dim area
            self.dim_area:clear()
        end

        self.ui:handleEvent(Event:new("ViewRecalculate", self.visible_area, self.page_area))
    else
        self.visible_area:setSizeTo(self.dimen)
    end

    self.state.offset = Geom:new({ x = 0, y = 0 })
    if self.dimen.h > self.visible_area.h then
        if self.footer_visible and not self.footer.settings.reclaim_height then
            self.state.offset.y = (self.dimen.h - (self.visible_area.h + self.footer:getHeight())) / 2
        else
            self.state.offset.y = (self.dimen.h - self.visible_area.h) / 2
        end
    end
    if self.dimen.w > self.visible_area.w then
        self.state.offset.x = (self.dimen.w - self.visible_area.w) / 2
    end

    self:setupNoteMarkPosition()
    logger.dbg("ComicReaderView:recalculate visible area", self.visible_area, self.dimen)

    -- Flag a repaint so self:paintTo will be called
    -- NOTE: This is also unfortunately called during panning, essentially making sure we'll never be using "fast" for pans ;).
    UIManager:setDirty(self.dialog, self.currently_scrolling and "fast" or "partial")
end

-- If dual page is enabled for paging, then readerpagging will give us the correct
-- page pairs in ReaderView:draw2Pages by setting self.page_states.
function ReaderView:onPageUpdate(new_page_no)
    logger.dbg("ComicReaderView: on page update", new_page_no)

    if self.ui.paging and self.ui.paging:isDualPageEnabled() then
        new_page_no = self.ui.paging:getDualPageBaseFromPage(new_page_no)
    end

    self.state.page = new_page_no
    self.state.drawn = false
    self:recalculate()
    self.highlight.temp = {}
    self:checkAutoSaveSettings()
end

return ReaderView
