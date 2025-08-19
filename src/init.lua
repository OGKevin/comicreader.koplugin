require("src/readerpaging")
require("src/readerview")
require("src/readerbookmark")
require("src/readerdogear")
require("src/readerhighlight")
require("src/koptoptions")
require("src/readerzooming")
require("src/reader_menu_order")
require("src/one_time_migration")

local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ComicReader = WidgetContainer:extend({
    name = "ComicReader",
    is_doc_only = true,
})

-- luacheck: ignore self
function ComicReader:onDispatcherRegisterActions(self)
    Dispatcher:registerAction("paging_set_auto_enable_dual_page_mode", {
        category = "string",
        event = "SetAutoEnableDualPageMode",
        title = _("Set auto enable dual page mode"),
        section = "paging",
        paging = true,
        args = { true, false },
        toggle = { _("true"), _("false") },
    })
    Dispatcher:registerAction("paging_set_auto_enable_dual_page_mode", {
        category = "string",
        event = "SetAutoEnableDualPageMode",
        title = _("Set auto enable dual page mode"),
        section = "paging",
        paging = true,
        args = { true, false },
        toggle = { _("true"), _("false") },
    })
    Dispatcher:registerAction("paging_toggle_dual_page_mode", {
        category = "none",
        event = "ToggleDualPageMode",
        title = _("Toggle dual page mode"),
        paging = true,
        section = "paging",
    })
    Dispatcher:registerAction("paging_set_page_mode", {
        category = "string",
        event = "SetPageMode",
        title = _("Set page mode"),
        args = { 1, 2 },
        toggle = { _("single"), _("dual") },
        paging = true,
        section = "paging",
    })
    Dispatcher:registerAction("paging_set_dual_page_mode_first_page_is_cover", {
        category = "string",
        event = "SetDualPageModeFirstPageIsCover",
        title = _("Set dual page mode first page is cover"),
        section = "paging",
        paging = true,
        args = { true, false },
        toggle = { _("true"), _("false") },
    })
    Dispatcher:registerAction("paging_set_dual_page_mode_rtl", {
        category = "string",
        event = "SetDualPageModeRTL",
        title = _("Set dual page mode RTL"),
        section = "paging",
        paging = true,
        args = { true, false },
        toggle = { _("true"), _("false") },
        separator = true,
    })
end

ComicReader:onDispatcherRegisterActions()

return ComicReader
