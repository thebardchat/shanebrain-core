--[[
    AtmosphereSystem.lua — Per-layer atmosphere, lighting, and weather
    Changes Lighting properties as players move between layers
    Handles fog, sky color, particle effects, and weather events
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layers = require(ReplicatedStorage.Config.Layers)

local AtmosphereSystem = {}

-- Per-layer atmosphere presets
local PRESETS = {
    -- Layer 1: The Nursery — warm, golden, safe
    {
        clockTime = 10,
        ambient = Color3.fromRGB(40, 35, 25),
        outdoorAmbient = Color3.fromRGB(120, 110, 80),
        fogEnd = 800,
        fogColor = Color3.fromRGB(255, 245, 220),
        atmosphereDensity = 0.25,
        atmosphereOffset = 0.2,
        atmosphereColor = Color3.fromRGB(255, 240, 200),
        atmosphereDecay = Color3.fromRGB(240, 220, 180),
        bloomIntensity = 0.5,
        bloomSize = 24,
        skyColor = Color3.fromRGB(180, 200, 255),
    },
    -- Layer 2: The Meadow — bright cyan, airy
    {
        clockTime = 12,
        ambient = Color3.fromRGB(20, 30, 35),
        outdoorAmbient = Color3.fromRGB(100, 130, 150),
        fogEnd = 1000,
        fogColor = Color3.fromRGB(200, 235, 255),
        atmosphereDensity = 0.3,
        atmosphereOffset = 0.25,
        atmosphereColor = Color3.fromRGB(200, 230, 255),
        atmosphereDecay = Color3.fromRGB(180, 210, 240),
        bloomIntensity = 0.6,
        bloomSize = 28,
        skyColor = Color3.fromRGB(135, 200, 255),
    },
    -- Layer 3: The Canopy — bioluminescent fog, dim
    {
        clockTime = 7,
        ambient = Color3.fromRGB(10, 25, 15),
        outdoorAmbient = Color3.fromRGB(40, 80, 50),
        fogEnd = 500,
        fogColor = Color3.fromRGB(30, 80, 50),
        atmosphereDensity = 0.5,
        atmosphereOffset = 0.1,
        atmosphereColor = Color3.fromRGB(50, 120, 80),
        atmosphereDecay = Color3.fromRGB(30, 60, 40),
        bloomIntensity = 0.8,
        bloomSize = 35,
        skyColor = Color3.fromRGB(20, 60, 40),
    },
    -- Layer 4: The Stormwall — dark purple, ominous
    {
        clockTime = 18,
        ambient = Color3.fromRGB(15, 8, 25),
        outdoorAmbient = Color3.fromRGB(50, 25, 70),
        fogEnd = 400,
        fogColor = Color3.fromRGB(40, 20, 60),
        atmosphereDensity = 0.6,
        atmosphereOffset = 0.05,
        atmosphereColor = Color3.fromRGB(60, 30, 80),
        atmosphereDecay = Color3.fromRGB(30, 15, 45),
        bloomIntensity = 0.4,
        bloomSize = 20,
        skyColor = Color3.fromRGB(30, 15, 50),
    },
    -- Layer 5: The Luminance — crystal clear, aurora
    {
        clockTime = 22,
        ambient = Color3.fromRGB(30, 35, 50),
        outdoorAmbient = Color3.fromRGB(100, 120, 160),
        fogEnd = 1500,
        fogColor = Color3.fromRGB(180, 200, 240),
        atmosphereDensity = 0.15,
        atmosphereOffset = 0.4,
        atmosphereColor = Color3.fromRGB(180, 210, 255),
        atmosphereDecay = Color3.fromRGB(150, 180, 220),
        bloomIntensity = 0.7,
        bloomSize = 40,
        skyColor = Color3.fromRGB(10, 15, 40),
    },
    -- Layer 6: The Empyrean — pure white light
    {
        clockTime = 12,
        ambient = Color3.fromRGB(60, 60, 65),
        outdoorAmbient = Color3.fromRGB(200, 200, 210),
        fogEnd = 2000,
        fogColor = Color3.fromRGB(255, 255, 255),
        atmosphereDensity = 0.1,
        atmosphereOffset = 0.5,
        atmosphereColor = Color3.fromRGB(255, 255, 250),
        atmosphereDecay = Color3.fromRGB(245, 245, 255),
        bloomIntensity = 1.0,
        bloomSize = 50,
        skyColor = Color3.fromRGB(240, 240, 255),
    },
}

-- Track each player's current layer for transitions
local playerLayers = {}

-- RemoteEvent for client atmosphere sync
local AtmosphereUpdate

function AtmosphereSystem.Init()
    AtmosphereUpdate = Instance.new("RemoteEvent")
    AtmosphereUpdate.Name = "AtmosphereUpdate"
    AtmosphereUpdate.Parent = ReplicatedStorage

    -- Apply default atmosphere (Layer 1)
    AtmosphereSystem.ApplyPreset(1)

    -- Track player height to detect layer changes
    RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            if character then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local height = hrp.Position.Y
                    local newLayer = AtmosphereSystem.GetLayerForHeight(height)
                    local currentLayer = playerLayers[player.UserId]

                    if newLayer ~= currentLayer then
                        playerLayers[player.UserId] = newLayer
                        -- Send atmosphere data to this specific player
                        local preset = PRESETS[newLayer]
                        if preset then
                            AtmosphereUpdate:FireClient(player, {
                                layerIndex = newLayer,
                                preset = {
                                    clockTime = preset.clockTime,
                                    fogEnd = preset.fogEnd,
                                    bloomIntensity = preset.bloomIntensity,
                                    bloomSize = preset.bloomSize,
                                },
                            })
                        end
                    end
                end
            end
        end
    end)

    -- Stormwall weather loop (Layer 4 lightning flashes)
    task.spawn(function()
        while true do
            task.wait(8 + math.random() * 12)
            AtmosphereSystem.TriggerLightningFlash()
        end
    end)

    print("[AtmosphereSystem] Atmosphere system initialized")
end

function AtmosphereSystem.GetLayerForHeight(height: number): number
    for i = #Layers.Definitions, 1, -1 do
        local layer = Layers.Definitions[i]
        if height >= layer.heightRange.min then
            return i
        end
    end
    return 1
end

function AtmosphereSystem.ApplyPreset(layerIndex: number)
    local preset = PRESETS[layerIndex]
    if not preset then return end

    Lighting.ClockTime = preset.clockTime
    Lighting.Ambient = preset.ambient
    Lighting.OutdoorAmbient = preset.outdoorAmbient
    Lighting.FogEnd = preset.fogEnd
    Lighting.FogColor = preset.fogColor

    local atmo = Lighting:FindFirstChildWhichIsA("Atmosphere")
    if atmo then
        atmo.Density = preset.atmosphereDensity
        atmo.Offset = preset.atmosphereOffset
        atmo.Color = preset.atmosphereColor
        atmo.Decay = preset.atmosphereDecay
    end

    local bloom = Lighting:FindFirstChildWhichIsA("BloomEffect")
    if bloom then
        bloom.Intensity = preset.bloomIntensity
        bloom.Size = preset.bloomSize
    end
end

function AtmosphereSystem.TriggerLightningFlash()
    -- Only flash if any player is in Layer 4 (Stormwall)
    local hasStormPlayer = false
    for _, layerIdx in pairs(playerLayers) do
        if layerIdx == 4 then
            hasStormPlayer = true
            break
        end
    end

    if not hasStormPlayer then return end

    -- Create brief flash by spawning a temporary bright part
    local flash = Instance.new("Part")
    flash.Name = "LightningFlash"
    flash.Size = Vector3.new(400, 2, 400)
    flash.Position = Vector3.new(
        math.random(-200, 200),
        math.random(850, 1050),
        math.random(-200, 200)
    )
    flash.Anchored = true
    flash.CanCollide = false
    flash.Material = Enum.Material.Neon
    flash.Color = Color3.fromRGB(200, 180, 255)
    flash.Transparency = 0.3
    flash.Parent = workspace

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(200, 180, 255)
    light.Brightness = 10
    light.Range = 300
    light.Parent = flash

    -- Brief flash then remove
    task.delay(0.15, function()
        flash.Transparency = 0.7
        task.delay(0.1, function()
            if flash.Parent then
                flash:Destroy()
            end
        end)
    end)
end

function AtmosphereSystem.RemovePlayer(player: Player)
    playerLayers[player.UserId] = nil
end

function AtmosphereSystem.GetPlayerLayer(player: Player): number
    return playerLayers[player.UserId] or 1
end

return AtmosphereSystem
