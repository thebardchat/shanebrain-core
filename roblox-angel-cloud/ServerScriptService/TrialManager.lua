--[[
    TrialManager.lua — Guardian Trial orchestration
    Manages trial lobbies, instance creation, and completion rewards
    MVP: Trials 1-2 (Bridge of Trust, Echo Chamber)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)
local LoreSystem = require(script.Parent.LoreSystem)
local Layers = require(ReplicatedStorage.Config.Layers)
local Trials = require(ReplicatedStorage.Config.Trials)

local TrialManager = {}

-- RemoteEvents
local TrialJoinRequest   -- Client -> Server: player wants to join trial queue
local TrialLeaveRequest  -- Client -> Server: player leaves queue
local TrialStart         -- Server -> Client: trial begins
local TrialUpdate        -- Server -> Client: trial state change
local TrialComplete      -- Server -> Client: trial finished
local TrialAction        -- Client -> Server: player performs trial action

-- Active trial queues: { trialId = { Player } }
local TrialQueues = {}

-- Active trial instances: { instanceId = { trialId, players, state, startTime } }
local ActiveTrials = {}
local nextInstanceId = 1

function TrialManager.Init()
    TrialJoinRequest = Instance.new("RemoteEvent")
    TrialJoinRequest.Name = "TrialJoinRequest"
    TrialJoinRequest.Parent = ReplicatedStorage

    TrialLeaveRequest = Instance.new("RemoteEvent")
    TrialLeaveRequest.Name = "TrialLeaveRequest"
    TrialLeaveRequest.Parent = ReplicatedStorage

    TrialStart = Instance.new("RemoteEvent")
    TrialStart.Name = "TrialStart"
    TrialStart.Parent = ReplicatedStorage

    TrialUpdate = Instance.new("RemoteEvent")
    TrialUpdate.Name = "TrialUpdate"
    TrialUpdate.Parent = ReplicatedStorage

    TrialComplete = Instance.new("RemoteEvent")
    TrialComplete.Name = "TrialComplete"
    TrialComplete.Parent = ReplicatedStorage

    TrialAction = Instance.new("RemoteEvent")
    TrialAction.Name = "TrialAction"
    TrialAction.Parent = ReplicatedStorage

    -- Initialize queues for MVP trials
    for _, trialId in ipairs(Trials.MVP_TRIAL_IDS) do
        TrialQueues[trialId] = {}
    end

    -- Listen for client events
    TrialJoinRequest.OnServerEvent:Connect(function(player, trialId)
        TrialManager.JoinQueue(player, trialId)
    end)

    TrialLeaveRequest.OnServerEvent:Connect(function(player, trialId)
        TrialManager.LeaveQueue(player, trialId)
    end)

    TrialAction.OnServerEvent:Connect(function(player, instanceId, action)
        TrialManager.HandleAction(player, instanceId, action)
    end)
end

function TrialManager.JoinQueue(player: Player, trialId: string): boolean
    local trial = Trials.GetTrial(trialId)
    if not trial then
        return false
    end

    -- Check layer access
    local data = DataManager.GetData(player)
    if not data then
        return false
    end
    if (data.layerIndex or 1) < trial.minLayer then
        return false
    end

    -- Check not already in a queue
    for _, queue in pairs(TrialQueues) do
        for i, qPlayer in ipairs(queue) do
            if qPlayer == player then
                return false  -- already queued
            end
        end
    end

    -- Add to queue
    local queue = TrialQueues[trialId]
    if not queue then
        return false
    end
    table.insert(queue, player)

    -- Check if queue has enough players to start
    if #queue >= trial.players.min then
        local participants = {}
        for i = 1, math.min(#queue, trial.players.max) do
            table.insert(participants, table.remove(queue, 1))
        end
        TrialManager.StartTrial(trialId, participants)
    end

    return true
end

function TrialManager.LeaveQueue(player: Player, trialId: string)
    local queue = TrialQueues[trialId]
    if not queue then
        return
    end
    for i, qPlayer in ipairs(queue) do
        if qPlayer == player then
            table.remove(queue, i)
            return
        end
    end
end

function TrialManager.StartTrial(trialId: string, participants: { Player })
    local trial = Trials.GetTrial(trialId)
    if not trial then
        return
    end

    local instanceId = "trial_" .. nextInstanceId
    nextInstanceId = nextInstanceId + 1

    local instance = {
        id = instanceId,
        trialId = trialId,
        trial = trial,
        players = participants,
        state = "active",
        startTime = os.time(),
        trialData = {},  -- trial-specific state
    }

    -- Initialize trial-specific data
    if trialId == "bridge_of_trust" then
        instance.trialData = {
            bridgePiecesA = {},  -- positions player A needs to place
            bridgePiecesB = {},  -- positions player B needs to place
            placedA = 0,
            placedB = 0,
            totalPieces = 5,
        }
        -- Generate random bridge piece positions
        for i = 1, 5 do
            table.insert(instance.trialData.bridgePiecesA, {
                x = math.random(-10, 10),
                y = math.random(0, 5),
                z = i * 4,
            })
            table.insert(instance.trialData.bridgePiecesB, {
                x = math.random(-10, 10),
                y = math.random(0, 5),
                z = i * 4,
            })
        end
    elseif trialId == "echo_chamber" then
        instance.trialData = {
            crystalPosition = { x = 0, y = 3, z = 0 },
            playerReached = {},
            soundPulses = {},
        }
    end

    ActiveTrials[instanceId] = instance

    -- Notify all participants
    for i, player in ipairs(participants) do
        local clientData = {
            instanceId = instanceId,
            trialId = trialId,
            trialName = trial.name,
            duration = trial.duration,
            playerIndex = i,
            totalPlayers = #participants,
            rules = trial.rules,
        }

        -- Send trial-specific data (asymmetric for Bridge of Trust)
        if trialId == "bridge_of_trust" then
            -- Player sees the OTHER player's piece positions
            if i == 1 then
                clientData.visiblePieces = instance.trialData.bridgePiecesB
            else
                clientData.visiblePieces = instance.trialData.bridgePiecesA
            end
        end

        TrialStart:FireClient(player, clientData)
    end

    -- Start trial timer
    task.spawn(function()
        task.wait(trial.duration)
        if ActiveTrials[instanceId] and ActiveTrials[instanceId].state == "active" then
            TrialManager.FailTrial(instanceId, "Time expired")
        end
    end)
end

function TrialManager.HandleAction(player: Player, instanceId: string, action: { [string]: any })
    local instance = ActiveTrials[instanceId]
    if not instance or instance.state ~= "active" then
        return
    end

    -- Verify player is in this trial
    local playerIndex = nil
    for i, p in ipairs(instance.players) do
        if p == player then
            playerIndex = i
            break
        end
    end
    if not playerIndex then
        return
    end

    local trialId = instance.trialId

    if trialId == "bridge_of_trust" then
        if action.type == "place_piece" then
            local data = instance.trialData
            if playerIndex == 1 then
                data.placedA = data.placedA + 1
            else
                data.placedB = data.placedB + 1
            end

            -- Broadcast update to all trial players
            for _, p in ipairs(instance.players) do
                TrialUpdate:FireClient(p, {
                    instanceId = instanceId,
                    update = "piece_placed",
                    playerIndex = playerIndex,
                    placedA = data.placedA,
                    placedB = data.placedB,
                })
            end

            -- Check completion
            if data.placedA >= data.totalPieces and data.placedB >= data.totalPieces then
                TrialManager.CompleteTrial(instanceId)
            end
        end

    elseif trialId == "echo_chamber" then
        if action.type == "sound_pulse" then
            -- Broadcast pulse to OTHER players only
            for i, p in ipairs(instance.players) do
                if p ~= player then
                    TrialUpdate:FireClient(p, {
                        instanceId = instanceId,
                        update = "sound_pulse",
                        position = action.position,
                        fromPlayerIndex = playerIndex,
                    })
                end
            end
        elseif action.type == "reached_crystal" then
            instance.trialData.playerReached[playerIndex] = true

            -- Check if all players reached
            local allReached = true
            for i = 1, #instance.players do
                if not instance.trialData.playerReached[i] then
                    allReached = false
                    break
                end
            end

            if allReached then
                TrialManager.CompleteTrial(instanceId)
            end
        end
    end
end

function TrialManager.CompleteTrial(instanceId: string)
    local instance = ActiveTrials[instanceId]
    if not instance or instance.state ~= "active" then
        return
    end

    instance.state = "completed"
    local trial = instance.trial

    -- Award rewards to all participants
    for _, player in ipairs(instance.players) do
        -- Award motes
        MoteSystem.AwardMotes(player, trial.moteReward, "guardian_trial")

        -- Award fragment
        if trial.fragmentReward then
            -- Find the fragment associated with this trial
            for _, frag in ipairs(Fragments.GetByCategory("Guardian")) do
                if frag.trialId == trial.id then
                    LoreSystem.TryCollectFragment(player, frag.id)
                    break
                end
            end
        end

        -- Track completion
        local data = DataManager.GetData(player)
        if data then
            if not data.trialsCompleted[trial.id] then
                data.trialsCompleted[trial.id] = 0
            end
            data.trialsCompleted[trial.id] = data.trialsCompleted[trial.id] + 1
        end

        -- Notify client
        TrialComplete:FireClient(player, {
            instanceId = instanceId,
            trialName = trial.name,
            success = true,
            moteReward = trial.moteReward,
            fragmentReward = trial.fragmentReward,
        })

        -- Check progression
        local ProgressionSystem = require(script.Parent.ProgressionSystem)
        ProgressionSystem.OnMotesChanged(player)
    end

    -- Community stat
    DataManager.IncrementCommunityStat("total_trials", 1)

    -- Cleanup after delay
    task.delay(10, function()
        ActiveTrials[instanceId] = nil
    end)
end

function TrialManager.FailTrial(instanceId: string, reason: string)
    local instance = ActiveTrials[instanceId]
    if not instance or instance.state ~= "active" then
        return
    end

    instance.state = "failed"

    for _, player in ipairs(instance.players) do
        TrialComplete:FireClient(player, {
            instanceId = instanceId,
            trialName = instance.trial.name,
            success = false,
            reason = reason,
        })
    end

    task.delay(5, function()
        ActiveTrials[instanceId] = nil
    end)
end

-- Fragments config reference needed for trial rewards
local Fragments = require(ReplicatedStorage.Config.Fragments)

return TrialManager
