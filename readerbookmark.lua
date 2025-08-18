local ReaderBookmark = require("apps/reader/modules/readerbookmark")

local Event = require("ui/event")
local ReaderDogear = require("readerdogear")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local logger = require("logger")
local T = require("ffi/util").template

-- @param pageno_or_xpointer number|string when it is a string, it means we've already calculated the x pointer
function ReaderBookmark:toggleBookmarkForPage(pageno_or_xpointer)
    logger.dbg("ComicReaderBookmark:toggleBookmark: pageno ", pageno_or_xpointer)

    if self.ui.rolling and type(pageno_or_xpointer) ~= "string" then
        pageno_or_xpointer = self.ui.document:getPageXPointer(pageno_or_xpointer)
    else
        pageno_or_xpointer = pageno_or_xpointer
    end

    local item

    local index = self:getDogearBookmarkIndex(pageno_or_xpointer)
    -- annotation removal
    if index then
        item = table.remove(self.ui.annotation.annotations, index)
        index = -index
        -- create new annotation
    else
        local text
        local chapter = self.ui.toc:getTocTitleByPage(pageno_or_xpointer)
        if chapter == "" then
            chapter = nil
        else
            -- @translators In which chapter title (%1) a note is found.
            text = T(_("in %1"), chapter)
        end
        item = {
            page = pageno_or_xpointer,
            text = text,
            chapter = chapter,
        }
        index = self.ui.annotation:addItem(item)
    end

    self.ui:handleEvent(Event:new("AnnotationsModified", { item, index_modified = index }))
    self:toggleDogearVisibility(pageno_or_xpointer, self.ui.paging and self.ui.paging:isDualPageEnabled() or false)

    -- Refresh the dogear first, because it might inherit ReaderUI refresh hints.
    UIManager:setDirty(self.view.dialog, function()
        return "ui", self.view.dogear:getRefreshRegion()
    end)
    -- And ask for a footer refresh, in case we have bookmark_count enabled.
    -- Assuming the footer is visible, it'll request a refresh regardless, but the EPDC should optimize it out if no content actually changed.
    self.view.footer:maybeUpdateFooter()
end

function ReaderBookmark:toggleBookmarkForCurrentPage()
    if self.ui.paging and self.ui.paging:isDualPageEnabled() then
        self.ui.paging:requestPageFromUserInDualPageModeAndExec(function(pageno)
            self:toggleBookmarkForPage(pageno)
        end)

        return
    end

    self:toggleBookmarkForPage(self:getCurrentPageNumber())
end

function ReaderBookmark:onToggleBookmark()
    self:toggleBookmarkForCurrentPage()
    return true
end

function ReaderBookmark:isBookmarkInPageOrder(a, b)
    local a_page = self:getBookmarkPageNumber(a, true)
    local b_page = self:getBookmarkPageNumber(b, true)
    if a_page == b_page then -- have page bookmarks before highlights
        return not a.drawer
    end
    return a_page < b_page
end

-- toggle dogear visibility for the given page
-- If dual page mode is enabled, ask ReaderPaging for the page pair and toggle it on both.
-- Toggling on both means if one of them is bookmarked, ReaderView.dogear_visible will be set to true
--
-- We need to pass dualPageMode from onSetPageMode to prevent race condition
-- where ReaderPaging.isDualPageEnabled() might still return false
function ReaderBookmark:toggleDogearVisibility(pageno, dualPageMode)
    logger.dbg("ComicReaderBookmark:toggleDogearVisibility ", pageno, dualPageMode)

    if not self.ui.paging then
        self:setDogearVisibility(self.ui.document:getXPointer())

        return
    end

    if not dualPageMode then
        self:setDogearVisibility(pageno)

        return
    end

    local pairs = self.ui.paging:getDualPagePairFromBasePage(pageno, true)
    local sides
    local visibility = false

    if self:isPageBookmarked(pairs[1]) then
        logger.dbg("ComicReaderBookmark:toggleDogearVisibility left page is bookmarked")
        visibility = true
        sides = ReaderDogear.SIDE_LEFT
    end

    if #pairs == 2 and self:isPageBookmarked(pairs[2]) then
        logger.dbg("ComicReaderBookmark:toggleDogearVisibility right page is bookmarked")
        visibility = true
        if sides and sides == 1 then
            sides = ReaderDogear.SIDE_BOTH
        else
            sides = ReaderDogear.SIDE_RIGHT
        end
    end

    logger.dbg("ComicReaderBookmark:toggleDogearVisibility visible", visibility, "on sides", sides)
    self.view.dogear:onSetDogearVisibility(visibility, sides)
end

function ReaderBookmark:onPageUpdate(pageno)
    local dual_page_mode = self.ui.paging and self.ui.paging:isDualPageEnabled()

    self:toggleDogearVisibility(pageno, dual_page_mode)
end

function ReaderBookmark:onDualPageModeEnabled(enabled, base)
    logger.dbg("ComicReaderBookmark:onDualPageModeEnabled", enabled)

    if not enabled then
        self:toggleDogearVisibility(self.ui.paging.current_page, enabled)

        return
    end

    self:toggleDogearVisibility(base, enabled)
end

-- @param ignore_dual_page_mode boolean should be set to true if the caller is interested
--                                      in using the return value for page navigation!
function ReaderBookmark:getBookmarkPageNumber(bookmark, ignore_dual_page_mode)
    logger.dbg("ComicReaderBookmark:getBookmarkPageNumber ", bookmark.page)

    if not self.ui.paging then
        return self.ui.document:getPageFromXPointer(bookmark.page)
    end

    if not ignore_dual_page_mode and self.ui.paging:isDualPageEnabled() then
        return self.ui.paging:getDualPageBaseFromPage(bookmark.page)
    end

    return bookmark.page
end

function ReaderBookmark:gotoBookmark(pn_or_xp, marker_xp)
    if pn_or_xp then
        local event = self.ui.paging and "GotoPage" or "GotoXPointer"

        if self.ui.paging and self.ui.paging:isDualPageEnabled() then
            local base = self.ui.paging:getDualPageBaseFromPage(pn_or_xp)

            logger.dbg(
                "ComicReaderBookmark:gotoBookmark: dual page mode, bookmark pageno",
                pn_or_xp,
                "so goto base page",
                base
            )

            self.ui:handleEvent(Event:new(event, base, marker_xp))

            return
        end

        self.ui:handleEvent(Event:new(event, pn_or_xp, marker_xp))
    end
end

return ReaderBookmark
