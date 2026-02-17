--[[
    UIManager.lua — Main UI framework for The Cloud Climb
    Manages ScreenGui, notifications, progress display, community board
    Visual identity: #0a0a0f background, #00d4ff accent (Angel Cloud branding)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIManager = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Color palette (matches angel-cloud/static/style.css)
local COLORS = {
    bg = Color3.fromRGB(10, 10, 15),        -- #0a0a0f
    bgLight = Color3.fromRGB(20, 20, 30),
    accent = Color3.fromRGB(0, 212, 255),    -- #00d4ff
    gold = Color3.fromRGB(255, 215, 0),
    white = Color3.fromRGB(255, 255, 255),
    dimWhite = Color3.fromRGB(180, 180, 200),
    green = Color3.fromRGB(100, 255, 150),
    red = Color3.fromRGB(255, 100, 100),
    purple = Color3.fromRGB(120, 50, 180),
}

local screenGui: ScreenGui
local notificationFrame: Frame
local progressFrame: Frame
local messageQueue = {}

function UIManager.Init()
    -- Main ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AngelCloudUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- HUD container (top-left: level + motes)
    UIManager.CreateHUD()

    -- Notification area (top-right)
    UIManager.CreateNotificationArea()

    -- Listen for progress updates
    local PlayerProgress = ReplicatedStorage:WaitForChild("PlayerProgress")
    PlayerProgress.OnClientEvent:Connect(UIManager.OnProgressUpdate)

    -- Mote collection — floating text instead of notification spam
    local MoteAwarded = ReplicatedStorage:WaitForChild("MoteAwarded")
    MoteAwarded.OnClientEvent:Connect(function(data)
        if data.amount > 0 then
            UIManager.ShowFloatingMoteText("+" .. data.amount)
        end
    end)

    -- Blessing notifications
    local BlessingReceived = ReplicatedStorage:WaitForChild("BlessingReceived")
    BlessingReceived.OnClientEvent:Connect(function(data)
        UIManager.ShowNotification(data.message, COLORS.gold, 4)
    end)

    -- Chain bonus notifications
    local BlessingChain = ReplicatedStorage:WaitForChild("BlessingChain")
    BlessingChain.OnClientEvent:Connect(function(data)
        UIManager.ShowNotification(data.message .. " (Chain: " .. data.chainLength .. ")", COLORS.green, 3)
    end)

    -- Layer unlock notifications (other players ascending)
    local LayerUnlocked = ReplicatedStorage:WaitForChild("LayerUnlocked")
    LayerUnlocked.OnClientEvent:Connect(function(data)
        UIManager.ShowNotification(data.message, COLORS.accent, 5)
    end)

    -- HALT notification
    local HALTNotify = ReplicatedStorage:WaitForChild("HALTNotify")
    HALTNotify.OnClientEvent:Connect(function(data)
        UIManager.ShowHALTNotification(data)
    end)
end

function UIManager.CreateHUD()
    progressFrame = Instance.new("Frame")
    progressFrame.Name = "HUD"
    progressFrame.Size = UDim2.new(0, 280, 0, 100)
    progressFrame.Position = UDim2.new(0, 15, 0, 15)
    progressFrame.BackgroundColor3 = COLORS.bg
    progressFrame.BackgroundTransparency = 0.3
    progressFrame.BorderSizePixel = 0
    progressFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = progressFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.accent
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = progressFrame

    -- Angel Level label
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel"
    levelLabel.Size = UDim2.new(1, -20, 0, 25)
    levelLabel.Position = UDim2.new(0, 10, 0, 8)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "Newborn"
    levelLabel.TextColor3 = COLORS.accent
    levelLabel.TextSize = 18
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.TextXAlignment = Enum.TextXAlignment.Left
    levelLabel.Parent = progressFrame

    -- Mote count
    local moteLabel = Instance.new("TextLabel")
    moteLabel.Name = "MoteLabel"
    moteLabel.Size = UDim2.new(1, -20, 0, 20)
    moteLabel.Position = UDim2.new(0, 10, 0, 35)
    moteLabel.BackgroundTransparency = 1
    moteLabel.Text = "0 Light Motes"
    moteLabel.TextColor3 = COLORS.dimWhite
    moteLabel.TextSize = 14
    moteLabel.Font = Enum.Font.Gotham
    moteLabel.TextXAlignment = Enum.TextXAlignment.Left
    moteLabel.Parent = progressFrame

    -- Progress bar
    local barBg = Instance.new("Frame")
    barBg.Name = "ProgressBarBg"
    barBg.Size = UDim2.new(1, -20, 0, 8)
    barBg.Position = UDim2.new(0, 10, 0, 60)
    barBg.BackgroundColor3 = COLORS.bgLight
    barBg.BorderSizePixel = 0
    barBg.Parent = progressFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name = "ProgressBarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = COLORS.accent
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = barFill

    -- Next threshold label
    local thresholdLabel = Instance.new("TextLabel")
    thresholdLabel.Name = "ThresholdLabel"
    thresholdLabel.Size = UDim2.new(1, -20, 0, 16)
    thresholdLabel.Position = UDim2.new(0, 10, 0, 74)
    thresholdLabel.BackgroundTransparency = 1
    thresholdLabel.Text = "Next: 10 Motes"
    thresholdLabel.TextColor3 = COLORS.dimWhite
    thresholdLabel.TextSize = 11
    thresholdLabel.Font = Enum.Font.Gotham
    thresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
    thresholdLabel.Parent = progressFrame

    -- Fragment count (right side)
    local fragLabel = Instance.new("TextLabel")
    fragLabel.Name = "FragmentLabel"
    fragLabel.Size = UDim2.new(0, 80, 0, 16)
    fragLabel.Position = UDim2.new(1, -90, 0, 74)
    fragLabel.BackgroundTransparency = 1
    fragLabel.Text = "0/65 Lore"
    fragLabel.TextColor3 = COLORS.gold
    fragLabel.TextSize = 11
    fragLabel.Font = Enum.Font.Gotham
    fragLabel.TextXAlignment = Enum.TextXAlignment.Right
    fragLabel.Parent = progressFrame
end

function UIManager.CreateNotificationArea()
    notificationFrame = Instance.new("Frame")
    notificationFrame.Name = "Notifications"
    notificationFrame.Size = UDim2.new(0, 350, 1, -30)
    notificationFrame.Position = UDim2.new(1, -365, 0, 15)
    notificationFrame.BackgroundTransparency = 1
    notificationFrame.Parent = screenGui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = notificationFrame
end

local MAX_NOTIFICATIONS = 5

function UIManager.ShowNotification(text: string, color: Color3?, duration: number?)
    color = color or COLORS.white
    duration = duration or 3

    -- Enforce max notification stack — remove oldest if at limit
    if notificationFrame then
        local children = {}
        for _, child in ipairs(notificationFrame:GetChildren()) do
            if child:IsA("Frame") then
                table.insert(children, child)
            end
        end
        while #children >= MAX_NOTIFICATIONS do
            children[1]:Destroy()
            table.remove(children, 1)
        end
    end

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 35)
    notif.BackgroundColor3 = COLORS.bg
    notif.BackgroundTransparency = 0.2
    notif.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notif

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = notif

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 14
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = notif

    notif.Parent = notificationFrame

    -- Slide in
    notif.Position = UDim2.new(1, 0, 0, 0)
    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()

    -- Fade out and remove
    task.delay(duration, function()
        local fadeOut = TweenService:Create(notif, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
        })
        TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            notif:Destroy()
        end)
    end)
