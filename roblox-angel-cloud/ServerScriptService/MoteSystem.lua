--[[
    MoteSystem.lua — Light Mote collection and awarding
    Server-authoritative: clients request actions, server validates and awards
    Motes map to interaction_count on the real Angel Cloud platform
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local SoundManager = require(script.Parent.SoundManager)
local Layers = require(ReplicatedStorage.Config.Layers)

local MoteSystem = {}

-- RemoteEvents (created at startup)
local MoteCollected  -- Server -> Client: notify mote pickup
local MoteAwarded    -- Server -> Client: notify mote award (from blessing, trial, etc.)

-- Mote sources and their values
MoteSystem.Sources = {
    reflection_task = 1,
    help_player = 1,
    guardian_trial = 3,  -- base, actual varies by trial
    cooperative_boss = 5,
    blessing_given = -2,   -- cost to give a blessing
    blessing_chain_bonus = 1,
    group_reflection = 2,
    guardian_duty = 2,
    halt_rest_bonus = 5,
    world_mote_pickup = 1,
}

function MoteSystem.Init()
    -- Create RemoteEvents in ReplicatedStorage
    MoteCollected = Instance.new("RemoteEvent")
    MoteCollected.Name = "MoteCollected"
    MoteCollected.Parent = ReplicatedStorage

    MoteAwarded = Instance.new("RemoteEvent")
    MoteAwarded.Name = "MoteAwarded"
    MoteAwarded.Parent = ReplicatedStorage
end

function MoteSystem.AwardMotes(player: Player, amount: number, source: string): number
    local data = DataManager.GetData(player)
    if not data then
        return 0
    end

    data.motes = math.max(0, data.motes + amount)

    -- Notify client
    MoteAwarded:FireClient(player, {
        amount = amount,
        source = source,
        totalMotes = data.motes,
    })

    -- CHECK FOR LEVEL UP after every mote gain
    if amount > 0 then
        local ProgressionSystem = require(script.Parent.ProgressionSystem)
        ProgressionSystem.OnMotesChanged(player)
        DataManager.IncrementCommunityStat("total_motes_earned", amount)

        -- Quest + sound hooks
        local QuestSystem = require(script.Parent.QuestSystem)
        pcall(QuestSystem.OnMoteCollected, player, amount)
        local SoundManager = require(script.Parent.SoundManager)
        pcall(SoundManager.OnMoteCollected, player)
    end

    return data.motes
end

function MoteSystem.GetMotes(player: Player): number
    local data = DataManager.GetData(player)
    return data and data.motes or 0
end

function MoteSystem.CanAfford(player: Player, cost: number): boolean
    return MoteSystem.GetMotes(player) >= cost
end

-- World mote pickup: called when player touches a mote part in the world
function MoteSystem.HandleWorldMotePickup(player: Player, motePart: BasePart)
    if not motePart or not motePart:FindFirstChild("MoteValue") then
        return
    end

    local value = motePart.MoteValue.Value or 1
    local newTotal = MoteSystem.AwardMotes(player, value, "world_mote_pickup")

    -- Hide mote + glow + particles (respawns after cooldown)
    motePart.Transparency = 1
    local sparkle = motePart:FindFirstChild("MoteSparkle")
    if sparkle then sparkle.Enabled = false end
    local light = motePart:FindFirstChildWhichIsA("PointLight")
    if light then light.Enabled = false end

    -- Hide the outer glow ring too
    local glowPart = motePart.Parent and motePart.Parent:FindFirstChild("MoteGlow")
    -- Glow shares folder, find nearest by position
    if motePart.Parent then
        for _, child in ipairs(motePart.Parent:GetChildren()) do
            if child.Name == "MoteGlow" and (child.Position - motePart.Position).Magnitude < 6 then
                child.Transparency = 1
                task.delay(30, function()
                    if child and child.Parent then child.Transparency = 0.85 end
                end)
                break
            end
        end
    end

    task.delay(30, function()
        if motePart and motePart.Parent then
            motePart.Transparency = 0.1
            if sparkle then sparkle.Enabled = true end
            if light then light.Enabled = true end
        end
    end)

    MoteCollected:FireClient(player, {
        position = motePart.Position,
        value = value,
        totalMotes = newTotal,
    })

    -- Play mote collect sound
    SoundManager.OnMoteCollected(player)
end

-- Spawn world motes in a layer — magical floating orbs with particles
function MoteSystem.SpawnWorldMotes(layerFolder: Folder, count: number, layerDef: { [string]: any })
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max
    local spread = 200

    for i = 1, count do
        local mote = Instance.new("Part")
        mote.Name = "LightMote_" .. i
        mote.Shape = Enum.PartType.Ball
        mote.Size = Vector3.new(2.5, 2.5, 2.5)
        mote.Position = Vector3.new(
            math.random(-spread, spread),
            math.random(heightMin + 10, heightMax - 10),
            math.random(-spread, spread)
        )
        mote.Anchored = true
        mote.CanCollide = false
        mote.Material = Enum.Material.Neon
        mote.Color = Color3.fromRGB(0, 212, 255)
        mote.Transparency = 0.1

        -- Bright glow
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0, 212, 255)
        light.Brightness = 2.5
        light.Range = 25
        light.Parent = mote

        -- Sparkle particle emitter (makes motes feel alive)
        local sparkle = Instance.new("ParticleEmitter")
        sparkle.Name = "MoteSparkle"
        sparkle.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 212, 255)),
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
        sparkle.Rate = 6
        sparkle.Speed = NumberRange.new(0.5, 2)
        sparkle.SpreadAngle = Vector2.new(360, 360)
        sparkle.LightEmission = 1
        sparkle.Parent = mote

        -- Outer glow ring (non-solid, adds visual size)
        local glow = Instance.new("Part")
        glow.Name = "MoteGlow"
        glow.Shape = Enum.PartType.Ball
        glow.Size = Vector3.new(5, 5, 5)
        glow.Position = mote.Position
        glow.Anchored = true
        glow.CanCollide = false
        glow.Material = Enum.Material.Neon
        glow.Color = Color3.fromRGB(0, 212, 255)
        glow.Transparency = 0.85
        glow.Parent = layerFolder

        local value = Instance.new("IntValue")
        value.Name = "MoteValue"
        value.Value = 1
        value.Parent = mote

        -- Touch detection (bigger radius — 8 stud magnet pickup)
        local touchRegion = Instance.new("Part")
        touchRegion.Name = "MotePickupZone"
        touchRegion.Shape = Enum.PartType.Ball
        touchRegion.Size = Vector3.new(12, 12, 12)
        touchRegion.Position = mote.Position
        touchRegion.Anchored = true
        touchRegion.CanCollide = false
        touchRegion.Transparency = 1
        touchRegion.Parent = layerFolder

        touchRegion.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player and mote.Transparency < 1 then
                MoteSystem.HandleWorldMotePickup(player, mote)
            end
        end)

        -- Bobbing + pulsing animation
        local originalY = mote.Position.Y
        task.spawn(function()
            local offset = math.random() * math.pi * 2
            while mote and mote.Parent do
                local t = tick()
                local newY = originalY + math.sin(t * 2.5 + offset) * 2
                mote.Position = Vector3.new(mote.Position.X, newY, mote.Position.Z)
                touchRegion.Position = mote.Position
                glow.Position = mote.Position

                -- Gentle pulse (size oscillation)
                local pulse = 2.5 + math.sin(t * 3 + offset) * 0.4
                mote.Size = Vector3.new(pulse, pulse, pulse)
                local glowPulse = 5 + math.sin(t * 3 + offset) * 0.8
                glow.Size = Vector3.new(glowPulse, glowPulse, glowPulse)

                task.wait(0.05)
            end
        end)

        mote.Parent = layerFolder
    end
end

return MoteSystem
