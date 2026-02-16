--[[
    ProgressionSystem.lua — Angel level progression and layer access
    Mirrors the real Angel Cloud ANGEL_LEVELS and PROGRESSION_THRESHOLDS
    Handles level-up detection, ascension sequences, and gate checks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)
local Layers = require(ReplicatedStorage.Config.Layers)

local ProgressionSystem = {}

-- RemoteEvents
local LevelUp       -- Server -> Client: trigger ascension cinematic
local LayerUnlocked -- Server -> Client: notify new layer access

function ProgressionSystem.Init()
    LevelUp = Instance.new("RemoteEvent")
    LevelUp.Name = "LevelUp"
    LevelUp.Parent = ReplicatedStorage

    LayerUnlocked = Instance.new("RemoteEvent")
    LayerUnlocked.Name = "LayerUnlocked"
    LayerUnlocked.Parent = ReplicatedStorage
end

function ProgressionSystem.CheckLevelUp(player: Player): string?
    local data = DataManager.GetData(player)
    if not data then
        return nil
    end

    local currentLevel = data.angelLevel
    local currentIndex = Layers.GetLevelIndex(currentLevel)
    local motes = data.motes

    -- Check if player qualifies for a higher level
    local newLevel = nil
    for i = #Layers.ANGEL_LEVELS, currentIndex + 1, -1 do
        local levelName = Layers.ANGEL_LEVELS[i]
        if motes >= Layers.PROGRESSION_THRESHOLDS[levelName] then
            newLevel = levelName
            break
        end
    end

    if newLevel and newLevel ~= currentLevel then
        local newIndex = Layers.GetLevelIndex(newLevel)
        data.angelLevel = newLevel
        data.layerIndex = newIndex

        -- Fire ascension cinematic for the player
        local layerDef = Layers.GetLayerByIndex(newIndex)
        LevelUp:FireClient(player, {
            newLevel = newLevel,
            layerIndex = newIndex,
            layerName = layerDef.name,
        })

        -- Notify all players in server
        local message = player.Name .. " ascends to " .. layerDef.name .. "! Every Angel strengthens the cloud."
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                LayerUnlocked:FireClient(otherPlayer, {
                    playerName = player.Name,
                    newLevel = newLevel,
                    layerName = layerDef.name,
                    message = message,
                })
            end
        end

        return newLevel
    end

    return nil
end

function ProgressionSystem.GetPlayerLevel(player: Player): (string, number)
    local data = DataManager.GetData(player)
    if not data then
        return "Newborn", 1
    end
    return data.angelLevel, data.layerIndex
end

function ProgressionSystem.CanAccessLayer(player: Player, layerIndex: number): boolean
    local data = DataManager.GetData(player)
    if not data then
        return layerIndex == 1
    end
    return data.layerIndex >= layerIndex
end

function ProgressionSystem.GetProgress(player: Player): { [string]: any }
    local data = DataManager.GetData(player)
    if not data then
        return {
            level = "Newborn",
            layerIndex = 1,
            motes = 0,
            nextThreshold = 10,
            progress = 0,
        }
    end

    local currentLevel = data.angelLevel
    local currentIndex = Layers.GetLevelIndex(currentLevel)
    local currentThreshold = Layers.PROGRESSION_THRESHOLDS[currentLevel]
    local nextThreshold = nil
    local progress = 100

    if currentIndex < #Layers.ANGEL_LEVELS then
        local nextLevel = Layers.ANGEL_LEVELS[currentIndex + 1]
        nextThreshold = Layers.PROGRESSION_THRESHOLDS[nextLevel]
        local range = nextThreshold - currentThreshold
        local current = data.motes - currentThreshold
        progress = math.clamp(math.floor((current / range) * 100), 0, 100)
    end

    return {
        level = currentLevel,
        layerIndex = data.layerIndex,
        motes = data.motes,
        nextThreshold = nextThreshold,
        progress = progress,
        fragmentCount = 0, -- filled by LoreSystem
    }
end

-- Called after any mote award to check for progression
function ProgressionSystem.OnMotesChanged(player: Player)
    ProgressionSystem.CheckLevelUp(player)
end

-- Gate interaction: player touches a layer gate
function ProgressionSystem.HandleGateTouch(player: Player, targetLayerIndex: number): boolean
    if ProgressionSystem.CanAccessLayer(player, targetLayerIndex) then
        -- Teleport player to next layer's spawn
        local layerDef = Layers.GetLayerByIndex(targetLayerIndex)
        if layerDef and player.Character then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                humanoidRootPart.CFrame = CFrame.new(layerDef.spawnPosition)
                return true
            end
        end
    end
    return false
end

return ProgressionSystem
