--[[
    LoreSystem.lua — Lore Fragment collection and codex management
    65 fragments across 7 categories telling the story of Angela's fall
    Server tracks collection; client renders codex constellation map
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local Fragments = require(ReplicatedStorage.Config.Fragments)
local Layers = require(ReplicatedStorage.Config.Layers)

local LoreSystem = {}

-- RemoteEvents
local FragmentCollected  -- Server -> Client: fragment pickup notification
local FragmentRequest    -- Client -> Server: player interacts with fragment location
local CodexRequest       -- Client -> Server: player opens codex
local CodexData          -- Server -> Client: send codex data

function LoreSystem.Init()
    FragmentCollected = Instance.new("RemoteEvent")
    FragmentCollected.Name = "FragmentCollected"
    FragmentCollected.Parent = ReplicatedStorage

    FragmentRequest = Instance.new("RemoteEvent")
    FragmentRequest.Name = "FragmentRequest"
    FragmentRequest.Parent = ReplicatedStorage

    CodexRequest = Instance.new("RemoteEvent")
    CodexRequest.Name = "CodexRequest"
    CodexRequest.Parent = ReplicatedStorage

    CodexData = Instance.new("RemoteEvent")
    CodexData.Name = "CodexData"
    CodexData.Parent = ReplicatedStorage

    -- Listen for client requests
    FragmentRequest.OnServerEvent:Connect(function(player, fragmentId)
        LoreSystem.TryCollectFragment(player, fragmentId)
    end)

    CodexRequest.OnServerEvent:Connect(function(player)
        LoreSystem.SendCodexData(player)
    end)
end

function LoreSystem.TryCollectFragment(player: Player, fragmentId: string): boolean
    local data = DataManager.GetData(player)
    if not data then
        return false
    end

    -- Already collected?
    if data.collectedFragments[fragmentId] then
        return false
    end

    -- Fragment exists?
    local fragment = Fragments.GetFragment(fragmentId)
    if not fragment then
        return false
    end

    -- Player on correct layer or higher?
    local playerLayerIndex = data.layerIndex or 1
    if playerLayerIndex < fragment.layer then
        return false
    end

    -- Angela fragments have special requirements (checked elsewhere)
    if fragment.category == "Angela" then
        if not LoreSystem.CheckAngelaRequirement(player, fragment) then
            return false
        end
    end

    -- Collect!
    data.collectedFragments[fragmentId] = true

    -- Notify client with full fragment data
    FragmentCollected:FireClient(player, {
        id = fragment.id,
        name = fragment.name,
        category = fragment.category,
        wisdom = fragment.wisdom,
        loreText = fragment.loreText,
        totalCollected = LoreSystem.GetCollectedCount(player),
        totalFragments = Fragments.TOTAL_COUNT,
    })

    return true
end

function LoreSystem.CheckAngelaRequirement(player: Player, fragment: { [string]: any }): boolean
    local data = DataManager.GetData(player)
    if not data then
        return false
    end

    if fragment.id == "angela_01" then
        -- Angela's Wing: must have at least 1 fragment from each non-Guardian, non-Angela category
        local categories = { Decision = false, Emotion = false, Relationship = false, Strength = false, Suffering = false }
        for fragId, _ in pairs(data.collectedFragments) do
            local frag = Fragments.GetFragment(fragId)
            if frag and categories[frag.category] ~= nil then
                categories[frag.category] = true
            end
        end
        for _, has in pairs(categories) do
            if not has then
                return false
            end
        end
        return true

    elseif fragment.id == "angela_02" then
        -- Angela's Voice: during a blessing chain of 5+
        -- This is checked by BlessingSystem and triggers collection
        return false  -- must be triggered externally

    elseif fragment.id == "angela_03" then
        -- Angela's Heart: 4 Angel-rank players at Cloud Core with emote sequence
        -- This is checked by a special interaction in Layer 6
        return false  -- must be triggered externally

    elseif fragment.id == "angela_04" then
        -- Angela's Light: enter Empyrean with all other 60 fragments at server dawn
        local count = LoreSystem.GetCollectedCount(player)
        return count >= 60  -- all non-Angela fragments

    elseif fragment.id == "angela_05" then
        -- Angela's Promise: Angel rank + helped 20+ Newborns
        return data.angelLevel == "Angel" and (data.newbornsHelped or 0) >= 20
    end

    return false
end

function LoreSystem.GetCollectedCount(player: Player): number
    local data = DataManager.GetData(player)
    if not data then
        return 0
    end

    local count = 0
    for _ in pairs(data.collectedFragments) do
        count = count + 1
    end
    return count
end

function LoreSystem.GetCollectedFragments(player: Player): { string }
    local data = DataManager.GetData(player)
    if not data then
        return {}
    end

    local collected = {}
    for fragId, _ in pairs(data.collectedFragments) do
        table.insert(collected, fragId)
    end
    return collected
end

function LoreSystem.SendCodexData(player: Player)
    local data = DataManager.GetData(player)
    if not data then
        return
    end

    -- Build codex: all fragments with collected status
    local codex = {}
    for _, fragment in ipairs(Fragments.Definitions) do
        local entry = {
            id = fragment.id,
            name = fragment.name,
            category = fragment.category,
            layer = fragment.layer,
            collected = data.collectedFragments[fragment.id] == true,
        }

        -- Only send wisdom/lore text if collected
        if entry.collected then
            entry.wisdom = fragment.wisdom
            entry.loreText = fragment.loreText
        end

        table.insert(codex, entry)
    end

    CodexData:FireClient(player, {
        codex = codex,
        totalCollected = LoreSystem.GetCollectedCount(player),
        totalFragments = Fragments.TOTAL_COUNT,
        categoryProgress = LoreSystem.GetCategoryProgress(player),
    })
end

function LoreSystem.GetCategoryProgress(player: Player): { [string]: { collected: number, total: number } }
    local data = DataManager.GetData(player)
    if not data then
        return {}
    end

    local progress = {}
    for category, frags in pairs(Fragments.ByCategory) do
        local collected = 0
        for _, frag in ipairs(frags) do
            if data.collectedFragments[frag.id] then
                collected = collected + 1
            end
        end
        progress[category] = {
            collected = collected,
            total = #frags,
        }
    end
    return progress
end

-- Spawn fragment interaction points in a layer
function LoreSystem.SpawnFragmentPoints(layerFolder: Folder, layerIndex: number)
    local layerFragments = Fragments.GetByLayer(layerIndex)
    local spread = 180

    for i, fragment in ipairs(layerFragments) do
        local layerDef = Layers.GetLayerByIndex(layerIndex)
        local heightMin = layerDef.heightRange.min
        local heightMax = layerDef.heightRange.max

        local point = Instance.new("Part")
        point.Name = "FragmentPoint_" .. fragment.id
        point.Shape = Enum.PartType.Ball
        point.Size = Vector3.new(3, 3, 3)
        point.Position = Vector3.new(
            math.random(-spread, spread),
            math.random(heightMin + 20, heightMax - 20),
            math.random(-spread, spread)
        )
        point.Anchored = true
        point.CanCollide = false
        point.Material = Enum.Material.ForceField
        point.Transparency = 0.2

        -- Color by category
        local categoryColors = {
            Decision = Color3.fromRGB(255, 215, 0),     -- gold
            Emotion = Color3.fromRGB(0, 212, 255),       -- cyan
            Relationship = Color3.fromRGB(255, 150, 200),-- pink
            Strength = Color3.fromRGB(255, 100, 50),     -- orange
            Suffering = Color3.fromRGB(120, 50, 180),    -- purple
            Guardian = Color3.fromRGB(100, 255, 100),    -- green
            Angela = Color3.fromRGB(255, 255, 255),      -- white
        }
        point.Color = categoryColors[fragment.category] or Color3.fromRGB(200, 200, 200)

        local fragIdValue = Instance.new("StringValue")
        fragIdValue.Name = "FragmentId"
        fragIdValue.Value = fragment.id
        fragIdValue.Parent = point

        -- Gentle rotation animation
        task.spawn(function()
            while point and point.Parent do
                point.Orientation = point.Orientation + Vector3.new(0, 1, 0)
                task.wait(0.03)
            end
        end)

        -- Touch detection
        point.Touched:Connect(function(hit)
            local character = hit.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                LoreSystem.TryCollectFragment(player, fragment.id)
            end
        end)

        point.Parent = layerFolder
    end
end

return LoreSystem
