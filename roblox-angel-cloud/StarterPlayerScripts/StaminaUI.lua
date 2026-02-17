--[[
    StaminaUI.lua — Wing Gauge stamina bar display
    Positioned below the HUD, shows current/max stamina with action indicators
    Color shifts from cyan (full) to red (empty)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local StaminaUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local barFrame: Frame
local barFill: Frame
local staminaLabel: TextLabel
local currentPulseTween = nil  -- track pulse so we can stop it

local COLORS = {
    full = Color3.fromRGB(0, 212, 255),     -- cyan
    mid = Color3.fromRGB(255, 215, 0),      -- gold
    low = Color3.fromRGB(255, 100, 100),    -- red
    bg = Color3.fromRGB(20, 20, 30),
}

function StaminaUI.Init()
    local screenGui = playerGui:WaitForChild("AngelCloudUI")

    -- Stamina bar container
    barFrame = Instance.new("Frame")
    barFrame.Name = "StaminaBar"
    barFrame.Size = UDim2.new(0, 200, 0, 12)
    barFrame.Position = UDim2.new(0, 15, 0, 125)
    barFrame.BackgroundColor3 = COLORS.bg
    barFrame.BackgroundTransparency = 0.3
    barFrame.BorderSizePixel = 0
    barFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = barFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.full
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Name = "StaminaStroke"
    stroke.Parent = barFrame

    -- Fill bar
    barFill = Instance.new("Frame")
    barFill.Name = "Fill"
    barFill.Size = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3 = COLORS.full
    barFill.BackgroundTransparency = 0.2
    barFill.BorderSizePixel = 0
    barFill.Parent = barFrame

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = barFill

    -- Label
    staminaLabel = Instance.new("TextLabel")
    staminaLabel.Name = "StaminaLabel"
    staminaLabel.Size = UDim2.new(0, 200, 0, 14)
    staminaLabel.Position = UDim2.new(0, 15, 0, 140)
    staminaLabel.BackgroundTransparency = 1
    staminaLabel.Text = "Wing Gauge: 100/100"
    staminaLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    staminaLabel.TextSize = 11
    staminaLabel.Font = Enum.Font.Gotham
    staminaLabel.TextXAlignment = Enum.TextXAlignment.Left
    staminaLabel.Parent = screenGui
end

function StaminaUI.UpdateBar(current: number, max: number, action: string?)
    if not barFill or not barFrame then
        return
    end

    local ratio = math.clamp(current / math.max(max, 1), 0, 1)

    -- Color based on ratio
    local color
    if ratio > 0.6 then
        color = COLORS.full
    elseif ratio > 0.25 then
        color = COLORS.mid
    else
        color = COLORS.low
    end

    -- Animate fill
    TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Size = UDim2.new(ratio, 0, 1, 0),
        BackgroundColor3 = color,
    }):Play()

    -- Update stroke color
    local stroke = barFrame:FindFirstChild("StaminaStroke")
    if stroke then
        stroke.Color = color
    end

    -- Update label
    if staminaLabel then
        local actionText = ""
        if action == "glide" then
            actionText = " (Gliding)"
        elseif action == "flight" then
            actionText = " (Flying)"
        elseif action == "shield" then
            actionText = " (Shielding)"
        elseif action == "meditation_complete" then
            actionText = " (Restored!)"
        elseif action == "blessing_received" then
            actionText = " (Blessed!)"
        end
        staminaLabel.Text = "Wing Gauge: " .. math.floor(current) .. "/" .. math.floor(max) .. actionText
    end

    -- Pulse effect when low (stop pulse when stamina recovers)
    if ratio <= 0.15 and ratio > 0 then
        if not currentPulseTween then
            currentPulseTween = TweenService:Create(barFill, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                BackgroundTransparency = 0.6,
            })
            currentPulseTween:Play()
        end
    else
        if currentPulseTween then
            currentPulseTween:Cancel()
            currentPulseTween = nil
            barFill.BackgroundTransparency = 0.2
        end
    end
end

return StaminaUI
