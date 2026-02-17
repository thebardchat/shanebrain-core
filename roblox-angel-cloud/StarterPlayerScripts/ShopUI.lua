--[[
    ShopUI.lua — Client-side cosmetic shop interface
    Tabbed catalog browser with category filters, purchase buttons,
    equip/unequip toggles, and preview cards
    Opens via proximity prompt or HUD button
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local ShopUI = {}

-- Color palette (matches angel-cloud CSS)
local COLORS = {
    bg = Color3.fromRGB(10, 10, 15),
    panel = Color3.fromRGB(20, 20, 30),
    card = Color3.fromRGB(30, 30, 45),
    cardHover = Color3.fromRGB(40, 40, 60),
    accent = Color3.fromRGB(0, 212, 255),
    gold = Color3.fromRGB(255, 215, 0),
    text = Color3.fromRGB(230, 230, 240),
    textDim = Color3.fromRGB(150, 150, 170),
    success = Color3.fromRGB(80, 200, 120),
    owned = Color3.fromRGB(60, 180, 100),
    robux = Color3.fromRGB(0, 180, 60),
}

local CATEGORY_LABELS = {
    WingSkins = "Wings",
    TrailEffects = "Trails",
    EmotePacks = "Emotes",
    CloudMaterials = "Cloud Materials",
    NameGlow = "Name Glow",
    StarterPack = "Starter Pack",
    Special = "Special",
}

local CATEGORY_ORDER = {
    "StarterPack", "WingSkins", "TrailEffects",
    "EmotePacks", "NameGlow", "CloudMaterials", "Special",
}

-- State
local shopGui = nil
local isOpen = false
local catalogData = {}
local equippedData = {}
local selectedCategory = "StarterPack"

-- RemoteEvents (resolved after Init)
local ShopData
local ShopRequest
local ShopResult

function ShopUI.Init()
    -- Wait for RemoteEvents
    ShopData = ReplicatedStorage:WaitForChild("ShopData", 15)
    ShopRequest = ReplicatedStorage:WaitForChild("ShopRequest", 15)
    ShopResult = ReplicatedStorage:WaitForChild("ShopResult", 15)

    if not ShopData or not ShopRequest then
        warn("[ShopUI] Shop RemoteEvents not found")
        return
    end

    -- Listen for catalog data from server
    ShopData.OnClientEvent:Connect(function(data)
        catalogData = data.catalog or {}
        equippedData = data.equipped or {}
        if isOpen then
            ShopUI.RefreshItems()
        end
    end)

    -- Listen for purchase/equip results
    if ShopResult then
        ShopResult.OnClientEvent:Connect(function(result)
            if result.equipped then
                equippedData = result.equipped
            end
            -- Update ownership in local catalog
            if result.success and result.itemId then
                for _, item in ipairs(catalogData) do
                    if item.id == result.itemId then
                        item.owned = true
                        break
                    end
                end
            end
            if isOpen then
                ShopUI.RefreshItems()
            end
        end)
    end

    -- Keybind: B to toggle shop
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.B then
            ShopUI.Toggle()
        end
    end)

    ShopUI.CreateUI()
    print("[ShopUI] Shop UI initialized (press B to open)")
end

function ShopUI.CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShopGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Enabled = false
    screenGui.Parent = player.PlayerGui
    shopGui = screenGui

    -- Main frame
    local main = Instance.new("Frame")
    main.Name = "ShopFrame"
    main.Size = UDim2.new(0.7, 0, 0.75, 0)
    main.Position = UDim2.new(0.15, 0, 0.125, 0)
    main.BackgroundColor3 = COLORS.bg
    main.BackgroundTransparency = 0.05
    main.BorderSizePixel = 0
    main.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.accent
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = main

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = COLORS.panel
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Angel Cloud Shop"
    titleLabel.TextColor3 = COLORS.accent
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        ShopUI.Close()
    end)

    -- Category tabs (left sidebar)
    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "CategorySidebar"
    sidebar.Size = UDim2.new(0.18, 0, 1, -55)
    sidebar.Position = UDim2.new(0, 5, 0, 52)
    sidebar.BackgroundColor3 = COLORS.panel
    sidebar.BackgroundTransparency = 0.3
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 3
    sidebar.ScrollBarImageColor3 = COLORS.accent
    sidebar.Parent = main

    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 8)
    sidebarCorner.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.Parent = sidebar

    for _, catId in ipairs(CATEGORY_ORDER) do
        local catBtn = Instance.new("TextButton")
        catBtn.Name = "Cat_" .. catId
        catBtn.Size = UDim2.new(1, -4, 0, 36)
        catBtn.BackgroundColor3 = catId == selectedCategory and COLORS.accent or COLORS.card
        catBtn.BackgroundTransparency = catId == selectedCategory and 0.3 or 0.5
        catBtn.Text = CATEGORY_LABELS[catId] or catId
        catBtn.TextColor3 = COLORS.text
        catBtn.TextScaled = true
        catBtn.Font = Enum.Font.GothamMedium
        catBtn.BorderSizePixel = 0
        catBtn.Parent = sidebar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = catBtn

        catBtn.MouseButton1Click:Connect(function()
            selectedCategory = catId
            ShopUI.RefreshCategoryButtons()
            ShopUI.RefreshItems()
        end)
    end

    -- Items grid (right area)
    local itemsArea = Instance.new("ScrollingFrame")
    itemsArea.Name = "ItemsArea"
    itemsArea.Size = UDim2.new(0.8, -10, 1, -55)
    itemsArea.Position = UDim2.new(0.19, 5, 0, 52)
    itemsArea.BackgroundTransparency = 1
    itemsArea.BorderSizePixel = 0
    itemsArea.ScrollBarThickness = 4
    itemsArea.ScrollBarImageColor3 = COLORS.accent
    itemsArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
    itemsArea.Parent = main

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 180, 0, 220)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = itemsArea

    local gridPadding = Instance.new("UIPadding")
    gridPadding.PaddingLeft = UDim.new(0, 8)
    gridPadding.PaddingTop = UDim.new(0, 8)
    gridPadding.Parent = itemsArea
