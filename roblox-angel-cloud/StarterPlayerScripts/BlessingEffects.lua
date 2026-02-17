--[[
    BlessingEffects.lua — Visual effects for the Blessing system
    Beam of light when sending, receiving, and chain bonuses
    Matches Angel Cloud visual identity (#00d4ff cyan, golden glow)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlessingEffects = {}

local player = Players.LocalPlayer

local COLORS = {
    blessingBeam = Color3.fromRGB(0, 212, 255),
    blessingGold = Color3.fromRGB(255, 215, 0),
    chainGreen = Color3.fromRGB(100, 255, 150),
}

function BlessingEffects.Init()
    -- Listen for blessing events
    local BlessingReceived = ReplicatedStorage:WaitForChild("BlessingReceived")
    BlessingReceived.OnClientEvent:Connect(function(data)
        BlessingEffects.PlayReceiveEffect()
    end)

    local BlessingChain = ReplicatedStorage:WaitForChild("BlessingChain")
    BlessingChain.OnClientEvent:Connect(function(data)
        BlessingEffects.PlayChainEffect(data.chainLength)
    end)

    local MoteCollected = ReplicatedStorage:WaitForChild("MoteCollected")
    MoteCollected.OnClientEvent:Connect(function(data)
        if data.position then
            BlessingEffects.PlayMotePickupEffect(data.position)
        end
    end)
end

function BlessingEffects.PlayReceiveEffect()
    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    -- Cyan light beam from above
    local beam = Instance.new("Part")
    beam.Name = "BlessingBeam"
    beam.Size = Vector3.new(3, 200, 3)
    beam.Position = humanoidRootPart.Position + Vector3.new(0, 100, 0)
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = COLORS.blessingBeam
    beam.Transparency = 0.3
    beam.Shape = Enum.PartType.Cylinder
    beam.Orientation = Vector3.new(0, 0, 90)
    beam.Parent = workspace

    -- Expanding ring at player's feet
    local ring = Instance.new("Part")
    ring.Name = "BlessingRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.5, 4, 4)
    ring.Position = humanoidRootPart.Position - Vector3.new(0, 3, 0)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = COLORS.blessingGold
    ring.Transparency = 0.3
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.Parent = workspace

    -- Animate: beam fades, ring expands
    TweenService:Create(beam, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(1, 200, 1),
    }):Play()

    TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.5, 30, 30),
        Transparency = 1,
    }):Play()

    -- Particle burst
    BlessingEffects.CreateParticleBurst(humanoidRootPart.Position, COLORS.blessingBeam, 20)

    -- Cleanup
    task.delay(2.5, function()
        beam:Destroy()
        ring:Destroy()
    end)
end

function BlessingEffects.PlayChainEffect(chainLength: number)
    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    -- Multiple expanding rings (one per chain length, up to 5)
    local ringCount = math.min(chainLength, 5)
    for i = 1, ringCount do
        task.delay(i * 0.2, function()
            local ring = Instance.new("Part")
            ring.Name = "ChainRing_" .. i
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.3, 2, 2)
            ring.Position = humanoidRootPart.Position + Vector3.new(0, i * 2, 0)
            ring.Anchored = true
            ring.CanCollide = false
            ring.Material = Enum.Material.Neon
            ring.Color = COLORS.chainGreen
            ring.Transparency = 0.2
            ring.Orientation = Vector3.new(0, 0, 90)
            ring.Parent = workspace

            TweenService:Create(ring, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(0.3, 20 + i * 5, 20 + i * 5),
                Transparency = 1,
                Position = ring.Position + Vector3.new(0, 5, 0),
            }):Play()

            task.delay(1.5, function()
                ring:Destroy()
            end)
        end)
    end

    BlessingEffects.CreateParticleBurst(humanoidRootPart.Position, COLORS.chainGreen, 15)
end

function BlessingEffects.PlayMotePickupEffect(position: Vector3)
    -- Burst emitter at pickup location (much cleaner than Part spam)
    local emitterPart = Instance.new("Part")
    emitterPart.Name = "MotePickupBurst"
    emitterPart.Size = Vector3.new(1, 1, 1)
    emitterPart.Position = position
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Transparency = 1
    emitterPart.Parent = workspace

    -- Flash sphere
    local flash = Instance.new("Part")
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(3, 3, 3)
    flash.Position = position
    flash.Anchored = true
    flash.CanCollide = false
    flash.Material = Enum.Material.Neon
    flash.Color = COLORS.blessingBeam
    flash.Transparency = 0
    flash.Parent = workspace

    -- Flash expands and fades
    TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(8, 8, 8),
        Transparency = 1,
    }):Play()

    -- Particle burst upward
    local burst = Instance.new("ParticleEmitter")
    burst.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.blessingBeam),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    burst.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    burst.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    burst.Lifetime = NumberRange.new(0.3, 0.8)
    burst.Speed = NumberRange.new(8, 15)
    burst.SpreadAngle = Vector2.new(360, 360)
    burst.LightEmission = 1
    burst.Parent = emitterPart

    -- Emit a burst then disable
    burst:Emit(20)
    burst.Enabled = false

    task.delay(1.2, function()
        emitterPart:Destroy()
        flash:Destroy()
    end)
end

function BlessingEffects.CreateParticleBurst(position: Vector3, color: Color3, count: number)
    for _ = 1, count do
        local particle = Instance.new("Part")
        particle.Shape = Enum.PartType.Ball
        particle.Size = Vector3.new(0.3, 0.3, 0.3)
        particle.Position = position
        particle.Anchored = true
        particle.CanCollide = false
        particle.Material = Enum.Material.Neon
        particle.Color = color
        particle.Transparency = 0
        particle.Parent = workspace

        local direction = Vector3.new(
            math.random() * 2 - 1,
            math.random() * 2,
            math.random() * 2 - 1
        ).Unit * (5 + math.random() * 10)

        TweenService:Create(particle, TweenInfo.new(0.6 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = position + direction,
            Size = Vector3.new(0.05, 0.05, 0.05),
            Transparency = 1,
        }):Play()

        task.delay(1.2, function()
            particle:Destroy()
        end)
    end
end

return BlessingEffects
