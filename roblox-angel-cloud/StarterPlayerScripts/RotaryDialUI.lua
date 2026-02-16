--[[
    RotaryDialUI.lua — Client-side rotary phone dial interface
    Opens when player picks up a phone booth handset
    Player clicks number buttons (styled as a rotary dial) to enter codes
    Dial visual spins when number is selected
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local RotaryDialUI = {}

-- Colors
local COLORS = {
    bg = Color3.fromRGB(10, 8, 5),
    phone = Color3.fromRGB(25, 25, 20),
    dial = Color3.fromRGB(220, 210, 180),
    dialHole = Color3.fromRGB(40, 35, 25),
    number = Color3.fromRGB(240, 230, 200),
    accent = Color3.fromRGB(0, 255, 180),
    text = Color3.fromRGB(200, 195, 170),
    textDim = Color3.fromRGB(120, 115, 100),
    red = Color3.fromRGB(200, 50, 50),
    green = Color3.fromRGB(50, 200, 80),
}

-- State
local dialGui = nil
local isOpen = false
local currentNumber = ""
local maxDigits = 8  -- XXX-XXXX format + dash

-- RemoteEvents
local DialCode
local DialResult

function RotaryDialUI.Init()
    DialCode = ReplicatedStorage:WaitForChild("DialCode", 15)
    DialResult = ReplicatedStorage:WaitForChild("DialResult", 15)

    if not DialResult then
        warn("[RotaryDialUI] DialResult RemoteEvent not found")
        return
    end

    DialResult.OnClientEvent:Connect(function(data)
        if data.action == "open_dial" then
            RotaryDialUI.Open()
        elseif data.message then
            RotaryDialUI.ShowResult(data.message, data.success)
        end
    end)

    -- Escape to close
    UserInputService.InputBegan:Connect(function(input, processed)
        if not isOpen then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            RotaryDialUI.Close()
        end
    end)

    RotaryDialUI.CreateUI()
    print("[RotaryDialUI] Rotary dial UI initialized")
end

function RotaryDialUI.CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RotaryDialGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Enabled = false
    screenGui.Parent = player.PlayerGui
    dialGui = screenGui

    -- Main phone frame (centered, portrait orientation like a real phone)
    local phone = Instance.new("Frame")
    phone.Name = "PhoneFrame"
    phone.Size = UDim2.new(0, 320, 0, 480)
    phone.Position = UDim2.new(0.5, -160, 0.5, -240)
    phone.BackgroundColor3 = COLORS.phone
    phone.BorderSizePixel = 0
    phone.Parent = screenGui

    local phoneCorner = Instance.new("UICorner")
    phoneCorner.CornerRadius = UDim.new(0, 16)
    phoneCorner.Parent = phone

    local phoneStroke = Instance.new("UIStroke")
    phoneStroke.Color = Color3.fromRGB(60, 55, 40)
    phoneStroke.Thickness = 3
    phoneStroke.Parent = phone

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "ROTARY TELEPHONE"
    title.TextColor3 = COLORS.text
    title.TextScaled = true
    title.Font = Enum.Font.Antique
    title.Parent = phone

    -- Number display (like an old LCD)
    local display = Instance.new("Frame")
    display.Name = "Display"
    display.Size = UDim2.new(0.85, 0, 0, 45)
    display.Position = UDim2.new(0.075, 0, 0, 45)
    display.BackgroundColor3 = Color3.fromRGB(15, 20, 10)
    display.BorderSizePixel = 0
    display.Parent = phone

    local displayCorner = Instance.new("UICorner")
    displayCorner.CornerRadius = UDim.new(0, 6)
    displayCorner.Parent = display

    local numberLabel = Instance.new("TextLabel")
    numberLabel.Name = "NumberLabel"
    numberLabel.Size = UDim2.new(1, -16, 1, 0)
    numberLabel.Position = UDim2.new(0, 8, 0, 0)
    numberLabel.BackgroundTransparency = 1
    numberLabel.Text = "_ _ _ - _ _ _ _"
    numberLabel.TextColor3 = COLORS.accent
    numberLabel.TextXAlignment = Enum.TextXAlignment.Center
    numberLabel.TextScaled = true
    numberLabel.Font = Enum.Font.Code
    numberLabel.Parent = display

    -- Result text (below display)
    local resultLabel = Instance.new("TextLabel")
    resultLabel.Name = "ResultLabel"
    resultLabel.Size = UDim2.new(0.9, 0, 0, 35)
    resultLabel.Position = UDim2.new(0.05, 0, 0, 95)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Text = "Dial a number..."
    resultLabel.TextColor3 = COLORS.textDim
    resultLabel.TextScaled = true
    resultLabel.TextWrapped = true
    resultLabel.Font = Enum.Font.Gotham
    resultLabel.Parent = phone

    -- Dial pad (circular arrangement like a real rotary, but as buttons for usability)
    local dialArea = Instance.new("Frame")
    dialArea.Name = "DialArea"
    dialArea.Size = UDim2.new(0, 260, 0, 260)
    dialArea.Position = UDim2.new(0.5, -130, 0, 140)
    dialArea.BackgroundColor3 = COLORS.dial
    dialArea.BorderSizePixel = 0
    dialArea.Parent = phone

    local dialCorner = Instance.new("UICorner")
    dialCorner.CornerRadius = UDim.new(0.5, 0)
    dialCorner.Parent = dialArea

    -- Number buttons arranged in a circle (1-9, then 0)
    local digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
    local centerX, centerY = 130, 130
    local radius = 95

    for i, digit in ipairs(digits) do
        local angle = ((i - 1) / 10) * math.pi * 2 - math.pi / 2  -- start from top
        local bx = centerX + math.cos(angle) * radius - 20
        local by = centerY + math.sin(angle) * radius - 20

        local btn = Instance.new("TextButton")
        btn.Name = "Digit_" .. digit
        btn.Size = UDim2.new(0, 40, 0, 40)
        btn.Position = UDim2.new(0, bx, 0, by)
        btn.BackgroundColor3 = COLORS.dialHole
        btn.Text = digit
        btn.TextColor3 = COLORS.number
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = dialArea

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0.5, 0)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            RotaryDialUI.DialDigit(digit)
        end)
    end

    -- Center decoration
    local centerDeco = Instance.new("Frame")
    centerDeco.Size = UDim2.new(0, 50, 0, 50)
    centerDeco.Position = UDim2.new(0.5, -25, 0.5, -25)
    centerDeco.BackgroundColor3 = COLORS.dialHole
    centerDeco.BorderSizePixel = 0
    centerDeco.Parent = dialArea

    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(0.5, 0)
    centerCorner.Parent = centerDeco

    -- Action buttons row
    local btnRow = Instance.new("Frame")
    btnRow.Name = "ActionRow"
    btnRow.Size = UDim2.new(0.85, 0, 0, 40)
    btnRow.Position = UDim2.new(0.075, 0, 0, 415)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = phone

    -- Clear button
    local clearBtn = Instance.new("TextButton")
    clearBtn.Name = "ClearBtn"
    clearBtn.Size = UDim2.new(0.3, 0, 1, 0)
    clearBtn.Position = UDim2.new(0, 0, 0, 0)
    clearBtn.BackgroundColor3 = COLORS.red
    clearBtn.Text = "CLEAR"
    clearBtn.TextColor3 = Color3.new(1, 1, 1)
    clearBtn.TextScaled = true
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.BorderSizePixel = 0
    clearBtn.Parent = btnRow

    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 6)
    clearCorner.Parent = clearBtn

    clearBtn.MouseButton1Click:Connect(function()
        RotaryDialUI.ClearNumber()
    end)

    -- Dial button
    local dialBtn = Instance.new("TextButton")
    dialBtn.Name = "DialBtn"
    dialBtn.Size = UDim2.new(0.4, 0, 1, 0)
    dialBtn.Position = UDim2.new(0.35, 0, 0, 0)
    dialBtn.BackgroundColor3 = COLORS.green
    dialBtn.Text = "DIAL"
    dialBtn.TextColor3 = Color3.new(1, 1, 1)
    dialBtn.TextScaled = true
    dialBtn.Font = Enum.Font.GothamBold
    dialBtn.BorderSizePixel = 0
    dialBtn.Parent = btnRow

    local dialBtnCorner = Instance.new("UICorner")
    dialBtnCorner.CornerRadius = UDim.new(0, 6)
    dialBtnCorner.Parent = dialBtn

    dialBtn.MouseButton1Click:Connect(function()
        RotaryDialUI.SubmitNumber()
    end)

    -- Hang up button
    local hangupBtn = Instance.new("TextButton")
    hangupBtn.Name = "HangupBtn"
    hangupBtn.Size = UDim2.new(0.25, 0, 1, 0)
    hangupBtn.Position = UDim2.new(0.78, 0, 0, 0)
    hangupBtn.BackgroundColor3 = COLORS.textDim
    hangupBtn.Text = "HANG UP"
    hangupBtn.TextColor3 = Color3.new(1, 1, 1)
    hangupBtn.TextScaled = true
    hangupBtn.Font = Enum.Font.GothamBold
    hangupBtn.BorderSizePixel = 0
    hangupBtn.Parent = btnRow

    local hangupCorner = Instance.new("UICorner")
    hangupCorner.CornerRadius = UDim.new(0, 6)
    hangupCorner.Parent = hangupBtn

    hangupBtn.MouseButton1Click:Connect(function()
        RotaryDialUI.Close()
    end)
