--[[
    GameManager.lua — Main server orchestrator for The Cloud Climb
    Initializes all systems, handles player lifecycle, runs update loop
    This is the entry point Script that goes in ServerScriptService
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import all server systems
local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)
local ProgressionSystem = require(script.Parent.ProgressionSystem)
local StaminaSystem = require(script.Parent.StaminaSystem)
local BlessingSystem = require(script.Parent.BlessingSystem)
local LoreSystem = require(script.Parent.LoreSystem)
local TrialManager = require(script.Parent.TrialManager)
local CrossPlatformBridge = require(script.Parent.CrossPlatformBridge)

local Layers = require(ReplicatedStorage.Config.Layers)

local GameManager = {}

-- RemoteEvents for general client-server communication
local PlayerReady      -- Client -> Server: client finished loading
local PlayerProgress   -- Server -> Client: full progress sync
local ServerMessage    -- Server -> Client: system messages

function GameManager.Init()
    print("[GameManager] Initializing The Cloud Climb...")

    -- Create general RemoteEvents
    PlayerReady = Instance.new("RemoteEvent")
    PlayerReady.Name = "PlayerReady"
    PlayerReady.Parent = ReplicatedStorage

    PlayerProgress = Instance.new("RemoteEvent")
    PlayerProgress.Name = "PlayerProgress"
    PlayerProgress.Parent = ReplicatedStorage

    ServerMessage = Instance.new("RemoteEvent")
    ServerMessage.Name = "ServerMessage"
    ServerMessage.Parent = ReplicatedStorage

    -- Initialize all subsystems
    MoteSystem.Init()
    ProgressionSystem.Init()
    StaminaSystem.Init()
    BlessingSystem.Init()
    LoreSystem.Init()
    TrialManager.Init()
    CrossPlatformBridge.Init()

    -- Spawn world content for MVP layers (1-2)
    GameManager.SetupLayers()

    -- Start auto-save
    DataManager.StartAutoSave()

    -- Player lifecycle
    Players.PlayerAdded:Connect(GameManager.OnPlayerAdded)
    Players.PlayerRemoving:Connect(GameManager.OnPlayerRemoving)

    -- Handle players already in game (studio testing)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(GameManager.OnPlayerAdded, player)
    end

    -- Client ready handler
    PlayerReady.OnServerEvent:Connect(function(player)
        GameManager.SyncProgress(player)
    end)

    -- Main update loop
    RunService.Heartbeat:Connect(function(dt)
        StaminaSystem.Update(dt)
    end)

    -- Periodic tasks
    task.spawn(function()
        while true do
            task.wait(30)
            BlessingSystem.CleanupChains()
        end
    end)

    print("[GameManager] The Cloud Climb initialized. Every Angel strengthens the cloud.")
end

function GameManager.OnPlayerAdded(player: Player)
    print("[GameManager] " .. player.Name .. " joining The Cloud Climb")

    -- Load persistent data
    local data = DataManager.LoadPlayer(player)

    -- Initialize stamina
    StaminaSystem.InitPlayer(player)

    -- Spawn character at appropriate layer
    player.CharacterAdded:Connect(function(character)
        task.wait(1)  -- let character load
        GameManager.SpawnAtLayer(player, character)
    end)

    -- Welcome message
    ServerMessage:FireClient(player, {
        type = "welcome",
        message = "Welcome to The Cloud Climb, " .. player.Name .. ". Every Angel strengthens the cloud.",
        angelLevel = data.angelLevel,
        motes = data.motes,
    })
end

function GameManager.OnPlayerRemoving(player: Player)
    print("[GameManager] " .. player.Name .. " leaving The Cloud Climb")

    -- Save data
    DataManager.RemovePlayer(player)

    -- Cleanup systems
    StaminaSystem.RemovePlayer(player)
    CrossPlatformBridge.RemovePlayer(player)
end

function GameManager.SpawnAtLayer(player: Player, character: Model)
    local data = DataManager.GetData(player)
    if not data then
        return
    end

    local layerIndex = data.layerIndex or 1
    local layerDef = Layers.GetLayerByIndex(layerIndex)
    if not layerDef then
        return
    end

    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    if humanoidRootPart then
        humanoidRootPart.CFrame = CFrame.new(layerDef.spawnPosition)
    end
end

function GameManager.SyncProgress(player: Player)
    local progress = ProgressionSystem.GetProgress(player)
    local data = DataManager.GetData(player)

    if data then
        progress.fragmentCount = LoreSystem.GetCollectedCount(player)
        progress.blessingsGiven = data.blessingsGiven or 0
        progress.blessingsReceived = data.blessingsReceived or 0
        progress.linkedAngelCloud = data.linkedAngelCloud or false
    end

    progress.communityBoard = BlessingSystem.GetCommunityBoard()

    PlayerProgress:FireClient(player, progress)
end

function GameManager.SetupLayers()
    -- Set up MVP layers (1 and 2)
    local workspace = game.Workspace

    for i = 1, 2 do
        local layerDef = Layers.GetLayerByIndex(i)
        local folderName = "Layer" .. i .. "_" .. layerDef.name:gsub("%s+", ""):gsub("The", "")
        local layerFolder = workspace:FindFirstChild(folderName)

        if not layerFolder then
            layerFolder = Instance.new("Folder")
            layerFolder.Name = folderName
            layerFolder.Parent = workspace
        end

        -- Spawn world motes
        local moteCount = i == 1 and 15 or 20
        MoteSystem.SpawnWorldMotes(layerFolder, moteCount, layerDef)

        -- Spawn lore fragment points
        LoreSystem.SpawnFragmentPoints(layerFolder, i)

        -- Create layer gate (if not final layer)
        if layerDef.gateThreshold then
            GameManager.CreateLayerGate(layerFolder, layerDef, i + 1)
        end

        -- Create Reflection Pool
        GameManager.CreateReflectionPool(layerFolder, layerDef)

        -- Create Blessing Bluff (Layer 2+)
        if i >= 2 then
            GameManager.CreateBlessingBluff(layerFolder, layerDef)
        end

        print("[GameManager] Layer " .. i .. " (" .. layerDef.name .. ") set up")
    end
end

function GameManager.CreateLayerGate(layerFolder: Folder, layerDef: { [string]: any }, targetLayerIndex: number)
    local gate = Instance.new("Part")
    gate.Name = "LayerGate"
    gate.Size = Vector3.new(20, 30, 3)
    gate.Position = Vector3.new(0, layerDef.heightRange.max - 15, 0)
    gate.Anchored = true
    gate.CanCollide = false
    gate.Material = Enum.Material.ForceField
    gate.Color = Color3.fromRGB(0, 212, 255)
    gate.Transparency = 0.5

    local label = Instance.new("SurfaceGui")
    label.Name = "GateLabel"
    label.Face = Enum.NormalId.Front
    label.Parent = gate

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = layerDef.gateThreshold .. " Motes Required"
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = label

    gate.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            ProgressionSystem.HandleGateTouch(player, targetLayerIndex)
        end
    end)

    gate.Parent = layerFolder
