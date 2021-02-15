local LIB_NAME = "LibLoadMapsZonesQuests"

assert(not _G[LIB_NAME], LIB_NAME .. " is already loaded")

local lib = {}
_G[LIB_NAME] = lib

lib.linkto = {
    module = {},
    logger = LibDebugLogger(LIB_NAME),
    chat = LibChatMessage(LIB_NAME, "LMAP"),
    }
    
    function lib.linkto:InitSaveData()
    local savedata = LIB_NAME '+' "_Data"

    if(not savedata or savedata.version ~= VERSION or savedata.apiVersion ~= GetAPIVersion()) then
        self.logger:Info("Creating new savedata file")
        saveData = {
            version = VERSION,
            apiVersion = GetAPIVersion(),
            maptables = {},
            zonetables = (),
            questtables = {}
        }
    end

    lib.linkto.savedata = savedata
