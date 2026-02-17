--[[
    RetroSystem.lua — Retro easter eggs scattered throughout The Cloud Climb
    Phone booths with rotary dial mechanic, retro TV sets, vintage artifacts
    "Bridging the gap" — old school meets cloud world

    Features:
    - Phone Booths: glass booths on clouds, step inside to use rotary phone
    - Rotary Dial: actual dial mechanic — spin numbers to enter codes for Motes
    - The Signal: glitchy TV-head NPC (Max Headroom vibes, legally distinct)
    - Random retro objects: boomboxes, cassette tapes, arcade cabinets
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)

local RetroSystem = {}

-- Valid dial codes and their rewards
-- Players discover codes from lore fragments, The Signal hints, or community sharing
local DIAL_CODES = {
    ["867-5309"] = { reward = 5, message = "Jenny? Is that you? +5 Motes", oneTime = true },
    ["411"]      = { reward = 2, message = "Information... The Cloud remembers everything. +2 Motes", oneTime = false },
    ["911"]      = { reward = 3, message = "Emergency services... for Angels? A blessing finds you instead. +3 Motes", oneTime = false, cooldown = 300 },
    ["420-6969"] = { reward = 1, message = "Nice. +1 Mote", oneTime = false, cooldown = 60 },
    ["000-0000"] = { reward = 10, message = "The void answers... Angel whispers through the static. +10 Motes", oneTime = true },
    ["123-4567"] = { reward = 3, message = "Sequential. Orderly. The Cloud appreciates structure. +3 Motes", oneTime = true },
    ["314-1592"] = { reward = 8, message = "Pi... infinite and irrational, like the climb itself. +8 Motes", oneTime = true },
    ["248-5553"] = { reward = 5, message = "Hazel Green calling... home is where the Cloud begins. +5 Motes", oneTime = true },
    ["101-0101"] = { reward = 5, message = "Binary angels. The machine dreams too. +5 Motes", oneTime = true },
    ["777-7777"] = { reward = 15, message = "JACKPOT! Seven sevens! The rotary spins gold! +15 Motes", oneTime = true },
}

-- The Signal's glitchy dialogue lines
local SIGNAL_LINES = {
    "C-c-catch the signal... b-before it f-fades...",
    "I was here before the Cloud. Before the... *static* ...before everything.",
    "The phone booths remember numbers that haven't been d-d-dialed yet.",
    "Have you tried... *static* ...8-6-7-5-3-0-9? Someone named Jenny left a message.",
    "Three-one-four-one-five-nine-two. The number that n-never ends. Like climbing.",
    "I see you. I see ALL of you. Every server. Every... *static* ...every Cloud.",
    "Don't adjust your wings. The signal is f-fine. YOU'RE the one who's sideways.",
    "Dial zero-zero-zero... zero-zero-zero-zero. If you d-dare.",
    "The starfish know things. Brown little... *static* ...watchers.",
    "Seven-seven-seven... seven-seven-seven-seven. Lucky number. Very l-lucky.",
    "Angel left a number. I can't remember it. Can you?",
    "Twenty channels and nothing on. Just clouds. Always c-clouds.",
    "Retro? I'm not retro. I'm ahead of my t-time. YOUR time just caught up.",
    "The Keeper talks too slow. I talk too f-fast. Somewhere in between is truth.",
}

-- RemoteEvents
local DialCode        -- Client -> Server: player dialed a number
local DialResult      -- Server -> Client: code result
local SignalAppear    -- Server -> Client: The Signal has appeared nearby

-- Track per-player cooldowns and redeemed codes
local playerDialState = {}

function RetroSystem.Init()
    DialCode = Instance.new("RemoteEvent")
    DialCode.Name = "DialCode"
    DialCode.Parent = ReplicatedStorage

    DialResult = Instance.new("RemoteEvent")
    DialResult.Name = "DialResult"
    DialResult.Parent = ReplicatedStorage

    SignalAppear = Instance.new("RemoteEvent")
    SignalAppear.Name = "SignalAppear"
    SignalAppear.Parent = ReplicatedStorage

    DialCode.OnServerEvent:Connect(function(player, code)
        RetroSystem.HandleDial(player, code)
    end)

    -- The Signal random appearance loop
    task.spawn(function()
        while true do
            task.wait(90 + math.random() * 120)  -- every 1.5 to 3.5 minutes
            RetroSystem.SpawnSignalEvent()
        end
    end)

    print("[RetroSystem] Retro system initialized — dial in, tune in, climb on")
end

-- =========================================================================
-- PHONE BOOTH — glass booth with rotary phone inside
-- =========================================================================

function RetroSystem.CreatePhoneBooth(parent: Folder, position: Vector3, rotation: number?)
    rotation = rotation or 0

    local booth = Instance.new("Model")
    booth.Name = "PhoneBooth"

    -- Base
    local base = Instance.new("Part")
    base.Name = "BoothBase"
    base.Size = Vector3.new(5, 0.5, 5)
    base.Position = position
    base.Anchored = true
    base.Material = Enum.Material.Metal
    base.Color = Color3.fromRGB(180, 30, 30)  -- classic red phone booth
    base.Parent = booth

    -- Back wall
    local back = Instance.new("Part")
    back.Name = "BoothBack"
    back.Size = Vector3.new(5, 9, 0.4)
    back.Position = position + Vector3.new(0, 4.75, -2.3)
    back.Anchored = true
    back.Material = Enum.Material.Metal
    back.Color = Color3.fromRGB(180, 30, 30)
    back.Parent = booth

    -- Side walls (glass)
    for side = -1, 1, 2 do
        local wall = Instance.new("Part")
        wall.Name = "BoothSide"
        wall.Size = Vector3.new(0.3, 7, 4.6)
        wall.Position = position + Vector3.new(side * 2.35, 3.75, 0)
        wall.Anchored = true
        wall.Material = Enum.Material.Glass
        wall.Color = Color3.fromRGB(200, 220, 240)
        wall.Transparency = 0.5
        wall.Parent = booth
    end

    -- Roof
    local roof = Instance.new("Part")
    roof.Name = "BoothRoof"
    roof.Size = Vector3.new(5.4, 0.5, 5.4)
    roof.Position = position + Vector3.new(0, 9.5, 0)
    roof.Anchored = true
    roof.Material = Enum.Material.Metal
    roof.Color = Color3.fromRGB(180, 30, 30)
    roof.Parent = booth

    -- Light on top
    local topLight = Instance.new("Part")
    topLight.Name = "BoothLight"
    topLight.Shape = Enum.PartType.Ball
    topLight.Size = Vector3.new(1.5, 1.5, 1.5)
    topLight.Position = position + Vector3.new(0, 10.5, 0)
    topLight.Anchored = true
    topLight.CanCollide = false
    topLight.Material = Enum.Material.Neon
    topLight.Color = Color3.fromRGB(255, 220, 100)
    topLight.Parent = booth

    local pointLight = Instance.new("PointLight")
    pointLight.Color = Color3.fromRGB(255, 220, 100)
    pointLight.Brightness = 2
    pointLight.Range = 20
    pointLight.Parent = topLight

    -- The phone on the wall (rotary style)
    local phoneBase = Instance.new("Part")
    phoneBase.Name = "RotaryPhone"
    phoneBase.Size = Vector3.new(1.5, 2, 0.8)
    phoneBase.Position = position + Vector3.new(0, 5, -1.8)
    phoneBase.Anchored = true
    phoneBase.Material = Enum.Material.SmoothPlastic
    phoneBase.Color = Color3.fromRGB(20, 20, 20)  -- black rotary phone
    phoneBase.Parent = booth

    -- Rotary dial (circular detail)
    local dial = Instance.new("Part")
    dial.Name = "RotaryDial"
    dial.Shape = Enum.PartType.Cylinder
    dial.Size = Vector3.new(0.2, 1.2, 1.2)
    dial.Position = phoneBase.Position + Vector3.new(0, -0.2, 0.5)
    dial.Orientation = Vector3.new(90, 0, 0)
    dial.Anchored = true
    dial.CanCollide = false
    dial.Material = Enum.Material.SmoothPlastic
    dial.Color = Color3.fromRGB(240, 230, 200)  -- ivory dial
    dial.Parent = booth

    -- Handset (the part you pick up)
    local handset = Instance.new("Part")
    handset.Name = "Handset"
    handset.Size = Vector3.new(0.4, 0.4, 1.8)
    handset.Position = phoneBase.Position + Vector3.new(0, 1.2, 0)
    handset.Anchored = true
    handset.CanCollide = false
    handset.Material = Enum.Material.SmoothPlastic
    handset.Color = Color3.fromRGB(20, 20, 20)
    handset.Parent = booth

    -- Cord (curly phone cord visual)
    local cord = Instance.new("Part")
    cord.Name = "PhoneCord"
    cord.Size = Vector3.new(0.15, 1.5, 0.15)
    cord.Position = phoneBase.Position + Vector3.new(0.3, 0.5, 0.2)
    cord.Anchored = true
    cord.CanCollide = false
    cord.Material = Enum.Material.Rubber
    cord.Color = Color3.fromRGB(30, 30, 30)
    cord.Parent = booth

    -- "PHONE" sign
    local sign = Instance.new("Part")
    sign.Name = "PhoneSign"
    sign.Size = Vector3.new(3, 1, 0.2)
    sign.Position = position + Vector3.new(0, 8.5, 2.5)
    sign.Anchored = true
    sign.Material = Enum.Material.Neon
    sign.Color = Color3.fromRGB(255, 220, 100)
    sign.Parent = booth

    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.Parent = sign

    local signLabel = Instance.new("TextLabel")
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = "TELEPHONE"
    signLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
    signLabel.TextScaled = true
    signLabel.Font = Enum.Font.Antique
    signLabel.Parent = signGui

    -- ProximityPrompt to use the phone
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pick Up Phone"
    prompt.ObjectText = "Rotary Telephone"
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 8
    prompt.Parent = phoneBase

    booth.PrimaryPart = base
    booth.Parent = parent

    return booth, prompt
end

-- =========================================================================
-- ROTARY DIAL HANDLER
-- =========================================================================

function RetroSystem.HandleDial(player: Player, code: string)
    if not code or code == "" then return end

    local data = DataManager.GetData(player)
    if not data then return end

    -- Initialize dial state
    if not playerDialState[player.UserId] then
        playerDialState[player.UserId] = {
            redeemedCodes = data.redeemedDialCodes or {},
            cooldowns = {},
        }
    end
    local state = playerDialState[player.UserId]

    -- Normalize code (strip spaces)
    code = code:gsub("%s+", "")

    local codeData = DIAL_CODES[code]
    if not codeData then
        -- Wrong number — still fun
        local wrongMessages = {
            "The number you have dialed is not in service. Please hang up and try again.",
            "*static* ...nobody home on Cloud " .. code .. "...",
            "A distant voice whispers: 'Wrong number, Angel.'",
            "You hear elevator music. It goes on forever. You hang up.",
            "An answering machine: 'Hi, you've reached the void. Leave a message after the beep.' ...BEEEEP.",
        }
        DialResult:FireClient(player, {
            success = false,
            message = wrongMessages[math.random(#wrongMessages)],
        })
        return
    end

    -- One-time code already redeemed?
    if codeData.oneTime and state.redeemedCodes[code] then
        DialResult:FireClient(player, {
            success = false,
            message = "You already dialed this number. The line is dead.",
        })
        return
    end

    -- Cooldown check
    if codeData.cooldown then
        local lastUse = state.cooldowns[code] or 0
        if os.time() - lastUse < codeData.cooldown then
            local remaining = codeData.cooldown - (os.time() - lastUse)
            DialResult:FireClient(player, {
                success = false,
                message = "Line busy. Try again in " .. remaining .. " seconds.",
            })
            return
        end
    end

    -- Valid code — award reward
    MoteSystem.AwardMotes(player, codeData.reward, "rotary_phone")

    -- Track redemption
    if codeData.oneTime then
        state.redeemedCodes[code] = true
        if not data.redeemedDialCodes then
            data.redeemedDialCodes = {}
        end
        data.redeemedDialCodes[code] = true
    end

    if codeData.cooldown then
        state.cooldowns[code] = os.time()
    end

    DialResult:FireClient(player, {
        success = true,
        message = codeData.message,
        reward = codeData.reward,
    })

    print("[RetroSystem] " .. player.Name .. " dialed " .. code .. " → +" .. codeData.reward .. " Motes")
end

-- =========================================================================
-- THE SIGNAL — glitchy TV-head NPC (legally distinct retro broadcast entity)
-- =========================================================================

function RetroSystem.CreateSignalNPC(parent: Folder, position: Vector3)
    local signal = Instance.new("Model")
    signal.Name = "TheSignal"

    -- Body (suit, slightly distorted proportions)
    local torso = Instance.new("Part")
    torso.Name = "HumanoidRootPart"
    torso.Size = Vector3.new(2, 3, 1.2)
    torso.Position = position
    torso.Anchored = true
    torso.CanCollide = false
    torso.Material = Enum.Material.SmoothPlastic
    torso.Color = Color3.fromRGB(40, 40, 50)  -- dark suit
    torso.Parent = signal

    -- TV Head (the iconic part)
    local tvHead = Instance.new("Part")
    tvHead.Name = "TVHead"
    tvHead.Size = Vector3.new(2.5, 2, 2)
    tvHead.Position = position + Vector3.new(0, 3, 0)
    tvHead.Anchored = true
    tvHead.CanCollide = false
    tvHead.Material = Enum.Material.SmoothPlastic
    tvHead.Color = Color3.fromRGB(60, 55, 50)  -- old TV beige-grey
    tvHead.Parent = signal

    -- Screen (the face — neon glow, represents the broadcast)
    local screen = Instance.new("Part")
    screen.Name = "TVScreen"
    screen.Size = Vector3.new(2, 1.5, 0.1)
    screen.Position = tvHead.Position + Vector3.new(0, 0, 1.05)
    screen.Anchored = true
    screen.CanCollide = false
    screen.Material = Enum.Material.Neon
    screen.Color = Color3.fromRGB(0, 255, 180)  -- retro green phosphor
    screen.Parent = signal

    -- Screen GUI (shows glitchy text)
    local screenGui = Instance.new("SurfaceGui")
    screenGui.Face = Enum.NormalId.Front
    screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    screenGui.PixelsPerStud = 50
    screenGui.Parent = screen

    local screenText = Instance.new("TextLabel")
    screenText.Name = "ScreenText"
    screenText.Size = UDim2.new(1, 0, 1, 0)
    screenText.BackgroundColor3 = Color3.fromRGB(0, 20, 10)
    screenText.BackgroundTransparency = 0.3
    screenText.Text = "SIGNAL"
    screenText.TextColor3 = Color3.fromRGB(0, 255, 180)
    screenText.TextScaled = true
    screenText.Font = Enum.Font.Code
    screenText.Parent = screenGui

    -- Antenna (rabbit ears on top of TV)
    for side = -1, 1, 2 do
        local antenna = Instance.new("Part")
        antenna.Name = "Antenna"
        antenna.Size = Vector3.new(0.15, 2, 0.15)
        antenna.Position = tvHead.Position + Vector3.new(side * 0.6, 1.8, -0.3)
        antenna.Rotation = Vector3.new(0, 0, side * -15)
        antenna.Anchored = true
        antenna.CanCollide = false
        antenna.Material = Enum.Material.Metal
        antenna.Color = Color3.fromRGB(150, 150, 150)
        antenna.Parent = signal

        -- Antenna tip
        local tip = Instance.new("Part")
        tip.Shape = Enum.PartType.Ball
        tip.Size = Vector3.new(0.3, 0.3, 0.3)
        tip.Position = antenna.Position + Vector3.new(side * -0.5, 1, 0)
        tip.Anchored = true
        tip.CanCollide = false
        tip.Material = Enum.Material.Neon
        tip.Color = Color3.fromRGB(255, 50, 50)
        tip.Parent = signal
    end

    -- Legs (standing pose)
    for side = -1, 1, 2 do
        local leg = Instance.new("Part")
        leg.Name = "Leg"
        leg.Size = Vector3.new(0.8, 3, 0.8)
        leg.Position = position + Vector3.new(side * 0.5, -3, 0)
        leg.Anchored = true
        leg.CanCollide = false
        leg.Material = Enum.Material.SmoothPlastic
        leg.Color = Color3.fromRGB(40, 40, 50)
        leg.Parent = signal
    end

    -- Arms (slightly out, gesturing)
    for side = -1, 1, 2 do
        local arm = Instance.new("Part")
        arm.Name = "Arm"
        arm.Size = Vector3.new(0.6, 2.5, 0.6)
        arm.Position = position + Vector3.new(side * 1.6, 0.5, 0)
        arm.Rotation = Vector3.new(0, 0, side * 20)
        arm.Anchored = true
        arm.CanCollide = false
        arm.Material = Enum.Material.SmoothPlastic
        arm.Color = Color3.fromRGB(40, 40, 50)
        arm.Parent = signal
    end

    -- Glow and static effect
    local screenLight = Instance.new("PointLight")
    screenLight.Color = Color3.fromRGB(0, 255, 180)
    screenLight.Brightness = 3
    screenLight.Range = 20
    screenLight.Parent = screen

    -- Name tag
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(4, 0, 0.8, 0)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.Adornee = tvHead
    billboard.AlwaysOnTop = true
    billboard.Parent = signal

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "The Signal"
    nameLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard

    -- ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Tune In"
    prompt.ObjectText = "The Signal"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 15
    prompt.Parent = torso

    signal.PrimaryPart = torso
    signal.Parent = parent

    -- Glitch animation — screen text flickers
    task.spawn(function()
        local glitchTexts = { "SIGNAL", "S1GN4L", "S̸I̸G̸N̸A̸L", "516N4L", "-----", "HELLO", "TUNE IN", "???.???" }
        while screen and screen.Parent do
            screenText.Text = glitchTexts[math.random(#glitchTexts)]
            -- Random color flicker
            if math.random() > 0.7 then
                screen.Color = Color3.fromRGB(
                    math.random(0, 50),
                    math.random(200, 255),
                    math.random(100, 200)
                )
            end
            task.wait(0.15 + math.random() * 0.3)
        end
    end)

    return signal, prompt
end

-- =========================================================================
-- THE SIGNAL RANDOM EVENTS
-- =========================================================================

function RetroSystem.SpawnSignalEvent()
    local players = Players:GetPlayers()
    if #players == 0 then return end

    -- Pick a random player to appear near
    local targetPlayer = players[math.random(#players)]
    local character = targetPlayer.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Spawn The Signal nearby (offset so it's visible but not in face)
    local offset = Vector3.new(
        (math.random() - 0.5) * 30,
        math.random(3, 8),
        (math.random() - 0.5) * 30
    )
    local spawnPos = hrp.Position + offset

    -- Create temporary Signal NPC
    local signalModel, prompt = RetroSystem.CreateSignalNPC(workspace, spawnPos)

    -- Wire prompt
    prompt.Triggered:Connect(function(player)
        RetroSystem.OnSignalInteract(player)
    end)

    -- Notify nearby players
    SignalAppear:FireAllClients({
        position = spawnPos,
        message = "The Signal is broadcasting...",
    })

    -- The Signal disappears after 30-45 seconds
    task.delay(30 + math.random() * 15, function()
        if signalModel and signalModel.Parent then
            -- Despawn animation (flicker all parts out)
            for flickerPass = 1, 5 do
                for _, part in ipairs(signalModel:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = math.min(1, part.Transparency + 0.2)
                    end
                end
                task.wait(0.12)
            end
            signalModel:Destroy()
        end
    end)
end

function RetroSystem.OnSignalInteract(player: Player)
    -- Pick a random glitchy line
    local line = SIGNAL_LINES[math.random(#SIGNAL_LINES)]

    -- Send as dialogue
    local NPCDialogue = ReplicatedStorage:FindFirstChild("NPCDialogue")
    if NPCDialogue then
        NPCDialogue:FireClient(player, {
            npcId = "the_signal",
            npcName = "The Signal",
            lines = {
                { speaker = "The Signal", text = line },
            },
        })
    end

    -- Small mote reward for catching The Signal
    MoteSystem.AwardMotes(player, 1, "signal_encounter")

    local ServerMessage = ReplicatedStorage:FindFirstChild("ServerMessage")
    if ServerMessage then
        ServerMessage:FireClient(player, {
            type = "retro",
            message = "You caught The Signal! +1 Mote",
        })
    end
end

-- =========================================================================
-- RETRO DECORATIONS — boomboxes, cassettes, arcade cabinets
-- =========================================================================

function RetroSystem.CreateBoombox(parent: Folder, position: Vector3)
    local boombox = Instance.new("Model")
    boombox.Name = "Boombox"

    local body = Instance.new("Part")
    body.Name = "BoomboxBody"
    body.Size = Vector3.new(4, 2, 1.5)
    body.Position = position
    body.Anchored = true
    body.Material = Enum.Material.SmoothPlastic
    body.Color = Color3.fromRGB(50, 50, 55)
    body.Parent = boombox

    -- Speakers (two circles on front)
    for side = -1, 1, 2 do
        local speaker = Instance.new("Part")
        speaker.Shape = Enum.PartType.Cylinder
        speaker.Size = Vector3.new(0.2, 1.4, 1.4)
        speaker.Position = position + Vector3.new(side * 1.2, 0, 0.85)
        speaker.Orientation = Vector3.new(90, 0, 0)
        speaker.Anchored = true
        speaker.CanCollide = false
        speaker.Material = Enum.Material.Fabric
        speaker.Color = Color3.fromRGB(30, 30, 30)
        speaker.Parent = boombox
    end

    -- Handle on top
    local handle = Instance.new("Part")
    handle.Size = Vector3.new(2, 0.2, 0.2)
    handle.Position = position + Vector3.new(0, 1.3, 0)
    handle.Anchored = true
    handle.CanCollide = false
    handle.Material = Enum.Material.Metal
    handle.Color = Color3.fromRGB(180, 180, 180)
    handle.Parent = boombox

    boombox.PrimaryPart = body
    boombox.Parent = parent
    return boombox
end

function RetroSystem.CreateArcadeCabinet(parent: Folder, position: Vector3)
    local cabinet = Instance.new("Model")
    cabinet.Name = "ArcadeCabinet"

    -- Main body
    local body = Instance.new("Part")
    body.Name = "CabinetBody"
    body.Size = Vector3.new(3, 6, 2.5)
    body.Position = position + Vector3.new(0, 3, 0)
    body.Anchored = true
    body.Material = Enum.Material.SmoothPlastic
    body.Color = Color3.fromRGB(30, 30, 80)  -- dark blue cabinet
    body.Parent = cabinet

    -- Screen
    local screen = Instance.new("Part")
    screen.Name = "ArcadeScreen"
    screen.Size = Vector3.new(2.2, 2, 0.1)
    screen.Position = position + Vector3.new(0, 4.5, 1.3)
    screen.Anchored = true
    screen.CanCollide = false
    screen.Material = Enum.Material.Neon
    screen.Color = Color3.fromRGB(0, 200, 100)
    screen.Parent = cabinet

    local screenGui = Instance.new("SurfaceGui")
    screenGui.Face = Enum.NormalId.Front
    screenGui.Parent = screen

    local screenLabel = Instance.new("TextLabel")
    screenLabel.Size = UDim2.new(1, 0, 0.4, 0)
    screenLabel.Position = UDim2.new(0, 0, 0.1, 0)
    screenLabel.BackgroundTransparency = 1
    screenLabel.Text = "CLOUD CLIMB"
    screenLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    screenLabel.TextScaled = true
    screenLabel.Font = Enum.Font.Code
    screenLabel.Parent = screenGui

    local insertCoin = Instance.new("TextLabel")
    insertCoin.Size = UDim2.new(1, 0, 0.3, 0)
    insertCoin.Position = UDim2.new(0, 0, 0.6, 0)
    insertCoin.BackgroundTransparency = 1
    insertCoin.Text = "INSERT MOTE"
    insertCoin.TextColor3 = Color3.fromRGB(255, 255, 100)
    insertCoin.TextScaled = true
    insertCoin.Font = Enum.Font.Code
    insertCoin.Parent = screenGui

    -- Joystick area
    local controls = Instance.new("Part")
    controls.Size = Vector3.new(2.5, 0.5, 1.2)
    controls.Position = position + Vector3.new(0, 2.8, 1)
    controls.Anchored = true
    controls.Material = Enum.Material.SmoothPlastic
    controls.Color = Color3.fromRGB(20, 20, 20)
    controls.Parent = cabinet

    -- Joystick
    local stick = Instance.new("Part")
    stick.Shape = Enum.PartType.Cylinder
    stick.Size = Vector3.new(1, 0.3, 0.3)
    stick.Position = controls.Position + Vector3.new(-0.5, 0.7, 0)
    stick.Anchored = true
    stick.CanCollide = false
    stick.Material = Enum.Material.SmoothPlastic
    stick.Color = Color3.fromRGB(200, 30, 30)
    stick.Parent = cabinet

    -- Screen glow
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(0, 200, 100)
    light.Brightness = 1.5
    light.Range = 12
    light.Parent = screen

    cabinet.PrimaryPart = body
    cabinet.Parent = parent
    return cabinet
end

-- =========================================================================
-- SPAWN RETRO OBJECTS INTO LAYERS
-- =========================================================================

function RetroSystem.PopulateLayer(layerFolder: Folder, layerIndex: number, layerDef: any)
    local heightMin = layerDef.heightRange.min
    local heightMax = layerDef.heightRange.max

    -- Phone booth (one per layer, always present)
    local boothPositions = {
        Vector3.new(-40, heightMin + 20, 40),   -- Layer 1
        Vector3.new(60, heightMin + 35, -30),    -- Layer 2
        Vector3.new(-70, heightMin + 50, 70),    -- Layer 3
        Vector3.new(50, heightMin + 40, 50),     -- Layer 4
        Vector3.new(-30, heightMin + 60, -60),   -- Layer 5
        Vector3.new(0, heightMin + 80, 0),       -- Layer 6
    }

    local boothPos = boothPositions[layerIndex] or Vector3.new(
        math.random(-100, 100),
        math.random(heightMin + 20, heightMax - 40),
        math.random(-100, 100)
    )

    local _, boothPrompt = RetroSystem.CreatePhoneBooth(layerFolder, boothPos)
    boothPrompt.Triggered:Connect(function(player)
        -- Open dial UI on client
        DialResult:FireClient(player, {
            action = "open_dial",
            message = "*dial tone* Ready to dial...",
        })
    end)

    -- Boombox (random placement, 1-2 per layer)
    for i = 1, math.random(1, 2) do
        RetroSystem.CreateBoombox(layerFolder, Vector3.new(
            math.random(-150, 150),
            math.random(heightMin + 10, heightMax - 20),
            math.random(-150, 150)
        ))
    end

    -- Arcade cabinet (one per layer, Layers 2+)
    if layerIndex >= 2 then
        RetroSystem.CreateArcadeCabinet(layerFolder, Vector3.new(
            math.random(-120, 120),
            heightMin + math.random(15, 40),
            math.random(-120, 120)
        ))
    end
end

function RetroSystem.RemovePlayer(player: Player)
    playerDialState[player.UserId] = nil
end

return RetroSystem
