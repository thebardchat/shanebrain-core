--[[
    LevelUpCinematic.lua — Ascension sequence when a player levels up
    Cyan light beam -> wings visually upgrade -> cloud staircase materializes
    Server notification: "[Player] ascends to [LayerName]! Every Angel strengthens the cloud."
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layers = require(ReplicatedStorage.Config.Layers)

local LevelUpCinematic = {}

local player = Players.LocalPlayer

local COLORS = {
    beam = Color3.fromRGB(0, 212, 255),
    wings = Color3.fromRGB(0, 212, 255),
    staircase = Color3.fromRGB(200, 230, 255),
    gold = Color3.fromRGB(255, 215, 0),
    white = Color3.fromRGB(255, 255, 255),
    bg = Color3.fromRGB(5, 5, 12),
}

function LevelUpCinematic.Init()
    local LevelUp = ReplicatedStorage:WaitForChild("LevelUp")
    LevelUp.OnClientEvent:Connect(function(data)
        LevelUpCinematic.Play(data)
    end)
end

function LevelUpCinematic.Play(data: { [string]: any })
    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    local playerGui = player:WaitForChild("PlayerGui")
    local position = humanoidRootPart.Position

    -- Phase 1: Cyan light beam (0-2s)
    local beam = Instance.new("Part")
    beam.Name = "AscensionBeam"
    beam.Size = Vector3.new(4, 500, 4)
    beam.Position = position + Vector3.new(0, 250, 0)
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = COLORS.beam
    beam.Transparency = 0.2
    beam.Parent = workspace

    -- Particle burst ring at player's feet (visible to everyone)
    local burstRing = Instance.new("Part")
    burstRing.Name = "AscensionBurst"
    burstRing.Shape = Enum.PartType.Cylinder
    burstRing.Size = Vector3.new(1, 4, 4)
    burstRing.Position = position
    burstRing.Orientation = Vector3.new(0, 0, 90)
    burstRing.Anchored = true
    burstRing.CanCollide = false
    burstRing.Material = Enum.Material.Neon
    burstRing.Color = COLORS.beam
    burstRing.Transparency = 0.3
    burstRing.Parent = workspace

    -- Ring expands outward
    TweenService:Create(burstRing, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1, 60, 60),
        Transparency = 1,
    }):Play()
    task.delay(2.5, function()
        if burstRing and burstRing.Parent then burstRing:Destroy() end
    end)

    -- Particle emitter on beam (sparkle shower)
    local beamParticles = Instance.new("ParticleEmitter")
    beamParticles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.beam),
        ColorSequenceKeypoint.new(1, COLORS.gold),
    })
    beamParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    beamParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    beamParticles.Lifetime = NumberRange.new(1, 3)
    beamParticles.Rate = 30
    beamParticles.Speed = NumberRange.new(2, 8)
    beamParticles.SpreadAngle = Vector2.new(180, 180)
    beamParticles.LightEmission = 1
    beamParticles.Parent = beam

    -- Screen flash
    local screenFlash = Instance.new("Frame")
    screenFlash.Name = "AscensionFlash"
    screenFlash.Size = UDim2.new(1, 0, 1, 0)
    screenFlash.BackgroundColor3 = COLORS.beam
    screenFlash.BackgroundTransparency = 0.5
    screenFlash.ZIndex = 50
    screenFlash.Parent = playerGui:FindFirstChild("AngelCloudUI") or playerGui

    TweenService:Create(screenFlash, TweenInfo.new(2), {
        BackgroundTransparency = 1,
    }):Play()

    -- Camera shake (subtle, 1.5 seconds)
    local camera = workspace.CurrentCamera
    task.spawn(function()
        local shakeEnd = tick() + 1.5
        local intensity = 0.3
        while tick() < shakeEnd do
            local elapsed = shakeEnd - tick()
            local shakeMag = intensity * (elapsed / 1.5)
            camera.CFrame = camera.CFrame * CFrame.new(
                (math.random() - 0.5) * shakeMag,
                (math.random() - 0.5) * shakeMag,
                0
            )
            RunService.RenderStepped:Wait()
        end
    end)

    -- Phase 2: Wings upgrade visual (1-3s)
    task.delay(1, function()
        -- Remove old wings if present
        local oldWings = character:FindFirstChild("AngelWings")
        if oldWings then
            oldWings:Destroy()
        end

        -- Create upgraded wings (bigger, brighter)
        local levelIndex = data.layerIndex or 1
        local wingSize = 4 + levelIndex * 0.5
        local wings = Instance.new("Part")
        wings.Name = "AngelWings"
        wings.Size = Vector3.new(0.5, wingSize, wingSize * 1.5)
        wings.Material = Enum.Material.ForceField
        wings.Color = COLORS.wings
        wings.Transparency = 0.3
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

        -- Wing pulse animation
        TweenService:Create(wings, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
            Transparency = 0.1,
            Size = Vector3.new(0.5, wingSize + 1, wingSize * 1.5 + 1),
        }):Play()
    end)

    -- Phase 3: Cloud staircase materializes (2-4s)
    task.delay(2, function()
        local layerDef = Layers.GetLayerByIndex(data.layerIndex)
        if not layerDef then
            return
        end

        local targetY = layerDef.spawnPosition.Y
        local startY = position.Y
        local stepCount = 8
        local stepHeight = (targetY - startY) / stepCount

        for i = 1, stepCount do
            task.delay(i * 0.15, function()
                local step = Instance.new("Part")
                step.Name = "CloudStep_" .. i
                step.Size = Vector3.new(6, 1, 4)
                step.Position = Vector3.new(
                    position.X + i * 3,
                    startY + i * stepHeight,
                    position.Z
                )
                step.Anchored = true
                step.CanCollide = true
                step.Material = Enum.Material.SmoothPlastic
                step.Color = COLORS.staircase
                step.Transparency = 0.3
                step.Parent = workspace

                local stepCorner = Instance.new("SpecialMesh")
                stepCorner.MeshType = Enum.MeshType.Brick
                stepCorner.Parent = step

                -- Fade in
                step.Transparency = 1
                TweenService:Create(step, TweenInfo.new(0.3), {
                    Transparency = 0.3,
                }):Play()

                -- Steps disappear after 15 seconds
                task.delay(15, function()
                    TweenService:Create(step, TweenInfo.new(1), {
                        Transparency = 1,
                    }):Play()
                    task.delay(1, function()
                        step:Destroy()
                    end)
                end)
            end)
        end
    end)

    -- Phase 4: UI announcement (1-5s)
    task.delay(0.5, function()
        LevelUpCinematic.ShowAscensionUI(data)
    end)

    -- Cleanup beam
    task.delay(4, function()
        TweenService:Create(beam, TweenInfo.new(2), {
            Transparency = 1,
            Size = Vector3.new(1, 500, 1),
        }):Play()
        task.delay(2, function()
            beam:Destroy()
        end)
    end)

    -- Cleanup flash
    task.delay(2, function()
        if screenFlash and screenFlash.Parent then
            screenFlash:Destroy()
        end
    end)
