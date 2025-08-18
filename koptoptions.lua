local KoptOptions = require("ui/data/koptoptions")

local Device = require("device")
local _ = require("gettext")
local optionsutil = require("ui/data/optionsutil")
local Screen = Device.screen

-- Utility: find option by name
local function find_option(name)
    for _, tab in ipairs(KoptOptions) do
        for _, opt in ipairs(tab.options) do
            if opt.name == name then
                return opt
            end
        end
    end
end

-- Patch zoom_overlap_h & zoom_overlap_v show_func
for _, name in ipairs({ "zoom_overlap_h", "zoom_overlap_v" }) do
    local opt = find_option(name)
    if opt then
        opt.show_func = function(configurable)
            return configurable.zoom_mode_genus and configurable.zoom_mode_genus < 3
        end
    end
end

-- Patch zoom_mode_type
do
    local opt = find_option("zoom_mode_type")
    if opt then
        opt.enabled_func = function(configurable)
            return optionsutil.enableIfEquals(configurable, "text_wrap", 0) and configurable.page_mode ~= 2
        end
        opt.show_func = function(configurable)
            return configurable.zoom_mode_genus and configurable.zoom_mode_genus > 2
        end
    end
end

-- Patch zoom_mode_genus
do
    local opt = find_option("zoom_mode_genus")
    if opt then
        opt.enabled_func = function(configurable)
            return optionsutil.enableIfEquals(configurable, "text_wrap", 0) and configurable.page_mode ~= 2
        end
    end
end

-- Insert page_mode option into the "pageview" tab
do
    -- luacheck: ignore __
    for __, tab in ipairs(KoptOptions) do
        if tab.icon == "appbar.pageview" then
            local opts = tab.options
            local insert_at = 2
            table.insert(opts, insert_at, {
                name = "page_mode",
                name_text = _("Page Mode"),
                toggle = { _("single"), _("dual") },
                values = { 1, 2 },
                default_value = 1,
                event = "SetPageMode",
                args = { 1, 2 },
                -- luacheck: ignore document
                enabled_func = function(configurable, document)
                    return optionsutil.enableIfEquals(configurable, "page_scroll", 0)
                        and Screen:getScreenMode() == "landscape"
                end,
                name_text_hold_callback = optionsutil.showValues,
                help_text = _([[- 'single' mode shows only one page of the document at a time.
- 'dual' mode shows two pages at a time

Zooming is disabled in this mode, for more info, consult the wiki.

This option only works when the device is in landscape mode.
]]),
            })
            break
        end
    end
end

return KoptOptions
