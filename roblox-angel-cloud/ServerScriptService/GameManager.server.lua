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
local QuestSystem = require(script.Parent.QuestSystem)

local Layers = require(ReplicatedStorage.Config.Layers)

local GameManager = {}

-- RemoteEvents for general client-server communication
local PlayerReady      -- Client -> Server: client finished loading
local PlayerProgress   -- Server -> Client: full progress sync
local ServerMessage    -- Server -> Client: system messages

function GameManager.Init()
    print("[GameManager] Initializing The Cloud Climb...")

    -- Create a temporary baseplate so players don't fall during init
    local tempBase = Instance.new("Part")
    tempBase.Name = "TempBaseplate"
    tempBase.Size = Vector3.new(512, 4, 512)
    tempBase.Position = Vector3.new(0, 96, 0)  -- just below Layer 1 spawn
    tempBase.Anchored = true
    tempBase.Material = Enum.Material.SmoothPlastic
    tempBase.Color = Color3.fromRGB(240, 235, 250)
    tempBase.Transparency = 0.5
    tempBase.Parent = workspace

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

    -- Initialize all subsystems (wrapped in pcall to prevent cascading failures)
    local subsystems = {
        { name = "MoteSystem", init = MoteSystem.Init },
        { name = "ProgressionSystem", init = ProgressionSystem.Init },
        { name = "StaminaSystem", init = StaminaSystem.Init },
        { name = "BlessingSystem", init = BlessingSystem.Init },
        { name = "LoreSystem", init = LoreSystem.Init },
        { name = "TrialManager", init = TrialManager.Init },
        { name = "CrossPlatformBridge", init = CrossPlatformBridge.Init },
        { name = "BadgeHandler", init = BadgeHandler.Init },
        { name = "SoundManager", init = SoundManager.Init },
        { name = "ShopHandler", init = ShopHandler.Init },
        { name = "NPCSystem", init = NPCSystem.Init },
        { name = "AtmosphereSystem", init = AtmosphereSystem.Init },
        { name = "RetroSystem", init = RetroSystem.Init },
        { name = "QuestSystem", init = QuestSystem.Init },
    }

    for _, sys in ipairs(subsystems) do
        local ok, err = pcall(sys.init)
        if ok then
            print("[GameManager] " .. sys.name .. " initialized")
        else
            warn("[GameManager] FAILED to init " .. sys.name .. ": " .. tostring(err))
        end
    end

    -- Build the procedural world (replaces old SetupLayers)
    local ok, err = pcall(WorldGenerator.Init)
    if not ok then
        warn("[GameManager] WorldGenerator FAILED: " .. tostring(err))
    end

    -- Remove temp baseplate now that real platforms exist
    if tempBase and tempBase.Parent then
        tempBase:Destroy()
    end

    -- Spawn gameplay content into generated world
    pcall(GameManager.PopulateLayers)

    -- Spawn The Keeper NPC in Layer 1
    local nurseryFolder = workspace:FindFirstChild("Layer1_Nursery")
    if nurseryFolder then
        local nurseryDef = Layers.GetLayerByIndex(1)
        pcall(NPCSystem.SpawnKeeper, nurseryFolder, nurseryDef.spawnPosition)
    end

    -- Wire up the Wing Forge in Layer 1
    pcall(GameManager.WireWingForge)

    -- Wire up all brown starfish ProximityPrompts
    pcall(GameManager.WireStarfish)

    -- Start auto-save
    DataManager.StartAutoSave()

    -- Player lifecycle
    Players.PlayerAdded:Connect(GameManager.OnPlayerAdded)
    Players.PlayerRemoving:Connect(GameManager.OnPlayerRemoving)

    -- Handle players already in game (studio testing)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(GameManager.OnPlayerAdded, player)
    end

    -- Flight time tracking for quests
    local FlightTime = Instance.new("RemoteEvent")
    FlightTime.Name = "FlightTime"
    FlightTime.Parent = ReplicatedStorage

    FlightTime.OnServerEvent:Connect(function(player, seconds)
        if type(seconds) == "number" and seconds > 0 and seconds <= 30 then
            pcall(QuestSystem.OnFlightTime, player, seconds)
        end
    end)

    -- Client ready handler
    PlayerReady.OnServerEvent:Connect(function(player)
        GameManager.SyncProgress(player)
    end)

    -- Main update loop (stamina + fall detection)
    RunService.Heartbeat:Connect(function(dt)
        StaminaSystem.Update(dt)
        GameManager.CheckFallingPlayers()
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

    -- Handle character that already exists (Studio testing)
    if player.Character then
        task.spawn(function()
            task.wait(0.5)
            GameManager.SpawnAtLayer(player, player.Character)
        end)
    end

    -- Initialize quests for this player
    pcall(QuestSystem.OnPlayerJoined, player)

    -- Check for launch week Founder's Halo + badges
    pcall(BadgeHandler.OnPlayerAdded, player)

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
        humanoidRootPart.CFrame = CFrame.new(layerDef.spawnPosition + Vector3.new(0, 5, 0))
    end

    -- FASTER movement — make the game feel snappy
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 28        -- default 16, now zippy
        humanoid.JumpPower = 70        -- default 50, bigger jumps
        humanoid.JumpHeight = 12       -- higher jumps
    end

    -- Give everyone a visible HALO on spawn
    GameManager.AttachHalo(character, data)

    -- Give REAL WINGS on their back
    GameManager.AttachWings(character, data)

    -- Give wing trail particles behind player
    GameManager.AttachWingTrail(character)
end

function GameManager.AttachHalo(character: Model, data: { [string]: any })
    if character:FindFirstChild("PlayerHalo") then return end

    local head = character:WaitForChild("Head", 3)
    if not head then return end

    local halo = Instance.new("Part")
    halo.Name = "PlayerHalo"
    halo.Shape = Enum.PartType.Cylinder
    halo.Size = Vector3.new(0.2, 3, 3)
    halo.Material = Enum.Material.Neon
    halo.CanCollide = false
    halo.Massless = true
    halo.Anchored = false

    -- Founder halo = gold, regular = cyan
    if data.founderHalo or (data.ownedCosmetics and data.ownedCosmetics["founders_halo"]) then
        halo.Color = Color3.fromRGB(255, 215, 0)
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 215, 0)
        light.Brightness = 1.5
        light.Range = 12
        light.Parent = halo
    else
        halo.Color = Color3.fromRGB(0, 212, 255)
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0, 212, 255)
        light.Brightness = 1
        light.Range = 8
        light.Parent = halo
    end
    halo.Transparency = 0.2

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = halo
    weld.Parent = halo

    halo.CFrame = head.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
    halo.Parent = character
