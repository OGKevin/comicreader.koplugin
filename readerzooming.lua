local ReaderZooming = require("apps/reader/modules/readerzooming")

local _ = require("gettext")
local logger = require("logger")

local ReaderZooming = ReaderZooming:extend({
    -- This flag is used to disable/ignore all zooming events and not update
    -- any zoom or zoom mode etc.
    -- The caller is, however, responsible for setting the right settings before disabling.
    disabled = false,
})

-- Update the genus/type Configurables given a specific zoom_mode...
function ReaderZooming:_updateConfigurable(zoom_mode)
    -- We may need to poke at the Configurable directly, because ReaderConfig is instantiated before us,
    -- so simply updating the DocSetting doesn't cut it...
    -- Technically ought to be conditional,
    -- because this is an optional engine feature (only if self.document.info.configurable is true).
    -- But the rest of the code (as well as most other modules) assumes this is supported on all paged engines (it is).
    local configurable = self.document.configurable

    local zoom_mode_genus, zoom_mode_type = self:mode_to_combo(zoom_mode)

    --- @fixme when zoom_mode is "free", zoom_mode_genus is nil
    -- This is because in the mode_to_combo mapping, free doesn't exist.
    -- Manual does, but is free and manual the same thing?
    logger.dbg("ReaderZooming:_updateConfigurable", zoom_mode, zoom_mode_genus, zoom_mode_type)

    -- Configurable keys aren't prefixed, unlike the actual settings...
    --- @fixme hack for nil zoom_mode_genus, needs confirmation if accaptable
    configurable.zoom_mode_genus = zoom_mode_genus and zoom_mode_genus or 0
    configurable.zoom_mode_type = zoom_mode_type

    return zoom_mode_genus, zoom_mode_type
end

local ReaderZoomingOnSpreadOrig = ReaderZooming.onSpread

function ReaderZooming:onSpread(arg, ges)
    if self.disabled then
        return
    end

    return ReaderZoomingOnSpreadOrig(self, arg, ges)
end

local ReaderZoomingOnPinchOrig = ReaderZooming.onPinch

function ReaderZooming:onPinch(arg, ges)
    if self.disabled then
        return
    end

    return ReaderZoomingOnPinchOrig(self, arg, ges)
end

local ReaderZoomingOnToggleFreeZoomOrig = ReaderZooming.onToggleFreeZoom

function ReaderZooming:onToggleFreeZoom(arg, ges)
    if self.disabled then
        return
    end

    return ReaderZoomingOnToggleFreeZoomOrig(self, arg, ges)
end

local ReaderZoomingOnZoom = ReaderZooming.onZoom

function ReaderZooming:onZoom(direction)
    logger.dbg("ComicReaderZooming:onZoom", direction, "enabled", not self.disabled)

    if self.disabled then
        return
    end

    return ReaderZoomingOnPinchOrig(self, direction)
end

local ReaderZoomingOnDefineZoomOrig = ReaderZooming.onDefineZoom

function ReaderZooming:onDefineZoom(btn, when_applied_callback)
    if self.disabled then
        return
    end

    return ReaderZoomingOnDefineZoomOrig(self, btn, when_applied_callback)
end

-- In dual page mode, zooming is a tricky concept.
-- Since we're rendering 2 pages next to each other which might not even have the same dimensions,
-- we can't use 1 zooming factor to apply a zoom to both pages.
-- Instead, we need individual factors per page.

-- Next to this, in dual page mode zooming must happen based on pageheight to algin pages,
-- e.g. in commics/manga, so zooming on anything else will misalign the pages.

-- Zooming in and out, happens per page and not for the canvas/visable area.
-- So when the user zooms in, the page is enlarged using a zooming factor, instead of the viewing area being enlarged.
-- In other words, if zooming in worked by taking a tmp screenshot and enlarging that, then this would be fine.
-- But since we're actually re-rendering the page and apply a zoom factor, we run in the same issue described above.
-- We can't apply 1 zoom factor to both pages in dual page mode, and calculating zoom on anything other then height
-- will result in misalignment.
--
-- @param enabled bool
-- @param _ number The base page on which dual page mode has been enabled, we don't care about that for zooming.
function ReaderZooming:onDualPageModeEnabled(enabled, _)
    logger.dbg("ReaderZooming:onDualPageModeEnabled:", enabled)

    if enabled then
        logger.dbg("ReaderZooming:onDualPageModeEnabled: disabling zooming")

        self:onSetZoomMode("page")
        self:_updateConfigurable("page")
        self.disabled = true

        return
    end

    logger.dbg("ReaderZooming:onDualPageModeEnabled: enabling zooming")

    self.disabled = false
    self:onSetZoomMode(self.zoom_mode)
end

local ReaderZoomingOnSetZoomModeOrig = ReaderZooming.onSetZoomMode

function ReaderZooming:onSetZoomMode(new_mode)
    if self.disabled then
        return
    end

    return ReaderZoomingOnSetZoomModeOrig(self, new_mode)
end

local ReaderZoomingSetZoomModeOrig = ReaderZooming.setZoomMode

function ReaderZooming:setZoomMode(mode, no_warning, is_reflowed)
    if self.disabled then
        return
    end

    return ReaderZoomingSetZoomModeOrig(self, mode, no_warning, is_reflowed)
end

local ReaderZoomingOnZoomFactorChangeOrig = ReaderZooming.onZoomFactorChange

function ReaderZooming:onZoomFactorChange()
    if self.disabled then
        return
    end

    return ReaderZoomingOnZoomFactorChangeOrig(self)
end

local ReaderZoomingOnSetZoomPanOrig = ReaderZooming.onSetZoomPan

function ReaderZooming:onSetZoomPan(settings, no_redraw)
    if self.disabled then
        return
    end

    return ReaderZoomingOnSetZoomPanOrig(self, settings, no_redraw)
end

return ReaderZooming