end

function UIManager.ShowMessage(data: { [string]: any })
    if data.type == "welcome" then
        UIManager.ShowNotification(data.message, COLORS.accent, 6)
        -- Show tutorial overlay for first-time players
        UIManager.ShowTutorial()
    elseif data.type == "info" then
        UIManager.ShowNotification(data.message or "", COLORS.accent, 4)
    elseif data.type == "starfish" then
        UIManager.ShowNotification(data.message or "", COLORS.gold, 4)
    else
        UIManager.ShowNotification(data.message or "", COLORS.white, 3)
    end
end

function UIManager.ShowTutorial()
    -- Full-screen tutorial overlay that fades in and auto-dismisses
    local tutorialFrame = Instance.new("Frame")
    tutorialFrame.Name = "TutorialOverlay"
    tutorialFrame.Size = UDim2.new(1, 0, 1, 0)
    tutorialFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    tutorialFrame.BackgroundTransparency = 0.5
    tutorialFrame.BorderSizePixel = 0
    tutorialFrame.ZIndex = 10
    tutorialFrame.Parent = screenGui

    -- Center card
    local card = Instance.new("Frame")
    card.Name = "TutorialCard"
    card.Size = UDim2.new(0, 500, 0, 320)
    card.Position = UDim2.new(0.5, -250, 0.5, -160)
    card.BackgroundColor3 = COLORS.bg
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.ZIndex = 11
    card.Parent = tutorialFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 14)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = COLORS.accent
    cardStroke.Thickness = 2
    cardStroke.Parent = card

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 40)
    title.Position = UDim2.new(0, 15, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "THE CLOUD CLIMB"
    title.TextColor3 = COLORS.accent
    title.TextSize = 28
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 12
    title.Parent = card

    -- Instructions
    local instructions = {
        { icon = "F",   text = "Press F to FLY! (or double-tap Space)" },
        { icon = "^^",  text = "While flying: WASD move, SPACE = up, SHIFT = down" },
        { icon = ">>",  text = "COLLECT glowing Light Motes to level up" },
        { icon = "!!",  text = "Visit the WING FORGE to upgrade your wings" },
        { icon = "ZZ",  text = "Hit GREEN PADS for speed, CYAN for updrafts" },
        { icon = "10",  text = "Get 10 Motes to unlock THE MEADOW (Layer 2)" },
    }

    for i, instr in ipairs(instructions) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -40, 0, 30)
        row.Position = UDim2.new(0, 20, 0, 55 + (i - 1) * 35)
        row.BackgroundTransparency = 1
        row.ZIndex = 12
        row.Parent = card

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 30, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Text = instr.icon
        icon.TextColor3 = COLORS.accent
        icon.TextSize = 16
        icon.Font = Enum.Font.Code
        icon.ZIndex = 12
        icon.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -40, 1, 0)
        label.Position = UDim2.new(0, 35, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = instr.text
        label.TextColor3 = COLORS.white
        label.TextSize = 16
        label.Font = Enum.Font.GothamMedium
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 12
        label.Parent = row
    end

    -- Motto at bottom
    local motto = Instance.new("TextLabel")
    motto.Size = UDim2.new(1, -30, 0, 20)
    motto.Position = UDim2.new(0, 15, 1, -55)
    motto.BackgroundTransparency = 1
    motto.Text = "Every Angel strengthens the cloud."
    motto.TextColor3 = COLORS.gold
    motto.TextSize = 14
    motto.Font = Enum.Font.GothamMedium
    motto.ZIndex = 12
    motto.Parent = card

    -- Dismiss button
    local dismissBtn = Instance.new("TextButton")
    dismissBtn.Size = UDim2.new(0, 160, 0, 36)
    dismissBtn.Position = UDim2.new(0.5, -80, 1, -45)
    dismissBtn.BackgroundColor3 = COLORS.accent
    dismissBtn.BorderSizePixel = 0
    dismissBtn.Text = "BEGIN CLIMBING"
    dismissBtn.TextColor3 = COLORS.bg
    dismissBtn.TextSize = 16
    dismissBtn.Font = Enum.Font.GothamBold
    dismissBtn.ZIndex = 12
    dismissBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = dismissBtn

    -- Click or auto-dismiss
    local function dismiss()
        if tutorialFrame and tutorialFrame.Parent then
            TweenService:Create(tutorialFrame, TweenInfo.new(0.5), {
                BackgroundTransparency = 1,
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.5), {
                BackgroundTransparency = 1,
            }):Play()
            for _, desc in ipairs(card:GetDescendants()) do
                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                    TweenService:Create(desc, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
                end
                if desc:IsA("UIStroke") then
                    TweenService:Create(desc, TweenInfo.new(0.5), { Transparency = 1 }):Play()
                end
            end
            task.delay(0.6, function()
                if tutorialFrame and tutorialFrame.Parent then
                    tutorialFrame:Destroy()
                end
            end)
        end
    end

    dismissBtn.MouseButton1Click:Connect(dismiss)
    -- Auto-dismiss after 15 seconds
    task.delay(15, dismiss)
end

function UIManager.ShowHALTNotification(data: { [string]: any })
    -- Special persistent notification for HALT
    local haltFrame = Instance.new("Frame")
    haltFrame.Name = "HALTNotification"
    haltFrame.Size = UDim2.new(0, 400, 0, 80)
    haltFrame.Position = UDim2.new(0.5, -200, 0.3, 0)
    haltFrame.BackgroundColor3 = COLORS.bg
    haltFrame.BackgroundTransparency = 0.1
    haltFrame.BorderSizePixel = 0
    haltFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = haltFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.gold
    stroke.Thickness = 2
    stroke.Parent = haltFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -10)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = data.message
    label.TextColor3 = COLORS.gold
    label.TextSize = 14
    label.Font = Enum.Font.GothamMedium
    label.TextWrapped = true
    label.Parent = haltFrame

    -- Auto-dismiss after 15 seconds
    task.delay(15, function()
        if haltFrame and haltFrame.Parent then
            haltFrame:Destroy()
        end
    end)
end

function UIManager.OnProgressUpdate(data: { [string]: any })
    if not progressFrame then
        return
    end

    local levelLabel = progressFrame:FindFirstChild("LevelLabel")
    if levelLabel then
        levelLabel.Text = data.level or "Newborn"
    end

    local moteLabel = progressFrame:FindFirstChild("MoteLabel")
    if moteLabel then
        moteLabel.Text = (data.motes or 0) .. " Light Motes"
    end

    local barBg = progressFrame:FindFirstChild("ProgressBarBg")
    if barBg then
        local barFill = barBg:FindFirstChild("ProgressBarFill")
        if barFill then
            local progress = (data.progress or 0) / 100
            TweenService:Create(barFill, TweenInfo.new(0.5), {
                Size = UDim2.new(progress, 0, 1, 0),
            }):Play()
        end
    end

    local thresholdLabel = progressFrame:FindFirstChild("ThresholdLabel")
    if thresholdLabel then
        if data.nextThreshold then
            thresholdLabel.Text = "Next: " .. data.nextThreshold .. " Motes"
        else
            thresholdLabel.Text = "Maximum Angel Level"
        end
    end

    local fragLabel = progressFrame:FindFirstChild("FragmentLabel")
    if fragLabel and data.fragmentCount then
        fragLabel.Text = data.fragmentCount .. "/65 Lore"
    end
end

-- Floating "+X" text that rises from HUD mote label and fades out
function UIManager.ShowFloatingMoteText(text: string)
    if not screenGui then return end

    local moteLabel = progressFrame and progressFrame:FindFirstChild("MoteLabel")
    local startPos = moteLabel and moteLabel.AbsolutePosition or Vector2.new(80, 50)

    local floater = Instance.new("TextLabel")
    floater.Name = "MoteFloat"
    floater.Size = UDim2.new(0, 100, 0, 30)
    floater.Position = UDim2.new(0, startPos.X + 10, 0, startPos.Y)
    floater.BackgroundTransparency = 1
    floater.Text = text
    floater.TextColor3 = COLORS.accent
    floater.TextSize = 22
    floater.Font = Enum.Font.GothamBold
    floater.TextStrokeTransparency = 0.5
    floater.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    floater.ZIndex = 20
    floater.Parent = screenGui

    -- Float upward and fade
    TweenService:Create(floater, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, startPos.X + 10, 0, startPos.Y - 60),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()

    task.delay(1.3, function()
        if floater and floater.Parent then
            floater:Destroy()
        end
    end)
end

function UIManager.GetScreenGui(): ScreenGui
    return screenGui
end

function UIManager.GetColors()
    return COLORS
end

return UIManager
