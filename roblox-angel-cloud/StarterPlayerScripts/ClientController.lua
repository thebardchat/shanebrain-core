--[[
    ClientController.lua — Main client-side input and movement controller
    Handles: movement, wing glide, flight (higher layers), interaction prompts
    Input: WASD + Space + Action Key (E)

    Wing Glide: Hold Space while airborne (Layer 2+)
    Flight: Double-tap Space (Layer 5+, drains stamina faster)
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
local canGlide = false   -- unlocked at Layer 2
local canFly = false      -- unlocked at Layer 5
local currentLayer = 1
local currentLevel = "Newborn"
local stamina = 100
local maxStamina = 100

-- Glide physics
local GLIDE_FALL_SPEED = -8    -- slow descent
local GLIDE_HORIZONTAL_BOOST = 1.3
local NORMAL_JUMP_POWER = 50

-- Double-tap detection for flight
local lastSpacePress = 0
local DOUBLE_TAP_WINDOW = 0.3

-- RemoteEvents (populated after they exist)
local StaminaUpdate
local PlayerReady
local LevelUp
local ServerMessage

function ClientController.Init()
    -- Wait for RemoteEvents
    StaminaUpdate = ReplicatedStorage:WaitForChild("StaminaUpdate")
    PlayerReady = ReplicatedStorage:WaitForChild("PlayerReady")
    LevelUp = ReplicatedStorage:WaitForChild("LevelUp")
    ServerMessage = ReplicatedStorage:WaitForChild("ServerMessage")

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

    print("[ClientController] Angel Cloud client initialized")
end

function ClientController.OnInputBegan(input: InputObject, gameProcessed: boolean)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.Space then
        local now = tick()

        -- Double-tap space for flight (Layer 5+)
        if canFly and (now - lastSpacePress) < DOUBLE_TAP_WINDOW then
            ClientController.ToggleFlight()
            lastSpacePress = 0
        else
            lastSpacePress = now
        end

        -- Hold space for glide (Layer 2+)
        if canGlide and not isFlying then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                    ClientController.StartGlide()
                end
            end
        end

    elseif input.KeyCode == Enum.KeyCode.E then
        -- Action key — handled by proximity prompts mostly,
        -- but also used for meditation spots
        ClientController.HandleAction()

    elseif input.KeyCode == Enum.KeyCode.C then
        -- Open Lore Codex
        local LoreCodexUI = require(script.Parent.LoreCodexUI)
        LoreCodexUI.Toggle()
    end
end

function ClientController.OnInputEnded(input: InputObject, gameProcessed: boolean)
    if input.KeyCode == Enum.KeyCode.Space then
        if isGliding then
            ClientController.StopGlide()
        end
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

    -- Create glide BodyVelocity
    local glideForce = Instance.new("BodyVelocity")
    glideForce.Name = "GlideForce"
    glideForce.MaxForce = Vector3.new(0, math.huge, 0)
    glideForce.Velocity = Vector3.new(0, GLIDE_FALL_SPEED, 0)
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
            if glideForce then
                glideForce:Destroy()
            end
        end
    end
    ClientController.ShowWings(false)
end

function ClientController.ToggleFlight()
    if isFlying then
        isFlying = false
        ClientController.StopGlide()
        return
    end

    if stamina <= 0 then
        return
    end

    isFlying = true
    isGliding = false

    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    -- Remove any existing glide force
    local existingForce = humanoidRootPart:FindFirstChild("GlideForce")
    if existingForce then
        existingForce:Destroy()
    end

    -- Create flight BodyVelocity (controlled by camera direction)
    local flightForce = Instance.new("BodyVelocity")
    flightForce.Name = "FlightForce"
    flightForce.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flightForce.Velocity = Vector3.zero
    flightForce.Parent = humanoidRootPart

    -- Counteract gravity
    local antiGrav = Instance.new("BodyForce")
    antiGrav.Name = "FlightAntiGrav"
    antiGrav.Force = Vector3.new(0, humanoidRootPart.AssemblyMass * workspace.Gravity, 0)
    antiGrav.Parent = humanoidRootPart

    ClientController.ShowWings(true)
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

function ClientController.ShowWings(visible: boolean)
    local character = player.Character
    if not character then
        return
    end

    local wings = character:FindFirstChild("AngelWings")
    if visible and not wings then
        -- Create simple wing visual
        wings = Instance.new("Part")
        wings.Name = "AngelWings"
        wings.Size = Vector3.new(0.5, 4, 6)
        wings.Material = Enum.Material.ForceField
        wings.Color = Color3.fromRGB(0, 212, 255)
        wings.Transparency = 0.4
        wings.CanCollide = false
        wings.Massless = true

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        weld.Part1 = wings
        weld.Parent = wings

        local torso = weld.Part0
        if torso then
            wings.CFrame = torso.CFrame * CFrame.new(0, 0.5, 1)
        end

        wings.Parent = character

    elseif not visible and wings then
        wings:Destroy()
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
        if flightForce and stamina > 0 then
            local moveDirection = humanoid.MoveDirection
            local cameraLook = camera.CFrame.LookVector
            local speed = 50

            if moveDirection.Magnitude > 0 then
                flightForce.Velocity = Vector3.new(
                    moveDirection.X * speed,
                    cameraLook.Y * speed * 0.5,
                    moveDirection.Z * speed
                )
            else
                -- Hover in place
                flightForce.Velocity = Vector3.zero
            end

            -- Space to go up, Shift to go down while flying
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                flightForce.Velocity = flightForce.Velocity + Vector3.new(0, 30, 0)
            elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                flightForce.Velocity = flightForce.Velocity + Vector3.new(0, -30, 0)
            end
        elseif stamina <= 0 then
            ClientController.ToggleFlight()  -- forced landing
        end
    end

    -- Auto-stop glide when landing
    if isGliding then
        if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            ClientController.StopGlide()
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
    canGlide = currentLayer >= 2
    canFly = currentLayer >= 5

    -- Trigger cinematic
    local LevelUpCinematic = require(script.Parent.LevelUpCinematic)
    LevelUpCinematic.Play(data)
end

function ClientController.OnServerMessage(data: { [string]: any })
    if data.type == "welcome" then
        currentLevel = data.angelLevel
        local levelIndex = Layers.GetLevelIndex(currentLevel)
        currentLayer = levelIndex
        canGlide = levelIndex >= 2
        canFly = levelIndex >= 5
    end

    local UIManager = require(script.Parent.UIManager)
    UIManager.ShowMessage(data)
end

-- Auto-initialize
ClientController.Init()

return ClientController
