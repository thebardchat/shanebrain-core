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
local SoundManager = require(script.Parent.SoundManager)
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

    -- Build the trial arena (visible geometry!)
    local arenaFolder = TrialManager.BuildTrialArena(instanceId, trialId, participants)
    instance.arenaFolder = arenaFolder

    -- Teleport players to arena
    local arenaCenter = instance.arenaCenter or Vector3.new(0, 2000, 0)
    for i, player in ipairs(participants) do
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local offset = Vector3.new((i - 1) * 10 - 5, 5, 0)
                hrp.CFrame = CFrame.new(arenaCenter + offset)
            end
        end
    end

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

    -- Play trial start sound for everyone
    SoundManager.OnTrialStart()

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

    -- Play trial complete sound for everyone
    SoundManager.OnTrialComplete()

    -- Community stat
    DataManager.IncrementCommunityStat("total_trials", 1)

    -- Cleanup after delay
    task.delay(10, function()
        TrialManager.CleanupArena(instanceId)
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
        TrialManager.CleanupArena(instanceId)
        ActiveTrials[instanceId] = nil
    end)
end

-- Fragments config reference needed for trial rewards
local Fragments = require(ReplicatedStorage.Config.Fragments)

-- =========================================================================
-- TRIAL ARENA GENERATION — visible geometry for each trial type
-- =========================================================================

local TweenService = game:GetService("TweenService")

function TrialManager.BuildTrialArena(instanceId: string, trialId: string, participants: { Player }): Folder
    local folder = Instance.new("Folder")
    folder.Name = "TrialArena_" .. instanceId
    folder.Parent = workspace

    -- Place arenas high up so they don't collide with main world
    local arenaY = 2000 + (nextInstanceId % 10) * 200
    local center = Vector3.new(0, arenaY, 0)

    -- Store center on the instance for teleportation
    local instance = ActiveTrials[instanceId]
    if instance then
        instance.arenaCenter = center
    end

    if trialId == "bridge_of_trust" then
        TrialManager.BuildBridgeArena(folder, center)
    elseif trialId == "echo_chamber" then
        TrialManager.BuildEchoArena(folder, center)
    end

    return folder
end

function TrialManager.BuildBridgeArena(folder: Folder, center: Vector3)
    -- Two starting platforms with a 50-stud gap
    for side = -1, 1, 2 do
        local platform = Instance.new("Part")
        platform.Name = "BridgePlatform_" .. (side == -1 and "A" or "B")
        platform.Size = Vector3.new(20, 3, 16)
        platform.Position = center + Vector3.new(side * 30, 0, 0)
        platform.Anchored = true
        platform.Material = Enum.Material.SmoothPlastic
        platform.Color = Color3.fromRGB(200, 220, 255)
        platform.Parent = folder

        -- Glowing edge
        local edge = Instance.new("Part")
        edge.Name = "PlatformEdge"
        edge.Size = Vector3.new(20, 0.5, 16)
        edge.Position = platform.Position + Vector3.new(0, 1.8, 0)
        edge.Anchored = true
        edge.CanCollide = false
        edge.Material = Enum.Material.Neon
        edge.Color = Color3.fromRGB(0, 212, 255)
        edge.Transparency = 0.5
        edge.Parent = folder
    end

    -- Bridge gap indicator (glowing line where bridge pieces go)
    for i = 1, 5 do
        local slot = Instance.new("Part")
        slot.Name = "BridgeSlot_" .. i
        slot.Size = Vector3.new(8, 0.3, 4)
        slot.Position = center + Vector3.new(-20 + i * 8, -0.5, 0)
        slot.Anchored = true
        slot.CanCollide = false
        slot.Material = Enum.Material.Neon
        slot.Color = Color3.fromRGB(0, 212, 255)
        slot.Transparency = 0.6
        slot.Parent = folder

        -- Pulse the slots
        TweenService:Create(slot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Transparency = 0.9,
        }):Play()
    end

    -- Arena boundary (glowing walls so players don't fall into void)
    for angle = 0, 300, 60 do
        local rad = math.rad(angle)
        local wall = Instance.new("Part")
        wall.Name = "ArenaWall"
        wall.Size = Vector3.new(30, 40, 1)
        wall.Position = center + Vector3.new(math.cos(rad) * 55, 15, math.sin(rad) * 55)
        wall.Orientation = Vector3.new(0, -angle, 0)
        wall.Anchored = true
        wall.CanCollide = true
        wall.Material = Enum.Material.ForceField
        wall.Color = Color3.fromRGB(0, 150, 200)
        wall.Transparency = 0.8
        wall.Parent = folder
    end

    -- Timer display (billboard above center)
    local timerPart = Instance.new("Part")
    timerPart.Name = "TimerDisplay"
    timerPart.Size = Vector3.new(1, 1, 1)
    timerPart.Position = center + Vector3.new(0, 25, 0)
    timerPart.Anchored = true
    timerPart.CanCollide = false
    timerPart.Transparency = 1
    timerPart.Parent = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(8, 0, 3, 0)
    billboard.Adornee = timerPart
    billboard.AlwaysOnTop = true
    billboard.Parent = timerPart

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "BRIDGE OF TRUST"
    titleLabel.TextColor3 = Color3.fromRGB(0, 212, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = billboard

    local instrLabel = Instance.new("TextLabel")
    instrLabel.Size = UDim2.new(1, 0, 0.3, 0)
    instrLabel.Position = UDim2.new(0, 0, 0.4, 0)
    instrLabel.BackgroundTransparency = 1
    instrLabel.Text = "Guide your partner to place bridge pieces!"
    instrLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    instrLabel.TextScaled = true
    instrLabel.Font = Enum.Font.GothamMedium
    instrLabel.Parent = billboard

    -- Ambient particles in the gap
    local gapEmitter = Instance.new("Part")
    gapEmitter.Size = Vector3.new(40, 1, 16)
    gapEmitter.Position = center - Vector3.new(0, 2, 0)
    gapEmitter.Anchored = true
    gapEmitter.CanCollide = false
    gapEmitter.Transparency = 1
    gapEmitter.Parent = folder

    local mist = Instance.new("ParticleEmitter")
    mist.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
    mist.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 3),
    })
    mist.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    mist.Lifetime = NumberRange.new(3, 6)
    mist.Rate = 10
    mist.Speed = NumberRange.new(1, 3)
    mist.SpreadAngle = Vector2.new(180, 30)
    mist.Parent = gapEmitter
