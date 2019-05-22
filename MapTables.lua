--[[###############################################################################################################################

MapTables - A standalone add-on to create and maintain Map tables for the QuestMap2 project
	by Drakanwulf and Hawkeye1889

A standalone support add-on to create and initialize or to retrieve and update Map information for all accounts and characters on 
any game megaserver.

WARNING: This add-on is a standalone library. Do NOT embed its folder within any other add-on!

###############################################################################################################################--]]

--[[-------------------------------------------------------------------------------------------------------------------------------
Local variables shared by multiple functions within this add-on.
---------------------------------------------------------------------------------------------------------------------------------]]
local ADDON_NAME = "MapTables"
local addon = {}

--[[-------------------------------------------------------------------------------------------------------------------------------
Bootstrap code to load this add-on.
---------------------------------------------------------------------------------------------------------------------------------]]
assert( not _G[ADDON_NAME], ADDON_NAME.. ": This add-on is already loaded. Do NOT load it multiple times!" )
 
_G[ADDON_NAME] = addon
assert( _G[ADDON_NAME], ADDON_NAME.. ": the game failed to create a control entry!" )

--[[-------------------------------------------------------------------------------------------------------------------------------
Define local variables and tables including a "defaults" Saved Variables table.
---------------------------------------------------------------------------------------------------------------------------------]]
-- Create empty Map information, reference, and cross-reference tables
local coordByIndex = {}			-- Global x,y coordinates (topleft corner) by mapIndex
local indexByMapId = {}			-- Map Index cross-reference by mapId
local indexByName = {}			-- Mapindex by Map Name
local infoByIndex = {}			-- Map information by mapIndex
local mapIdByIndex = {}			-- Map Identifier cross-reference by mapIndex
local mapIdByName = {}			-- Map Identifier by mapName
local nameByMapId = {}			-- Map Name by mapId
local zoneIdByIndex = {}		-- Zone Identifier cross-reference by mapIndex

-- This Saved Variables "defaults" table contains pointers to all the Maps tables
local defaults = {
	addonVersion = 0,				-- AddOnVersion value in use the last time these tables were loaded
	apiVersion = 0,					-- ESO API Version in use the last time these tables were loaded
	numMaps = 0,					-- Number of maps in the world the last time these tables were loaded
	coord = coordByIndex,
	info = infoByIndex,
	inxmid = indexByMapId,
	inxnam = indexByName,
	midinx = mapIdByIndex,
	midnam = mapIdByName,
	nammid = nameByMapId,
	zidinx = zoneIdByIndex,
}

--[[-------------------------------------------------------------------------------------------------------------------------------
Obtain a local link to "LibGPS2" and define a measurements table for its use.
---------------------------------------------------------------------------------------------------------------------------------]]
local GPS = LibStub:GetLibrary( "LibGPS2", SILENT )
assert( GPS, ADDON_NAME.. ": LibStub refused to create a link to LibGPS2!" )

local measurement = {
	scaleX = 0,
	scaleY = 0,
	offsetX = 0,
	offsetY = 0,
	mapIndex = 0,
	zoneIndex = 0,
}

--[[-------------------------------------------------------------------------------------------------------------------------------
Local functions to load the Maps reference tables.
---------------------------------------------------------------------------------------------------------------------------------]]
-- Loads the data for one Map into the reference tables
local function LoadOneMap( mdx: number )			-- The Map Index of this Map
	-- Get the reference information for this mapIndex
	local name, mtype, ctype, zid = GetMapInfo( mdx )

	-- Load the reference tables for this Map
	indexByName[name] = mdx											-- Indexes table
	infoByIndex[mdx] = { mapType = mtype, content = ctype }			-- Info table
	if zid and type( zid ) == "number" and zid > 0 then				-- Map Index to Zone Identifier xref table
		zoneIdByIndex[mdx] = zid
	end

	-- Get the global x,y coordinate values
	SetMapToMapListIndex( mdx )										-- Change maps
	-- Verify we point to the same map before we generate cross-reference tables
	assert( GetCurrentMapIndex() == mdx, "MapTables:LoadOneMap, mapIndexes are not equal!" )
	
	measurement = GPS:GetCurrentMapMeasurements() or {}				-- "or {}" because The Aurbis map returns nil!
	coordByIndex[mdx] = { measurement.offsetX or 0, measurement.offsetY or 0 }

	-- Generate the Map Identifier reference and cross-reference tables for this Map.
	local mid = GetCurrentMapId()		-- Must be executed after we change game maps!
	if mid and mid > 0 then				-- Generate table entries only for valid Map Identifiers!
		indexByMapId[mid] = mdx
		mapIdByIndex[mdx] = mid
		mapIdByName[name] = mid
		nameByMapId[mid] = name
	end
end

-- Resets and loads the reference tables for every Map in the world
local function LoadAllMaps( tmax: number )			-- tmax := The number of maps in the world
	-- Reset the reference tables
	coordByIndex = {}
	indexByMapId = {}
	indexByName = {}
	infoByIndex = {}
	mapIdByIndex = {}
	mapIdByName = {}
	nameByMapId = {}
	zoneIdByIndex = {}
	-- Loop through all the maps
	local mdx										-- mapIndex
	for mdx = 1, tmax do
		LoadOneMap( mdx )							-- Load the data for one Map
	end
end

-- Updates any missing entries in each reference table for every Map in the world
local function UpdateAllMaps( tmax: number )	-- tmax := The number of maps in the world
	-- Loop through all the maps
	local mdx										-- mapIndex
	for mdx = 1, tmax do
		if not coordByIndex[mdx] or coordByIndex[mdx] == {}
		or not infoByIndex[mdx] or infoByIndex[mdx] == {}
		or not mapIdByIndex[mdx] or mapIdByIndex[mdx] == 0
		or not zoneIdByIndex[mdx] or zoneIdByIndex[mdx] == 0 then
			LoadOneMap( mdx )						-- Load the data for one Map
		end
	end
end

--[[-------------------------------------------------------------------------------------------------------------------------------
The "OnAddonLoaded" function reads the saved variables table (sv) from the saved variables file, "...\SavedVariables\MapTables.lua"
if the file exists; otherwise, the function loads partially filled, default tables into the "sv" variable. Finally, the function
links everything in its local tables to their equivalent MapTables table entries.
---------------------------------------------------------------------------------------------------------------------------------]]
local function OnAddonLoaded( event, name )
	if name ~= ADDON_NAME then
		return
	end
	EVENT_MANAGER:UnregisterForEvent( ADDON_NAME, EVENT_ADD_ON_LOADED )

	-- Define megaserver constants and a saved variables filenames table. Default is the PTS megaserver.
	local SERVER_EU = "EU Megaserver" 
	local SERVER_NA = "NA Megaserver"
	local SERVER_PTS = "PTS"

	local savedVarsNameTable = {
		[SERVER_EU] = "MapTables_EU_Vars",
		[SERVER_NA] = "MapTables_NA_Vars",
		[SERVER_PTS] = "MapTables_PTS_Vars",
	}	 	

	-- Retrieve the saved variables data or load their default values
	local savedVarsFile = savedVarsNameTable[GetWorldName()] or savedVarsNameTable[SERVER_PTS]
	local sv = _G[savedVarsFile] or defaults
	
	--Update the Maps reference tables from their Saved Data variables
	coordByIndex = sv.coord
	infoByIndex = sv.info
	indexByMapId = sv.inxmid
	indexByName = sv.inxnam
	mapIdByIndex = sv.midinx
	mapIdByName = sv.midnam
	nameByMapId = sv.nammid
	zoneIdByIndex = sv.zidinx

	-- Wait for a player to become active; LibGPS2 needs this
	EVENT_MANAGER:RegisterForEvent( ADDON_NAME, EVENT_PLAYER_ACTIVATED,
		function( event, initial )
			EVENT_MANAGER:UnregisterForEvent( ADDON_NAME, EVENT_PLAYER_ACTIVATED )
		end
	)
	assert( GPS:IsReady(), ADDON_NAME.. ": LibGPS2 cannot function until a player is active!" )

	-- Save wherever we are in the world
	SetMapToPlayerLocation()					-- Set the current map to wherever we are in the world
	GPS:PushCurrentMap()						-- Save the current map settings

	-- Get the current values for the AddOnVersion, APIVersion, and number of maps
	local addonVersion = addon.addonVersion
	local currentAPI = GetAPIVersion()
	local numMaps = GetNumMaps()
	-- If the APIVersion, the AddOnVersion, or the number of maps changed, reload all Maps tables
	if currentAPI ~= sv.apiVersion
	or addonVersion ~= sv.addonVersion
	or numMaps ~= sv.numMaps then
		LoadAllMaps( numMaps )
	-- If any Maps tables are missing from or empty, reload all Maps tables
	elseif not coordByIndex or coordByIndex == {}
		or not indexByMapId or indexByMapId == {}
		or not indexByName or indexByName == {}
		or not infoByIndex or infoByIndex == {}
		or not mapIdByIndex or mapIdByIndex == {}
		or not mapIdByName or mapIdByName == {}
		or not nameByMapId or nameByMapId == {}
		or not zoneIdByIndex or zoneIdByIndex == {} then
			LoadAllMaps( numMaps )
	-- Otherwise, update all Maps tables with missing and/or new entries
	else
		UpdateAllMaps( numMaps )
	end

	-- Put us back to wherever we were in the world
	GPS:PopCurrentMap()

	-- Transfer the loaded or updated reference tables back into their Saved Data variables
	sv.coord = coordByIndex
	sv.info = infoByIndex
	sv.inxmid = indexByMapId
	sv.inxnam = indexByName
	sv.midinx = mapIdByIndex
	sv.midnam = mapIdByName
	sv.nammid = nameByMapId
	sv.zidinx = zoneIdByIndex
	-- Update the Saved Data control variables. Note that these variable values do not change for table Updates
	sv.addonVersion = addonVersion
	sv.apiVersion = currentAPI
	sv.numMaps = numMaps
	-- Create a new or update an existing Saved Variables data file (e.g. "...\SavedVariables\MapTables.lua")
	_G[savedVarsFile] = sv
end

--[[-------------------------------------------------------------------------------------------------------------------------------
MapTables public API function definitions. MapTables does not duplicate any of the game API functions listed below:

The game API documentation defines these Map Index API functions.
	Line 10260: * GetCyrodiilMapIndex()
	Line 10263: * GetImperialCityMapIndex()
	Line 10272: * GetMapNameByIndex(*luaindex* _mapIndex_)
	Line 10377: * GetAutoMapNavigationCommonZoomOutMapIndex()

The game API documentation defines these Map Identifer API functions.
	Line 10306: * GetMapNumTilesForMapId(*integer* _mapId_)
	Line 10309: * GetMapTileTextureForMapId(*integer* _mapId_, *luaindex* _tileIndex_)

The game API documentation defines these functions for getting the identifier, index, and/or name values for the current Map. 
MapTables uses the "SetMapToMapListIndex()" game API function to traverse games Maps by their Map Indexes.
	Line 10251: * GetCurrentMapIndex()
	Line 10254: * GetCurrentMapId()
	Line 10312: * GetMapName()

---------------------------------------------------------------------------------------------------------------------------------]]

-- Get the content type for this map
function MapTables:GetContentType( mapIndex: number )
	return infoByIndex[mapIndex].content or nil
end

-- Get the global x,y coordinates for this Map
function MapTables:GetCoord( mapIndex: number )
	return coordByIndex[mapIndex][1] or nil, coordByIndex[mapIndex][2] or nil
end

-- Get the Map Identifier for this Map Index
function MapTables:GetIdByIndex( mapIndex: number )
	return mapIdByIndex[mapIndex] or nil
end

-- Get the Map Identifier for this Map Name
function MapTables:GetIdByName( mapName: string )
	return mapIdByName[mapName] or nil
end

-- Get the Map Index for this Map Name
function MapTables:GetIndex( mapName: string )
	return indexByName[mapName] or nil
end

-- Get the Map Index for this Map Identifier
function MapTables:GetIndexById( mapId: number )
	return indexByMapId[mapId] or nil
end

-- Get the map type for this Map
function MapTables:GetMapType( mapIndex: number )
	return infoByIndex[mapIndex].mapType or nil
end

-- Get the Map Name for this Map Identifier
function MapTables:GetNameById( mapId: number )
	return nameByMapId[mapId] or nil
end

-- Get the equivalent Zone Identifier for this Map
function MapTables:GetZoneId( mapIndex: number )
	return zoneIdByIndex[mapIndex] or nil
end

--[[-------------------------------------------------------------------------------------------------------------------------------
And the last thing we do in this add-on is to wait for ESO to notify us that our add-on modules and support add-ons (i.e. libraries) have been loaded.
---------------------------------------------------------------------------------------------------------------------------------]]
EVENT_MANAGER:RegisterForEvent( ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded )
