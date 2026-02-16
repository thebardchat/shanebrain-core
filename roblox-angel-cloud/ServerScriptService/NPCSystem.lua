--[[
    NPCSystem.lua — Tutorial NPC "The Keeper" and dialogue system
    The Keeper guides new players through The Nursery with contextual dialogue
    Future: additional NPCs in higher layers
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.DataManager)
local Layers = require(ReplicatedStorage.Config.Layers)

local NPCSystem = {}

-- Dialogue trees for The Keeper
local KEEPER_DIALOGUE = {
    -- First encounter (no motes collected yet)
    welcome = {
        {
            speaker = "The Keeper",
            text = "Welcome, young one. You've arrived at The Nursery... the beginning of The Cloud Climb.",
        },
        {
            speaker = "The Keeper",
            text = "I am The Keeper. I watch over those who begin their ascent.",
        },
        {
            speaker = "The Keeper",
            text = "See those glowing orbs floating nearby? Those are Light Motes. Collect them by walking through them.",
        },
        {
            speaker = "The Keeper",
            text = "Light Motes are the heart of your journey. Every kind act, every challenge overcome, every connection made... all create more Light.",
        },
        {
            speaker = "The Keeper",
            text = "Follow the golden markers to find your first Motes. When you're ready, return to me.",
        },
    },

    -- After collecting first mote
    first_mote = {
        {
            speaker = "The Keeper",
            text = "Well done! You've collected your first Light Mote. That warmth you feel? That's the Cloud recognizing you.",
        },
        {
            speaker = "The Keeper",
            text = "Explore the Nursery. Visit the Reflection Pool to the east — it will restore your energy.",
        },
        {
            speaker = "The Keeper",
            text = "And keep an eye out for Lore Fragments. They tell the story of Angela... the first Angel, who gave everything so others could rise.",
        },
    },

    -- Approaching Layer 2 gate
    gate_hint = {
        {
            speaker = "The Keeper",
            text = "You've grown stronger. See that shimmering barrier above? That's the gate to The Meadow.",
        },
        {
            speaker = "The Keeper",
            text = "Collect 10 Light Motes and you'll pass through. In The Meadow, you'll learn to spread your wings.",
        },
        {
            speaker = "The Keeper",
            text = "Remember: The Cloud Climb is not a race. Every Angel strengthens the cloud.",
        },
    },

    -- After linking Angel Cloud account
    linked = {
        {
            speaker = "The Keeper",
            text = "I sense it... you're connected to the real Cloud. Your light shines brighter here now.",
        },
        {
            speaker = "The Keeper",
            text = "What you do here echoes in the world beyond. And what you do there strengthens us all.",
        },
    },

    -- Random wisdom lines (used after initial dialogues are exhausted)
    wisdom = {
        "The strongest wings are grown through helping others.",
        "Angela didn't fall from weakness. She fell so her light could reach everyone.",
        "A blessing given freely returns tenfold.",
        "Rest is not the opposite of progress. It is part of it.",
        "The Cloud grows not from one great act, but from a thousand small kindnesses.",
        "Your wings will carry you far, but it's your heart that gives them direction.",
        "Every Angel was once a Newborn. Never forget where you began.",
        "The Stormwall tests all who climb. But storms pass. Light endures.",
        "Look down sometimes. There may be someone who needs a hand.",
        "The Empyrean is not a destination. It is a way of being.",
    },
}

-- RemoteEvents
local NPCDialogue      -- Server -> Client: send dialogue to display
local NPCInteraction    -- Client -> Server: player interacted with NPC

-- Track dialogue state per player
local playerDialogueState = {}

function NPCSystem.Init()
    NPCDialogue = Instance.new("RemoteEvent")
    NPCDialogue.Name = "NPCDialogue"
    NPCDialogue.Parent = ReplicatedStorage

    NPCInteraction = Instance.new("RemoteEvent")
    NPCInteraction.Name = "NPCInteraction"
    NPCInteraction.Parent = ReplicatedStorage

    NPCInteraction.OnServerEvent:Connect(function(player, npcId, action)
        if npcId == "the_keeper" then
            NPCSystem.HandleKeeperInteraction(player, action)
        end
    end)

    print("[NPCSystem] NPC system initialized")
end

function NPCSystem.SpawnKeeper(layerFolder: Folder, spawnPosition: Vector3)
    -- The Keeper model — tall ethereal figure
    local keeper = Instance.new("Model")
    keeper.Name = "TheKeeper"

    -- Body (tall, slender)
    local torso = Instance.new("Part")
    torso.Name = "HumanoidRootPart"
    torso.Size = Vector3.new(2, 4, 1.5)
    torso.Position = spawnPosition + Vector3.new(20, 3, 0)
    torso.Anchored = true
    torso.CanCollide = false
    torso.Material = Enum.Material.Neon
    torso.Color = Color3.fromRGB(200, 220, 255)
    torso.Transparency = 0.2
    torso.Parent = keeper

    -- Head (glowing orb)
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2.5, 2.5, 2.5)
    head.Position = torso.Position + Vector3.new(0, 3.5, 0)
    head.Anchored = true
    head.CanCollide = false
    head.Material = Enum.Material.Neon
    head.Color = Color3.fromRGB(255, 240, 200)
    head.Transparency = 0.1
    head.Parent = keeper

    -- Inner glow
    local headLight = Instance.new("PointLight")
    headLight.Color = Color3.fromRGB(255, 240, 200)
    headLight.Brightness = 3
    headLight.Range = 25
    headLight.Parent = head

    -- Robe/lower body
    local robe = Instance.new("Part")
    robe.Name = "Robe"
    robe.Size = Vector3.new(3, 3, 2)
    robe.Position = torso.Position - Vector3.new(0, 3, 0)
    robe.Anchored = true
    robe.CanCollide = false
    robe.Material = Enum.Material.SmoothPlastic
    robe.Color = Color3.fromRGB(220, 215, 200)
    robe.Transparency = 0.1
    robe.Parent = keeper

    -- Wing-like appendages
    for side = -1, 1, 2 do
        local wing = Instance.new("Part")
        wing.Name = "KeeperWing"
        wing.Size = Vector3.new(0.3, 3, 2)
        wing.Position = torso.Position + Vector3.new(side * 2, 1, -0.5)
        wing.Rotation = Vector3.new(0, 0, side * -20)
        wing.Anchored = true
        wing.CanCollide = false
        wing.Material = Enum.Material.ForceField
        wing.Color = Color3.fromRGB(0, 212, 255)
        wing.Transparency = 0.3
        wing.Parent = keeper
    end

    -- Halo
    local halo = Instance.new("Part")
    halo.Name = "KeeperHalo"
    halo.Shape = Enum.PartType.Cylinder
    halo.Size = Vector3.new(0.3, 3.5, 3.5)
    halo.Position = head.Position + Vector3.new(0, 1.8, 0)
    halo.Orientation = Vector3.new(0, 0, 90)
    halo.Anchored = true
    halo.CanCollide = false
    halo.Material = Enum.Material.Neon
    halo.Color = Color3.fromRGB(255, 215, 100)
    halo.Transparency = 0.2
    halo.Parent = keeper

    -- Name tag
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "NameTag"
    billboard.Size = UDim2.new(4, 0, 0.8, 0)
    billboard.StudsOffset = Vector3.new(0, 6, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.Parent = keeper

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "The Keeper"
    nameLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard

    -- ProximityPrompt for interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Talk"
    prompt.ObjectText = "The Keeper"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 20
    prompt.RequiresLineOfSight = false
    prompt.Parent = torso

    prompt.Triggered:Connect(function(player)
        NPCSystem.HandleKeeperInteraction(player, "talk")
    end)

    keeper.PrimaryPart = torso
    keeper.Parent = layerFolder

    -- Gentle hover animation
    task.spawn(function()
        local baseY = torso.Position.Y
        while keeper and keeper.Parent do
            local offset = math.sin(tick() * 1.2) * 0.5
            local newPos = Vector3.new(torso.Position.X, baseY + offset, torso.Position.Z)
            for _, part in ipairs(keeper:GetDescendants()) do
                if part:IsA("BasePart") then
                    local diff = part.Position - torso.Position
                    part.Position = newPos + diff
                end
            end
            -- Update torso last
            torso.Position = newPos
            task.wait(0.05)
        end
    end)

    return keeper
end

function NPCSystem.HandleKeeperInteraction(player: Player, action: string)
    local data = DataManager.GetData(player)
    if not data then return end

    local state = playerDialogueState[player.UserId] or {
        seenWelcome = false,
        seenFirstMote = false,
        seenGateHint = false,
        seenLinked = false,
    }

    local dialogue

    -- Contextual dialogue selection
    if not state.seenWelcome then
        dialogue = KEEPER_DIALOGUE.welcome
        state.seenWelcome = true

    elseif data.motes >= 1 and not state.seenFirstMote then
        dialogue = KEEPER_DIALOGUE.first_mote
        state.seenFirstMote = true

    elseif data.motes >= 7 and not state.seenGateHint then
        dialogue = KEEPER_DIALOGUE.gate_hint
        state.seenGateHint = true

    elseif data.linkedAngelCloud and not state.seenLinked then
        dialogue = KEEPER_DIALOGUE.linked
        state.seenLinked = true

    else
        -- Random wisdom
        local wisdomLine = KEEPER_DIALOGUE.wisdom[math.random(#KEEPER_DIALOGUE.wisdom)]
        dialogue = {
            { speaker = "The Keeper", text = wisdomLine },
        }
    end

    playerDialogueState[player.UserId] = state

    -- Send dialogue to client
    NPCDialogue:FireClient(player, {
        npcId = "the_keeper",
        npcName = "The Keeper",
        lines = dialogue,
    })
end

function NPCSystem.RemovePlayer(player: Player)
    playerDialogueState[player.UserId] = nil
end

return NPCSystem