end

function RotaryDialUI.DialDigit(digit: string)
    if #currentNumber >= maxDigits then return end

    -- Add dash after 3rd digit
    if #currentNumber == 3 then
        currentNumber = currentNumber .. "-"
    end

    currentNumber = currentNumber .. digit

    -- Update display
    RotaryDialUI.UpdateDisplay()
end

function RotaryDialUI.ClearNumber()
    currentNumber = ""
    RotaryDialUI.UpdateDisplay()

    local phone = dialGui.PhoneFrame
    phone.ResultLabel.Text = "Dial a number..."
    phone.ResultLabel.TextColor3 = COLORS.textDim
end

function RotaryDialUI.UpdateDisplay()
    if not dialGui then return end
    local phone = dialGui.PhoneFrame
    local display = phone.Display.NumberLabel

    if currentNumber == "" then
        display.Text = "_ _ _ - _ _ _ _"
    else
        -- Format with spacing
        local formatted = ""
        for i = 1, #currentNumber do
            formatted = formatted .. currentNumber:sub(i, i)
            if i < #currentNumber then
                formatted = formatted .. " "
            end
        end
        display.Text = formatted
    end
end

function RotaryDialUI.SubmitNumber()
    if currentNumber == "" then return end

    -- Send to server
    if DialCode then
        DialCode:FireServer(currentNumber)
    end
end

function RotaryDialUI.ShowResult(message: string, success: boolean?)
    if not dialGui then return end
    local phone = dialGui.PhoneFrame
    local resultLabel = phone.ResultLabel

    resultLabel.Text = message
    resultLabel.TextColor3 = success and COLORS.accent or COLORS.text

    -- Auto-clear after showing result
    if success then
        task.delay(3, function()
            currentNumber = ""
            RotaryDialUI.UpdateDisplay()
            if resultLabel then
                resultLabel.Text = "Dial a number..."
                resultLabel.TextColor3 = COLORS.textDim
            end
        end)
    end
end

function RotaryDialUI.Open()
    if not dialGui then return end
    isOpen = true
    currentNumber = ""
    RotaryDialUI.UpdateDisplay()
    dialGui.Enabled = true
end

function RotaryDialUI.Close()
    if not dialGui then return end
    isOpen = false
    currentNumber = ""
    dialGui.Enabled = false
end

function RotaryDialUI.IsOpen(): boolean
    return isOpen
end

return RotaryDialUI