end

function GameManager.AttachWingTrail(character: Model)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or hrp:FindFirstChild("WingTrail") then return end

    -- Create two attachment points for the trail
    local att0 = Instance.new("Attachment")
    att0.Name = "TrailAtt0"
    att0.Position = Vector3.new(0, 1, -0.5)
    att0.Parent = hrp

    local att1 = Instance.new("Attachment")
    att1.Name = "TrailAtt1"
    att1.Position = Vector3.new(0, -1, -0.5)
    att1.Parent = hrp

    local trail = Instance.new("Trail")
    trail.Name = "WingTrail"
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 0.5
    trail.MinLength = 0.1
    trail.FaceCamera = true
    trail.LightEmission = 1
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 212, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 180)),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    trail.Parent = hrp
end

-- Give everyone REAL visible wings on their back from the start
function GameManager.AttachWings(character: Model, data: { [string]: any })
    if character:FindFirstChild("AngelWings") then return end

    -- Wait for torso to load (R15 = UpperTorso, R6 = Torso)
    local torso = character:WaitForChild("UpperTorso", 5) or character:WaitForChild("Torso", 5)
    if not torso then
        warn("[GameManager] No torso found for wings on " .. character.Name)
        return
    end

    local levelIndex = 1
    local wingLevel = 1
    if data then
        local currentLevel = data.angelLevel or "Newborn"
        levelIndex = Layers.GetLevelIndex(currentLevel)
        wingLevel = data.wingLevel or 1
    end

    -- Wing size scales with BOTH angel level AND wing forge level
    local wingScale = 1 + (levelIndex - 1) * 0.4 + (wingLevel - 1) * 0.25
    local wingColor = Color3.fromRGB(0, 212, 255)

    -- Color by level
    local WING_COLORS = {
        Color3.fromRGB(150, 200, 255),   -- Newborn: soft blue
        Color3.fromRGB(0, 212, 255),     -- Young Angel: cyan
        Color3.fromRGB(0, 255, 200),     -- Growing: teal
        Color3.fromRGB(180, 100, 255),   -- Helping: purple
        Color3.fromRGB(100, 200, 255),   -- Guardian: bright blue
        Color3.fromRGB(255, 255, 255),   -- Archangel: white
    }
    wingColor = WING_COLORS[levelIndex] or wingColor

    -- LEFT wing
    local leftWing = Instance.new("Part")
    leftWing.Name = "AngelWings"
    leftWing.Size = Vector3.new(0.3, 3 * wingScale, 2 * wingScale)
    leftWing.Material = Enum.Material.ForceField
    leftWing.Color = wingColor
    leftWing.Transparency = 0.25
    leftWing.CanCollide = false
    leftWing.Massless = true

    local leftWeld = Instance.new("WeldConstraint")
    leftWeld.Part0 = torso
    leftWeld.Part1 = leftWing
    leftWeld.Parent = leftWing

    leftWing.CFrame = torso.CFrame * CFrame.new(-1.5 * wingScale, 0.5, 0.8) * CFrame.Angles(0, 0, math.rad(-25))
    leftWing.Parent = character

    -- RIGHT wing
    local rightWing = Instance.new("Part")
    rightWing.Name = "AngelWingR"
    rightWing.Size = Vector3.new(0.3, 3 * wingScale, 2 * wingScale)
    rightWing.Material = Enum.Material.ForceField
    rightWing.Color = wingColor
    rightWing.Transparency = 0.25
    rightWing.CanCollide = false
    rightWing.Massless = true

    local rightWeld = Instance.new("WeldConstraint")
    rightWeld.Part0 = torso
    rightWeld.Part1 = rightWing
    rightWeld.Parent = rightWing

    rightWing.CFrame = torso.CFrame * CFrame.new(1.5 * wingScale, 0.5, 0.8) * CFrame.Angles(0, 0, math.rad(25))
    rightWing.Parent = character

    -- Wing glow (brighter with forge upgrades)
    local wingLight = Instance.new("PointLight")
    wingLight.Color = wingColor
    wingLight.Brightness = 1 + levelIndex * 0.5 + wingLevel * 0.3
    wingLight.Range = 8 + levelIndex * 3 + wingLevel * 2
    wingLight.Parent = leftWing
