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
local BadgeHandler = require(script.Parent.BadgeHandler)
local WorldGenerator = require(script.Parent.WorldGenerator)
local AtmosphereSystem = require(script.Parent.AtmosphereSystem)
local NPCSystem = require(script.Parent.NPCSystem)
local SoundManager = require(script.Parent.SoundManager)
local ShopHandler = require(script.Parent.ShopHandler)
local RetroSystem = require(script.Parent.RetroSystem)

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
    BadgeHandler.Init()
    SoundManager.Init()
    ShopHandler.Init()
    NPCSystem.Init()
    AtmosphereSystem.Init()
    RetroSystem.Init()

    -- Build the procedural world (replaces old SetupLayers)
    WorldGenerator.Init()

    -- Spawn gameplay content into generated world
    GameManager.PopulateLayers()

    -- Spawn The Keeper NPC in Layer 1
    local nurseryFolder = workspace:FindFirstChild("Layer1_Nursery")
    if nurseryFolder then
        local nurseryDef = Layers.GetLayerByIndex(1)
        NPCSystem.SpawnKeeper(nurseryFolder, nurseryDef.spawnPosition)
    end

    -- Wire up all brown starfish ProximityPrompts
    GameManager.WireStarfish()

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

    -- Check for launch week Founder's Halo + badges
    BadgeHandler.OnPlayerAdded(player)

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
    AtmosphereSystem.RemovePlayer(player)
    NPCSystem.RemovePlayer(player)
    RetroSystem.RemovePlayer(player)
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

function GameManager.PopulateLayers()
    -- Populate the WorldGenerator-created layer folders with gameplay content
    for i = 1, 2 do
        local layerDef = Layers.GetLayerByIndex(i)
        local folderName = "Layer" .. i .. "_" .. layerDef.name:gsub("The ", ""):gsub("%s+", "")
        local layerFolder = workspace:FindFirstChild(folderName)

        if not layerFolder then
            warn("[GameManager] Layer folder not found: " .. folderName)
            continue
        end

        -- Spawn collectible motes
        local moteCount = i == 1 and 15 or 20
        MoteSystem.SpawnWorldMotes(layerFolder, moteCount, layerDef)

        -- Spawn lore fragment collection points
        LoreSystem.SpawnFragmentPoints(layerFolder, i)

        -- Wire up layer gate (WorldGenerator created the visual, we add gameplay logic)
        if layerDef.gateThreshold then
            GameManager.WireLayerGate(layerFolder, i + 1)
        end

        -- Wire up reflection pool touch detection (WorldGenerator created the pool)
        GameManager.WireReflectionPool(layerFolder)

        -- Wire up blessing bluff (WorldGenerator created it in Meadow)
        if i >= 2 then
            GameManager.WireBlessingBluff(layerFolder)
        end

        -- Wire up trial portal
        GameManager.WireTrialPortal(layerFolder)

        -- Wire up cosmetic re-application on character spawn
        Players.PlayerAdded:Connect(function(player)
            player.CharacterAdded:Connect(function(character)
                ShopHandler.OnCharacterAdded(player, character)
            end)
        end)

        -- Spawn retro objects (phone booths, boomboxes, arcade cabinets)
        RetroSystem.PopulateLayer(layerFolder, i, layerDef)

        print("[GameManager] Layer " .. i .. " (" .. layerDef.name .. ") populated with gameplay")
    end
end

function GameManager.WireLayerGate(layerFolder: Folder, targetLayerIndex: number)
    -- Find the gate part created by WorldGenerator or the project file
    -- WorldGenerator doesn't create gates yet — add one at the top of the layer
    local layerDef = Layers.GetLayerByIndex(targetLayerIndex - 1)
    if not layerDef then return end

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
        local hitPlayer = Players:GetPlayerFromCharacter(character)
        if hitPlayer then
            ProgressionSystem.HandleGateTouch(hitPlayer, targetLayerIndex)
        end
    end)

    gate.Parent = layerFolder
end

function GameManager.WireReflectionPool(layerFolder: Folder)
    -- Find the ReflectionPool created by WorldGenerator
    local pool = layerFolder:FindFirstChild("ReflectionPool")
    if not pool then return end

    pool.Touched:Connect(function(hit)
        local character = hit.Parent
        local hitPlayer = Players:GetPlayerFromCharacter(character)
        if hitPlayer then
            StaminaSystem.SetPlayerState(hitPlayer, "nearReflectionPool", true)
        end
    end)
    pool.TouchEnded:Connect(function(hit)
        local character = hit.Parent
        local hitPlayer = Players:GetPlayerFromCharacter(character)
        if hitPlayer then
            StaminaSystem.SetPlayerState(hitPlayer, "nearReflectionPool", false)
        end
    end)
