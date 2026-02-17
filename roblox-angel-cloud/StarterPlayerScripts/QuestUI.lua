--[[
    QuestUI.lua — Shows current quest objective on screen
    Persistent tracker in top-right, completion popup with rewards
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local QuestUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
    bg = Color3.fromRGB(10, 10, 20),
    accent = Color3.fromRGB(0, 212, 255),
    gold = Color3.fromRGB(255, 215, 0),
    white = Color3.fromRGB(255, 255, 255),
    green = Color3.fromRGB(100, 255, 150),
    dimWhite = Color3.fromRGB(150, 150, 170),
}

local screenGui
local questFrame
local titleLabel
local descLabel
local progressLabel
local progressBar
local progressFill
local completionFrame

function QuestUI.Init()
    local QuestUpdate = ReplicatedStorage:WaitForChild("QuestUpdate", 30)
    if not QuestUpdate then
        warn("[QuestUI] QuestUpdate RemoteEvent not found")
        return
    end

    -- Create the quest tracker UI
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "QuestTrackerUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    -- Quest tracker frame (top-right)
    questFrame = Instance.new("Frame")
    questFrame.Name = "QuestTracker"
    questFrame.Size = UDim2.new(0, 280, 0, 90)
    questFrame.Position = UDim2.new(1, -295, 0, 15)
    questFrame.BackgroundColor3 = COLORS.bg
    questFrame.BackgroundTransparency = 0.3
    questFrame.BorderSizePixel = 0
    questFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = questFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.accent
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = questFrame

    -- Quest icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 24, 0, 24)
    icon.Position = UDim2.new(0, 10, 0, 8)
    icon.BackgroundTransparency = 1
    icon.Text = ">"
    icon.TextColor3 = COLORS.gold
    icon.TextSize = 18
    icon.Font = Enum.Font.GothamBold
    icon.Parent = questFrame

    -- Quest title
    titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -45, 0, 22)
    titleLabel.Position = UDim2.new(0, 35, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Loading quest..."
    titleLabel.TextColor3 = COLORS.gold
    titleLabel.TextSize = 15
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = questFrame

    -- Quest description
    descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -20, 0, 20)
    descLabel.Position = UDim2.new(0, 10, 0, 30)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = ""
    descLabel.TextColor3 = COLORS.dimWhite
    descLabel.TextSize = 12
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.Parent = questFrame

    -- Progress text
    progressLabel = Instance.new("TextLabel")
    progressLabel.Size = UDim2.new(1, -20, 0, 16)
    progressLabel.Position = UDim2.new(0, 10, 0, 52)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Text = "0 / 5"
    progressLabel.TextColor3 = COLORS.accent
    progressLabel.TextSize = 13
    progressLabel.Font = Enum.Font.GothamBold
    progressLabel.TextXAlignment = Enum.TextXAlignment.Left
    progressLabel.Parent = questFrame

    -- Progress bar background
    progressBar = Instance.new("Frame")
    progressBar.Size = UDim2.new(1, -20, 0, 6)
    progressBar.Position = UDim2.new(0, 10, 0, 72)
    progressBar.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = questFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 3)
    barCorner.Parent = progressBar

    -- Progress bar fill
    progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = COLORS.accent
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = progressFill

    -- Completion popup (hidden by default)
    QuestUI.CreateCompletionPopup()

    -- Listen for quest updates
    QuestUpdate.OnClientEvent:Connect(QuestUI.OnQuestUpdate)

    print("[QuestUI] Quest tracker initialized")
end

