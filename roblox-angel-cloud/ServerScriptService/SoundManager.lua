--[[
    SoundManager.lua — Ambient music, environmental audio, and SFX
    Uses Roblox SoundService and Sound instances
    Per-layer ambient tracks with crossfading
    Sound asset IDs are placeholders — replace with uploaded audio assets
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundManager = {}

-- Real audio asset IDs from Roblox Creator Store
local AUDIO = {
    -- Ambient tracks per layer (loop)
    ambient = {
        [1] = "rbxassetid://1848354536",   -- Nursery: relaxed, calm atmosphere
        [2] = "rbxassetid://1841044496",   -- Meadow: ethereal world
        [3] = "rbxassetid://1837536733",   -- Canopy: heavenly
        [4] = "rbxassetid://1848354536",   -- Stormwall: dramatic (reuse calm for now)
        [5] = "rbxassetid://1841044496",   -- Luminance: ethereal
        [6] = "rbxassetid://1837536733",   -- Empyrean: heavenly choir
    },

    -- Sound effects
    sfx = {
        mote_collect = "rbxassetid://9126073011",     -- sparkle bell chime
        level_up = "rbxassetid://2686079706",          -- ascending level up fanfare
        blessing_send = "rbxassetid://9126073011",     -- sparkle tone
        blessing_receive = "rbxassetid://5826672935",  -- announcement chime
        fragment_collect = "rbxassetid://5654075071",  -- sparkle sound effect
        gate_open = "rbxassetid://206902974",          -- victory/grand opening
        trial_start = "rbxassetid://9125647873",       -- magic zoom whoosh
        trial_complete = "rbxassetid://2686079706",    -- level up / victory
        npc_talk = "rbxassetid://7128958209",          -- bell ding
        wing_glide = "rbxassetid://9113081793",        -- airy whoosh
        wing_flight = "rbxassetid://6455667685",       -- wind sound
        stamina_low = "rbxassetid://2909601104",       -- bell warning
        halt_reminder = "rbxassetid://7128958209",     -- gentle bell ding
        shop_purchase = "rbxassetid://5826672935",     -- announcement chime
        meditation_start = "rbxassetid://9126073011",  -- sparkle bell tone
        lightning = "rbxassetid://9114444008",          -- fire whoosh (thunder-like)
        bounce = "rbxassetid://2764461710",            -- bounce boing
        speed_boost = "rbxassetid://9125647873",       -- magic zoom whoosh
        wing_forge = "rbxassetid://9113446696",        -- blacksmith anvil hit
    },
}

-- Layer ambient volume levels
local LAYER_VOLUMES = {
    [1] = 0.3,   -- Nursery: gentle
    [2] = 0.35,  -- Meadow: slightly louder, more life
    [3] = 0.25,  -- Canopy: hushed
    [4] = 0.4,   -- Stormwall: louder, dramatic
    [5] = 0.3,   -- Luminance: serene
    [6] = 0.35,  -- Empyrean: full
}

local CROSSFADE_TIME = 3  -- seconds to crossfade between layer ambients

-- Active sounds
local ambientSounds = {}  -- [layerIndex] = Sound instance
local currentAmbientLayer = 0

-- SFX sound pool (reusable)
local sfxPool = {}

-- RemoteEvent for client-triggered sounds
local PlaySound

function SoundManager.Init()
    -- Create RemoteEvent for triggering sounds from server to client
    PlaySound = Instance.new("RemoteEvent")
    PlaySound.Name = "PlaySound"
    PlaySound.Parent = ReplicatedStorage

    -- Create SFX folder in SoundService
    local sfxFolder = Instance.new("Folder")
    sfxFolder.Name = "SFX"
    sfxFolder.Parent = SoundService

    -- Pre-create ambient sound instances for each layer
    for layerIndex, assetId in pairs(AUDIO.ambient) do
        local sound = Instance.new("Sound")
        sound.Name = "Ambient_Layer" .. layerIndex
        sound.SoundId = assetId
        sound.Looped = true
        sound.Volume = 0
        sound.Playing = false
        sound.SoundGroup = nil
        sound.Parent = SoundService
        ambientSounds[layerIndex] = sound
    end

    -- Pre-create reusable SFX instances
    for sfxName, assetId in pairs(AUDIO.sfx) do
        local sound = Instance.new("Sound")
        sound.Name = "SFX_" .. sfxName
        sound.SoundId = assetId
        sound.Looped = false
        sound.Volume = 0.5
        sound.Parent = sfxFolder
        sfxPool[sfxName] = sound
    end

    -- Start with Layer 1 ambient
    SoundManager.SetAmbientLayer(1)

    print("[SoundManager] Sound system initialized with " .. #AUDIO.sfx .. " SFX loaded")
end

function SoundManager.SetAmbientLayer(layerIndex: number)
    if layerIndex == currentAmbientLayer then return end

    -- Fade out current
    if currentAmbientLayer > 0 then
        local oldSound = ambientSounds[currentAmbientLayer]
        if oldSound then
            local fadeOut = TweenService:Create(oldSound, TweenInfo.new(CROSSFADE_TIME), {
                Volume = 0,
            })
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                oldSound.Playing = false
            end)
        end
    end

    -- Fade in new
    local newSound = ambientSounds[layerIndex]
    if newSound then
        newSound.Volume = 0
        newSound.Playing = true
        local targetVolume = LAYER_VOLUMES[layerIndex] or 0.3
        TweenService:Create(newSound, TweenInfo.new(CROSSFADE_TIME), {
            Volume = targetVolume,
        }):Play()
    end

    currentAmbientLayer = layerIndex
end

function SoundManager.PlaySFX(sfxName: string, volumeOverride: number?)
    local sound = sfxPool[sfxName]
    if not sound then return end

    -- Clone to allow overlapping plays
    local clone = sound:Clone()
    clone.Volume = volumeOverride or sound.Volume
    clone.Parent = sound.Parent
    clone:Play()

    -- Auto-cleanup after playing
    clone.Ended:Connect(function()
        clone:Destroy()
    end)

    -- Safety cleanup in case Ended doesn't fire
    task.delay(10, function()
        if clone and clone.Parent then
            clone:Destroy()
        end
    end)
end

function SoundManager.PlaySFXForPlayer(player: Player, sfxName: string, volume: number?)
    PlaySound:FireClient(player, {
        sfx = sfxName,
        volume = volume or 0.5,
        assetId = AUDIO.sfx[sfxName],
    })
end

function SoundManager.PlaySFXForAll(sfxName: string, volume: number?)
    PlaySound:FireAllClients({
        sfx = sfxName,
        volume = volume or 0.5,
        assetId = AUDIO.sfx[sfxName],
    })
end

-- Called by AtmosphereSystem when player changes layers
function SoundManager.OnPlayerLayerChanged(player: Player, newLayerIndex: number)
    SoundManager.PlaySFXForPlayer(player, "gate_open", 0.3)
end

-- Convenience methods for common game events
function SoundManager.OnMoteCollected(player: Player)
    SoundManager.PlaySFXForPlayer(player, "mote_collect", 0.4)
end

function SoundManager.OnLevelUp(player: Player)
    SoundManager.PlaySFXForPlayer(player, "level_up", 0.7)
end

function SoundManager.OnBlessingSent(player: Player)
    SoundManager.PlaySFXForPlayer(player, "blessing_send", 0.5)
end

function SoundManager.OnBlessingReceived(player: Player)
    SoundManager.PlaySFXForPlayer(player, "blessing_receive", 0.5)
end

function SoundManager.OnFragmentCollected(player: Player)
    SoundManager.PlaySFXForPlayer(player, "fragment_collect", 0.6)
end

function SoundManager.OnTrialStart()
    SoundManager.PlaySFXForAll("trial_start", 0.5)
end

function SoundManager.OnTrialComplete()
    SoundManager.PlaySFXForAll("trial_complete", 0.6)
end

function SoundManager.OnNPCTalk(player: Player)
    SoundManager.PlaySFXForPlayer(player, "npc_talk", 0.3)
end

function SoundManager.OnLightning()
    SoundManager.PlaySFXForAll("lightning", 0.6)
end

return SoundManager
