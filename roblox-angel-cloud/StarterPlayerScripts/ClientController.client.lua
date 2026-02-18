--[[
    ClientController.lua — Main client-side input and movement controller
    Handles: movement, wing glide, full flight, interaction prompts
    Supports: Keyboard + Xbox/Gamepad controller

    FLIGHT IS THE CORE MECHANIC — make it dead simple to use:

    KEYBOARD:
    F key = TOGGLE FLIGHT (one press fly, one press land)
    HOLD Space while airborne = glide
    While flying: WASD move, Space = up, Shift = down

    GAMEPAD (Xbox Controller):
    Y button = TOGGLE FLIGHT (one press fly, one press land)
    Left Bumper (LB) = TOGGLE FLIGHT (alternate)
    While flying: Left Stick = move, RT = up, LT = down
    Hold A while airborne = glide
    X button = action / interact
    B button = open Lore Codex
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layers = require(ReplicatedStorage.Config.Layers)

local ClientController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- State
local isGliding = false
local isFlying = false
local canGlide = true    -- UNLOCKED FROM THE START
local canFly = true      -- EVERYONE CAN FLY from the start!
local currentLayer = 1
local currentLevel = "Newborn"
local stamina = 100
local maxStamina = 100

-- Glide physics — fast and fun, not floaty and boring
local GLIDE_FALL_SPEED = -4    -- very slow descent (hang time!)
local GLIDE_HORIZONTAL_BOOST = 2.5  -- zip across the sky
local NORMAL_JUMP_POWER = 70

-- Flight speed — FAST so it feels good
local FLIGHT_SPEED = 80       -- horizontal flight speed
local FLIGHT_VERTICAL = 50    -- up/down speed while flying

-- Dynamic FOV (inspired by Gemini's FlightEngine — smooth camera zoom at speed)
local BASE_FOV = 70
local GLIDE_FOV = 80
local FLIGHT_FOV = 95
local FOV_LERP_SPEED = 0.1  -- smooth interpolation factor

-- Gamepad state
local gamepadFlyUp = false    -- RT or A held while flying
local gamepadFlyDown = false  -- LT held
local gamepadGlideHeld = false -- A held while not flying

-- Flight time tracking for quests
local flightTimeAccum = 0
local FLIGHT_REPORT_INTERVAL = 5  -- report every 5 seconds of flight

-- RemoteEvents (populated after they exist)
local StaminaUpdate
local PlayerReady
local LevelUp
local ServerMessage

function ClientController.Init()
    -- Wait for RemoteEvents (with timeout to avoid infinite hang)
    StaminaUpdate = ReplicatedStorage:WaitForChild("StaminaUpdate", 30)
    PlayerReady = ReplicatedStorage:WaitForChild("PlayerReady", 30)
    LevelUp = ReplicatedStorage:WaitForChild("LevelUp", 30)
    ServerMessage = ReplicatedStorage:WaitForChild("ServerMessage", 30)

    if not StaminaUpdate or not PlayerReady or not LevelUp or not ServerMessage then
        warn("[ClientController] Timed out waiting for RemoteEvents — server may still be loading")
        return
    end

    -- Input handling
    UserInputService.InputBegan:Connect(ClientController.OnInputBegan)
    UserInputService.InputEnded:Connect(ClientController.OnInputEnded)

    -- Update loop
    RunService.RenderStepped:Connect(ClientController.Update)

    -- Listen for server events
    StaminaUpdate.OnClientEvent:Connect(ClientController.OnStaminaUpdate)
    LevelUp.OnClientEvent:Connect(ClientController.OnLevelUp)
    ServerMessage.OnClientEvent:Connect(ClientController.OnServerMessage)

    -- Notify server we're ready
    task.wait(2)  -- let everything load
    PlayerReady:FireServer()

    -- Load UI systems
    local UIManager = require(script.Parent.UIManager)
    UIManager.Init()

    local StaminaUI = require(script.Parent.StaminaUI)
    StaminaUI.Init()

    local LoreCodexUI = require(script.Parent.LoreCodexUI)
    LoreCodexUI.Init()

    local BlessingEffects = require(script.Parent.BlessingEffects)
    BlessingEffects.Init()

    local LevelUpCinematic = require(script.Parent.LevelUpCinematic)
    LevelUpCinematic.Init()

    local DialogueUI = require(script.Parent.DialogueUI)
    DialogueUI.Init()

    local ShopUI = require(script.Parent.ShopUI)
    ShopUI.Init()

    local SoundPlayer = require(script.Parent.SoundPlayer)
    SoundPlayer.Init()

    local RotaryDialUI = require(script.Parent.RotaryDialUI)
    RotaryDialUI.Init()

    local QuestUI = require(script.Parent.QuestUI)
    QuestUI.Init()

    print("[ClientController] Angel Cloud client initialized")
end

function ClientController.OnInputBegan(input: InputObject, gameProcessed: boolean)
    -- IMPORTANT: Roblox marks gamepad buttons as "gameProcessed" (ButtonA = jump, etc.)
    -- We MUST let gamepad buttons through, otherwise controller flight never works.
    -- Only block keyboard inputs that were consumed by chat/GUI.
    local isGamepad = input.UserInputType == Enum.UserInputType.Gamepad1
    if gameProcessed and not isGamepad then
        return
    end

    -- === FLIGHT TOGGLE (the #1 most important input) ===
    -- Y button (gamepad) or F key (keyboard) = instant flight toggle
    if input.KeyCode == Enum.KeyCode.ButtonY
        or input.KeyCode == Enum.KeyCode.ButtonL1
        or input.KeyCode == Enum.KeyCode.F then
        if canFly then
            ClientController.ToggleFlight()
        end
        return
    end

    -- === A button (gamepad) / Space (keyboard) = glide or fly up ===
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        -- If already flying, A/Space = go up (handled in Update loop via flag)
        if isFlying then
            if input.KeyCode == Enum.KeyCode.ButtonA then
                gamepadFlyUp = true
            end
            return
        end

        -- Hold while falling = glide
        if canGlide then
            if input.KeyCode == Enum.KeyCode.ButtonA then
                gamepadGlideHeld = true
            end
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                    ClientController.StartGlide()
                end
            end
        end
        return
    end

    -- === Right Trigger = fly up ===
    if input.KeyCode == Enum.KeyCode.ButtonR2 then
        gamepadFlyUp = true
        return
    end

    -- === Left Trigger = fly down ===
    if input.KeyCode == Enum.KeyCode.ButtonL2 then
        gamepadFlyDown = true
        return
    end

    -- === X button (gamepad) / E key = action ===
    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
        ClientController.HandleAction()
        return
    end

    -- === B button (gamepad) / C key = Lore Codex ===
    if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
        local LoreCodexUI = require(script.Parent.LoreCodexUI)
        LoreCodexUI.Toggle()
        return
    end
end

function ClientController.OnInputEnded(input: InputObject, gameProcessed: boolean)
    -- Let gamepad releases through (same logic as OnInputBegan)
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        if isGliding then
            ClientController.StopGlide()
        end
        gamepadGlideHeld = false
        if input.KeyCode == Enum.KeyCode.ButtonA then
            gamepadFlyUp = false
        end
    end

    if input.KeyCode == Enum.KeyCode.ButtonR2 then
        gamepadFlyUp = false
    end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then
        gamepadFlyDown = false
    end
end

function ClientController.StartGlide()
    if isGliding or stamina <= 0 then
        return
    end

    isGliding = true
    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    -- Create glide using LinearVelocity (modern physics)
    local att = humanoidRootPart:FindFirstChild("GlideAttachment")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "GlideAttachment"
        att.Parent = humanoidRootPart
    end

    local glideForce = Instance.new("LinearVelocity")
    glideForce.Name = "GlideForce"
    glideForce.Attachment0 = att
    glideForce.MaxForce = 20000
    glideForce.VectorVelocity = Vector3.new(0, GLIDE_FALL_SPEED, 0)
    glideForce.RelativeTo = Enum.ActuatorRelativeTo.World
    glideForce.Parent = humanoidRootPart

    -- Wing visual effect
    ClientController.ShowWings(true)
end

function ClientController.StopGlide()
    isGliding = false
    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            local glideForce = humanoidRootPart:FindFirstChild("GlideForce")
            if glideForce then glideForce:Destroy() end
            local glideAtt = humanoidRootPart:FindFirstChild("GlideAttachment")
            if glideAtt then glideAtt:Destroy() end
        end
    end
    ClientController.ShowWings(false)
end

function ClientController.ToggleFlight()
    if isFlying then
        -- STOP flying
        isFlying = false
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local ff = hrp:FindFirstChild("FlightForce")
                if ff then ff:Destroy() end
                local ag = hrp:FindFirstChild("FlightAntiGrav")
                if ag then ag:Destroy() end
                local fa = hrp:FindFirstChild("FlightAttachment")
                if fa then fa:Destroy() end
            end
        end
        ClientController.ShowWings(false)
        return
    end

    -- START flying
    isFlying = true
    isGliding = false

    local character = player.Character
    if not character then
        isFlying = false
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        isFlying = false
        return
    end

    -- Remove any existing glide force
    local existingForce = humanoidRootPart:FindFirstChild("GlideForce")
    if existingForce then
        existingForce:Destroy()
    end

    -- Create attachment for LinearVelocity
    local att = Instance.new("Attachment")
    att.Name = "FlightAttachment"
    att.Parent = humanoidRootPart

    -- Use LinearVelocity (modern replacement for BodyVelocity)
    local flightForce = Instance.new("LinearVelocity")
    flightForce.Name = "FlightForce"
    flightForce.Attachment0 = att
    flightForce.MaxForce = 50000
    flightForce.VectorVelocity = Vector3.zero
    flightForce.RelativeTo = Enum.ActuatorRelativeTo.World
    flightForce.Parent = humanoidRootPart

    -- Counteract gravity with VectorForce
    local antiGrav = Instance.new("VectorForce")
    antiGrav.Name = "FlightAntiGrav"
    antiGrav.Attachment0 = att
    antiGrav.Force = Vector3.new(0, humanoidRootPart.AssemblyMass * workspace.Gravity, 0)
    antiGrav.RelativeTo = Enum.ActuatorRelativeTo.World
    antiGrav.ApplyAtCenterOfMass = true
    antiGrav.Parent = humanoidRootPart

    ClientController.ShowWings(true)
    print("[Flight] Flight enabled!")
end

function ClientController.HandleAction()
    -- Check if near a meditation spot
    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    -- Look for nearby meditation spots or reflection pools
    local position = humanoidRootPart.Position
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "MeditationSpot" and obj:IsA("BasePart") then
            if (obj.Position - position).Magnitude < 15 then
                -- Start meditation (tell server)
                local staminaEvent = ReplicatedStorage:FindFirstChild("StaminaUpdate")
                -- Meditation is handled server-side via stamina system
                break
            end
        end
    end
end

function ClientController.ShowWings(active: boolean)
    -- Server already creates wings — just make them glow brighter when flying/gliding
    local character = player.Character
    if not character then return end

    local leftWing = character:FindFirstChild("AngelWings")
    local rightWing = character:FindFirstChild("AngelWingR")

    if leftWing then
        leftWing.Transparency = active and 0.1 or 0.25
    end
    if rightWing then
        rightWing.Transparency = active and 0.1 or 0.25
    end

    -- Add/remove glow effects on server-created wings
    if active and leftWing then
        -- Add particle sparkles + light if not already present
        if not leftWing:FindFirstChild("WingSparkle") then
            local wingColor = leftWing.Color

            -- Point light (wing glow visible to others)
            local wingLight = Instance.new("PointLight")
            wingLight.Name = "WingLight"
            wingLight.Color = wingColor
            wingLight.Brightness = 1.5 + currentLayer * 0.3
            wingLight.Range = 12 + currentLayer * 2
            wingLight.Parent = leftWing

            -- Particle trail (feather sparkles)
            local sparkle = Instance.new("ParticleEmitter")
            sparkle.Name = "WingSparkle"
            sparkle.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, wingColor),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            })
            sparkle.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(1, 0),
            })
            sparkle.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            })
            sparkle.Lifetime = NumberRange.new(0.5, 1.5)
            sparkle.Rate = 8 + currentLayer * 2
            sparkle.Speed = NumberRange.new(1, 3)
            sparkle.SpreadAngle = Vector2.new(180, 90)
            sparkle.LightEmission = 1
            sparkle.Parent = leftWing

            -- Same for right wing
            if rightWing then
                local rLight = wingLight:Clone()
                rLight.Parent = rightWing
                local rSparkle = sparkle:Clone()
                rSparkle.Parent = rightWing
            end
        end
    elseif not active then
        -- Remove glow effects when landing
        for _, wing in ipairs({leftWing, rightWing}) do
            if wing then
                local light = wing:FindFirstChild("WingLight")
                if light then light:Destroy() end
                local sparkle = wing:FindFirstChild("WingSparkle")
                if sparkle then sparkle:Destroy() end
            end
        end
    end
