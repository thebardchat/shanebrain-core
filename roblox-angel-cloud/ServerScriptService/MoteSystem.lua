--[[
    MoteSystem.lua — Light Mote collection and awarding
    Server-authoritative: clients request actions, server validates and awards
    Motes map to interaction_count on the real Angel Cloud platform
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
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

    -- Disable the mote for this player (respawns after cooldown)
    motePart.Transparency = 1
    motePart.CanCollide = false

    task.delay(30, function()
        if motePart and motePart.Parent then
            motePart.Transparency = 0
            motePart.CanCollide = false  -- motes are always walk-through
        end
    end)

    MoteCollected:FireClient(player, {
        position = motePart.Position,
        value = value,
        totalMotes = newTotal,
    })
end

-- Spawn world motes in a layer
function MoteSystem.SpawnWorldMotes(layerFolder: Folder, count: number, layerDef: { [string]: any })
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max
    local spread = 200

    for i = 1, count do
        local mote = Instance.new("Part")
        mote.Name = "LightMote_" .. i
        mote.Shape = Enum.PartType.Ball
        mote.Size = Vector3.new(3, 3, 3)  -- bigger, easier to see
        mote.Position = Vector3.new(
            math.random(-spread, spread),
            math.random(heightMin + 10, heightMax - 10),
            math.random(-spread, spread)
        )
        mote.Anchored = true
        mote.CanCollide = false
        mote.Material = Enum.Material.Neon
        mote.Color = Color3.fromRGB(0, 212, 255)  -- Angel Cloud cyan
        mote.Transparency = 0.1

        -- Bright glow so you can see them from far away
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0, 212, 255)
        light.Brightness = 2
        light.Range = 20
        light.Parent = mote

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

        -- Bobbing animation
        local originalY = mote.Position.Y
        task.spawn(function()
            local offset = math.random() * math.pi * 2
            while mote and mote.Parent do
                local newY = originalY + math.sin(tick() * 2.5 + offset) * 2
                mote.Position = Vector3.new(mote.Position.X, newY, mote.Position.Z)
                touchRegion.Position = mote.Position
                task.wait(0.05)
            end
        end)

        mote.Parent = layerFolder
    end
end

return MoteSystem