end

function LevelUpCinematic.ShowAscensionUI(data: { [string]: any })
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("AngelCloudUI")
    if not screenGui then
        return
    end

    local frame = Instance.new("Frame")
    frame.Name = "AscensionUI"
    frame.Size = UDim2.new(0, 500, 0, 180)
    frame.Position = UDim2.new(0.5, -250, 0.35, -90)
    frame.BackgroundColor3 = COLORS.bg
    frame.BackgroundTransparency = 0.1
    frame.ZIndex = 30
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.beam
    stroke.Thickness = 2
    stroke.Parent = frame

    -- "ASCENSION" header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 15)
    header.BackgroundTransparency = 1
    header.Text = "A S C E N S I O N"
    header.TextColor3 = COLORS.beam
    header.TextSize = 16
    header.Font = Enum.Font.GothamBold
    header.ZIndex = 31
    header.Parent = frame

    -- Level name
    local levelName = Instance.new("TextLabel")
    levelName.Size = UDim2.new(1, 0, 0, 40)
    levelName.Position = UDim2.new(0, 0, 0, 50)
    levelName.BackgroundTransparency = 1
    levelName.Text = data.newLevel or "Unknown"
    levelName.TextColor3 = COLORS.gold
    levelName.TextSize = 32
    levelName.Font = Enum.Font.GothamBold
    levelName.ZIndex = 31
    levelName.Parent = frame

    -- Layer name
    local layerName = Instance.new("TextLabel")
    layerName.Size = UDim2.new(1, 0, 0, 25)
    layerName.Position = UDim2.new(0, 0, 0, 95)
    layerName.BackgroundTransparency = 1
    layerName.Text = "Welcome to " .. (data.layerName or "the next layer")
    layerName.TextColor3 = COLORS.white
    layerName.TextSize = 18
    layerName.Font = Enum.Font.GothamMedium
    layerName.ZIndex = 31
    layerName.Parent = frame

    -- Motto
    local motto = Instance.new("TextLabel")
    motto.Size = UDim2.new(1, 0, 0, 20)
    motto.Position = UDim2.new(0, 0, 0, 135)
    motto.BackgroundTransparency = 1
    motto.Text = "Every Angel strengthens the cloud."
    motto.TextColor3 = Color3.fromRGB(150, 150, 170)
    motto.TextSize = 13
    motto.Font = Enum.Font.GothamMedium
    motto.ZIndex = 31
    motto.Parent = frame

    -- Animate in
    frame.BackgroundTransparency = 1
    header.TextTransparency = 1
    levelName.TextTransparency = 1
    layerName.TextTransparency = 1
    motto.TextTransparency = 1
    stroke.Transparency = 1

    TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 0.1 }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 0 }):Play()
    task.delay(0.3, function()
        TweenService:Create(header, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    end)
    task.delay(0.6, function()
        TweenService:Create(levelName, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    end)
    task.delay(0.9, function()
        TweenService:Create(layerName, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    end)
    task.delay(1.2, function()
        TweenService:Create(motto, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    end)

    -- Auto-dismiss after 6 seconds
    task.delay(6, function()
        TweenService:Create(frame, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(header, TweenInfo.new(1), { TextTransparency = 1 }):Play()
        TweenService:Create(levelName, TweenInfo.new(1), { TextTransparency = 1 }):Play()
        TweenService:Create(layerName, TweenInfo.new(1), { TextTransparency = 1 }):Play()
        TweenService:Create(motto, TweenInfo.new(1), { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, TweenInfo.new(1), { Transparency = 1 }):Play()
        task.delay(1.5, function()
            frame:Destroy()
        end)
    end)
end

return LevelUpCinematic