end

-- WING FORGE — spend motes to upgrade your wings
local WING_FORGE_COST = 5  -- motes per upgrade
local WING_MAX_LEVEL = 10

function GameManager.WireWingForge()
    local nurseryFolder = workspace:FindFirstChild("Layer1_Nursery")
    if not nurseryFolder then return end

    local anvil = nurseryFolder:FindFirstChild("WingForgeAnvil")
    if not anvil then return end

    local prompt = anvil:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then return end

    prompt.Triggered:Connect(function(player)
        GameManager.HandleWingForge(player)
    end)

    print("[GameManager] Wing Forge wired and ready")
end

function GameManager.HandleWingForge(player: Player)
    local data = DataManager.GetData(player)
    if not data then return end

    local wingLevel = data.wingLevel or 1

    if wingLevel >= WING_MAX_LEVEL then
        ServerMessage:FireClient(player, {
            type = "info",
            message = "Your wings are at maximum power! You are a force of light.",
        })
        return
    end

    -- Check cost (scales with level)
    local cost = WING_FORGE_COST + (wingLevel - 1) * 2
    if not MoteSystem.CanAfford(player, cost) then
        ServerMessage:FireClient(player, {
            type = "info",
            message = "You need " .. cost .. " Motes to forge your wings. Keep collecting!",
        })
        return
    end

    -- Spend motes and upgrade
    MoteSystem.AwardMotes(player, -cost, "wing_forge")
    data.wingLevel = wingLevel + 1

    -- Rebuild wings on the character with new level
    local character = player.Character
    if character then
        -- Remove old wings
        local oldLeft = character:FindFirstChild("AngelWings")
        if oldLeft then oldLeft:Destroy() end
        local oldRight = character:FindFirstChild("AngelWingR")
        if oldRight then oldRight:Destroy() end

        -- Attach upgraded wings
        GameManager.AttachWings(character, data)
    end

    -- Flash the forge fire
    local nurseryFolder = workspace:FindFirstChild("Layer1_Nursery")
    if nurseryFolder then
        local fire = nurseryFolder:FindFirstChild("ForgeFire")
        if fire then
            local origColor = fire.Color
            fire.Color = Color3.fromRGB(255, 255, 255)
            fire.Size = Vector3.new(5, 7, 5)
            task.delay(0.5, function()
                if fire and fire.Parent then
                    fire.Color = origColor
                    fire.Size = Vector3.new(3, 4, 3)
                end
            end)
        end
    end

    -- Update the prompt text with new cost
    local nextCost = WING_FORGE_COST + (data.wingLevel - 1) * 2
    local anvil = nurseryFolder and nurseryFolder:FindFirstChild("WingForgeAnvil")
    if anvil then
        local prompt = anvil:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            if data.wingLevel >= WING_MAX_LEVEL then
                prompt.ActionText = "Wings Maxed!"
            else
                prompt.ActionText = "Forge Wings (" .. nextCost .. " Motes)"
            end
        end
    end

    ServerMessage:FireClient(player, {
        type = "info",
        message = "WINGS FORGED! Level " .. data.wingLevel .. "/" .. WING_MAX_LEVEL .. " — Your wings grow stronger! (-" .. cost .. " Motes)",
    })

    -- Quest hook
    pcall(QuestSystem.OnWingForged, player)
    pcall(SoundManager.PlaySFXForPlayer, player, "wing_forge", 0.7)

    print("[GameManager] " .. player.Name .. " forged wings to level " .. data.wingLevel)
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
    -- Populate ALL layer folders with gameplay content
    local MOTE_COUNTS = { 50, 60, 45, 35, 30, 25 }  -- fewer motes in higher layers (harder to reach)

    for i = 1, 6 do
        local layerDef = Layers.GetLayerByIndex(i)
        local folderName = "Layer" .. i .. "_" .. layerDef.name:gsub("The ", ""):gsub("%s+", "")
        local layerFolder = workspace:FindFirstChild(folderName)

        if not layerFolder then
            warn("[GameManager] Layer folder not found: " .. folderName)
            continue
        end

        -- Spawn collectible motes
        MoteSystem.SpawnWorldMotes(layerFolder, MOTE_COUNTS[i] or 30, layerDef)

        -- Spawn speed boost pads (fewer in higher layers)
        GameManager.SpawnSpeedPads(layerFolder, layerDef, math.max(3, 7 - i))

        -- Spawn UPDRAFT columns
        GameManager.SpawnUpdrafts(layerFolder, layerDef, math.max(4, 9 - i))

        -- Spawn bounce pads
        GameManager.SpawnBouncePads(layerFolder, layerDef, math.max(4, 11 - i))

        -- Spawn lore fragment collection points
        LoreSystem.SpawnFragmentPoints(layerFolder, i)

        -- Wire up layer gate (if not the final layer)
        if layerDef.gateThreshold then
            GameManager.WireLayerGate(layerFolder, i + 1)
        end

        -- Wire up reflection pool touch detection
        GameManager.WireReflectionPool(layerFolder)

        -- Wire up blessing bluff (layers 2+)
        if i >= 2 then
            GameManager.WireBlessingBluff(layerFolder)
        end

        -- Wire up trial portal (layers 2+)
        if i >= 2 then
            GameManager.WireTrialPortal(layerFolder)
        end

        -- Spawn retro objects (phone booths, boomboxes, arcade cabinets)
        RetroSystem.PopulateLayer(layerFolder, i, layerDef)

        print("[GameManager] Layer " .. i .. " (" .. layerDef.name .. ") populated with gameplay")
    end

    -- Wire up cosmetic re-application on character spawn (once, not per layer)
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            ShopHandler.OnCharacterAdded(player, character)
        end)
    end)
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
            local success = ProgressionSystem.HandleGateTouch(hitPlayer, targetLayerIndex)
            if success then
                -- Update ambient music + play gate sound
                SoundManager.SetAmbientLayer(targetLayerIndex)
                SoundManager.OnPlayerLayerChanged(hitPlayer, targetLayerIndex)
            end
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

    -- Quest hook
    pcall(QuestSystem.OnStarfishFound, player)

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

