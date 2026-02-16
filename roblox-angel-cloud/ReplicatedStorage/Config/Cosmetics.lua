--[[
    Cosmetics.lua — Purchasable cosmetic items (ethical, no pay-to-win)
    NEVER for sale: Light Motes, stamina boosts, Lore Fragments, layer access, trial advantages
]]

local Cosmetics = {}

Cosmetics.Categories = {
    WingSkins = "WingSkins",
    TrailEffects = "TrailEffects",
    EmotePacks = "EmotePacks",
    CloudMaterials = "CloudMaterials",
    NameGlow = "NameGlow",
    StarterPack = "StarterPack",
    Special = "Special",
}

Cosmetics.Items = {
    -- Wing Skins (75-150 Robux)
    {
        id = "wings_crystal",
        name = "Crystal Wings",
        category = "WingSkins",
        price = 100,
        description = "Transparent crystalline wings that refract light",
        color = Color3.fromRGB(200, 230, 255),
    },
    {
        id = "wings_nebula",
        name = "Nebula Wings",
        category = "WingSkins",
        price = 150,
        description = "Swirling cosmic nebula pattern",
        color = Color3.fromRGB(120, 50, 200),
    },
    {
        id = "wings_flame",
        name = "Phoenix Wings",
        category = "WingSkins",
        price = 150,
        description = "Flickering flame effects at the edges",
        color = Color3.fromRGB(255, 120, 30),
    },
    {
        id = "wings_nature",
        name = "Verdant Wings",
        category = "WingSkins",
        price = 75,
        description = "Leaf and vine patterns with a natural glow",
        color = Color3.fromRGB(80, 200, 80),
    },
    {
        id = "wings_aurora",
        name = "Aurora Wings",
        category = "WingSkins",
        price = 125,
        description = "Shifting aurora borealis colors",
        color = Color3.fromRGB(0, 212, 255),
    },

    -- Trail Effects (50-100 Robux)
    {
        id = "trail_stardust",
        name = "Stardust Trail",
        category = "TrailEffects",
        price = 75,
        description = "Sparkling particles follow your path",
        color = Color3.fromRGB(255, 255, 200),
    },
    {
        id = "trail_cyan_ribbon",
        name = "Cyan Ribbon",
        category = "TrailEffects",
        price = 50,
        description = "Flowing cyan ribbon trail",
        color = Color3.fromRGB(0, 212, 255),
    },
    {
        id = "trail_rainbow",
        name = "Prismatic Trail",
        category = "TrailEffects",
        price = 100,
        description = "Slowly cycling rainbow colors",
        color = Color3.fromRGB(255, 255, 255),
    },

    -- Emote Packs (75 Robux)
    {
        id = "emote_meditation",
        name = "Meditation Pack",
        category = "EmotePacks",
        price = 75,
        description = "Lotus sit, breathing glow, mindful nod",
    },
    {
        id = "emote_celebration",
        name = "Celebration Pack",
        category = "EmotePacks",
        price = 75,
        description = "Group hug, wing flutter, light burst",
    },

    -- Cloud Architect Materials (50-100 Robux, Layer 6 only)
    {
        id = "cloud_crystal",
        name = "Crystal Cloud Material",
        category = "CloudMaterials",
        price = 75,
        description = "Build with shimmering crystal clouds (Layer 6)",
        requiredLayer = 6,
    },
    {
        id = "cloud_golden",
        name = "Golden Cloud Material",
        category = "CloudMaterials",
        price = 100,
        description = "Build with radiant golden clouds (Layer 6)",
        requiredLayer = 6,
    },

    -- Name Glow (50 Robux)
    {
        id = "glow_cyan",
        name = "Cyan Name Glow",
        category = "NameGlow",
        price = 50,
        description = "Your name shines in Angel Cloud cyan",
        color = Color3.fromRGB(0, 212, 255),
    },
    {
        id = "glow_gold",
        name = "Golden Name Glow",
        category = "NameGlow",
        price = 50,
        description = "Your name shines in warm gold",
        color = Color3.fromRGB(255, 215, 0),
    },

    -- Starter Pack (199 Robux, 30% off)
    {
        id = "starter_pack",
        name = "Angel Starter Pack",
        category = "StarterPack",
        price = 199,
        description = "Crystal Wings + Stardust Trail + Meditation Pack (30% off!)",
        includes = { "wings_crystal", "trail_stardust", "emote_meditation" },
    },

    -- Special (earned, not purchased)
    {
        id = "founders_halo",
        name = "Founder's Halo",
        category = "Special",
        price = 0,  -- Ko-fi code redemption only
        description = "Golden halo for real-world Angel Cloud supporters",
        earned = true,
        earnMethod = "Ko-fi donation code",
    },
    {
        id = "cloud_connected_badge",
        name = "Cloud Connected",
        category = "Special",
        price = 0,
        description = "Badge showing you're linked to the real Angel Cloud",
        earned = true,
        earnMethod = "Cross-platform link verification",
    },
    {
        id = "starfish_hunter",
        name = "Starfish Hunter",
        category = "Special",
        price = 0,
        description = "Found every hidden Brown Starfish in The Cloud Climb. The great mind smiles upon you.",
        earned = true,
        earnMethod = "Find all Brown Starfish easter eggs",
        color = Color3.fromRGB(161, 120, 72),
    },
}

function Cosmetics.GetItem(itemId: string)
    for _, item in ipairs(Cosmetics.Items) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

function Cosmetics.GetByCategory(category: string): { any }
    local items = {}
    for _, item in ipairs(Cosmetics.Items) do
        if item.category == category then
            table.insert(items, item)
        end
    end
    return items
end

function Cosmetics.GetPurchasable(): { any }
    local items = {}
    for _, item in ipairs(Cosmetics.Items) do
        if item.price > 0 and not item.earned then
            table.insert(items, item)
        end
    end
    return items
end

return Cosmetics
