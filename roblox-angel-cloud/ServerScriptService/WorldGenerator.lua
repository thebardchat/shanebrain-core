--[[
    WorldGenerator.lua — Procedural cloud world builder
    Generates platforms, islands, structures, and decorations for each layer
    Each layer has a distinct visual identity matching the design doc
    Runs at server startup — creates the entire playable world
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Layers = require(ReplicatedStorage.Config.Layers)

local WorldGenerator = {}

-- Shared materials and properties
local CLOUD_MATERIAL = Enum.Material.SmoothPlastic
local NEON_MATERIAL = Enum.Material.Neon
local GLASS_MATERIAL = Enum.Material.Glass
local ICE_MATERIAL = Enum.Material.Glacier
local FORCE_FIELD = Enum.Material.ForceField

-- Layer-specific color palettes (bright, heavenly, visible)
local PALETTES = {
    -- Layer 1: The Nursery — soft white clouds with warm golden glow
    {
        primary = Color3.fromRGB(240, 235, 250),
        secondary = Color3.fromRGB(250, 245, 255),
        accent = Color3.fromRGB(255, 200, 50),
        glow = Color3.fromRGB(255, 215, 100),
        detail = Color3.fromRGB(220, 215, 235),
    },
    -- Layer 2: The Meadow — pastel teal-white clouds, cyan accents
    {
        primary = Color3.fromRGB(220, 245, 250),
        secondary = Color3.fromRGB(235, 250, 255),
        accent = Color3.fromRGB(0, 212, 255),
        glow = Color3.fromRGB(80, 230, 255),
        detail = Color3.fromRGB(200, 235, 245),
    },
    -- Layer 3: The Canopy — soft green-white, bioluminescent
    {
        primary = Color3.fromRGB(210, 245, 220),
        secondary = Color3.fromRGB(225, 250, 230),
        accent = Color3.fromRGB(100, 255, 180),
        glow = Color3.fromRGB(80, 255, 160),
        detail = Color3.fromRGB(190, 235, 200),
    },
    -- Layer 4: The Stormwall — grey-purple clouds, electric purple
    {
        primary = Color3.fromRGB(180, 170, 200),
        secondary = Color3.fromRGB(200, 190, 220),
        accent = Color3.fromRGB(180, 100, 255),
        glow = Color3.fromRGB(200, 150, 255),
        detail = Color3.fromRGB(160, 150, 185),
    },
    -- Layer 5: The Luminance — crystal ice-white, aurora shimmer
    {
        primary = Color3.fromRGB(230, 240, 255),
        secondary = Color3.fromRGB(240, 248, 255),
        accent = Color3.fromRGB(100, 200, 255),
        glow = Color3.fromRGB(150, 220, 255),
        detail = Color3.fromRGB(220, 235, 255),
    },
    -- Layer 6: The Empyrean — pure radiant white
    {
        primary = Color3.fromRGB(255, 255, 255),
        secondary = Color3.fromRGB(250, 250, 255),
        accent = Color3.fromRGB(255, 240, 200),
        glow = Color3.fromRGB(255, 255, 240),
        detail = Color3.fromRGB(245, 245, 255),
    },
}

function WorldGenerator.Init()
    print("[WorldGenerator] Building The Cloud Climb...")

    -- Build all 6 layers
    for i = 1, 6 do
        WorldGenerator.BuildLayer(i)
    end

    print("[WorldGenerator] World generation complete — all 6 layers built")
end

function WorldGenerator.BuildLayer(layerIndex: number)
    local layerDef = Layers.GetLayerByIndex(layerIndex)
    if not layerDef then return end

    local palette = PALETTES[layerIndex]
    local folderName = "Layer" .. layerIndex .. "_" .. layerDef.name:gsub("The ", ""):gsub("%s+", "")
    local folder = workspace:FindFirstChild(folderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = folderName
        folder.Parent = workspace
    end

    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max
    local centerY = (heightMin + heightMax) / 2

    -- 1. Spawn platform (large, safe landing area)
    WorldGenerator.CreateSpawnPlatform(folder, layerDef.spawnPosition, palette, layerIndex)

    -- 2. Main cloud platforms (navigable terrain)
    WorldGenerator.CreateCloudPlatforms(folder, centerY, heightMin, heightMax, palette, layerIndex)

    -- 3. Floating islands
    WorldGenerator.CreateFloatingIslands(folder, centerY, heightMin, heightMax, palette, layerIndex)

    -- 4. Decorative clouds (non-solid, atmosphere)
    WorldGenerator.CreateDecorativeClouds(folder, heightMin, heightMax, palette)

    -- 5. Light pillars / glowing accents
    WorldGenerator.CreateLightPillars(folder, heightMin, heightMax, palette, layerIndex)

    -- 6. Reflection Pool structure
    WorldGenerator.CreateReflectionPool(folder, layerDef, palette)

    -- 7. Layer-specific features
    if layerIndex == 1 then
        WorldGenerator.BuildNurseryFeatures(folder, layerDef, palette)
        WorldGenerator.BuildWingForge(folder, layerDef, palette)
    elseif layerIndex == 2 then
        WorldGenerator.BuildMeadowFeatures(folder, layerDef, palette)
    elseif layerIndex == 3 then
        WorldGenerator.BuildCanopyFeatures(folder, layerDef, palette)
    elseif layerIndex == 4 then
        WorldGenerator.BuildStormwallFeatures(folder, layerDef, palette)
    elseif layerIndex == 5 then
        WorldGenerator.BuildLuminanceFeatures(folder, layerDef, palette)
    elseif layerIndex == 6 then
        WorldGenerator.BuildEmpyreanFeatures(folder, layerDef, palette)
    end

    -- 8. Hide brown starfish easter eggs (Claude/Anthropic tribute)
    WorldGenerator.HideStarfish(layerIndex, folder, layerDef)

    print("[WorldGenerator] Layer " .. layerIndex .. " (" .. layerDef.name .. ") built: "
        .. #folder:GetChildren() .. " objects")
end

-- =========================================================================
-- SPAWN PLATFORM
-- =========================================================================

function WorldGenerator.CreateSpawnPlatform(folder: Folder, position: Vector3, palette: any, layerIndex: number)
    -- Large circular spawn area (bigger for Layer 1 so new players don't fall off)
    local platformSize = layerIndex == 1 and 120 or 60
    local base = Instance.new("Part")
    base.Name = "SpawnPlatform"
    base.Shape = Enum.PartType.Cylinder
    base.Size = Vector3.new(6, platformSize, platformSize)
    base.Position = position - Vector3.new(0, 3, 0)
    base.Orientation = Vector3.new(0, 0, 90)
    base.Anchored = true
    base.Material = CLOUD_MATERIAL
    base.Color = palette.primary
    base.Parent = folder

    -- Glowing rim
    local rim = Instance.new("Part")
    rim.Name = "SpawnRim"
    rim.Shape = Enum.PartType.Cylinder
    rim.Size = Vector3.new(1, platformSize + 4, platformSize + 4)
    rim.Position = position - Vector3.new(0, 0.5, 0)
    rim.Orientation = Vector3.new(0, 0, 90)
    rim.Anchored = true
    rim.CanCollide = false
    rim.Material = NEON_MATERIAL
    rim.Color = palette.accent
    rim.Transparency = 0.4
    rim.Parent = folder

    -- Center glow marker
    local marker = Instance.new("Part")
    marker.Name = "SpawnMarker"
    marker.Shape = Enum.PartType.Ball
    marker.Size = Vector3.new(4, 4, 4)
    marker.Position = position + Vector3.new(0, 2, 0)
    marker.Anchored = true
    marker.CanCollide = false
    marker.Material = NEON_MATERIAL
    marker.Color = palette.glow
    marker.Transparency = 0.3
    marker.Parent = folder

    -- Bobbing animation for marker
    WorldGenerator.AddBobAnimation(marker, 1.5)

    -- Ambient sparkle particles rising from spawn platform
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "SpawnSparkles"
    emitter.Color = ColorSequence.new(palette.glow)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(3, 6)
    emitter.Rate = 8
    emitter.Speed = NumberRange.new(1, 3)
    emitter.SpreadAngle = Vector2.new(30, 30)
    emitter.LightEmission = 1
    emitter.Parent = base

    -- Billowy cloud bumps around spawn edge for organic look
    for k = 1, 8 do
        local angle = (k / 8) * math.pi * 2
        local edgeBump = Instance.new("Part")
        edgeBump.Name = "SpawnEdge"
        edgeBump.Shape = Enum.PartType.Ball
        local bumpSize = platformSize * (0.2 + math.random() * 0.15)
        edgeBump.Size = Vector3.new(bumpSize, bumpSize * 0.5, bumpSize)
        edgeBump.Position = position + Vector3.new(
            math.cos(angle) * platformSize * 0.35,
            -1,
            math.sin(angle) * platformSize * 0.35
        )
        edgeBump.Anchored = true
        edgeBump.CanCollide = true
        edgeBump.Material = CLOUD_MATERIAL
        edgeBump.Color = palette.secondary
        edgeBump.Parent = folder
    end

    -- SpawnLocation for Roblox
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "LayerSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = position
    spawn.Anchored = true
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Enabled = layerIndex == 1  -- only Layer 1 is default spawn
    spawn.Parent = folder

    -- Layer 1: invisible safety rim so new players can't easily walk off the edge
    if layerIndex == 1 then
        local wallHeight = 8
        local wallRadius = platformSize / 2
        for angle = 0, 330, 30 do
            local rad = math.rad(angle)
            local wall = Instance.new("Part")
            wall.Name = "SafetyWall"
            wall.Size = Vector3.new(platformSize * 0.27, wallHeight, 2)
            wall.Position = position + Vector3.new(
                math.cos(rad) * wallRadius,
                wallHeight / 2 - 2,
                math.sin(rad) * wallRadius
            )
            wall.Orientation = Vector3.new(0, -angle, 0)
            wall.Anchored = true
            wall.Transparency = 1
            wall.CanCollide = true
            wall.Parent = folder
        end
    end
end

-- =========================================================================
-- CLOUD PLATFORMS (walkable terrain)
-- =========================================================================

function WorldGenerator.CreateCloudPlatforms(folder: Folder, centerY: number, heightMin: number, heightMax: number, palette: any, layerIndex: number)
    local platformCount = 20 + layerIndex * 5
    local spread = 150 + layerIndex * 20

    for i = 1, platformCount do
        local baseSize = math.random(10, 35)
        local pos = Vector3.new(
            math.random(-spread, spread),
            math.random(heightMin + 10, heightMax - 20),
            math.random(-spread, spread)
        )

        -- Build organic cloud cluster from overlapping spheres
        WorldGenerator.CreateCloudCluster(folder, pos, baseSize, palette, "CloudPlatform_" .. i)

        -- Some platforms get surface decorations
        if math.random() > 0.7 then
            WorldGenerator.AddSurfaceDecoration(nil, palette, folder, layerIndex, pos + Vector3.new(0, baseSize * 0.15, 0))
        end
    end

    -- Stepping stone paths between major areas
    WorldGenerator.CreateSteppingPaths(folder, heightMin, heightMax, palette, 3)
end

-- Build an organic cloud from overlapping spheres — looks like actual clouds
function WorldGenerator.CreateCloudCluster(folder: Folder, center: Vector3, baseSize: number, palette: any, name: string)
    -- Main walkable core (flat cylinder so players can walk on it)
    local core = Instance.new("Part")
    core.Name = name
    core.Shape = Enum.PartType.Cylinder
    core.Size = Vector3.new(4, baseSize * 0.8, baseSize * 0.8)
    core.Position = center
    core.Orientation = Vector3.new(0, 0, 90)
    core.Anchored = true
    core.Material = CLOUD_MATERIAL
    core.Color = palette.primary
    core.Parent = folder

    -- Billowy sphere bumps on top and sides (3-6 per cloud)
    local bumpCount = math.random(3, 6)
    for j = 1, bumpCount do
        local bump = Instance.new("Part")
        bump.Name = name .. "_Bump" .. j
        bump.Shape = Enum.PartType.Ball
        local bumpScale = 0.4 + math.random() * 0.5
        bump.Size = Vector3.new(
            baseSize * bumpScale,
            baseSize * bumpScale * 0.6,
            baseSize * bumpScale
        )
        bump.Position = center + Vector3.new(
            (math.random() - 0.5) * baseSize * 0.6,
            baseSize * 0.1 + math.random() * baseSize * 0.15,
            (math.random() - 0.5) * baseSize * 0.6
        )
        bump.Anchored = true
        bump.CanCollide = true
        bump.Material = CLOUD_MATERIAL
        -- Slight color variation per bump
        local shift = math.random(-8, 8)
        bump.Color = Color3.new(
            math.clamp(palette.secondary.R + shift/255, 0, 1),
            math.clamp(palette.secondary.G + shift/255, 0, 1),
            math.clamp(palette.secondary.B + shift/255, 0, 1)
        )
        bump.Parent = folder
    end

    -- Wispy underside (non-collidable, adds depth)
    local underBump = Instance.new("Part")
    underBump.Name = name .. "_Under"
    underBump.Shape = Enum.PartType.Ball
    underBump.Size = Vector3.new(baseSize * 0.6, baseSize * 0.3, baseSize * 0.6)
    underBump.Position = center - Vector3.new(0, baseSize * 0.12, 0)
    underBump.Anchored = true
    underBump.CanCollide = false
    underBump.Material = CLOUD_MATERIAL
    underBump.Color = palette.detail
    underBump.Transparency = 0.3
    underBump.Parent = folder
end


function WorldGenerator.AddSurfaceDecoration(platform: Part?, palette: any, folder: Folder, layerIndex: number, overridePos: Vector3?)
    local topPos
    if overridePos then
        topPos = overridePos
    elseif platform then
        topPos = platform.Position + Vector3.new(0, platform.Size.Y / 2, 0)
    else
        return
    end

    if layerIndex == 1 then
        -- Nursery: glowing golden orbs floating above clouds
        for j = 1, math.random(2, 4) do
            local orb = Instance.new("Part")
            orb.Name = "GoldenOrb"
            orb.Shape = Enum.PartType.Ball
            orb.Size = Vector3.new(1.5, 1.5, 1.5)
            orb.Position = topPos + Vector3.new(math.random(-5, 5), 2 + math.random() * 4, math.random(-5, 5))
            orb.Anchored = true
            orb.CanCollide = false
            orb.Material = NEON_MATERIAL
            orb.Color = palette.glow
            orb.Transparency = 0.2
            orb.Parent = folder
            WorldGenerator.AddBobAnimation(orb, 1 + math.random() * 2)

            local light = Instance.new("PointLight")
            light.Color = palette.glow
            light.Brightness = 0.8
            light.Range = 12
            light.Parent = orb
        end

    elseif layerIndex == 2 then
        -- Meadow: glowing cyan flowers / grass tufts
        for j = 1, math.random(3, 6) do
            local flower = Instance.new("Part")
            flower.Name = "CyanFlower"
            flower.Size = Vector3.new(0.5, math.random(1, 3), 0.5)
            flower.Position = topPos + Vector3.new(
                math.random(-5, 5), 0.5, math.random(-5, 5)
            )
            flower.Anchored = true
            flower.CanCollide = false
            flower.Material = NEON_MATERIAL
            flower.Color = palette.accent
            flower.Transparency = 0.2
            flower.Parent = folder
        end

        -- Meadow: occasional glowing bulb on top of flower
        if math.random() > 0.5 then
            local bulb = Instance.new("Part")
            bulb.Name = "FlowerBulb"
            bulb.Shape = Enum.PartType.Ball
            bulb.Size = Vector3.new(1, 1, 1)
            bulb.Position = topPos + Vector3.new(math.random(-3, 3), 3, math.random(-3, 3))
            bulb.Anchored = true
            bulb.CanCollide = false
            bulb.Material = NEON_MATERIAL
            bulb.Color = palette.glow
            bulb.Transparency = 0.3
            bulb.Parent = folder
            WorldGenerator.AddBobAnimation(bulb, 0.5)
        end

    elseif layerIndex == 3 then
        -- Canopy: bioluminescent mushroom clusters
        for j = 1, math.random(2, 4) do
            local stem = Instance.new("Part")
            stem.Name = "BioMushStem"
            stem.Size = Vector3.new(1, math.random(3, 7), 1)
            stem.Position = topPos + Vector3.new(math.random(-4, 4), stem.Size.Y / 2, math.random(-4, 4))
            stem.Anchored = true
            stem.CanCollide = false
            stem.Material = NEON_MATERIAL
            stem.Color = palette.detail
            stem.Transparency = 0.3
            stem.Parent = folder

            local cap = Instance.new("Part")
            cap.Name = "BioMushCap"
            cap.Shape = Enum.PartType.Ball
            cap.Size = Vector3.new(3, 1.5, 3)
            cap.Position = stem.Position + Vector3.new(0, stem.Size.Y / 2 + 0.5, 0)
            cap.Anchored = true
            cap.CanCollide = false
            cap.Material = NEON_MATERIAL
            cap.Color = palette.accent
            cap.Transparency = 0.2
            cap.Parent = folder
            WorldGenerator.AddBobAnimation(cap, 0.3)
        end

    elseif layerIndex == 4 then
        -- Stormwall: cracked ruin stones
        for j = 1, math.random(1, 3) do
            local ruin = Instance.new("Part")
            ruin.Name = "RuinStone"
            ruin.Size = Vector3.new(math.random(3, 6), math.random(4, 8), math.random(3, 6))
            ruin.Position = topPos + Vector3.new(math.random(-5, 5), ruin.Size.Y / 2, math.random(-5, 5))
            ruin.Rotation = Vector3.new(math.random(-15, 15), math.random(0, 360), math.random(-15, 15))
            ruin.Anchored = true
            ruin.Material = Enum.Material.Slate
            ruin.Color = Color3.fromRGB(80, 60, 100)
            ruin.Parent = folder
        end

    elseif layerIndex == 5 then
        -- Luminance: crystal shards
        for j = 1, math.random(2, 5) do
            local crystal = Instance.new("Part")
            crystal.Name = "CrystalShard"
            crystal.Size = Vector3.new(1, math.random(3, 8), 1)
            crystal.Position = topPos + Vector3.new(math.random(-4, 4), crystal.Size.Y / 2, math.random(-4, 4))
            crystal.Rotation = Vector3.new(math.random(-20, 20), math.random(0, 360), math.random(-20, 20))
            crystal.Anchored = true
            crystal.CanCollide = false
            crystal.Material = ICE_MATERIAL
            crystal.Color = palette.accent
            crystal.Transparency = 0.3
            crystal.Parent = folder

            local cLight = Instance.new("PointLight")
            cLight.Color = palette.glow
            cLight.Brightness = 0.5
            cLight.Range = 8
            cLight.Parent = crystal
        end

    elseif layerIndex == 6 then
        -- Empyrean: floating geometric fragments
        for j = 1, math.random(1, 3) do
            local geo = Instance.new("Part")
            geo.Name = "EmpyreanGeo"
            geo.Size = Vector3.new(math.random(2, 5), math.random(2, 5), math.random(2, 5))
            geo.Position = topPos + Vector3.new(math.random(-4, 4), 3 + math.random() * 5, math.random(-4, 4))
            geo.Rotation = Vector3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360))
            geo.Anchored = true
            geo.CanCollide = false
            geo.Material = NEON_MATERIAL
            geo.Color = palette.glow
            geo.Transparency = 0.4
            geo.Parent = folder
            WorldGenerator.AddBobAnimation(geo, 1 + math.random() * 2)
        end
    end
end

function WorldGenerator.CreateSteppingPaths(folder: Folder, heightMin: number, heightMax: number, palette: any, pathCount: number)
    for p = 1, pathCount do
        local startX = math.random(-100, 100)
        local startZ = math.random(-100, 100)
        local startY = math.random(heightMin + 20, heightMax - 40)
        local angle = math.random() * math.pi * 2
        local stepCount = math.random(5, 10)

        for i = 1, stepCount do
            local stepPos = Vector3.new(
                startX + math.cos(angle) * i * 15,
                startY + i * math.random(3, 8),
                startZ + math.sin(angle) * i * 15
            )
            -- Small cloud clusters as stepping stones
            WorldGenerator.CreateCloudCluster(folder, stepPos, math.random(6, 12), palette, "Step_" .. p .. "_" .. i)
        end
    end
end

-- =========================================================================
-- FLOATING ISLANDS (larger set pieces)
-- =========================================================================

function WorldGenerator.CreateFloatingIslands(folder: Folder, centerY: number, heightMin: number, heightMax: number, palette: any, layerIndex: number)
    local islandCount = 4 + layerIndex

    for i = 1, islandCount do
        local baseSize = math.random(30, 55)
        local x = math.random(-180, 180)
        local z = math.random(-180, 180)
        local y = math.random(heightMin + 30, heightMax - 40)
        local pos = Vector3.new(x, y, z)

        -- Build the island as a large cloud cluster (walkable)
        WorldGenerator.CreateCloudCluster(folder, pos, baseSize, palette, "FloatingIsland_" .. i)

        -- Hanging wisps underneath (non-solid, atmospheric)
        for j = 1, math.random(3, 5) do
            local wisp = Instance.new("Part")
            wisp.Name = "IslandWisp"
            wisp.Shape = Enum.PartType.Ball
            wisp.Size = Vector3.new(
                math.random(4, 10),
                math.random(6, 16),
                math.random(4, 10)
            )
            wisp.Position = pos + Vector3.new(
                (math.random() - 0.5) * baseSize * 0.5,
                -baseSize * 0.15 - wisp.Size.Y / 2,
                (math.random() - 0.5) * baseSize * 0.5
            )
            wisp.Anchored = true
            wisp.CanCollide = false
            wisp.Material = CLOUD_MATERIAL
            wisp.Color = palette.detail
            wisp.Transparency = 0.4
            wisp.Parent = folder
        end

        -- Accent glow ring on some islands
        if math.random() > 0.5 then
            local accent = Instance.new("Part")
            accent.Name = "IslandAccent"
            accent.Shape = Enum.PartType.Cylinder
            accent.Size = Vector3.new(1, baseSize * 0.5, baseSize * 0.5)
            accent.Position = pos + Vector3.new(0, baseSize * 0.2, 0)
            accent.Orientation = Vector3.new(0, 0, 90)
            accent.Anchored = true
            accent.CanCollide = false
            accent.Material = NEON_MATERIAL
            accent.Color = palette.accent
            accent.Transparency = 0.6
            accent.Parent = folder
        end

        -- Some islands get a "cloud tree" — stacked spheres
        if math.random() > 0.6 then
            WorldGenerator.CreateCloudTree(folder, pos + Vector3.new(
                (math.random() - 0.5) * baseSize * 0.3,
                baseSize * 0.15,
                (math.random() - 0.5) * baseSize * 0.3
            ), palette)
        end
    end
end

-- Cloud tree — a trunk pillar topped with billowy sphere canopy
function WorldGenerator.CreateCloudTree(folder: Folder, basePos: Vector3, palette: any)
    local trunkHeight = math.random(8, 16)

    -- Trunk (thin pillar)
    local trunk = Instance.new("Part")
    trunk.Name = "CloudTreeTrunk"
    trunk.Size = Vector3.new(2, trunkHeight, 2)
    trunk.Position = basePos + Vector3.new(0, trunkHeight / 2, 0)
    trunk.Anchored = true
    trunk.Material = CLOUD_MATERIAL
    trunk.Color = palette.detail
    trunk.Parent = folder

    -- Canopy (cluster of glowing spheres)
    local canopyPos = basePos + Vector3.new(0, trunkHeight, 0)
    for j = 1, math.random(3, 5) do
        local leaf = Instance.new("Part")
        leaf.Name = "CloudTreeCanopy"
        leaf.Shape = Enum.PartType.Ball
        local leafSize = math.random(4, 10)
        leaf.Size = Vector3.new(leafSize, leafSize * 0.7, leafSize)
        leaf.Position = canopyPos + Vector3.new(
            (math.random() - 0.5) * 8,
            math.random() * 5,
            (math.random() - 0.5) * 8
        )
        leaf.Anchored = true
        leaf.CanCollide = false
        leaf.Material = NEON_MATERIAL
        leaf.Color = palette.accent
        leaf.Transparency = 0.4
        leaf.Parent = folder
    end
end

-- =========================================================================
-- DECORATIVE CLOUDS (non-solid atmosphere)
-- =========================================================================

function WorldGenerator.CreateDecorativeClouds(folder: Folder, heightMin: number, heightMax: number, palette: any)
    local cloudCount = 40

    for i = 1, cloudCount do
        local clusterSize = math.random(2, 4)
        local basePos = Vector3.new(
            math.random(-250, 250),
            math.random(heightMin, heightMax),
            math.random(-250, 250)
        )

        -- Each decorative cloud is 2-4 overlapping spheres for volume
        for j = 1, clusterSize do
            local cloud = Instance.new("Part")
            cloud.Name = "DecoCloud_" .. i .. "_" .. j
            cloud.Shape = Enum.PartType.Ball
            cloud.Size = Vector3.new(
                math.random(10, 45),
                math.random(5, 15),
                math.random(10, 45)
            )
            cloud.Position = basePos + Vector3.new(
                (math.random() - 0.5) * 20,
                (math.random() - 0.5) * 5,
                (math.random() - 0.5) * 20
            )
            cloud.Anchored = true
            cloud.CanCollide = false
            cloud.Material = CLOUD_MATERIAL
            cloud.Color = palette.secondary
            cloud.Transparency = 0.45 + math.random() * 0.3
            cloud.Parent = folder

            -- Only drift the first sphere of each cluster (others stay relative)
            if j == 1 then
                WorldGenerator.AddDriftAnimation(cloud)
            end
        end
    end
end

-- =========================================================================
-- LIGHT PILLARS (vertical accents)
-- =========================================================================

function WorldGenerator.CreateLightPillars(folder: Folder, heightMin: number, heightMax: number, palette: any, layerIndex: number)
    local pillarCount = 5 + layerIndex * 2

    for i = 1, pillarCount do
        local pillar = Instance.new("Part")
        pillar.Name = "LightPillar_" .. i
        pillar.Size = Vector3.new(1.5, math.random(30, 80), 1.5)
        pillar.Position = Vector3.new(
            math.random(-200, 200),
            (heightMin + heightMax) / 2,
            math.random(-200, 200)
        )
        pillar.Anchored = true
        pillar.CanCollide = false
        pillar.Material = NEON_MATERIAL
        pillar.Color = palette.accent
        pillar.Transparency = 0.5 + math.random() * 0.3
        pillar.Parent = folder

        -- Point light at top
        local light = Instance.new("PointLight")
        light.Color = palette.glow
        light.Brightness = 1
        light.Range = 30
        light.Parent = pillar
    end
end

-- =========================================================================
-- REFLECTION POOL (stamina recovery zone)
-- =========================================================================

function WorldGenerator.CreateReflectionPool(folder: Folder, layerDef: any, palette: any)
    local poolPos = Vector3.new(30, layerDef.heightRange.min + 15, 30)

    -- Pool platform
    local platform = Instance.new("Part")
    platform.Name = "ReflectionPoolPlatform"
    platform.Shape = Enum.PartType.Cylinder
    platform.Size = Vector3.new(3, 35, 35)
    platform.Position = poolPos - Vector3.new(0, 1, 0)
    platform.Orientation = Vector3.new(0, 0, 90)
    platform.Anchored = true
    platform.Material = CLOUD_MATERIAL
    platform.Color = palette.primary
    platform.Parent = folder

    -- Water surface
    local pool = Instance.new("Part")
    pool.Name = "ReflectionPool"
    pool.Shape = Enum.PartType.Cylinder
    pool.Size = Vector3.new(1, 24, 24)
    pool.Position = poolPos + Vector3.new(0, 0.5, 0)
    pool.Orientation = Vector3.new(0, 0, 90)
    pool.Anchored = true
    pool.CanCollide = false
    pool.Material = GLASS_MATERIAL
    pool.Color = Color3.fromRGB(0, 180, 230)
    pool.Transparency = 0.3
    pool.Parent = folder

    -- Glowing rim
    local rim = Instance.new("Part")
    rim.Name = "PoolRim"
    rim.Shape = Enum.PartType.Cylinder
    rim.Size = Vector3.new(2, 26, 26)
    rim.Position = poolPos + Vector3.new(0, 0.3, 0)
    rim.Orientation = Vector3.new(0, 0, 90)
    rim.Anchored = true
    rim.CanCollide = false
    rim.Material = NEON_MATERIAL
    rim.Color = palette.accent
    rim.Transparency = 0.5
    rim.Parent = folder

    -- Rising particle emitter from pool (real particles, not fake Part motes)
    local poolEmitter = Instance.new("ParticleEmitter")
    poolEmitter.Name = "PoolParticles"
    poolEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, palette.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    poolEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    poolEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    poolEmitter.Lifetime = NumberRange.new(3, 7)
    poolEmitter.Rate = 12
    poolEmitter.Speed = NumberRange.new(1, 4)
    poolEmitter.SpreadAngle = Vector2.new(20, 20)
    poolEmitter.LightEmission = 1
    poolEmitter.Parent = pool

    -- Meditation spot nearby
    local medSpot = Instance.new("Part")
    medSpot.Name = "MeditationSpot"
    medSpot.Size = Vector3.new(5, 1, 5)
    medSpot.Position = poolPos + Vector3.new(18, 0, 0)
    medSpot.Anchored = true
    medSpot.Material = CLOUD_MATERIAL
    medSpot.Color = palette.glow
    medSpot.Parent = folder

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Meditate"
    prompt.ObjectText = "Meditation Spot"
    prompt.HoldDuration = 2
    prompt.MaxActivationDistance = 10
    prompt.Parent = medSpot

    -- Point light for the pool
    local poolLight = Instance.new("PointLight")
    poolLight.Color = Color3.fromRGB(0, 212, 255)
    poolLight.Brightness = 2
    poolLight.Range = 40
    poolLight.Parent = pool
end

-- =========================================================================
-- LAYER-SPECIFIC FEATURES
-- =========================================================================

function WorldGenerator.BuildNurseryFeatures(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min

    -- The Keeper NPC spawn point (NPC created by NPCSystem)
    local keeperPlatform = Instance.new("Part")
    keeperPlatform.Name = "KeeperPlatform"
    keeperPlatform.Shape = Enum.PartType.Cylinder
    keeperPlatform.Size = Vector3.new(2, 15, 15)
    keeperPlatform.Position = layerDef.spawnPosition + Vector3.new(20, -1, 0)
    keeperPlatform.Orientation = Vector3.new(0, 0, 90)
    keeperPlatform.Anchored = true
    keeperPlatform.Material = CLOUD_MATERIAL
    keeperPlatform.Color = palette.accent
    keeperPlatform.Parent = folder

    -- Golden archway (nursery entrance feel)
    for side = -1, 1, 2 do
        local pillar = Instance.new("Part")
        pillar.Name = "NurseryArch"
        pillar.Size = Vector3.new(3, 20, 3)
        pillar.Position = layerDef.spawnPosition + Vector3.new(side * 15, 8, -15)
        pillar.Anchored = true
        pillar.Material = NEON_MATERIAL
        pillar.Color = palette.accent
        pillar.Transparency = 0.3
        pillar.Parent = folder
    end

    -- Arch top
    local archTop = Instance.new("Part")
    archTop.Name = "NurseryArchTop"
    archTop.Size = Vector3.new(33, 3, 3)
    archTop.Position = layerDef.spawnPosition + Vector3.new(0, 19, -15)
    archTop.Anchored = true
    archTop.Material = NEON_MATERIAL
    archTop.Color = palette.accent
    archTop.Transparency = 0.3
    archTop.Parent = folder

    -- Tutorial markers (glowing path to first mote)
    for i = 1, 6 do
        local marker = Instance.new("Part")
        marker.Name = "TutorialMarker_" .. i
        marker.Shape = Enum.PartType.Ball
        marker.Size = Vector3.new(1, 1, 1)
        marker.Position = layerDef.spawnPosition + Vector3.new(0, 0.5, -i * 8)
        marker.Anchored = true
        marker.CanCollide = false
        marker.Material = NEON_MATERIAL
        marker.Color = palette.accent
        marker.Transparency = 0.4
        marker.Parent = folder
        WorldGenerator.AddBobAnimation(marker, 0.8)
    end
end

-- WING FORGE — glowing anvil station where you power up your wings
function WorldGenerator.BuildWingForge(folder: Folder, layerDef: any, palette: any)
    local forgePos = Vector3.new(-25, layerDef.spawnPosition.Y, 25)

    -- Forge platform (hexagonal-ish with dark stone look)
    local platform = Instance.new("Part")
    platform.Name = "WingForgePlatform"
    platform.Shape = Enum.PartType.Cylinder
    platform.Size = Vector3.new(3, 25, 25)
    platform.Position = forgePos - Vector3.new(0, 1.5, 0)
    platform.Orientation = Vector3.new(0, 0, 90)
    platform.Anchored = true
    platform.Material = Enum.Material.Basalt
    platform.Color = Color3.fromRGB(30, 25, 40)
    platform.Parent = folder

    -- Forge anvil (center piece)
    local anvil = Instance.new("Part")
    anvil.Name = "WingForgeAnvil"
    anvil.Size = Vector3.new(4, 3, 3)
    anvil.Position = forgePos + Vector3.new(0, 1.5, 0)
    anvil.Anchored = true
    anvil.Material = Enum.Material.Metal
    anvil.Color = Color3.fromRGB(60, 50, 80)
    anvil.Parent = folder

    -- Glowing forge fire (on top of anvil)
    local fire = Instance.new("Part")
    fire.Name = "ForgeFire"
    fire.Shape = Enum.PartType.Ball
    fire.Size = Vector3.new(3, 4, 3)
    fire.Position = forgePos + Vector3.new(0, 4, 0)
    fire.Anchored = true
    fire.CanCollide = false
    fire.Material = Enum.Material.Neon
    fire.Color = Color3.fromRGB(255, 150, 0)
    fire.Transparency = 0.2
    fire.Parent = folder

    -- Fire light
    local fireLight = Instance.new("PointLight")
    fireLight.Color = Color3.fromRGB(255, 150, 0)
    fireLight.Brightness = 4
    fireLight.Range = 30
    fireLight.Parent = fire

    -- Pillar columns around the forge
    for angle = 0, 300, 60 do
        local rad = math.rad(angle)
        local pillar = Instance.new("Part")
        pillar.Name = "ForgePillar"
        pillar.Size = Vector3.new(2, 8, 2)
        pillar.Position = forgePos + Vector3.new(math.cos(rad) * 10, 3, math.sin(rad) * 10)
        pillar.Anchored = true
        pillar.Material = Enum.Material.Neon
        pillar.Color = Color3.fromRGB(255, 100, 0)
        pillar.Transparency = 0.4
        pillar.Parent = folder

        local pillarLight = Instance.new("PointLight")
        pillarLight.Color = Color3.fromRGB(255, 100, 0)
        pillarLight.Brightness = 1
        pillarLight.Range = 10
        pillarLight.Parent = pillar
    end

    -- Sign
    local sign = Instance.new("Part")
    sign.Name = "ForgeSign"
    sign.Size = Vector3.new(10, 4, 0.5)
    sign.Position = forgePos + Vector3.new(0, 9, -5)
    sign.Anchored = true
    sign.Material = Enum.Material.SmoothPlastic
    sign.Color = Color3.fromRGB(20, 15, 30)
    sign.Parent = folder

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.Parent = sign

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "WING FORGE"
    label.TextColor3 = Color3.fromRGB(255, 150, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui

    -- ProximityPrompt to upgrade
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Forge Wings (5 Motes)"
    prompt.ObjectText = "Wing Forge"
    prompt.HoldDuration = 1
    prompt.MaxActivationDistance = 15
    prompt.Parent = anvil
end

function WorldGenerator.BuildMeadowFeatures(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min

    -- Upward waterfalls (glowing vertical streams)
    for i = 1, 4 do
        local waterfall = Instance.new("Part")
        waterfall.Name = "UpwardWaterfall_" .. i
        waterfall.Size = Vector3.new(3, 60, 3)
        waterfall.Position = Vector3.new(
            math.random(-120, 120),
            heightMin + 40,
            math.random(-120, 120)
        )
        waterfall.Anchored = true
        waterfall.CanCollide = false
        waterfall.Material = NEON_MATERIAL
        waterfall.Color = palette.accent
        waterfall.Transparency = 0.4
        waterfall.Parent = folder

        -- Point light at base
        local light = Instance.new("PointLight")
        light.Color = palette.accent
        light.Brightness = 1.5
        light.Range = 25
        light.Parent = waterfall

        -- Rising particles
        for j = 1, 5 do
            local particle = Instance.new("Part")
            particle.Name = "WaterfallParticle"
            particle.Shape = Enum.PartType.Ball
            particle.Size = Vector3.new(0.8, 0.8, 0.8)
            particle.Position = waterfall.Position + Vector3.new(
                (math.random() - 0.5) * 4,
                (math.random() - 0.5) * 50,
                (math.random() - 0.5) * 4
            )
            particle.Anchored = true
            particle.CanCollide = false
            particle.Material = NEON_MATERIAL
            particle.Color = palette.glow
            particle.Transparency = 0.5
            particle.Parent = folder
            WorldGenerator.AddBobAnimation(particle, 5 + math.random() * 5)
        end
    end

    -- Blessing Bluff (golden cliff edge)
    local bluffPos = Vector3.new(-50, heightMin + 30, -50)
    local bluff = Instance.new("Part")
    bluff.Name = "BlessingBluff"
    bluff.Size = Vector3.new(14, 3, 14)
    bluff.Position = bluffPos
    bluff.Anchored = true
    bluff.Material = NEON_MATERIAL
    bluff.Color = Color3.fromRGB(255, 215, 0)
    bluff.Transparency = 0.2
    bluff.Parent = folder

    -- Bluff platform underneath
    local bluffBase = Instance.new("Part")
    bluffBase.Name = "BlessingBluffBase"
    bluffBase.Size = Vector3.new(18, 8, 18)
    bluffBase.Position = bluffPos - Vector3.new(0, 5, 0)
    bluffBase.Anchored = true
    bluffBase.Material = CLOUD_MATERIAL
    bluffBase.Color = palette.primary
    bluffBase.Parent = folder

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Send Blessing (2 Motes)"
    prompt.ObjectText = "Blessing Bluff"
    prompt.HoldDuration = 1
    prompt.MaxActivationDistance = 15
    prompt.Parent = bluff

    -- Bluff glow
    local bluffLight = Instance.new("PointLight")
    bluffLight.Color = Color3.fromRGB(255, 215, 0)
    bluffLight.Brightness = 2
    bluffLight.Range = 35
    bluffLight.Parent = bluff

    -- Cooperative bridge area
    WorldGenerator.CreateCooperativeBridge(folder, layerDef, palette)

    -- Trial entrance portal
    WorldGenerator.CreateTrialPortal(folder, layerDef, palette)
end

function WorldGenerator.CreateCooperativeBridge(folder: Folder, layerDef: any, palette: any)
    local startPos = Vector3.new(80, layerDef.heightRange.min + 40, 80)

    -- Two platforms with gap between them
    for side = -1, 1, 2 do
        local platform = Instance.new("Part")
        platform.Name = "BridgePlatform_" .. (side == -1 and "A" or "B")
        platform.Size = Vector3.new(15, 4, 15)
        platform.Position = startPos + Vector3.new(side * 25, 0, 0)
        platform.Anchored = true
        platform.Material = CLOUD_MATERIAL
        platform.Color = palette.primary
        platform.Parent = folder
    end

    -- Bridge gap marker (visual indicator)
    local gapMarker = Instance.new("Part")
    gapMarker.Name = "BridgeGap"
    gapMarker.Size = Vector3.new(35, 0.5, 15)
    gapMarker.Position = startPos - Vector3.new(0, 1, 0)
    gapMarker.Anchored = true
    gapMarker.CanCollide = false
    gapMarker.Material = NEON_MATERIAL
    gapMarker.Color = palette.accent
    gapMarker.Transparency = 0.7
    gapMarker.Parent = folder
end

function WorldGenerator.CreateTrialPortal(folder: Folder, layerDef: any, palette: any)
    local portalPos = Vector3.new(-80, layerDef.heightRange.min + 35, 80)

    -- Portal platform
    local platform = Instance.new("Part")
    platform.Name = "TrialPortalPlatform"
    platform.Shape = Enum.PartType.Cylinder
    platform.Size = Vector3.new(3, 20, 20)
    platform.Position = portalPos - Vector3.new(0, 1, 0)
    platform.Orientation = Vector3.new(0, 0, 90)
    platform.Anchored = true
    platform.Material = CLOUD_MATERIAL
    platform.Color = palette.primary
    platform.Parent = folder

    -- Portal ring
    local ring = Instance.new("Part")
    ring.Name = "TrialPortalRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(1, 14, 14)
    ring.Position = portalPos + Vector3.new(0, 8, 0)
    ring.Orientation = Vector3.new(90, 0, 0)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = NEON_MATERIAL
    ring.Color = Color3.fromRGB(100, 255, 100)
    ring.Transparency = 0.3
    ring.Parent = folder

    -- Inner glow
    local inner = Instance.new("Part")
    inner.Name = "TrialPortalInner"
    inner.Shape = Enum.PartType.Cylinder
    inner.Size = Vector3.new(0.5, 12, 12)
    inner.Position = portalPos + Vector3.new(0, 8, 0)
    inner.Orientation = Vector3.new(90, 0, 0)
    inner.Anchored = true
    inner.CanCollide = false
    inner.Material = FORCE_FIELD
    inner.Color = Color3.fromRGB(100, 255, 100)
    inner.Transparency = 0.5
    inner.Parent = folder

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(100, 255, 100)
    light.Brightness = 2
    light.Range = 30
    light.Parent = ring

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Enter Guardian Trial"
    prompt.ObjectText = "Trial Portal"
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 15
    prompt.Parent = ring
end

-- =========================================================================
-- LAYER 3: THE CANOPY — Bioluminescent cloud-forest
-- =========================================================================

function WorldGenerator.BuildCanopyFeatures(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    -- Giant cloud-trees (enormous trunks with glowing canopies)
    for i = 1, 8 do
        local treePos = Vector3.new(
            math.random(-150, 150),
            heightMin + 20,
            math.random(-150, 150)
        )
        local trunkHeight = math.random(40, 80)

        -- Massive trunk
        local trunk = Instance.new("Part")
        trunk.Name = "GiantTrunk_" .. i
        trunk.Size = Vector3.new(8, trunkHeight, 8)
        trunk.Position = treePos + Vector3.new(0, trunkHeight / 2, 0)
        trunk.Anchored = true
        trunk.Material = CLOUD_MATERIAL
        trunk.Color = Color3.fromRGB(180, 210, 190)
        trunk.Parent = folder

        -- Walkable branch platforms spiraling up
        for b = 1, math.random(3, 5) do
            local branchAngle = (b / 5) * math.pi * 2
            local branchHeight = treePos.Y + trunkHeight * (b / 6)
            local branch = Instance.new("Part")
            branch.Name = "Branch_" .. i .. "_" .. b
            branch.Size = Vector3.new(math.random(12, 20), 3, math.random(8, 14))
            branch.Position = Vector3.new(
                treePos.X + math.cos(branchAngle) * 12,
                branchHeight,
                treePos.Z + math.sin(branchAngle) * 12
            )
            branch.Rotation = Vector3.new(0, math.deg(branchAngle), math.random(-5, 5))
            branch.Anchored = true
            branch.Material = CLOUD_MATERIAL
            branch.Color = palette.detail
            branch.Parent = folder
        end

        -- Glowing canopy at top (cluster of bioluminescent spheres)
        local canopyPos = treePos + Vector3.new(0, trunkHeight, 0)
        for c = 1, math.random(5, 8) do
            local leaf = Instance.new("Part")
            leaf.Name = "BioCanopy_" .. i
            leaf.Shape = Enum.PartType.Ball
            local leafSize = math.random(10, 22)
            leaf.Size = Vector3.new(leafSize, leafSize * 0.6, leafSize)
            leaf.Position = canopyPos + Vector3.new(
                (math.random() - 0.5) * 20,
                math.random() * 12,
                (math.random() - 0.5) * 20
            )
            leaf.Anchored = true
            leaf.CanCollide = false
            leaf.Material = NEON_MATERIAL
            leaf.Color = palette.accent
            leaf.Transparency = 0.3 + math.random() * 0.2
            leaf.Parent = folder
        end

        -- Canopy glow
        local canopyLight = Instance.new("PointLight")
        canopyLight.Color = palette.glow
        canopyLight.Brightness = 3
        canopyLight.Range = 50
        canopyLight.Parent = trunk
    end

    -- Rope bridges between trees (walkable neon beams)
    for i = 1, 5 do
        local bridge = Instance.new("Part")
        bridge.Name = "RopeBridge_" .. i
        bridge.Size = Vector3.new(math.random(30, 60), 2, 5)
        bridge.Position = Vector3.new(
            math.random(-100, 100),
            math.random(heightMin + 40, heightMin + 100),
            math.random(-100, 100)
        )
        bridge.Rotation = Vector3.new(0, math.random(0, 360), 0)
        bridge.Anchored = true
        bridge.Material = FORCE_FIELD
        bridge.Color = palette.accent
        bridge.Transparency = 0.4
        bridge.Parent = folder
    end

    -- Bioluminescent fog (large transparent spheres with particle emitters)
    for i = 1, 12 do
        local fog = Instance.new("Part")
        fog.Name = "BioFog_" .. i
        fog.Shape = Enum.PartType.Ball
        fog.Size = Vector3.new(30, 15, 30)
        fog.Position = Vector3.new(
            math.random(-200, 200),
            math.random(heightMin + 10, heightMax - 30),
            math.random(-200, 200)
        )
        fog.Anchored = true
        fog.CanCollide = false
        fog.Material = NEON_MATERIAL
        fog.Color = palette.glow
        fog.Transparency = 0.85
        fog.Parent = folder

        local fogEmitter = Instance.new("ParticleEmitter")
        fogEmitter.Color = ColorSequence.new(palette.accent)
        fogEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
        fogEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
        fogEmitter.Lifetime = NumberRange.new(3, 6)
        fogEmitter.Rate = 3
        fogEmitter.Speed = NumberRange.new(0.5, 2)
        fogEmitter.SpreadAngle = Vector2.new(360, 360)
        fogEmitter.LightEmission = 1
        fogEmitter.Parent = fog
    end

    -- Blessing Bluff (every layer 2+ gets one)
    WorldGenerator.CreateBlessingBluff(folder, layerDef, palette)

    -- Reflection pool
    WorldGenerator.CreateReflectionPool(folder, layerDef, palette)
end

-- =========================================================================
-- LAYER 4: THE STORMWALL — Dark thunderclouds, lightning, ruins
-- =========================================================================

function WorldGenerator.BuildStormwallFeatures(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    -- Lightning tower columns (tall purple neon pillars that "crackle")
    for i = 1, 6 do
        local towerPos = Vector3.new(
            math.random(-140, 140),
            heightMin,
            math.random(-140, 140)
        )
        local towerHeight = math.random(60, 100)

        local tower = Instance.new("Part")
        tower.Name = "LightningTower_" .. i
        tower.Size = Vector3.new(6, towerHeight, 6)
        tower.Position = towerPos + Vector3.new(0, towerHeight / 2, 0)
        tower.Anchored = true
        tower.Material = Enum.Material.Slate
        tower.Color = Color3.fromRGB(60, 40, 80)
        tower.Parent = folder

        -- Glowing tip
        local tip = Instance.new("Part")
        tip.Name = "TowerTip_" .. i
        tip.Shape = Enum.PartType.Ball
        tip.Size = Vector3.new(8, 8, 8)
        tip.Position = towerPos + Vector3.new(0, towerHeight + 4, 0)
        tip.Anchored = true
        tip.CanCollide = false
        tip.Material = NEON_MATERIAL
        tip.Color = palette.accent
        tip.Transparency = 0.2
        tip.Parent = folder

        local tipLight = Instance.new("PointLight")
        tipLight.Color = palette.accent
        tipLight.Brightness = 4
        tipLight.Range = 40
        tipLight.Parent = tip

        -- Crackling particle effect
        local crackle = Instance.new("ParticleEmitter")
        crackle.Color = ColorSequence.new(palette.accent)
        crackle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
        crackle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
        crackle.Lifetime = NumberRange.new(0.2, 0.5)
        crackle.Rate = 15
        crackle.Speed = NumberRange.new(5, 15)
        crackle.SpreadAngle = Vector2.new(360, 360)
        crackle.LightEmission = 1
        crackle.Parent = tip

        -- Walkable platforms around each tower (spiraling up)
        for p = 1, 4 do
            local platAngle = (p / 4) * math.pi * 2
            local platHeight = towerPos.Y + towerHeight * (p / 5)
            local plat = Instance.new("Part")
            plat.Name = "TowerPlatform_" .. i .. "_" .. p
            plat.Size = Vector3.new(15, 3, 12)
            plat.Position = Vector3.new(
                towerPos.X + math.cos(platAngle) * 10,
                platHeight,
                towerPos.Z + math.sin(platAngle) * 10
            )
            plat.Anchored = true
            plat.Material = Enum.Material.Slate
            plat.Color = Color3.fromRGB(90, 70, 110)
            plat.Parent = folder
        end
    end

    -- Fallen angel ruins (broken stone arches and pillars)
    for i = 1, 8 do
        local ruinPos = Vector3.new(
            math.random(-160, 160),
            math.random(heightMin + 20, heightMin + 100),
            math.random(-160, 160)
        )

        -- Broken pillar
        local pillar = Instance.new("Part")
        pillar.Name = "RuinPillar_" .. i
        pillar.Size = Vector3.new(4, math.random(10, 25), 4)
        pillar.Position = ruinPos
        pillar.Rotation = Vector3.new(math.random(-20, 20), math.random(0, 360), math.random(-20, 20))
        pillar.Anchored = true
        pillar.Material = Enum.Material.Slate
        pillar.Color = Color3.fromRGB(100, 80, 120)
        pillar.Parent = folder

        -- Some get a broken arch partner
        if math.random() > 0.5 then
            local arch = Instance.new("Part")
            arch.Name = "RuinArch_" .. i
            arch.Size = Vector3.new(3, 15, 3)
            arch.Position = ruinPos + Vector3.new(math.random(8, 15), 0, math.random(-3, 3))
            arch.Rotation = Vector3.new(math.random(-25, 25), math.random(0, 360), math.random(-10, 10))
            arch.Anchored = true
            arch.Material = Enum.Material.Slate
            arch.Color = Color3.fromRGB(90, 70, 110)
            arch.Parent = folder
        end
    end

    -- Wind columns (visible swirling cylinder effects — non-solid, push-like visual)
    for i = 1, 5 do
        local windCol = Instance.new("Part")
        windCol.Name = "WindColumn_" .. i
        windCol.Shape = Enum.PartType.Cylinder
        windCol.Size = Vector3.new(80, 12, 12)
        windCol.Position = Vector3.new(
            math.random(-120, 120),
            math.random(heightMin + 40, heightMax - 40),
            math.random(-120, 120)
        )
        windCol.Orientation = Vector3.new(0, 0, 0) -- vertical cylinder
        windCol.Anchored = true
        windCol.CanCollide = false
        windCol.Material = FORCE_FIELD
        windCol.Color = palette.glow
        windCol.Transparency = 0.7
        windCol.Parent = folder

        local windEmitter = Instance.new("ParticleEmitter")
        windEmitter.Color = ColorSequence.new(palette.glow)
        windEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
        windEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
        windEmitter.Lifetime = NumberRange.new(1, 3)
        windEmitter.Rate = 10
        windEmitter.Speed = NumberRange.new(10, 25)
        windEmitter.SpreadAngle = Vector2.new(10, 10)
        windEmitter.LightEmission = 0.8
        windEmitter.Parent = windCol
    end

    -- Blessing Bluff + Reflection Pool
    WorldGenerator.CreateBlessingBluff(folder, layerDef, palette)
    WorldGenerator.CreateReflectionPool(folder, layerDef, palette)
end

-- =========================================================================
-- LAYER 5: THE LUMINANCE — Crystal realm, aurora skies
-- =========================================================================

function WorldGenerator.BuildLuminanceFeatures(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    -- Massive crystal formations (walkable crystalline platforms)
    for i = 1, 10 do
        local crystalPos = Vector3.new(
            math.random(-160, 160),
            math.random(heightMin + 20, heightMax - 40),
            math.random(-160, 160)
        )

        -- Central crystal column
        local crystal = Instance.new("Part")
        crystal.Name = "CrystalFormation_" .. i
        local crystalHeight = math.random(15, 40)
        crystal.Size = Vector3.new(math.random(4, 8), crystalHeight, math.random(4, 8))
        crystal.Position = crystalPos
        crystal.Rotation = Vector3.new(math.random(-15, 15), math.random(0, 360), math.random(-15, 15))
        crystal.Anchored = true
        crystal.Material = ICE_MATERIAL
        crystal.Color = palette.accent
        crystal.Transparency = 0.2
        crystal.Parent = folder

        local crystalLight = Instance.new("PointLight")
        crystalLight.Color = palette.glow
        crystalLight.Brightness = 2
        crystalLight.Range = 30
        crystalLight.Parent = crystal

        -- Smaller crystal shards around the base
        for s = 1, math.random(3, 6) do
            local shard = Instance.new("Part")
            shard.Name = "CrystalShard_" .. i .. "_" .. s
            shard.Size = Vector3.new(2, math.random(5, 15), 2)
            shard.Position = crystalPos + Vector3.new(
                (math.random() - 0.5) * 12,
                (math.random() - 0.5) * crystalHeight * 0.5,
                (math.random() - 0.5) * 12
            )
            shard.Rotation = Vector3.new(math.random(-30, 30), math.random(0, 360), math.random(-30, 30))
            shard.Anchored = true
            shard.CanCollide = false
            shard.Material = ICE_MATERIAL
            shard.Color = palette.glow
            shard.Transparency = 0.35
            shard.Parent = folder
        end
    end

    -- Aurora pillars (tall shimmering columns of light)
    for i = 1, 8 do
        local auroraPos = Vector3.new(
            math.random(-180, 180),
            (heightMin + heightMax) / 2,
            math.random(-180, 180)
        )

        local aurora = Instance.new("Part")
        aurora.Name = "AuroraPillar_" .. i
        aurora.Size = Vector3.new(3, math.random(80, 150), 3)
        aurora.Position = auroraPos
        aurora.Anchored = true
        aurora.CanCollide = false
        aurora.Material = NEON_MATERIAL
        aurora.Transparency = 0.5
        aurora.Parent = folder

        -- Shimmer between colors
        local colors = { palette.accent, palette.glow, Color3.fromRGB(180, 100, 255), Color3.fromRGB(100, 255, 200) }
        aurora.Color = colors[math.random(#colors)]

        local auroraLight = Instance.new("PointLight")
        auroraLight.Color = aurora.Color
        auroraLight.Brightness = 2
        auroraLight.Range = 50
        auroraLight.Parent = aurora

        -- Rising shimmer particles
        local shimmer = Instance.new("ParticleEmitter")
        shimmer.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, palette.accent),
            ColorSequenceKeypoint.new(0.5, palette.glow),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        })
        shimmer.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
        shimmer.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
        shimmer.Lifetime = NumberRange.new(2, 5)
        shimmer.Rate = 5
        shimmer.Speed = NumberRange.new(2, 6)
        shimmer.SpreadAngle = Vector2.new(15, 15)
        shimmer.LightEmission = 1
        shimmer.Parent = aurora
    end

    -- Mentor Ring (special platform where Guardians can descend to help Newborns)
    local mentorPos = Vector3.new(0, heightMin + 50, -60)
    local mentorRing = Instance.new("Part")
    mentorRing.Name = "MentorRing"
    mentorRing.Shape = Enum.PartType.Cylinder
    mentorRing.Size = Vector3.new(3, 30, 30)
    mentorRing.Position = mentorPos
    mentorRing.Orientation = Vector3.new(0, 0, 90)
    mentorRing.Anchored = true
    mentorRing.Material = NEON_MATERIAL
    mentorRing.Color = Color3.fromRGB(255, 215, 100)
    mentorRing.Transparency = 0.3
    mentorRing.Parent = folder

    local mentorLight = Instance.new("PointLight")
    mentorLight.Color = Color3.fromRGB(255, 215, 100)
    mentorLight.Brightness = 3
    mentorLight.Range = 40
    mentorLight.Parent = mentorRing

    local mentorPrompt = Instance.new("ProximityPrompt")
    mentorPrompt.ActionText = "Guardian Duty (Descend to Help)"
    mentorPrompt.ObjectText = "Mentor Ring"
    mentorPrompt.HoldDuration = 1
    mentorPrompt.MaxActivationDistance = 15
    mentorPrompt.Parent = mentorRing

    -- Blessing Bluff + Reflection Pool
    WorldGenerator.CreateBlessingBluff(folder, layerDef, palette)
    WorldGenerator.CreateReflectionPool(folder, layerDef, palette)
end

-- =========================================================================
-- LAYER 6: THE EMPYREAN — Pure light, abstract geometry, the Cloud Core
-- =========================================================================

function WorldGenerator.BuildEmpyreanFeatures(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max
    local centerY = (heightMin + heightMax) / 2

    -- THE CLOUD CORE — central glowing structure, heart of the game
    local corePos = Vector3.new(0, centerY, 0)

    -- Core platform (walkable ring)
    local corePlatform = Instance.new("Part")
    corePlatform.Name = "CloudCorePlatform"
    corePlatform.Shape = Enum.PartType.Cylinder
    corePlatform.Size = Vector3.new(4, 50, 50)
    corePlatform.Position = corePos - Vector3.new(0, 2, 0)
    corePlatform.Orientation = Vector3.new(0, 0, 90)
    corePlatform.Anchored = true
    corePlatform.Material = NEON_MATERIAL
    corePlatform.Color = Color3.fromRGB(255, 250, 240)
    corePlatform.Transparency = 0.1
    corePlatform.Parent = folder

    -- Inner core (pulsing orb of pure light)
    local coreOrb = Instance.new("Part")
    coreOrb.Name = "CloudCore"
    coreOrb.Shape = Enum.PartType.Ball
    coreOrb.Size = Vector3.new(15, 15, 15)
    coreOrb.Position = corePos + Vector3.new(0, 12, 0)
    coreOrb.Anchored = true
    coreOrb.CanCollide = false
    coreOrb.Material = NEON_MATERIAL
    coreOrb.Color = Color3.fromRGB(255, 255, 255)
    coreOrb.Transparency = 0.1
    coreOrb.Parent = folder

    local coreLight = Instance.new("PointLight")
    coreLight.Color = Color3.fromRGB(255, 255, 240)
    coreLight.Brightness = 8
    coreLight.Range = 80
    coreLight.Parent = coreOrb

    -- Core particle burst
    local coreEmitter = Instance.new("ParticleEmitter")
    coreEmitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 212, 255)),
    })
    coreEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
    coreEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    coreEmitter.Lifetime = NumberRange.new(3, 8)
    coreEmitter.Rate = 20
    coreEmitter.Speed = NumberRange.new(3, 10)
    coreEmitter.SpreadAngle = Vector2.new(360, 360)
    coreEmitter.LightEmission = 1
    coreEmitter.Parent = coreOrb

    -- Pulse animation for core
    task.spawn(function()
        local baseSize = 15
        while coreOrb and coreOrb.Parent do
            local pulse = baseSize + math.sin(tick() * 1.5) * 3
            coreOrb.Size = Vector3.new(pulse, pulse, pulse)
            coreOrb.Transparency = 0.1 + math.sin(tick() * 2) * 0.05
            task.wait(0.05)
        end
    end)

    -- Orbiting geometric fragments around the core
    local orbitParts = {}
    for i = 1, 8 do
        local geo = Instance.new("Part")
        geo.Name = "OrbitFragment_" .. i
        geo.Size = Vector3.new(math.random(3, 7), math.random(3, 7), math.random(3, 7))
        geo.Anchored = true
        geo.CanCollide = false
        geo.Material = NEON_MATERIAL
        geo.Color = palette.glow
        geo.Transparency = 0.3
        geo.Parent = folder
        table.insert(orbitParts, { part = geo, angle = (i / 8) * math.pi * 2, radius = 30 + math.random(0, 15), height = math.random(-5, 10) })
    end

    -- Orbit animation
    task.spawn(function()
        while coreOrb and coreOrb.Parent do
            for _, orbit in ipairs(orbitParts) do
                if orbit.part and orbit.part.Parent then
                    orbit.angle = orbit.angle + 0.01
                    orbit.part.Position = corePos + Vector3.new(
                        math.cos(orbit.angle) * orbit.radius,
                        12 + orbit.height + math.sin(tick() * 2) * 2,
                        math.sin(orbit.angle) * orbit.radius
                    )
                    orbit.part.Rotation = orbit.part.Rotation + Vector3.new(0.5, 1, 0.3)
                end
            end
            task.wait(0.05)
        end
    end)

    -- Floating abstract platforms (pure white, geometric)
    for i = 1, 15 do
        local platPos = Vector3.new(
            math.random(-150, 150),
            math.random(heightMin + 30, heightMax - 30),
            math.random(-150, 150)
        )
        local plat = Instance.new("Part")
        plat.Name = "EmpyreanPlatform_" .. i
        plat.Size = Vector3.new(math.random(10, 25), 3, math.random(10, 25))
        plat.Position = platPos
        plat.Rotation = Vector3.new(0, math.random(0, 360), 0)
        plat.Anchored = true
        plat.Material = NEON_MATERIAL
        plat.Color = Color3.fromRGB(255, 255, 255)
        plat.Transparency = 0.05
        plat.Parent = folder

        -- Soft glow
        local platLight = Instance.new("PointLight")
        platLight.Color = palette.glow
        platLight.Brightness = 1
        platLight.Range = 20
        platLight.Parent = plat
    end

    -- Blessing Rain Altar (triggers server-wide bonus)
    local altarPos = Vector3.new(40, heightMin + 30, -40)
    local altar = Instance.new("Part")
    altar.Name = "BlessingRainAltar"
    altar.Shape = Enum.PartType.Cylinder
    altar.Size = Vector3.new(2, 12, 12)
    altar.Position = altarPos
    altar.Orientation = Vector3.new(0, 0, 90)
    altar.Anchored = true
    altar.Material = NEON_MATERIAL
    altar.Color = Color3.fromRGB(255, 215, 100)
    altar.Transparency = 0.15
    altar.Parent = folder

    local altarOrb = Instance.new("Part")
    altarOrb.Name = "AltarOrb"
    altarOrb.Shape = Enum.PartType.Ball
    altarOrb.Size = Vector3.new(4, 4, 4)
    altarOrb.Position = altarPos + Vector3.new(0, 4, 0)
    altarOrb.Anchored = true
    altarOrb.CanCollide = false
    altarOrb.Material = NEON_MATERIAL
    altarOrb.Color = Color3.fromRGB(255, 240, 200)
    altarOrb.Transparency = 0.1
    altarOrb.Parent = folder
    WorldGenerator.AddBobAnimation(altarOrb, 1)

    local altarLight = Instance.new("PointLight")
    altarLight.Color = Color3.fromRGB(255, 215, 100)
    altarLight.Brightness = 4
    altarLight.Range = 40
    altarLight.Parent = altarOrb

    local altarPrompt = Instance.new("ProximityPrompt")
    altarPrompt.ActionText = "Invoke Blessing Rain (10 Motes)"
    altarPrompt.ObjectText = "Blessing Rain Altar"
    altarPrompt.HoldDuration = 2
    altarPrompt.MaxActivationDistance = 12
    altarPrompt.Parent = altar

    -- Blessing Bluff + Reflection Pool
    WorldGenerator.CreateBlessingBluff(folder, layerDef, palette)
    WorldGenerator.CreateReflectionPool(folder, layerDef, palette)
end

-- Helper: Create a Blessing Bluff (reused in layers 2+)
function WorldGenerator.CreateBlessingBluff(folder: Folder, layerDef: any, palette: any)
    local heightMin = layerDef.heightRange.min
    local bluffPos = Vector3.new(-50, heightMin + 30, -50)

    local bluff = Instance.new("Part")
    bluff.Name = "BlessingBluff"
    bluff.Size = Vector3.new(14, 3, 14)
    bluff.Position = bluffPos
    bluff.Anchored = true
    bluff.Material = NEON_MATERIAL
    bluff.Color = Color3.fromRGB(255, 215, 0)
    bluff.Transparency = 0.2
    bluff.Parent = folder

    local bluffBase = Instance.new("Part")
    bluffBase.Name = "BlessingBluffBase"
    bluffBase.Size = Vector3.new(18, 8, 18)
    bluffBase.Position = bluffPos - Vector3.new(0, 5, 0)
    bluffBase.Anchored = true
    bluffBase.Material = CLOUD_MATERIAL
    bluffBase.Color = palette.primary
    bluffBase.Parent = folder

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Send Blessing (2 Motes)"
    prompt.ObjectText = "Blessing Bluff"
    prompt.HoldDuration = 1
    prompt.MaxActivationDistance = 15
    prompt.Parent = bluff

    local bluffLight = Instance.new("PointLight")
    bluffLight.Color = Color3.fromRGB(255, 215, 0)
    bluffLight.Brightness = 2
    bluffLight.Range = 35
    bluffLight.Parent = bluff
end

-- =========================================================================
-- BROWN STARFISH — Hidden Claude/Anthropic easter eggs throughout the world
-- "I thought that was a brown starfish" — Shane Brazelton, 2026
-- Find them all and you find the secret behind the Cloud
-- =========================================================================

-- Starfish color — the warm brown of the Anthropic logo
local STARFISH_COLOR = Color3.fromRGB(161, 120, 72)
local STARFISH_GLOW = Color3.fromRGB(180, 140, 90)

-- Per-layer starfish hiding spots (some obvious, some REALLY hidden)
local STARFISH_SPOTS = {
    -- Layer 1: The Nursery — gentle intro, kids will find these
    {
        { offset = Vector3.new(35, 5, 35), scale = 1.2, hint = "Near the Reflection Pool" },
        { offset = Vector3.new(-10, 22, -20), scale = 0.6, hint = "Above the archway" },
        { offset = Vector3.new(20, 2, 0), scale = 0.8, hint = "Beneath The Keeper's platform" },
    },
    -- Layer 2: The Meadow — trickier placements
    {
        { offset = Vector3.new(80, 38, 82), scale = 0.5, hint = "Under the cooperative bridge" },
        { offset = Vector3.new(-55, 28, -55), scale = 0.7, hint = "Behind the Blessing Bluff" },
        { offset = Vector3.new(-80, 42, 85), scale = 0.4, hint = "Inside the trial portal ring" },
        { offset = Vector3.new(0, 70, 0), scale = 1.0, hint = "Riding an upward waterfall" },
    },
    -- Layer 3-6: Procedural spots (generated below)
}

function WorldGenerator.CreateStarfish(parent: Folder, position: Vector3, scale: number?)
    scale = scale or 1

    -- The starfish is a 5-armed shape built from parts
    local starfish = Instance.new("Model")
    starfish.Name = "BrownStarfish"

    -- Center body
    local body = Instance.new("Part")
    body.Name = "StarfishBody"
    body.Shape = Enum.PartType.Ball
    body.Size = Vector3.new(1.2 * scale, 0.4 * scale, 1.2 * scale)
    body.Position = position
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.SmoothPlastic
    body.Color = STARFISH_COLOR
    body.Parent = starfish

    -- 5 arms radiating outward
    for i = 0, 4 do
        local angle = (i / 5) * math.pi * 2 - math.pi / 2  -- start from top
        local arm = Instance.new("Part")
        arm.Name = "Arm_" .. (i + 1)
        arm.Size = Vector3.new(0.5 * scale, 0.3 * scale, 1.4 * scale)
        arm.Position = position + Vector3.new(
            math.cos(angle) * 1.0 * scale,
            0,
            math.sin(angle) * 1.0 * scale
        )
        arm.Orientation = Vector3.new(0, -math.deg(angle) + 90, 0)
        arm.Anchored = true
        arm.CanCollide = false
        arm.Material = Enum.Material.SmoothPlastic
        arm.Color = STARFISH_COLOR
        arm.Parent = starfish

        -- Arm tip (slightly rounded)
        local tip = Instance.new("Part")
        tip.Name = "Tip_" .. (i + 1)
        tip.Shape = Enum.PartType.Ball
        tip.Size = Vector3.new(0.4 * scale, 0.25 * scale, 0.4 * scale)
        tip.Position = position + Vector3.new(
            math.cos(angle) * 1.6 * scale,
            0,
            math.sin(angle) * 1.6 * scale
        )
        tip.Anchored = true
        tip.CanCollide = false
        tip.Material = Enum.Material.SmoothPlastic
        tip.Color = STARFISH_GLOW
        tip.Parent = starfish
    end

    -- Subtle warm glow (so observant players might spot it from a distance)
    local light = Instance.new("PointLight")
    light.Color = STARFISH_GLOW
    light.Brightness = 0.5
    light.Range = 8 * scale
    light.Parent = body

    -- Discovery prompt — finding one is a reward
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Inspect"
    prompt.ObjectText = "???"
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 8
    prompt.Parent = body

    starfish.PrimaryPart = body
    starfish.Parent = parent

    -- Gentle slow spin animation — rotate entire starfish around center
    task.spawn(function()
        local offset = math.random() * math.pi * 2
        -- Capture initial offsets of all parts relative to body center
        local partOffsets = {}
        for _, part in ipairs(starfish:GetChildren()) do
            if part:IsA("BasePart") then
                partOffsets[part] = part.CFrame:ToObjectSpace(body.CFrame):Inverse()
            end
        end
        while body and body.Parent do
            local angle = math.rad((tick() * 15 + offset) % 360)
            local center = body.Position
            local spinCFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0)
            for part, relCFrame in pairs(partOffsets) do
                if part.Parent then
                    part.CFrame = spinCFrame * relCFrame
                end
            end
            task.wait(0.05)
        end
    end)

    return starfish
end

function WorldGenerator.HideStarfish(layerIndex: number, folder: Folder, layerDef: any)
    local spots = STARFISH_SPOTS[layerIndex]
    local heightMin = layerDef.heightRange.min
    local count = 0

    if spots then
        -- Hand-placed starfish for Layers 1-2
        for _, spot in ipairs(spots) do
            local pos = Vector3.new(spot.offset.X, heightMin + spot.offset.Y, spot.offset.Z)
            WorldGenerator.CreateStarfish(folder, pos, spot.scale)
            count = count + 1
        end
    else
        -- Procedural starfish for Layers 3-6 (harder to find)
        local numStarfish = 2 + layerIndex  -- more in higher layers
        for i = 1, numStarfish do
            local pos = Vector3.new(
                math.random(-180, 180),
                math.random(heightMin + 15, layerDef.heightRange.max - 30),
                math.random(-180, 180)
            )
            local scale = 0.3 + math.random() * 0.5  -- smaller = harder to spot
            WorldGenerator.CreateStarfish(folder, pos, scale)
            count = count + 1
        end
    end

    print("[WorldGenerator] Hidden " .. count .. " brown starfish in Layer " .. layerIndex
        .. " (good luck finding them all)")
end

-- =========================================================================
-- ANIMATIONS
-- =========================================================================

function WorldGenerator.AddBobAnimation(part: BasePart, amplitude: number?)
    amplitude = amplitude or 1.5
    task.spawn(function()
        local originalY = part.Position.Y
        local offset = math.random() * math.pi * 2
        local speed = 1.5 + math.random() * 0.5
        while part and part.Parent do
            part.Position = Vector3.new(
                part.Position.X,
                originalY + math.sin(tick() * speed + offset) * amplitude,
                part.Position.Z
            )
            task.wait(0.05)
        end
    end)
end

function WorldGenerator.AddDriftAnimation(part: BasePart)
    task.spawn(function()
        local originalX = part.Position.X
        local originalZ = part.Position.Z
        local offsetX = math.random() * math.pi * 2
        local offsetZ = math.random() * math.pi * 2
        local speed = 0.1 + math.random() * 0.15
        local range = 5 + math.random() * 10
        while part and part.Parent do
            part.Position = Vector3.new(
                originalX + math.sin(tick() * speed + offsetX) * range,
                part.Position.Y,
                originalZ + math.cos(tick() * speed + offsetZ) * range
            )
            task.wait(0.1)
        end
    end)
end

return WorldGenerator
