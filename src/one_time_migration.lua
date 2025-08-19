local ReaderPaging = require("src/readerpaging")
local logger = require("logger")

local migration_date = 20250818
local last_migration_date = G_reader_settings:readSetting("last_migration_date", 0)

if last_migration_date < migration_date then
    logger.info("ComicReader: Plugin migration for 20250818")

    local paging_settings = G_reader_settings:readSetting("paging") or {}
    for k, v in pairs(ReaderPaging.default_reader_settings) do
        if paging_settings[k] == nil then
            paging_settings[k] = v
        end
    end
    G_reader_settings:saveSetting("paging", paging_settings)

    G_reader_settings:saveSetting("last_migration_date", migration_date)
end
