local order = require("ui/elements/reader_menu_order")

order.typeset = {
    "document_settings",
    "----------------------------",
    "set_render_style",
    "style_tweaks",
    "----------------------------",
    "change_font",
    "typography",
    "----------------------------",
    "switch_zoom_mode",
    "----------------------------",
    "page_overlap",
    "speed_reading_module_perception_expander",
    "----------------------------",
    "highlight_options",
    "selection_text", -- if Device:hasDPad()
    "panel_zoom_options",
    "dual_page_options",
    "djvu_render_mode",
    "start_content_selection", -- if Device:hasDPad(), put this as last one so it is easy to select with "press" and "up" keys
}

return order