end

function ShopUI.RefreshCategoryButtons()
    if not shopGui then return end
    local sidebar = shopGui.ShopFrame.CategorySidebar
    for _, catId in ipairs(CATEGORY_ORDER) do
        local btn = sidebar:FindFirstChild("Cat_" .. catId)
        if btn then
            btn.BackgroundColor3 = catId == selectedCategory and COLORS.accent or COLORS.card
            btn.BackgroundTransparency = catId == selectedCategory and 0.3 or 0.5
        end
    end
end

function ShopUI.RefreshItems()
    if not shopGui then return end
    local itemsArea = shopGui.ShopFrame.ItemsArea

    -- Clear existing cards (keep UIGridLayout and UIPadding)
    for _, child in ipairs(itemsArea:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Filter items by selected category
    local filteredItems = {}
    for _, item in ipairs(catalogData) do
        if item.category == selectedCategory then
            table.insert(filteredItems, item)
        end
    end

    -- Create cards
    for i, item in ipairs(filteredItems) do
        ShopUI.CreateItemCard(itemsArea, item, i)
    end
end

function ShopUI.CreateItemCard(parent: ScrollingFrame, item: any, order: number)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. item.id
    card.BackgroundColor3 = COLORS.card
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = COLORS.accent
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.8
    cardStroke.Parent = card

    -- Hover effects (brighten + scale feel via stroke)
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            card.BackgroundColor3 = COLORS.cardHover
            cardStroke.Transparency = 0.2
        end
    end)
    card.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            card.BackgroundColor3 = COLORS.card
            cardStroke.Transparency = 0.8
        end
    end)

    -- Color preview (top area)
    local preview = Instance.new("Frame")
    preview.Name = "Preview"
    preview.Size = UDim2.new(1, 0, 0, 70)
    preview.BackgroundColor3 = item.color
        and Color3.fromRGB(item.color[1], item.color[2], item.color[3])
        or COLORS.accent
    preview.BackgroundTransparency = 0.3
    preview.BorderSizePixel = 0
    preview.Parent = card

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 8)
    previewCorner.Parent = preview

    -- Item name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -8, 0, 24)
    nameLabel.Position = UDim2.new(0, 4, 0, 75)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name
    nameLabel.TextColor3 = COLORS.text
    nameLabel.TextScaled = true
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = card

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -8, 0, 40)
    descLabel.Position = UDim2.new(0, 4, 0, 100)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = item.description or ""
    descLabel.TextColor3 = COLORS.textDim
    descLabel.TextScaled = true
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.Font = Enum.Font.Gotham
    descLabel.Parent = card

    -- Price / owned / action button
    local isOwned = item.owned
    local isEquipped = false
    for _, equippedId in pairs(equippedData) do
        if equippedId == item.id then
            isEquipped = true
            break
        end
    end

    local actionBtn = Instance.new("TextButton")
    actionBtn.Name = "ActionBtn"
    actionBtn.Size = UDim2.new(1, -16, 0, 32)
    actionBtn.Position = UDim2.new(0, 8, 1, -40)
    actionBtn.BorderSizePixel = 0
    actionBtn.TextScaled = true
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.Parent = card

    local actionCorner = Instance.new("UICorner")
    actionCorner.CornerRadius = UDim.new(0, 6)
    actionCorner.Parent = actionBtn

    if item.earned and not isOwned then
        -- Special earned item, not yet earned
        actionBtn.Text = "Earn: " .. (item.earnMethod or "Special")
        actionBtn.BackgroundColor3 = COLORS.gold
        actionBtn.TextColor3 = COLORS.bg

    elseif isOwned and isEquipped then
        actionBtn.Text = "Unequip"
        actionBtn.BackgroundColor3 = COLORS.textDim
        actionBtn.TextColor3 = COLORS.bg
        actionBtn.MouseButton1Click:Connect(function()
            ShopRequest:FireServer("unequip", item.id)
        end)

    elseif isOwned then
        actionBtn.Text = "Equip"
        actionBtn.BackgroundColor3 = COLORS.success
        actionBtn.TextColor3 = COLORS.bg
        actionBtn.MouseButton1Click:Connect(function()
            ShopRequest:FireServer("equip", item.id)
        end)

    else
        actionBtn.Text = "R$ " .. item.price
        actionBtn.BackgroundColor3 = COLORS.robux
        actionBtn.TextColor3 = Color3.new(1, 1, 1)
        actionBtn.MouseButton1Click:Connect(function()
            ShopRequest:FireServer("buy", item.id)
        end)
    end

    -- Owned badge
    if isOwned then
        local ownedBadge = Instance.new("TextLabel")
        ownedBadge.Size = UDim2.new(0, 60, 0, 20)
        ownedBadge.Position = UDim2.new(1, -65, 0, 5)
        ownedBadge.BackgroundColor3 = COLORS.owned
        ownedBadge.Text = "OWNED"
        ownedBadge.TextColor3 = Color3.new(1, 1, 1)
        ownedBadge.TextScaled = true
        ownedBadge.Font = Enum.Font.GothamBold
        ownedBadge.Parent = card

        local ownedCorner = Instance.new("UICorner")
        ownedCorner.CornerRadius = UDim.new(0, 4)
        ownedCorner.Parent = ownedBadge
    end
end

function ShopUI.Toggle()
    if isOpen then
        ShopUI.Close()
    else
        ShopUI.Open()
    end
end

function ShopUI.Open()
    if not shopGui then return end
    isOpen = true
    shopGui.Enabled = true

    -- Request fresh catalog from server
    if ShopRequest then
        ShopRequest:FireServer("catalog")
    end
end

function ShopUI.Close()
    if not shopGui then return end
    isOpen = false
    shopGui.Enabled = false
end

function ShopUI.IsOpen(): boolean
    return isOpen
end

return ShopUI
