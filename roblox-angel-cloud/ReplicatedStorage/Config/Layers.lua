--[[
    Layers.lua — Cloud layer definitions for The Cloud Climb
    Maps directly to ANGEL_LEVELS and PROGRESSION_THRESHOLDS from angel-cloud/models.py
]]

local Layers = {}

Layers.ANGEL_LEVELS = {
    "Newborn",
    "Young Angel",
    "Growing Angel",
    "Helping Angel",
    "Guardian Angel",
    "Angel",
}

Layers.PROGRESSION_THRESHOLDS = {
    Newborn = 0,
    ["Young Angel"] = 10,
    ["Growing Angel"] = 25,
    ["Helping Angel"] = 50,
    ["Guardian Angel"] = 100,
    Angel = 250,
}

Layers.Definitions = {
    {
        name = "The Nursery",
        layerIndex = 1,
        angelLevel = "Newborn",
        requiredMotes = 0,
        gateThreshold = 10,
        loreFragmentCount = 8,
        description = "Soft white clouds, golden light, simple platforms",
        color = Color3.fromRGB(255, 248, 230),  -- warm white-gold
        features = {
            "Basic movement",
            "Mote collection",
            "Reflection Pools",
            "Tutorial NPC: The Keeper",
        },
        spawnPosition = Vector3.new(0, 100, 0),
        heightRange = { min = 50, max = 250 },
    },
    {
        name = "The Meadow",
        layerIndex = 2,
        angelLevel = "Young Angel",
        requiredMotes = 10,
        gateThreshold = 25,
        loreFragmentCount = 10,
        description = "Floating grass islands, cyan flowers, upward waterfalls",
        color = Color3.fromRGB(0, 212, 255),  -- #00d4ff cyan accent
        features = {
            "Wing Glide",
            "Cooperative Bridges",
            "Guardian Trial access",
            "Blessing Bluffs",
        },
        spawnPosition = Vector3.new(0, 350, 0),
        heightRange = { min = 250, max = 500 },
    },
    {
        name = "The Canopy",
        layerIndex = 3,
        angelLevel = "Growing Angel",
        requiredMotes = 25,
        gateThreshold = 50,
        loreFragmentCount = 12,
        description = "Enormous cloud-trees, bioluminescent fog, rope bridges",
        color = Color3.fromRGB(50, 200, 120),  -- forest-bio green
        features = {
            "Full Stamina System",
            "Cloud-Shaping (create temp platforms)",
            "Group Reflections (3+ players = bonus)",
        },
        spawnPosition = Vector3.new(0, 600, 0),
        heightRange = { min = 500, max = 800 },
    },
    {
        name = "The Stormwall",
        layerIndex = 4,
        angelLevel = "Helping Angel",
        requiredMotes = 50,
        gateThreshold = 100,
        loreFragmentCount = 15,
        description = "Dark purple thunderclouds, lightning arcs, fallen angel ruins",
        color = Color3.fromRGB(100, 40, 160),  -- deep purple
        features = {
            "Wind mechanics (gusts push players)",
            "Shield Wings (protect nearby players)",
            "Angel lore items",
        },
        spawnPosition = Vector3.new(0, 900, 0),
        heightRange = { min = 800, max = 1100 },
    },
    {
        name = "The Luminance",
        layerIndex = 5,
        angelLevel = "Guardian Angel",
        requiredMotes = 100,
        gateThreshold = 250,
        loreFragmentCount = 15,
        description = "Crystalline platforms, aurora sky, deep space visible above",
        color = Color3.fromRGB(180, 220, 255),  -- pale aurora blue
        features = {
            "Full Wing Flight",
            "Memory Echoes",
            "Guardian Duty (descend to help Newborns for bonus Motes)",
            "Mentor Ring",
        },
        spawnPosition = Vector3.new(0, 1200, 0),
        heightRange = { min = 1100, max = 1500 },
    },
    {
        name = "The Empyrean",
        layerIndex = 6,
        angelLevel = "Angel",
        requiredMotes = 250,
        gateThreshold = nil,  -- final layer
        loreFragmentCount = 5,
        description = "Pure light realm, abstract geometry, the Cloud Core",
        color = Color3.fromRGB(255, 255, 255),  -- pure white
        features = {
            "Cloud Architect (place permanent decorative structures)",
            "Blessing Rain (trigger server-wide bonus events)",
            "Full Lore Codex",
        },
        spawnPosition = Vector3.new(0, 1600, 0),
        heightRange = { min = 1500, max = 2000 },
    },
}

function Layers.GetLayerForLevel(angelLevel: string)
    for _, layer in ipairs(Layers.Definitions) do
        if layer.angelLevel == angelLevel then
            return layer
        end
    end
    return Layers.Definitions[1]
end

function Layers.GetLayerByIndex(index: number)
    return Layers.Definitions[index]
end

function Layers.GetLevelForMotes(motes: number): string
    local level = "Newborn"
    for i = #Layers.ANGEL_LEVELS, 1, -1 do
        local name = Layers.ANGEL_LEVELS[i]
        if motes >= Layers.PROGRESSION_THRESHOLDS[name] then
            level = name
            break
        end
    end
    return level
end

function Layers.GetLevelIndex(level: string): number
    for i, name in ipairs(Layers.ANGEL_LEVELS) do
        if name == level then
            return i
        end
    end
    return 1
end

return Layers