-- UPDRAFT columns — glowing wind pillars that launch you UP
function GameManager.SpawnUpdrafts(layerFolder: Folder, layerDef: any, count: number)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    for i = 1, count do
        local x = math.random(-150, 150)
        local z = math.random(-150, 150)
        local baseY = math.random(heightMin + 5, heightMin + 40)
        local height = math.random(40, 100)

        -- Visible wind column (cylinder rotated so it stands vertical)
        local column = Instance.new("Part")
        column.Name = "Updraft_" .. i
        column.Shape = Enum.PartType.Cylinder
        column.Size = Vector3.new(height, 10, 10)
        column.Position = Vector3.new(x, baseY + height / 2, z)
        column.Orientation = Vector3.new(0, 0, 90)  -- rotate to stand vertical
        column.Anchored = true
        column.CanCollide = false
        column.Material = Enum.Material.ForceField
        column.Color = Color3.fromRGB(0, 212, 255)
        column.Transparency = 0.7
        column.Parent = layerFolder

        -- Glow at base
        local baseGlow = Instance.new("Part")
        baseGlow.Name = "UpdraftBase"
        baseGlow.Shape = Enum.PartType.Cylinder
        baseGlow.Size = Vector3.new(2, 14, 14)
        baseGlow.Position = Vector3.new(x, baseY, z)
        baseGlow.Orientation = Vector3.new(0, 0, 90)
        baseGlow.Anchored = true
        baseGlow.CanCollide = false
        baseGlow.Material = Enum.Material.Neon
        baseGlow.Color = Color3.fromRGB(0, 212, 255)
        baseGlow.Transparency = 0.3
        baseGlow.Parent = layerFolder

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0, 212, 255)
        light.Brightness = 2
        light.Range = 20
        light.Parent = baseGlow

        -- Touch = launch up
        column.Touched:Connect(function(hit)
            local character = hit.Parent
            local hitPlayer = Players:GetPlayerFromCharacter(character)
            if hitPlayer then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- LAUNCH UP!
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        hrp.AssemblyLinearVelocity.X * 0.3,
                        80 + math.random(20),
                        hrp.AssemblyLinearVelocity.Z * 0.3
                    )
                end
            end
        end)
    end