function QuestUI.CreateCompletionPopup()
    completionFrame = Instance.new("Frame")
    completionFrame.Name = "QuestComplete"
    completionFrame.Size = UDim2.new(0, 320, 0, 120)
    completionFrame.Position = UDim2.new(0.5, -160, 0.3, 0)
    completionFrame.BackgroundColor3 = COLORS.bg
    completionFrame.BackgroundTransparency = 0.15
    completionFrame.BorderSizePixel = 0
    completionFrame.Visible = false
    completionFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = completionFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.gold
    stroke.Thickness = 2
    stroke.Parent = completionFrame

    local completeTitle = Instance.new("TextLabel")
    completeTitle.Name = "Title"
    completeTitle.Size = UDim2.new(1, 0, 0, 30)
    completeTitle.Position = UDim2.new(0, 0, 0, 15)
    completeTitle.BackgroundTransparency = 1
    completeTitle.Text = "QUEST COMPLETE!"
    completeTitle.TextColor3 = COLORS.gold
    completeTitle.TextSize = 22
    completeTitle.Font = Enum.Font.GothamBold
    completeTitle.Parent = completionFrame

    local questName = Instance.new("TextLabel")
    questName.Name = "QuestName"
    questName.Size = UDim2.new(1, 0, 0, 22)
    questName.Position = UDim2.new(0, 0, 0, 48)
    questName.BackgroundTransparency = 1
    questName.Text = ""
    questName.TextColor3 = COLORS.white
    questName.TextSize = 16
    questName.Font = Enum.Font.GothamMedium
    questName.Parent = completionFrame

    local rewardText = Instance.new("TextLabel")
    rewardText.Name = "Reward"
    rewardText.Size = UDim2.new(1, 0, 0, 22)
    rewardText.Position = UDim2.new(0, 0, 0, 75)
    rewardText.BackgroundTransparency = 1
    rewardText.Text = ""
    rewardText.TextColor3 = COLORS.green
    rewardText.TextSize = 16
    rewardText.Font = Enum.Font.GothamBold
    rewardText.Parent = completionFrame
end

function QuestUI.OnQuestUpdate(data)
    if data.status == "active" then
        questFrame.Visible = true
        titleLabel.Text = data.title
        descLabel.Text = data.description

        local progress = math.min(data.progress, data.target)
        progressLabel.Text = progress .. " / " .. data.target

        -- Animate progress bar
        local fillPercent = math.clamp(progress / data.target, 0, 1)
        TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(fillPercent, 0, 1, 0),
        }):Play()

        -- Color changes near completion
        if fillPercent >= 0.8 then
            progressLabel.TextColor3 = COLORS.green
            progressFill.BackgroundColor3 = COLORS.green
        else
            progressLabel.TextColor3 = COLORS.accent
            progressFill.BackgroundColor3 = COLORS.accent
        end

    elseif data.status == "completed" then
        -- Show completion popup
        QuestUI.ShowCompletion(data)

    elseif data.status == "all_complete" then
        questFrame.Visible = true
        titleLabel.Text = "All Quests Complete!"
        descLabel.Text = "You've mastered The Cloud Climb."
        progressLabel.Text = ""
        progressFill.Size = UDim2.new(1, 0, 1, 0)
        progressFill.BackgroundColor3 = COLORS.gold
    end
end

function QuestUI.ShowCompletion(data)
    completionFrame.Visible = true

    local questName = completionFrame:FindFirstChild("QuestName")
    if questName then
        questName.Text = data.title
    end

    local rewardText = completionFrame:FindFirstChild("Reward")
    if rewardText and data.reward then
        local parts = {}
        if data.reward.motes then
            table.insert(parts, "+" .. data.reward.motes .. " Motes")
        end
        rewardText.Text = table.concat(parts, "  ")
    end

    -- Animate in
    completionFrame.Position = UDim2.new(0.5, -160, 0.25, 0)
    completionFrame.BackgroundTransparency = 1
    TweenService:Create(completionFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -160, 0.3, 0),
        BackgroundTransparency = 0.15,
    }):Play()

    -- Auto-hide after 3 seconds
    task.delay(3, function()
        TweenService:Create(completionFrame, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -160, 0.25, 0),
        }):Play()
        task.delay(0.5, function()
            completionFrame.Visible = false
        end)
    end)
end

return QuestUI
