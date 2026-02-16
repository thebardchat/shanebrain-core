--[[
    DataManager.lua — Server-side DataStore persistence
    Saves/loads all player data: motes, level, fragments, cosmetics, blessings, stamina
    All progression is server-authoritative (anti-cheat)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Layers = require(game.ReplicatedStorage.Config.Layers)
local Fragments = require(game.ReplicatedStorage.Config.Fragments)

local DataManager = {}

local PlayerDataStore = DataStoreService:GetDataStore("PlayerDataStore_v1")
local CommunityStore = DataStoreService:GetOrderedDataStore("CommunityStats_v1")

-- In-memory cache of loaded player data
local PlayerCache = {}

-- Default data template for new players
local DEFAULT_DATA = {
    motes = 0,
    angelLevel = "Newborn",
    layerIndex = 1,
    collectedFragments = {},  -- { fragmentId = true }
    ownedCosmetics = {},      -- { cosmeticId = true }
    equippedCosmetics = {},   -- { category = cosmeticId }
    equippedWingSkin = nil,
    equippedTrail = nil,
    equippedNameGlow = nil,
    blessingsGiven = 0,
    blessingsReceived = 0,
    longestBlessingChain = 0,
    trialsCompleted = {},     -- { trialId = completionCount }
    newbornsHelped = 0,       -- for Guardian Duty / Angela's Promise
    totalPlaytime = 0,        -- seconds
    sessionStart = 0,
    linkedAngelCloud = false,
    angelCloudUserId = nil,
    robloxLinkCode = nil,
    founderHalo = false,
    starfishFound = {},       -- { starfishId = true } — brown starfish easter eggs
    redeemedDialCodes = {},   -- { code = true } — rotary phone codes redeemed
    firstJoin = 0,
    lastSeen = 0,
}

function DataManager.GetDefaultData(): { [string]: any }
    local data = {}
    for k, v in pairs(DEFAULT_DATA) do
        if type(v) == "table" then
            data[k] = {}
        else
            data[k] = v
        end
    end
    data.firstJoin = os.time()
    data.lastSeen = os.time()
    data.sessionStart = os.time()
    return data
end

function DataManager.LoadPlayer(player: Player): { [string]: any }
    local key = "player_" .. player.UserId
    local success, data = pcall(function()
        return PlayerDataStore:GetAsync(key)
    end)

    if success and data then
        -- Migrate: fill in any missing fields from DEFAULT_DATA
        for k, v in pairs(DEFAULT_DATA) do
            if data[k] == nil then
                if type(v) == "table" then
                    data[k] = {}
                else
                    data[k] = v
                end
            end
        end
        data.sessionStart = os.time()
        data.lastSeen = os.time()
    else
        data = DataManager.GetDefaultData()
        if not success then
            warn("[DataManager] Failed to load data for " .. player.Name .. ", using defaults")
        end
    end

    PlayerCache[player.UserId] = data
    return data
end

function DataManager.SavePlayer(player: Player): boolean
    local data = PlayerCache[player.UserId]
    if not data then
        return false
    end

    -- Update playtime
    data.totalPlaytime = data.totalPlaytime + (os.time() - data.sessionStart)
    data.sessionStart = os.time()
    data.lastSeen = os.time()

    local key = "player_" .. player.UserId
    local success, err = pcall(function()
        PlayerDataStore:SetAsync(key, data)
    end)

    if not success then
        warn("[DataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
    end
    return success
end

function DataManager.GetData(player: Player): { [string]: any }?
    return PlayerCache[player.UserId]
end

function DataManager.SetData(player: Player, key: string, value: any)
    local data = PlayerCache[player.UserId]
    if data then
        data[key] = value
    end
end

function DataManager.RemovePlayer(player: Player)
    DataManager.SavePlayer(player)
    PlayerCache[player.UserId] = nil
end

-- Auto-save loop (every 60 seconds)
function DataManager.StartAutoSave()
    task.spawn(function()
        while true do
            task.wait(60)
            for _, player in ipairs(Players:GetPlayers()) do
                task.spawn(function()
                    DataManager.SavePlayer(player)
                end)
            end
        end
    end)
end

-- Community stats (OrderedDataStore for server-wide communal stats)
function DataManager.IncrementCommunityStat(statName: string, amount: number)
    local success, err = pcall(function()
        CommunityStore:IncrementAsync(statName, amount)
    end)
    if not success then
        warn("[DataManager] Failed to increment community stat: " .. tostring(err))
    end
end

function DataManager.GetCommunityStats(): { [string]: number }
    local stats = {}
    local keys = { "total_blessings", "total_trials", "total_motes_earned", "longest_chain" }
    for _, key in ipairs(keys) do
        local success, value = pcall(function()
            return CommunityStore:GetAsync(key)
        end)
        stats[key] = (success and value) or 0
    end
    return stats
end

return DataManager