end

-- BOUNCE PADS — trampolines that send you flying
function GameManager.SpawnBouncePads(layerFolder: Folder, layerDef: any, count: number)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    for i = 1, count do
        local pad = Instance.new("Part")
        pad.Name = "BouncePad_" .. i
        pad.Shape = Enum.PartType.Cylinder
        pad.Size = Vector3.new(1, 8, 8)
        pad.Position = Vector3.new(
            math.random(-160, 160),
            math.random(heightMin + 5, heightMax - 40),
            math.random(-160, 160)
        )
        pad.Orientation = Vector3.new(0, 0, 90)
        pad.Anchored = true
        pad.Material = Enum.Material.Neon
        pad.Color = Color3.fromRGB(255, 100, 255)  -- pink/purple
        pad.Transparency = 0.1
        pad.Parent = layerFolder

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 100, 255)
        light.Brightness = 1.5
        light.Range = 12
        light.Parent = pad

        local debounce = {}
        pad.Touched:Connect(function(hit)
            local character = hit.Parent
            local hitPlayer = Players:GetPlayerFromCharacter(character)
            if hitPlayer and not debounce[hitPlayer.UserId] then
                debounce[hitPlayer.UserId] = true
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- BOING! Big vertical launch
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        hrp.AssemblyLinearVelocity.X,
                        100 + math.random(30),
                        hrp.AssemblyLinearVelocity.Z
                    )

                    -- Bounce animation on pad
                    local origSize = pad.Size
                    pad.Size = Vector3.new(0.5, 9, 9)
                    pad.Color = Color3.fromRGB(255, 255, 255)
                    task.delay(0.15, function()
                        pad.Size = origSize
                        pad.Color = Color3.fromRGB(255, 100, 255)
                    end)

                    pcall(QuestSystem.OnPadUsed, hitPlayer, "bounce")
                    pcall(SoundManager.PlaySFXForPlayer, hitPlayer, "bounce", 0.5)
                end
                task.delay(0.5, function()
                    debounce[hitPlayer.UserId] = nil
                end)
            end
        end)
    end