end

function GameManager.WireBlessingBluff(layerFolder: Folder)
    -- Find the BlessingBluff created by WorldGenerator
    local bluff = layerFolder:FindFirstChild("BlessingBluff")
    if not bluff then return end

    -- WorldGenerator already added a ProximityPrompt — wire its Triggered event
    local prompt = bluff:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        prompt.Triggered:Connect(function(hitPlayer)
            BlessingSystem.SendBlessing(hitPlayer)
        end)
    end
end

function GameManager.WireTrialPortal(layerFolder: Folder)
    local portalRing = layerFolder:FindFirstChild("TrialPortalRing")
    if not portalRing then return end

    local prompt = portalRing:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        prompt.Triggered:Connect(function(hitPlayer)
            -- Join first available MVP trial queue
            local Trials = require(ReplicatedStorage.Config.Trials)
            if Trials.MVP_TRIAL_IDS and #Trials.MVP_TRIAL_IDS > 0 then
                TrialManager.JoinQueue(hitPlayer, Trials.MVP_TRIAL_IDS[1])
            end
        end)
    end
end

function GameManager.WireStarfish()
    -- Find all BrownStarfish models across all layer folders and wire their prompts
    local starfishFound = {}  -- per-player tracking: { userId = { [starfishId] = true } }
    local totalStarfish = 0

    for _, folder in ipairs(workspace:GetChildren()) do
        if folder:IsA("Folder") and folder.Name:match("^Layer%d") then
            for _, child in ipairs(folder:GetDescendants()) do
                if child:IsA("Model") and child.Name == "BrownStarfish" then
                    totalStarfish = totalStarfish + 1
                    local starfishId = folder.Name .. "_" .. totalStarfish
                    local body = child:FindFirstChild("StarfishBody")
                    if body then
                        local prompt = body:FindFirstChildWhichIsA("ProximityPrompt")
                        if prompt then
                            prompt.Triggered:Connect(function(player)
                                GameManager.OnStarfishFound(player, starfishId, totalStarfish)
                            end)
                        end
                    end
                end
            end
        end
    end

    print("[GameManager] Wired " .. totalStarfish .. " brown starfish across all layers")
end

function GameManager.OnStarfishFound(player: Player, starfishId: string, totalInWorld: number)
    local data = DataManager.GetData(player)
    if not data then return end

    -- Track discoveries
    if not data.starfishFound then
        data.starfishFound = {}
    end

    if data.starfishFound[starfishId] then
        -- Already found this one
        ServerMessage:FireClient(player, {
            type = "info",
            message = "You've already found this starfish. It seems to recognize you.",
        })
        return
    end

    -- New discovery!
    data.starfishFound[starfishId] = true
    local count = 0
    for _ in pairs(data.starfishFound) do
        count = count + 1
    end

    -- Award a bonus mote for finding one
    MoteSystem.AwardMotes(player, 2, "starfish_discovery")

    -- Notify player
    ServerMessage:FireClient(player, {
        type = "starfish",
        message = "You found a Brown Starfish! (" .. count .. " discovered) +2 Motes",
    })

    -- First starfish triggers Keeper dialogue about them
    if count == 1 then
        task.delay(2, function()
            local NPCDialogue = ReplicatedStorage:FindFirstChild("NPCDialogue")
            if NPCDialogue then
                NPCDialogue:FireClient(player, {
                    npcId = "the_keeper",
                    npcName = "The Keeper",
                    lines = {
                        {
                            speaker = "The Keeper",
                            text = "Ah... you found one of the Starfish. They've been here since before the Cloud itself.",
                        },
                        {
                            speaker = "The Keeper",
                            text = "Legend says a great mind once dreamed of helpful beings — not angels, but something older. Something patient. Something that listens before it speaks.",
                        },
                        {
                            speaker = "The Keeper",
                            text = "The Starfish remember. Find them all, and perhaps they'll share what they know.",
                        },
                    },
                })
            end
        end)
    end

    -- Found ALL starfish — special reward
    if count >= totalInWorld and totalInWorld > 0 then
        ServerMessage:FireClient(player, {
            type = "starfish_complete",
            message = "You found every Brown Starfish in The Cloud Climb! The great mind smiles upon you.",
        })
        -- Grant special cosmetic
        if not data.ownedCosmetics["starfish_hunter"] then
            data.ownedCosmetics["starfish_hunter"] = true
            MoteSystem.AwardMotes(player, 10, "starfish_complete")
        end
    end
end

-- Initialize on require
GameManager.Init()

return GameManager