end

function TrialManager.BuildEchoArena(folder: Folder, center: Vector3)
    -- Circular platform
    local platform = Instance.new("Part")
    platform.Name = "EchoPlatform"
    platform.Shape = Enum.PartType.Cylinder
    platform.Size = Vector3.new(3, 60, 60)
    platform.Position = center
    platform.Orientation = Vector3.new(0, 0, 90)
    platform.Anchored = true
    platform.Material = Enum.Material.SmoothPlastic
    platform.Color = Color3.fromRGB(220, 210, 240)
    platform.Parent = folder

    -- Central crystal (the goal)
    local crystal = Instance.new("Part")
    crystal.Name = "EchoCrystal"
    crystal.Size = Vector3.new(3, 6, 3)
    crystal.Position = center + Vector3.new(0, 5, 0)
    crystal.Rotation = Vector3.new(0, 45, 0)
    crystal.Anchored = true
    crystal.CanCollide = false
    crystal.Material = Enum.Material.Neon
    crystal.Color = Color3.fromRGB(180, 100, 255)
    crystal.Parent = folder

    local crystalLight = Instance.new("PointLight")
    crystalLight.Color = Color3.fromRGB(180, 100, 255)
    crystalLight.Brightness = 3
    crystalLight.Range = 30
    crystalLight.Parent = crystal

    -- Crystal particles
    local crystalEmitter = Instance.new("ParticleEmitter")
    crystalEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 100, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    crystalEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    })
    crystalEmitter.Lifetime = NumberRange.new(1, 3)
    crystalEmitter.Rate = 8
    crystalEmitter.Speed = NumberRange.new(1, 3)
    crystalEmitter.SpreadAngle = Vector2.new(360, 360)
    crystalEmitter.LightEmission = 1
    crystalEmitter.Parent = crystal

    -- Crystal rotation
    task.spawn(function()
        while crystal and crystal.Parent do
            crystal.Orientation = crystal.Orientation + Vector3.new(0, 1, 0.5)
            task.wait(0.03)
        end
    end)

    -- Concentric rings (visual guides)
    for ring = 1, 3 do
        local ringPart = Instance.new("Part")
        ringPart.Name = "EchoRing_" .. ring
        ringPart.Shape = Enum.PartType.Cylinder
        ringPart.Size = Vector3.new(0.3, ring * 15, ring * 15)
        ringPart.Position = center + Vector3.new(0, 0.3, 0)
        ringPart.Orientation = Vector3.new(0, 0, 90)
        ringPart.Anchored = true
        ringPart.CanCollide = false
        ringPart.Material = Enum.Material.Neon
        ringPart.Color = Color3.fromRGB(180, 100, 255)
        ringPart.Transparency = 0.7
        ringPart.Parent = folder
    end

    -- Title billboard
    local timerPart = Instance.new("Part")
    timerPart.Size = Vector3.new(1, 1, 1)
    timerPart.Position = center + Vector3.new(0, 20, 0)
    timerPart.Anchored = true
    timerPart.CanCollide = false
    timerPart.Transparency = 1
    timerPart.Parent = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(8, 0, 3, 0)
    billboard.Adornee = timerPart
    billboard.AlwaysOnTop = true
    billboard.Parent = timerPart

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ECHO CHAMBER"
    titleLabel.TextColor3 = Color3.fromRGB(180, 100, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = billboard

    local instrLabel = Instance.new("TextLabel")
    instrLabel.Size = UDim2.new(1, 0, 0.3, 0)
    instrLabel.Position = UDim2.new(0, 0, 0.4, 0)
    instrLabel.BackgroundTransparency = 1
    instrLabel.Text = "Send sound pulses to guide each other to the crystal!"
    instrLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    instrLabel.TextScaled = true
    instrLabel.Font = Enum.Font.GothamMedium
    instrLabel.Parent = billboard
end

-- Cleanup trial arena when trial ends
function TrialManager.CleanupArena(instanceId: string)
    local instance = ActiveTrials[instanceId]
    if instance and instance.arenaFolder then
        -- Teleport players back to their layer spawn first
        for _, player in ipairs(instance.players) do
            local data = DataManager.GetData(player)
            local layerIndex = (data and data.layerIndex) or 1
            local layerDef = Layers.GetLayerByIndex(layerIndex)
            if layerDef then
                local character = player.Character
                if character then
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = CFrame.new(layerDef.spawnPosition + Vector3.new(0, 5, 0))
                    end
                end
            end
        end
        instance.arenaFolder:Destroy()
    end
end

return TrialManager