end

function ClientController.Update(dt: number)
    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoidRootPart or not humanoid then
        return
    end

    -- Update flight velocity based on camera direction
    if isFlying then
        local flightForce = humanoidRootPart:FindFirstChild("FlightForce")
        if flightForce then
            local moveDirection = humanoid.MoveDirection
            local cameraLook = camera.CFrame.LookVector
            local cameraRight = camera.CFrame.RightVector

            local velocity = Vector3.zero

            -- WASD moves you in camera direction (true 3D flight)
            if moveDirection.Magnitude > 0 then
                local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
                if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
                local flatRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
                if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
                velocity = (flatLook * moveDirection.Z * -1 + flatRight * moveDirection.X) * -FLIGHT_SPEED
            end

            -- Space/RT/A = go UP, Shift/LT = go DOWN (keyboard + gamepad)
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or gamepadFlyUp then
                velocity = velocity + Vector3.new(0, FLIGHT_VERTICAL, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or gamepadFlyDown then
                velocity = velocity + Vector3.new(0, -FLIGHT_VERTICAL, 0)
            end

            flightForce.VectorVelocity = velocity
        end
    end

    -- Auto-stop glide when landing
    if isGliding then
        if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            ClientController.StopGlide()
        end
    end

    -- Gamepad: auto-start glide if A is held and we enter freefall
    if gamepadGlideHeld and not isGliding and not isFlying and canGlide then
        if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            ClientController.StartGlide()
        end
    end

    -- Glide horizontal boost
    if isGliding and stamina > 0 then
        local moveDirection = humanoid.MoveDirection
        if moveDirection.Magnitude > 0 then
            humanoidRootPart.Velocity = Vector3.new(
                moveDirection.X * 30 * GLIDE_HORIZONTAL_BOOST,
                humanoidRootPart.Velocity.Y,
                moveDirection.Z * 30 * GLIDE_HORIZONTAL_BOOST
            )
        end
    end

    -- Track flight time for quests
    if isFlying then
        flightTimeAccum = flightTimeAccum + dt
        if flightTimeAccum >= FLIGHT_REPORT_INTERVAL then
            local FlightTime = ReplicatedStorage:FindFirstChild("FlightTime")
            if FlightTime then
                FlightTime:FireServer(math.floor(flightTimeAccum))
            end
            flightTimeAccum = 0
        end
    else
        flightTimeAccum = 0
    end

    -- Dynamic FOV: widens during flight/glide based on speed
    local targetFOV = BASE_FOV
    if isFlying then
        local velocity = humanoidRootPart.AssemblyLinearVelocity.Magnitude
        targetFOV = math.clamp(FLIGHT_FOV + velocity * 0.1, FLIGHT_FOV, FLIGHT_FOV + 10)
    elseif isGliding then
        local velocity = humanoidRootPart.AssemblyLinearVelocity.Magnitude
        targetFOV = math.clamp(GLIDE_FOV + velocity * 0.08, GLIDE_FOV, FLIGHT_FOV)
    end
    camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * FOV_LERP_SPEED
end

function ClientController.OnStaminaUpdate(data: { [string]: any })
    stamina = data.current
    maxStamina = data.max

    -- Update stamina UI
    local StaminaUI = require(script.Parent.StaminaUI)
    StaminaUI.UpdateBar(stamina, maxStamina, data.action)
end

function ClientController.OnLevelUp(data: { [string]: any })
    currentLevel = data.newLevel
    currentLayer = data.layerIndex

    -- Update capabilities
    canGlide = true
    canFly = true  -- everyone flies!

    -- Trigger cinematic
    local LevelUpCinematic = require(script.Parent.LevelUpCinematic)
    LevelUpCinematic.Play(data)
end

function ClientController.OnServerMessage(data: { [string]: any })
    if data.type == "welcome" then
        currentLevel = data.angelLevel
        local levelIndex = Layers.GetLevelIndex(currentLevel)
        currentLayer = levelIndex
        canGlide = true
        canFly = true
    end

    local UIManager = require(script.Parent.UIManager)
    UIManager.ShowMessage(data)
end

-- Auto-initialize
ClientController.Init()

return ClientController
