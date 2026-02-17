--[[
    LoreCodexUI.lua — Constellation map codex for Lore Fragments
    Press C to toggle. Each fragment is a star; connected stars form Angel's silhouette.
    Collected fragments show narrative passage + wisdom principle.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoreCodexUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local codexFrame: Frame
local isOpen = false
local cachedCodex = nil

local COLORS = {
    bg = Color3.fromRGB(5, 5, 12),
    accent = Color3.fromRGB(0, 212, 255),
    gold = Color3.fromRGB(255, 215, 0),
    white = Color3.fromRGB(255, 255, 255),
    dim = Color3.fromRGB(80, 80, 100),
    uncollected = Color3.fromRGB(40, 40, 55),
    categoryColors = {
        Decision = Color3.fromRGB(255, 215, 0),
        Emotion = Color3.fromRGB(0, 212, 255),
        Relationship = Color3.fromRGB(255, 150, 200),
        Strength = Color3.fromRGB(255, 100, 50),
        Suffering = Color3.fromRGB(120, 50, 180),
        Guardian = Color3.fromRGB(100, 255, 100),
        Angel = Color3.fromRGB(255, 255, 255),
    },
}

function LoreCodexUI.Init()
    local screenGui = playerGui:WaitForChild("AngelCloudUI")

    -- Main codex frame (full screen overlay)
    codexFrame = Instance.new("Frame")
    codexFrame.Name = "LoreCodex"
    codexFrame.Size = UDim2.new(1, 0, 1, 0)
    codexFrame.Position = UDim2.new(0, 0, 0, 0)
    codexFrame.BackgroundColor3 = COLORS.bg
    codexFrame.BackgroundTransparency = 0.05
    codexFrame.Visible = false
    codexFrame.ZIndex = 10
    codexFrame.Parent = screenGui

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "THE LORE OF ANGEL"
    title.TextColor3 = COLORS.gold
    title.TextSize = 28
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 11
    title.Parent = codexFrame

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 25)
    subtitle.Position = UDim2.new(0, 0, 0, 55)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Each star is a fragment of Angel's scattered light"
    subtitle.TextColor3 = COLORS.dim
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.ZIndex = 11
    subtitle.Parent = codexFrame

    -- Progress counter
    local progress = Instance.new("TextLabel")
    progress.Name = "ProgressCount"
    progress.Size = UDim2.new(0, 200, 0, 25)
    progress.Position = UDim2.new(1, -215, 0, 15)
    progress.BackgroundTransparency = 1
    progress.Text = "0 / 65 Fragments"
    progress.TextColor3 = COLORS.accent
    progress.TextSize = 16
    progress.Font = Enum.Font.GothamBold
    progress.TextXAlignment = Enum.TextXAlignment.Right
    progress.ZIndex = 11
    progress.Parent = codexFrame

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -55, 0, 10)
    closeBtn.BackgroundColor3 = COLORS.bg
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.white
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 12
    closeBtn.Parent = codexFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        LoreCodexUI.Toggle()
    end)

    -- Category tabs (left sidebar)
    local sidebar = Instance.new("Frame")
    sidebar.Name = "CategorySidebar"
    sidebar.Size = UDim2.new(0, 160, 1, -100)
    sidebar.Position = UDim2.new(0, 15, 0, 90)
    sidebar.BackgroundTransparency = 1
    sidebar.ZIndex = 11
    sidebar.Parent = codexFrame

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 5)
    sidebarLayout.Parent = sidebar

    local categories = { "Decision", "Emotion", "Relationship", "Strength", "Suffering", "Guardian", "Angel" }
    for i, cat in ipairs(categories) do
        local tab = Instance.new("TextButton")
        tab.Name = "Tab_" .. cat
        tab.Size = UDim2.new(1, 0, 0, 35)
        tab.BackgroundColor3 = COLORS.uncollected
        tab.BackgroundTransparency = 0.3
        tab.Text = "  " .. cat
        tab.TextColor3 = COLORS.categoryColors[cat] or COLORS.white
        tab.TextSize = 14
        tab.Font = Enum.Font.GothamMedium
        tab.TextXAlignment = Enum.TextXAlignment.Left
        tab.LayoutOrder = i
        tab.ZIndex = 12
        tab.Parent = sidebar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tab

        tab.MouseButton1Click:Connect(function()
            LoreCodexUI.ShowCategory(cat)
        end)
    end

    -- Fragment detail area (right side)
    local detailArea = Instance.new("ScrollingFrame")
    detailArea.Name = "DetailArea"
    detailArea.Size = UDim2.new(1, -200, 1, -100)
    detailArea.Position = UDim2.new(0, 190, 0, 90)
    detailArea.BackgroundTransparency = 1
    detailArea.ScrollBarThickness = 4
    detailArea.ScrollBarImageColor3 = COLORS.accent
    detailArea.ZIndex = 11
    detailArea.Parent = codexFrame

    local detailLayout = Instance.new("UIListLayout")
    detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
    detailLayout.Padding = UDim.new(0, 10)
    detailLayout.Parent = detailArea

    -- Listen for codex data
    local CodexData = ReplicatedStorage:WaitForChild("CodexData")
    CodexData.OnClientEvent:Connect(function(data)
        cachedCodex = data
        if isOpen then
            LoreCodexUI.Refresh()
        end
    end)

    -- Fragment collection notification
    local FragmentCollected = ReplicatedStorage:WaitForChild("FragmentCollected")
    FragmentCollected.OnClientEvent:Connect(function(data)
        LoreCodexUI.ShowFragmentPopup(data)
    end)
