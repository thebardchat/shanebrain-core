--[[
    SoundPlayer.lua — Client-side sound player
    Receives sound events from server and plays them locally
    Also handles local atmosphere audio transitions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local SoundPlayer = {}

-- Local SFX cache
local sfxCache = {}

-- RemoteEvents
local PlaySound
local AtmosphereUpdate

function SoundPlayer.Init()
    PlaySound = ReplicatedStorage:WaitForChild("PlaySound", 15)
    AtmosphereUpdate = ReplicatedStorage:WaitForChild("AtmosphereUpdate", 15)

    if PlaySound then
        PlaySound.OnClientEvent:Connect(function(data)
            SoundPlayer.PlaySFX(data.sfx, data.assetId, data.volume)
        end)
    end

    if AtmosphereUpdate then
        AtmosphereUpdate.OnClientEvent:Connect(function(data)
            SoundPlayer.OnLayerChanged(data.layerIndex)
        end)
    end

    print("[SoundPlayer] Client sound player initialized")
end

function SoundPlayer.PlaySFX(sfxName: string, assetId: string?, volume: number?)
    if not assetId or assetId == "" then return end

    -- Reuse or create sound
    local sound = sfxCache[sfxName]
    if not sound then
        sound = Instance.new("Sound")
        sound.Name = "ClientSFX_" .. sfxName
        sound.Parent = SoundService
        sfxCache[sfxName] = sound
    end

    -- Clone for overlap support
    local clone = sound:Clone()
    clone.SoundId = assetId
    clone.Volume = volume or 0.5
    clone.Looped = false
    clone.Parent = SoundService
    clone:Play()

    clone.Ended:Connect(function()
        clone:Destroy()
    end)

    task.delay(10, function()
        if clone and clone.Parent then
            clone:Destroy()
        end
    end)
end

function SoundPlayer.OnLayerChanged(layerIndex: number)
    -- Play a transition whoosh
    SoundPlayer.PlaySFX("layer_transition", "rbxassetid://9114819156", 0.3)
end

return SoundPlayer
