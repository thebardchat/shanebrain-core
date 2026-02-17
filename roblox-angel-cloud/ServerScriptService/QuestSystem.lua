--[[
    QuestSystem.lua — Gives players actual missions and objectives
    Quests drive the gameplay loop: collect, explore, forge, ascend
    Server-authoritative: tracks progress, awards rewards on completion
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)
local SoundManager = require(script.Parent.SoundManager)

local QuestSystem = {}

-- RemoteEvents
local QuestUpdate    -- Server -> Client: quest progress/completion
local QuestAccept    -- Client -> Server: player accepts a quest

-- Quest definitions: id, title, description, objective type, target, reward
local QUESTS = {
    -- STARTER QUESTS (Layer 1 — teach the basics)
    {
        id = "first_motes",
        title = "First Light",
        description = "Collect 5 Light Motes floating in the Nursery",
        layer = 1,
        objective = "collect_motes",
        target = 5,
        reward = { motes = 3 },
        nextQuest = "explore_nursery",
    },
    {
        id = "explore_nursery",
        title = "Cloud Walker",
        description = "Use a Speed Pad and a Bounce Pad",
        layer = 1,
        objective = "use_pads",
        target = 2,  -- 1 speed + 1 bounce
        reward = { motes = 5 },
        nextQuest = "learn_to_fly",
    },
    {
        id = "learn_to_fly",
        title = "Spread Your Wings",
        description = "Take flight! Press F to fly, then fly for 10 seconds",
        layer = 1,
        objective = "fly_time",
        target = 10,
        reward = { motes = 5 },
        nextQuest = "visit_forge",
    },
    {
        id = "visit_forge",
        title = "The Forge Calls",
        description = "Visit the Wing Forge and upgrade your wings",
        layer = 1,
        objective = "forge_wings",
        target = 1,
        reward = { motes = 5 },
        nextQuest = "collect_ten",
    },
    {
        id = "collect_ten",
        title = "Rising Light",
        description = "Collect 10 total Motes to unlock the Meadow",
        layer = 1,
        objective = "total_motes",
        target = 10,
        reward = { motes = 5 },
        nextQuest = "reach_meadow",
    },

    -- LAYER 2 QUESTS
    {
        id = "reach_meadow",
        title = "The Meadow Awaits",
        description = "Pass through the Layer Gate to reach The Meadow",
        layer = 1,
        objective = "reach_layer",
        target = 2,
        reward = { motes = 10 },
        nextQuest = "meadow_motes",
    },
    {
        id = "meadow_motes",
        title = "Meadow Harvest",
        description = "Collect 15 more Motes in The Meadow",
        layer = 2,
        objective = "collect_motes_in_session",
        target = 15,
        reward = { motes = 8 },
        nextQuest = "first_blessing",
    },
    {
        id = "first_blessing",
        title = "Pay It Forward",
        description = "Send a Blessing to another Angel from the Blessing Bluff",
        layer = 2,
        objective = "send_blessing",
        target = 1,
        reward = { motes = 10 },
        nextQuest = "forge_level_3",
    },
    {
        id = "forge_level_3",
        title = "Wings of Power",
        description = "Upgrade your wings to Level 3 at the Wing Forge",
        layer = 1,
        objective = "wing_level",
        target = 3,
        reward = { motes = 10 },
        nextQuest = "find_starfish",
    },
    {
        id = "find_starfish",
        title = "Hidden Friends",
        description = "Find 3 hidden Brown Starfish in the clouds",
        layer = 1,
        objective = "starfish_count",
        target = 3,
        reward = { motes = 15 },
        nextQuest = "collect_fragment",
    },
    {
        id = "collect_fragment",
        title = "Ancient Wisdom",
        description = "Collect a Lore Fragment — press C to view your Codex",
        layer = 1,
        objective = "fragments",
        target = 1,
        reward = { motes = 10 },
        nextQuest = "forge_level_5",
    },
    {
        id = "forge_level_5",
        title = "Radiant Wings",
        description = "Upgrade your wings to Level 5 at the Wing Forge",
        layer = 1,
        objective = "wing_level",
        target = 5,
        reward = { motes = 15 },
        nextQuest = "growing_angel",
    },
    {
        id = "growing_angel",
        title = "Growing Angel",
        description = "Reach 25 total Motes to become a Growing Angel",
        layer = 1,
        objective = "total_motes",
        target = 25,
        reward = { motes = 10 },
        nextQuest = "master_forge",
    },
    {
        id = "master_forge",
        title = "Master Forger",
        description = "Max out your wings at the Wing Forge (Level 10)",
        layer = 1,
        objective = "wing_level",
        target = 10,
        reward = { motes = 25 },
        nextQuest = nil,  -- end of current quest chain
    },
}

-- Quick lookup
local QuestById = {}
for _, quest in ipairs(QUESTS) do
    QuestById[quest.id] = quest
end

function QuestSystem.Init()
    QuestUpdate = Instance.new("RemoteEvent")
    QuestUpdate.Name = "QuestUpdate"
    QuestUpdate.Parent = ReplicatedStorage

    QuestAccept = Instance.new("RemoteEvent")
    QuestAccept.Name = "QuestAccept"
    QuestAccept.Parent = ReplicatedStorage

    -- Client can request to accept a quest
    QuestAccept.OnServerEvent:Connect(function(player, questId)
        QuestSystem.AcceptQuest(player, questId)
    end)

    print("[QuestSystem] Quest system initialized with " .. #QUESTS .. " quests")
end

function QuestSystem.OnPlayerJoined(player: Player)
    local data = DataManager.GetData(player)
    if not data then return end

    -- Initialize quest data if missing
    if not data.activeQuest then
        data.activeQuest = "first_motes"
        data.questProgress = 0
        data.completedQuests = {}
    end

    -- Send current quest state to client
    task.delay(3, function()
        QuestSystem.SyncQuest(player)
    end)
end

function QuestSystem.AcceptQuest(player: Player, questId: string)
    local data = DataManager.GetData(player)
    if not data then return end

    local quest = QuestById[questId]
    if not quest then return end

    -- Don't accept if already completed
    if data.completedQuests and data.completedQuests[questId] then
        return
    end

    data.activeQuest = questId
    data.questProgress = 0
    QuestSystem.SyncQuest(player)
end

function QuestSystem.SyncQuest(player: Player)
    local data = DataManager.GetData(player)
    if not data then return end

    local questId = data.activeQuest
    local quest = QuestById[questId]

    if not quest then
        -- All quests done
        QuestUpdate:FireClient(player, {
            status = "all_complete",
            completedCount = data.completedQuests and #data.completedQuests or 0,
        })
        return
    end

    -- Calculate current progress based on objective type
    local progress = QuestSystem.CalculateProgress(player, quest)
    data.questProgress = progress

    QuestUpdate:FireClient(player, {
        status = "active",
        questId = quest.id,
        title = quest.title,
        description = quest.description,
        progress = progress,
        target = quest.target,
        reward = quest.reward,
    })

    -- Auto-complete if already met
    if progress >= quest.target then
        QuestSystem.CompleteQuest(player, quest)
    end
end

function QuestSystem.CalculateProgress(player: Player, quest: any): number
    local data = DataManager.GetData(player)
    if not data then return 0 end

    local objective = quest.objective

    if objective == "collect_motes" or objective == "total_motes" then
        return data.motes or 0

    elseif objective == "collect_motes_in_session" then
        return data.questProgress or 0  -- tracked incrementally

    elseif objective == "use_pads" then
        return data.questProgress or 0  -- tracked via events

    elseif objective == "fly_time" then
        return data.questProgress or 0  -- tracked via events

    elseif objective == "forge_wings" then
        return data.questProgress or 0  -- tracked when forge used

    elseif objective == "wing_level" then
        return data.wingLevel or 1

    elseif objective == "reach_layer" then
        return data.layerIndex or 1

    elseif objective == "send_blessing" then
        return data.blessingsGiven or 0

    elseif objective == "starfish_count" then
        local count = 0
        if data.starfishFound then
            for _ in pairs(data.starfishFound) do
                count = count + 1
            end
        end
        return count

    elseif objective == "fragments" then
        local count = 0
        if data.collectedFragments then
            for _ in pairs(data.collectedFragments) do
                count = count + 1
            end
        end
        return count
    end

    return 0
end

function QuestSystem.CompleteQuest(player: Player, quest: any)
    local data = DataManager.GetData(player)
    if not data then return end

    -- Mark completed
    if not data.completedQuests then
        data.completedQuests = {}
    end
    data.completedQuests[quest.id] = true

    -- Award rewards
    if quest.reward.motes then
        MoteSystem.AwardMotes(player, quest.reward.motes, "quest_complete")
    end

    -- Play completion sound
    SoundManager.PlaySFXForPlayer(player, "level_up", 0.6)

    -- Notify client
    QuestUpdate:FireClient(player, {
        status = "completed",
        questId = quest.id,
        title = quest.title,
        reward = quest.reward,
    })

    -- Auto-advance to next quest
    if quest.nextQuest then
        data.activeQuest = quest.nextQuest
        data.questProgress = 0

        -- Sync the new quest after a short delay (let completion UI show)
        task.delay(3, function()
            QuestSystem.SyncQuest(player)
        end)
    else
        data.activeQuest = nil
        data.questProgress = 0
    end

    print("[QuestSystem] " .. player.Name .. " completed quest: " .. quest.title)
end

-- EVENT HOOKS — called by other systems to update quest progress

function QuestSystem.OnMoteCollected(player: Player, amount: number)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    local quest = QuestById[data.activeQuest]
    if not quest then return end

    if quest.objective == "collect_motes_in_session" then
        data.questProgress = (data.questProgress or 0) + amount
    end

    -- Check all mote-related quests
    if quest.objective == "collect_motes" or quest.objective == "total_motes" or quest.objective == "collect_motes_in_session" then
        QuestSystem.SyncQuest(player)
    end
end

function QuestSystem.OnPadUsed(player: Player, padType: string)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    local quest = QuestById[data.activeQuest]
    if not quest or quest.objective ~= "use_pads" then return end

    data.questProgress = (data.questProgress or 0) + 1
    QuestSystem.SyncQuest(player)
end

function QuestSystem.OnFlightTime(player: Player, seconds: number)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    local quest = QuestById[data.activeQuest]
    if not quest or quest.objective ~= "fly_time" then return end

    data.questProgress = (data.questProgress or 0) + seconds
    QuestSystem.SyncQuest(player)
end

function QuestSystem.OnWingForged(player: Player)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    local quest = QuestById[data.activeQuest]
    if not quest then return end

    if quest.objective == "forge_wings" then
        data.questProgress = (data.questProgress or 0) + 1
    end

    -- Wing level quests auto-calculate from data
    QuestSystem.SyncQuest(player)
end

function QuestSystem.OnBlessingGiven(player: Player)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    QuestSystem.SyncQuest(player)
end

function QuestSystem.OnLayerReached(player: Player, layerIndex: number)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    QuestSystem.SyncQuest(player)
end

function QuestSystem.OnStarfishFound(player: Player)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    QuestSystem.SyncQuest(player)
end

function QuestSystem.OnFragmentCollected(player: Player)
    local data = DataManager.GetData(player)
    if not data or not data.activeQuest then return end

    QuestSystem.SyncQuest(player)
end

return QuestSystem
