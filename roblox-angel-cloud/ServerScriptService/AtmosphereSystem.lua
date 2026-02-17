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
local SoundManager = require(script.Parent.SoundManager)

local AtmosphereSystem = {}

-- Per-layer atmosphere presets (bright and heavenly — this is a cloud world!)
local PRESETS = {
    -- Layer 1: The Nursery — warm golden morning, welcoming
    {
        clockTime = 10,
        ambient = Color3.fromRGB(80, 75, 90),
        outdoorAmbient = Color3.fromRGB(180, 170, 200),
        fogEnd = 800,
        fogColor = Color3.fromRGB(200, 190, 220),
        atmosphereDensity = 0.25,
        atmosphereOffset = 0.3,
        atmosphereColor = Color3.fromRGB(210, 200, 235),
        atmosphereDecay = Color3.fromRGB(190, 180, 215),
        bloomIntensity = 0.6,
        bloomSize = 30,
        skyColor = Color3.fromRGB(140, 160, 220),
    },
    -- Layer 2: The Meadow — bright blue sky, cyan-tinted atmosphere
    {
        clockTime = 14,
        ambient = Color3.fromRGB(70, 85, 100),
        outdoorAmbient = Color3.fromRGB(160, 200, 220),
        fogEnd = 900,
        fogColor = Color3.fromRGB(180, 220, 240),
        atmosphereDensity = 0.2,
        atmosphereOffset = 0.35,
        atmosphereColor = Color3.fromRGB(180, 225, 245),
        atmosphereDecay = Color3.fromRGB(160, 200, 230),
        bloomIntensity = 0.7,
        bloomSize = 28,
        skyColor = Color3.fromRGB(100, 180, 240),
    },
    -- Layer 3: The Canopy — lush green-tinted light, bioluminescent glow
    {
        clockTime = 11,
        ambient = Color3.fromRGB(60, 80, 65),
        outdoorAmbient = Color3.fromRGB(140, 200, 160),
        fogEnd = 600,
        fogColor = Color3.fromRGB(160, 210, 170),
        atmosphereDensity = 0.35,
        atmosphereOffset = 0.2,
        atmosphereColor = Color3.fromRGB(150, 210, 170),
        atmosphereDecay = Color3.fromRGB(130, 180, 150),
        bloomIntensity = 0.7,
        bloomSize = 32,
        skyColor = Color3.fromRGB(80, 160, 120),
    },
    -- Layer 4: The Stormwall — dramatic purple-grey, moody but visible
    {
        clockTime = 18,
        ambient = Color3.fromRGB(50, 40, 65),
        outdoorAmbient = Color3.fromRGB(120, 100, 150),
        fogEnd = 500,
        fogColor = Color3.fromRGB(130, 110, 160),
        atmosphereDensity = 0.45,
        atmosphereOffset = 0.1,
        atmosphereColor = Color3.fromRGB(140, 120, 170),
        atmosphereDecay = Color3.fromRGB(100, 80, 130),
        bloomIntensity = 0.5,
        bloomSize = 24,
        skyColor = Color3.fromRGB(80, 60, 110),
    },
    -- Layer 5: The Luminance — crystal clear aurora sky, ethereal
    {
        clockTime = 22,
        ambient = Color3.fromRGB(60, 70, 90),
        outdoorAmbient = Color3.fromRGB(140, 160, 200),
        fogEnd = 1500,
        fogColor = Color3.fromRGB(200, 215, 245),
        atmosphereDensity = 0.15,
        atmosphereOffset = 0.4,
        atmosphereColor = Color3.fromRGB(200, 220, 255),
        atmosphereDecay = Color3.fromRGB(170, 195, 240),
        bloomIntensity = 0.8,
        bloomSize = 40,
        skyColor = Color3.fromRGB(30, 40, 80),
    },
    -- Layer 6: The Empyrean — pure radiant white light
    {
        clockTime = 12,
        ambient = Color3.fromRGB(100, 100, 105),
        outdoorAmbient = Color3.fromRGB(220, 220, 230),
        fogEnd = 2000,
        fogColor = Color3.fromRGB(255, 255, 255),
        atmosphereDensity = 0.1,
        atmosphereOffset = 0.5,
        atmosphereColor = Color3.fromRGB(255, 255, 250),
        atmosphereDecay = Color3.fromRGB(250, 250, 255),
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

    -- Create atmosphere + bloom if they don't exist
    if not Lighting:FindFirstChildWhichIsA("Atmosphere") then
        local atmo = Instance.new("Atmosphere")
        atmo.Parent = Lighting
    end
    if not Lighting:FindFirstChildWhichIsA("BloomEffect") then
        local bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    -- Darker sky
    if not Lighting:FindFirstChildWhichIsA("Sky") then
        local sky = Instance.new("Sky")
        sky.StarCount = 5000
        sky.Parent = Lighting
    end
    Lighting.GlobalShadows = true
    Lighting.Brightness = 2
    Lighting.EnvironmentDiffuseScale = 1
    Lighting.EnvironmentSpecularScale = 1

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
                        -- Update ambient music for this player's layer
                        SoundManager.SetAmbientLayer(newLayer)
                        SoundManager.OnPlayerLayerChanged(player, newLayer)
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

    -- Play thunder sound
    SoundManager.OnLightning()

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