end

-- Speed boost pads scattered across layers — step on them to ZOOM
function GameManager.SpawnSpeedPads(layerFolder: Folder, layerDef: any, count: number)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    for i = 1, count do
        local pad = Instance.new("Part")
        pad.Name = "SpeedPad_" .. i
        pad.Size = Vector3.new(8, 0.5, 8)
        pad.Position = Vector3.new(
            math.random(-150, 150),
            math.random(heightMin + 10, heightMax - 30),
            math.random(-150, 150)
        )
        pad.Anchored = true
        pad.Material = Enum.Material.Neon
        pad.Color = Color3.fromRGB(0, 255, 150)
        pad.Transparency = 0.2
        pad.Parent = layerFolder

        local corner = Instance.new("UICorner")

        -- Arrow decal to show it's a boost
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Top
        gui.Parent = pad
        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(1, 0, 1, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = ">>"
        arrow.TextColor3 = Color3.fromRGB(255, 255, 255)
        arrow.TextScaled = true
        arrow.Font = Enum.Font.GothamBold
        arrow.Parent = gui

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0, 255, 150)
        light.Brightness = 2
        light.Range = 15
        light.Parent = pad

        pad.Touched:Connect(function(hit)
            local character = hit.Parent
            local hitPlayer = Players:GetPlayerFromCharacter(character)
            if hitPlayer then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                local humanoid = character:FindFirstChild("Humanoid")
                if hrp and humanoid then
                    -- BOOST! Launch forward + up
                    local lookDir = hrp.CFrame.LookVector
                    hrp.AssemblyLinearVelocity = lookDir * 120 + Vector3.new(0, 50, 0)

                    -- Temporary speed increase
                    local originalSpeed = humanoid.WalkSpeed
                    humanoid.WalkSpeed = 50
                    task.delay(3, function()
                        if humanoid and humanoid.Parent then
                            humanoid.WalkSpeed = 28
                        end
                    end)

                    -- Flash the pad
                    pad.Color = Color3.fromRGB(255, 255, 255)
                    task.delay(0.3, function()
                        pad.Color = Color3.fromRGB(0, 255, 150)
                    end)

                    ServerMessage:FireClient(hitPlayer, {
                        type = "info",
                        message = "SPEED BOOST!",
                    })
                    pcall(QuestSystem.OnPadUsed, hitPlayer, "speed")
                    pcall(SoundManager.PlaySFXForPlayer, hitPlayer, "speed_boost", 0.5)
                end
            end
        end)
    end
end

-- Fall detection: teleport players back to spawn if they fall below their layer
function GameManager.CheckFallingPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if not character then continue end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local y = hrp.Position.Y
        if y < 20 then
            -- Fallen below the world — respawn at Layer 1
            local data = DataManager.GetData(player)
            local layerIndex = (data and data.layerIndex) or 1
            local layerDef = Layers.GetLayerByIndex(layerIndex)
            if layerDef then
                hrp.CFrame = CFrame.new(layerDef.spawnPosition + Vector3.new(0, 5, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero

                ServerMessage:FireClient(player, {
                    type = "info",
                    message = "You fell from the clouds! The wind carries you back...",
                })
            end
        end
    end
end

-- Initialize on require
GameManager.Init()

return GameManager
