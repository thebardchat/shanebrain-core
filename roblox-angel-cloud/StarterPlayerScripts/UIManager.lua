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

    -- Mote collection notifications
    local MoteAwarded = ReplicatedStorage:WaitForChild("MoteAwarded")
    MoteAwarded.OnClientEvent:Connect(function(data)
        if data.amount > 0 then
            UIManager.ShowNotification("+" .. data.amount .. " Light Mote", COLORS.accent, 2)
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

function UIManager.ShowNotification(text: string, color: Color3?, duration: number?)
    color = color or COLORS.white
    duration = duration or 3

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
        UIManager.ShowNotification(data.message, COLORS.accent, 5)
    else
        UIManager.ShowNotification(data.message or "", COLORS.white, 3)
    end
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

function UIManager.GetScreenGui(): ScreenGui
    return screenGui
end

function UIManager.GetColors()
    return COLORS
end

return UIManager