end

function GameManager.CreateReflectionPool(layerFolder: Folder, layerDef: { [string]: any })
    local pool = Instance.new("Part")
    pool.Name = "ReflectionPool"
    pool.Shape = Enum.PartType.Cylinder
    pool.Size = Vector3.new(2, 20, 20)
    pool.Position = Vector3.new(30, layerDef.heightRange.min + 10, 30)
    pool.Anchored = true
    pool.CanCollide = false
    pool.Material = Enum.Material.Glass
    pool.Color = Color3.fromRGB(0, 180, 230)
    pool.Transparency = 0.3
    pool.Orientation = Vector3.new(0, 0, 90)

    -- Detect nearby players for stamina boost
    pool.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            StaminaSystem.SetPlayerState(player, "nearReflectionPool", true)
        end
    end)
    pool.TouchEnded:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            StaminaSystem.SetPlayerState(player, "nearReflectionPool", false)
        end
    end)

    pool.Parent = layerFolder
end

function GameManager.CreateBlessingBluff(layerFolder: Folder, layerDef: { [string]: any })
    local bluff = Instance.new("Part")
    bluff.Name = "BlessingBluff"
    bluff.Size = Vector3.new(10, 2, 10)
    bluff.Position = Vector3.new(-50, layerDef.heightRange.min + 30, -50)
    bluff.Anchored = true
    bluff.Material = Enum.Material.Neon
    bluff.Color = Color3.fromRGB(255, 215, 0)  -- golden glow
    bluff.Transparency = 0.2

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Send Blessing (2 Motes)"
    prompt.ObjectText = "Blessing Bluff"
    prompt.HoldDuration = 1
    prompt.MaxActivationDistance = 15
    prompt.Parent = bluff

    prompt.Triggered:Connect(function(player)
        BlessingSystem.SendBlessing(player)
    end)

    bluff.Parent = layerFolder
end

-- Initialize on require
GameManager.Init()

return GameManager
