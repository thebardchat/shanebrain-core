--[[
    DataManager.lua — Server-side data persistence using ProfileStore
    Saves/loads all player data: motes, level, fragments, cosmetics, blessings, stamina
    All progression is server-authoritative (anti-cheat)

    Uses ProfileStore for:
    - Session locking (no data duplication across servers)
    - Auto-saving every 5 minutes
    - Graceful shutdown saving
    - Automatic data migration via Reconcile()
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Layers = require(game.ReplicatedStorage.Config.Layers)
local Fragments = require(game.ReplicatedStorage.Config.Fragments)

local DataManager = {}

-- Try to load ProfileStore (graceful fallback for unpublished places)
local ProfileStore
local ProfileStoreAvailable = false

local ok, result = pcall(function()
    return require(script.Parent.ProfileStore)
end)
if ok and result then
    ProfileStore = result
    ProfileStoreAvailable = true
    print("[DataManager] ProfileStore loaded successfully")
else
    warn("[DataManager] ProfileStore failed to load: " .. tostring(result))
end

-- Create the player store
local PlayerStore
if ProfileStoreAvailable then
    local storeOk, storeResult = pcall(function()
        return ProfileStore.New("PlayerData_v2", {
            motes = 0,
            angelLevel = "Newborn",
            layerIndex = 1,
            collectedFragments = {},
            ownedCosmetics = {},
            equippedCosmetics = {},
            equippedWingSkin = "",
            equippedTrail = "",
            equippedNameGlow = "",
            blessingsGiven = 0,
            blessingsReceived = 0,
            longestBlessingChain = 0,
            trialsCompleted = {},
            newbornsHelped = 0,
            totalPlaytime = 0,
            sessionStart = 0,
            linkedAngelCloud = false,
            angelCloudUserId = "",
            robloxLinkCode = "",
            founderHalo = false,
            starfishFound = {},
            redeemedDialCodes = {},
            wingLevel = 1,
            activeQuest = "first_motes",
            questProgress = 0,
            completedQuests = {},
            firstJoin = 0,
            lastSeen = 0,
        })
    end)
    if storeOk then
        PlayerStore = storeResult
    else
        warn("[DataManager] Failed to create ProfileStore: " .. tostring(storeResult))
        ProfileStoreAvailable = false
    end
end

-- Community stats (separate OrderedDataStore — ProfileStore doesn't handle these)
local CommunityStore
local CommunityStoreAvailable = false
local csOk, csResult = pcall(function()
    return DataStoreService:GetOrderedDataStore("CommunityStats_v1")
end)
if csOk and csResult then
    CommunityStore = csResult
    CommunityStoreAvailable = true
end

-- Active profiles: UserId -> Profile
local Profiles = {}

-- In-memory fallback cache (used when ProfileStore unavailable, e.g. Studio)
local FallbackCache = {}

-- Default data template (used for fallback mode)
local DEFAULT_DATA = {
    motes = 0,
    angelLevel = "Newborn",
    layerIndex = 1,
    collectedFragments = {},
    ownedCosmetics = {},
    equippedCosmetics = {},
    equippedWingSkin = "",
    equippedTrail = "",
    equippedNameGlow = "",
    blessingsGiven = 0,
    blessingsReceived = 0,
    longestBlessingChain = 0,
    trialsCompleted = {},
    newbornsHelped = 0,
    totalPlaytime = 0,
    sessionStart = 0,
    linkedAngelCloud = false,
    angelCloudUserId = "",
    robloxLinkCode = "",
    founderHalo = false,
    starfishFound = {},
    redeemedDialCodes = {},
    wingLevel = 1,
    activeQuest = "first_motes",
    questProgress = 0,
    completedQuests = {},
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
    if not ProfileStoreAvailable or not PlayerStore then
        -- Fallback: in-memory only (Studio / unpublished)
        local data = DataManager.GetDefaultData()
        FallbackCache[player.UserId] = data
        print("[DataManager] In-memory profile for " .. player.Name)
        return data
    end

    -- ProfileStore session-locked load
    local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })

    if profile ~= nil then
        profile:AddUserId(player.UserId)  -- GDPR compliance
        profile:Reconcile()               -- Fill missing fields from template

        profile.OnSessionEnd:Connect(function()
            Profiles[player.UserId] = nil
            if player.Parent == Players then
                player:Kick("Your data session ended. Please rejoin.")
            end
        end)

        if player.Parent == Players then
            Profiles[player.UserId] = profile

            -- Set session timestamps
            if profile.Data.firstJoin == 0 then
                profile.Data.firstJoin = os.time()
            end
            profile.Data.sessionStart = os.time()
            profile.Data.lastSeen = os.time()

            print("[DataManager] ProfileStore session started for " .. player.Name)
            return profile.Data
        else
            -- Player left during load
            profile:EndSession()
            return DataManager.GetDefaultData()
        end
    else
        -- Profile load failed
        warn("[DataManager] ProfileStore load failed for " .. player.Name .. " — using in-memory")
        local data = DataManager.GetDefaultData()
        FallbackCache[player.UserId] = data
        return data
    end
end

function DataManager.SavePlayer(player: Player): boolean
    local profile = Profiles[player.UserId]
    if profile then
        -- ProfileStore auto-saves, but we can update timestamps
        profile.Data.totalPlaytime = profile.Data.totalPlaytime + (os.time() - profile.Data.sessionStart)
        profile.Data.sessionStart = os.time()
        profile.Data.lastSeen = os.time()
        return true
    end

    -- Fallback mode — no persistent save
    local data = FallbackCache[player.UserId]
    if data then
        data.totalPlaytime = data.totalPlaytime + (os.time() - data.sessionStart)
        data.sessionStart = os.time()
        data.lastSeen = os.time()
    end
    return true
end

function DataManager.GetData(player: Player): { [string]: any }?
    local profile = Profiles[player.UserId]
    if profile then
        return profile.Data
    end
    return FallbackCache[player.UserId]
end

function DataManager.SetData(player: Player, key: string, value: any)
    local data = DataManager.GetData(player)
    if data then
        data[key] = value
    end
end

function DataManager.RemovePlayer(player: Player)
    -- Update playtime before ending session
    DataManager.SavePlayer(player)

    local profile = Profiles[player.UserId]
    if profile then
        profile:EndSession()
        -- Profiles[player.UserId] is cleared by OnSessionEnd handler
    end

    FallbackCache[player.UserId] = nil
end

-- Auto-save: ProfileStore handles this automatically (every 300s)
-- We just keep timestamps updated periodically
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

-- Community stats (OrderedDataStore — separate from ProfileStore)
function DataManager.IncrementCommunityStat(statName: string, amount: number)
    if not CommunityStoreAvailable then return end
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
    if not CommunityStoreAvailable then
        for _, key in ipairs(keys) do
            stats[key] = 0
        end
        return stats
    end
    for _, key in ipairs(keys) do
        local success, value = pcall(function()
            return CommunityStore:GetAsync(key)
        end)
        stats[key] = (success and value) or 0
    end
    return stats
end

return DataManager