end

function LoreCodexUI.Toggle()
    isOpen = not isOpen
    codexFrame.Visible = isOpen

    if isOpen then
        -- Request fresh data from server
        local CodexRequest = ReplicatedStorage:FindFirstChild("CodexRequest")
        if CodexRequest then
            CodexRequest:FireServer()
        end
    end
end

function LoreCodexUI.Refresh()
    if not cachedCodex then
        return
    end

    -- Update progress counter
    local progressLabel = codexFrame:FindFirstChild("ProgressCount")
    if progressLabel then
        progressLabel.Text = cachedCodex.totalCollected .. " / " .. cachedCodex.totalFragments .. " Fragments"
    end

    -- Update category tab counts
    local sidebar = codexFrame:FindFirstChild("CategorySidebar")
    if sidebar and cachedCodex.categoryProgress then
        for cat, progress in pairs(cachedCodex.categoryProgress) do
            local tab = sidebar:FindFirstChild("Tab_" .. cat)
            if tab then
                tab.Text = "  " .. cat .. " (" .. progress.collected .. "/" .. progress.total .. ")"
            end
        end
    end

    -- Show first category by default
    LoreCodexUI.ShowCategory("Decision")
end

function LoreCodexUI.ShowCategory(category: string)
    local detailArea = codexFrame:FindFirstChild("DetailArea")
    if not detailArea or not cachedCodex then
        return
    end

    -- Clear existing
    for _, child in ipairs(detailArea:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Filter fragments by category
    local order = 0
    for _, frag in ipairs(cachedCodex.codex) do
        if frag.category == category then
            order = order + 1
            LoreCodexUI.CreateFragmentCard(detailArea, frag, order)
        end
    end

    -- Update canvas size
    local layout = detailArea:FindFirstChild("UIListLayout")
    if layout then
        detailArea.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end
end

function LoreCodexUI.CreateFragmentCard(parent: ScrollingFrame, frag: { [string]: any }, order: number)
    local card = Instance.new("Frame")
    card.Name = "Fragment_" .. frag.id
    card.Size = UDim2.new(1, -20, 0, frag.collected and 120 or 50)
    card.BackgroundColor3 = frag.collected and Color3.fromRGB(15, 15, 25) or COLORS.uncollected
    card.BackgroundTransparency = 0.2
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 12
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local catColor = COLORS.categoryColors[frag.category] or COLORS.white

    if frag.collected then
        local stroke = Instance.new("UIStroke")
        stroke.Color = catColor
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = card
    end

    -- Star indicator
    local star = Instance.new("TextLabel")
    star.Size = UDim2.new(0, 25, 0, 25)
    star.Position = UDim2.new(0, 10, 0, 10)
    star.BackgroundTransparency = 1
    star.Text = frag.collected and "*" or "."
    star.TextColor3 = frag.collected and catColor or COLORS.dim
    star.TextSize = frag.collected and 24 or 16
    star.Font = Enum.Font.GothamBold
    star.ZIndex = 13
    star.Parent = card

    -- Name
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -50, 0, 25)
    name.Position = UDim2.new(0, 40, 0, 10)
    name.BackgroundTransparency = 1
    name.Text = frag.collected and frag.name or "???"
    name.TextColor3 = frag.collected and COLORS.white or COLORS.dim
    name.TextSize = 15
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 13
    name.Parent = card

    if frag.collected and frag.wisdom then
        -- Wisdom text
        local wisdom = Instance.new("TextLabel")
        wisdom.Size = UDim2.new(1, -50, 0, 35)
        wisdom.Position = UDim2.new(0, 40, 0, 38)
        wisdom.BackgroundTransparency = 1
        wisdom.Text = frag.wisdom
        wisdom.TextColor3 = catColor
        wisdom.TextSize = 12
        wisdom.Font = Enum.Font.GothamMedium
        wisdom.TextWrapped = true
        wisdom.TextXAlignment = Enum.TextXAlignment.Left
        wisdom.ZIndex = 13
        wisdom.Parent = card

        -- Lore text
        if frag.loreText then
            local lore = Instance.new("TextLabel")
            lore.Size = UDim2.new(1, -50, 0, 35)
            lore.Position = UDim2.new(0, 40, 0, 78)
            lore.BackgroundTransparency = 1
            lore.Text = '"' .. frag.loreText .. '"'
            lore.TextColor3 = COLORS.dim
            lore.TextSize = 11
            lore.Font = Enum.Font.GothamMedium
            lore.TextWrapped = true
            lore.TextXAlignment = Enum.TextXAlignment.Left
            lore.ZIndex = 13
            lore.Parent = card
        end
    end
