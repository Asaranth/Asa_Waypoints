local AW = LibStub('AceAddon-3.0'):NewAddon('AW', 'AceConsole-3.0', 'AceEvent-3.0')

local waypointQueue = {}
local activeWaypoint

function AW:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New('AW_DB', {}, true)
    self:RegisterChatCommand('way', 'HandleWaypointCommands')
    self:RegisterEvent('NAVIGATION_DESTINATION_REACHED', 'OnNavigationDestinationReached')
end

function AW:HandleWaypointCommands(input)
    if not input or input:trim() == "" then
        return
    end
    local commands = self:SplitStr(input)
    if #commands > 0 and commands[1] == 'help' then
        self:PrintHelp()
    elseif #commands > 0 and commands[1] == 'clear' then
        self:ClearWaypoint()
        activeWaypoint = nil
        if #commands > 1 and commands[2] == 'all' then
            waypointQueue = {}
            self:Print('All waypoints cleared.')
        else
            self:Print('Waypoint cleared.')
            if #waypointQueue > 0 then
                self:SetWaypoint(table.remove(waypointQueue, 1))
            end
        end
    else
        local locationId, xCoord, yCoord = nil, nil, nil
        local withMapIdPattern = "#(%d+)%s+([%d%.]+)[,%s]+([%d%.]+)"
        local withoutMapIdPattern = "([%d%.]+)[,%s]+([%d%.]+)"

        local matchedInput = false

        if input:match("^#%d+") then
            locationId, xCoord, yCoord = input:match(withMapIdPattern)
            matchedInput = true
        end

        if not matchedInput then
            xCoord, yCoord = input:match(withoutMapIdPattern)
        end

        xCoord = tonumber(xCoord)
        yCoord = tonumber(yCoord)
        locationId = tonumber(locationId) or C_Map.GetBestMapForUnit('player')

        if not xCoord or not yCoord then
            self:Print('Invalid coordinates provided.')
            return
        end

        local options = { locationId, xCoord / 100, yCoord / 100 }

        table.insert(waypointQueue, options)
        if not activeWaypoint then
            self:SetWaypoint(table.remove(waypointQueue, 1))
        else
            local mapInfo = C_Map.GetMapInfo(locationId)
            local locationName = mapInfo and mapInfo.name or tostring(locationId)
            self:Print(string.format('Waypoint added to queue at position %d (zone: %s, x: %.1f, y: %.1f)',
                #waypointQueue, locationName, xCoord, yCoord))
        end
    end
end

function AW:OnNavigationDestinationReached()
    if #waypointQueue > 0 then
        self:SetWaypoint(table.remove(waypointQueue, 1))
    else
        self:ClearWaypoint()
        activeWaypoint = nil
    end
end

function AW:SetWaypoint(coords)
    local mapID = coords[1]
    local xCoord = coords[2]
    local yCoord = coords[3]

    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, xCoord, yCoord))
    local link = C_Map.GetUserWaypointHyperlink()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local locationName = mapInfo and mapInfo.name or tostring(mapID)
    self:Print(string.format('Waypoint created at (zone: %s, x: %.1f, y: %.1f): ', locationName, (xCoord * 100), (yCoord * 100)) .. link)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    activeWaypoint = { mapID, xCoord, yCoord }
end

function AW:ClearWaypoint()
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
end

function AW:PrintHelp()
    local commands = {
        { command = '/way help',           description = 'Displays this help message.' },
        { command = '/way #mapID x y',     description = 'Sets a waypoint at coordinates x, y in the specified mapID.' },
        { command = '/way x y',            description = 'Sets a waypoint at coordinates x, y in the current zone.' },
        { command = '/way clear',          description = 'Clears the current active waypoint and sets the next one in queue.' },
        { command = '/way clear all',      description = 'Clears the current active waypoint and the entire queue.' },
    }
    self:Print('Available commands:')
    for _, cmd in ipairs(commands) do
        self:Print(string.format('%s - %s', cmd.command, cmd.description))
    end
end

function AW:SplitStr(str)
    local tbl = {}
    for x in str:gmatch('%S+') do
        table.insert(tbl, x)
    end
    return tbl
end