end

function LoreCodexUI.ShowFragmentPopup(data: { [string]: any })
    local screenGui = playerGui:FindFirstChild("AngelCloudUI")
    if not screenGui then
        return
    end

    local catColor = COLORS.categoryColors[data.category] or COLORS.gold

    local popup = Instance.new("Frame")
    popup.Name = "FragmentPopup"
    popup.Size = UDim2.new(0, 450, 0, 200)
    popup.Position = UDim2.new(0.5, -225, 0.5, -100)
    popup.BackgroundColor3 = COLORS.bg
    popup.BackgroundTransparency = 0.05
    popup.ZIndex = 20
    popup.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = popup

    local stroke = Instance.new("UIStroke")
    stroke.Color = catColor
    stroke.Thickness = 2
    stroke.Parent = popup

    -- Category label
    local catLabel = Instance.new("TextLabel")
    catLabel.Size = UDim2.new(1, 0, 0, 20)
    catLabel.Position = UDim2.new(0, 0, 0, 12)
    catLabel.BackgroundTransparency = 1
    catLabel.Text = data.category .. " Fragment"
    catLabel.TextColor3 = catColor
    catLabel.TextSize = 12
    catLabel.Font = Enum.Font.GothamMedium
    catLabel.ZIndex = 21
    catLabel.Parent = popup

    -- Fragment name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -30, 0, 30)
    nameLabel.Position = UDim2.new(0, 15, 0, 35)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = data.name
    nameLabel.TextColor3 = COLORS.white
    nameLabel.TextSize = 22
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 21
    nameLabel.Parent = popup

    -- Wisdom
    local wisdomLabel = Instance.new("TextLabel")
    wisdomLabel.Size = UDim2.new(1, -30, 0, 50)
    wisdomLabel.Position = UDim2.new(0, 15, 0, 70)
    wisdomLabel.BackgroundTransparency = 1
    wisdomLabel.Text = data.wisdom or ""
    wisdomLabel.TextColor3 = catColor
    wisdomLabel.TextSize = 13
    wisdomLabel.Font = Enum.Font.GothamMedium
    wisdomLabel.TextWrapped = true
    wisdomLabel.TextXAlignment = Enum.TextXAlignment.Left
    wisdomLabel.ZIndex = 21
    wisdomLabel.Parent = popup

    -- Lore
    local loreLabel = Instance.new("TextLabel")
    loreLabel.Size = UDim2.new(1, -30, 0, 40)
    loreLabel.Position = UDim2.new(0, 15, 0, 125)
    loreLabel.BackgroundTransparency = 1
    loreLabel.Text = '"' .. (data.loreText or "") .. '"'
    loreLabel.TextColor3 = COLORS.dim
    loreLabel.TextSize = 12
    loreLabel.Font = Enum.Font.GothamMedium
    loreLabel.TextWrapped = true
    loreLabel.TextXAlignment = Enum.TextXAlignment.Left
    loreLabel.ZIndex = 21
    loreLabel.Parent = popup

    -- Progress
    local progLabel = Instance.new("TextLabel")
    progLabel.Size = UDim2.new(1, -30, 0, 20)
    progLabel.Position = UDim2.new(0, 15, 1, -25)
    progLabel.BackgroundTransparency = 1
    progLabel.Text = data.totalCollected .. " / " .. data.totalFragments .. " Fragments Collected"
    progLabel.TextColor3 = COLORS.accent
    progLabel.TextSize = 11
    progLabel.Font = Enum.Font.Gotham
    progLabel.TextXAlignment = Enum.TextXAlignment.Left
    progLabel.ZIndex = 21
    progLabel.Parent = popup

    -- Fade-in animation
    popup.BackgroundTransparency = 1
    stroke.Transparency = 1
    for _, child in ipairs(popup:GetChildren()) do
        if child:IsA("TextLabel") then
            child.TextTransparency = 1
        end
    end
    local fadeInInfo = TweenInfo.new(0.5)
    TweenService:Create(popup, fadeInInfo, { BackgroundTransparency = 0.05 }):Play()
    TweenService:Create(stroke, fadeInInfo, { Transparency = 0 }):Play()
    task.delay(0.2, function()
        for _, child in ipairs(popup:GetChildren()) do
            if child:IsA("TextLabel") then
                TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
            end
        end
    end)

    -- Auto-dismiss (fade all elements)
    task.delay(8, function()
        if popup and popup.Parent then
            local fadeInfo = TweenInfo.new(1)
            TweenService:Create(popup, fadeInfo, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
            for _, child in ipairs(popup:GetChildren()) do
                if child:IsA("TextLabel") then
                    TweenService:Create(child, fadeInfo, { TextTransparency = 1 }):Play()
                end
            end
            task.delay(1.2, function()
                popup:Destroy()
            end)
        end
    end)
end

return LoreCodexUI
