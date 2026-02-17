--[[
    DialogueUI.lua — NPC dialogue display system
    Shows dialogue boxes with speaker name, text, and click-to-advance
    Used by NPCSystem for The Keeper and future NPCs
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local DialogueUI = {}

-- Colors
local COLORS = {
    bg = Color3.fromRGB(10, 10, 20),
    panel = Color3.fromRGB(20, 22, 35),
    accent = Color3.fromRGB(0, 212, 255),
    gold = Color3.fromRGB(255, 240, 200),
    text = Color3.fromRGB(230, 230, 240),
    textDim = Color3.fromRGB(150, 150, 170),
}

-- State
local dialogueGui = nil
local isShowing = false
local currentLines = {}
local currentLineIndex = 0
local advanceCallback = nil

-- RemoteEvents
local NPCDialogue

function DialogueUI.Init()
    NPCDialogue = ReplicatedStorage:WaitForChild("NPCDialogue", 15)
    if not NPCDialogue then
        warn("[DialogueUI] NPCDialogue RemoteEvent not found")
        return
    end

    NPCDialogue.OnClientEvent:Connect(function(data)
        DialogueUI.ShowDialogue(data.lines, data.npcName)
    end)

    -- Click or E to advance dialogue
    UserInputService.InputBegan:Connect(function(input, processed)
        if not isShowing then return end
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.KeyCode == Enum.KeyCode.E
            or input.KeyCode == Enum.KeyCode.Return then
            DialogueUI.Advance()
        end
    end)

    DialogueUI.CreateUI()
    print("[DialogueUI] Dialogue UI initialized")
end

function DialogueUI.CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DialogueGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Enabled = false
    screenGui.Parent = player.PlayerGui
    dialogueGui = screenGui

    -- Dialogue box (bottom of screen)
    local box = Instance.new("Frame")
    box.Name = "DialogueBox"
    box.Size = UDim2.new(0.6, 0, 0, 140)
    box.Position = UDim2.new(0.2, 0, 1, -160)
    box.BackgroundColor3 = COLORS.panel
    box.BackgroundTransparency = 0.05
    box.BorderSizePixel = 0
    box.Parent = screenGui

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 12)
    boxCorner.Parent = box

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = COLORS.accent
    boxStroke.Thickness = 1.5
    boxStroke.Transparency = 0.3
    boxStroke.Parent = box

    -- Speaker name
    local speakerLabel = Instance.new("TextLabel")
    speakerLabel.Name = "SpeakerLabel"
    speakerLabel.Size = UDim2.new(0.4, 0, 0, 28)
    speakerLabel.Position = UDim2.new(0.02, 0, 0, 8)
    speakerLabel.BackgroundTransparency = 1
    speakerLabel.Text = ""
    speakerLabel.TextColor3 = COLORS.gold
    speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
    speakerLabel.TextScaled = true
    speakerLabel.Font = Enum.Font.GothamBold
    speakerLabel.Parent = box

    -- Dialogue text
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "DialogueText"
    textLabel.Size = UDim2.new(0.96, 0, 0, 70)
    textLabel.Position = UDim2.new(0.02, 0, 0, 38)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = ""
    textLabel.TextColor3 = COLORS.text
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.Gotham
    textLabel.Parent = box

    -- Continue prompt
    local continueLabel = Instance.new("TextLabel")
    continueLabel.Name = "ContinueLabel"
    continueLabel.Size = UDim2.new(1, 0, 0, 20)
    continueLabel.Position = UDim2.new(0, 0, 1, -25)
    continueLabel.BackgroundTransparency = 1
    continueLabel.Text = "Click or press E to continue..."
    continueLabel.TextColor3 = COLORS.textDim
    continueLabel.TextScaled = true
    continueLabel.Font = Enum.Font.GothamMedium
    continueLabel.Parent = box

    -- Click to advance
    local clickArea = Instance.new("TextButton")
    clickArea.Name = "ClickArea"
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.Parent = box

    clickArea.MouseButton1Click:Connect(function()
        DialogueUI.Advance()
    end)
end

function DialogueUI.ShowDialogue(lines: { any }, npcName: string?)
    if not dialogueGui then return end

    currentLines = lines or {}
    currentLineIndex = 0
    isShowing = true

    dialogueGui.Enabled = true

    -- Fade in the dialogue box
    local box = dialogueGui.DialogueBox
    box.BackgroundTransparency = 1
    TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.05,
    }):Play()

    -- Show first line
    DialogueUI.Advance()
end

function DialogueUI.Advance()
    if not isShowing then return end

    currentLineIndex = currentLineIndex + 1

    if currentLineIndex > #currentLines then
        DialogueUI.Close()
        return
    end

    local line = currentLines[currentLineIndex]
    local box = dialogueGui.DialogueBox
    local speakerLabel = box.SpeakerLabel
    local textLabel = box.DialogueText
    local continueLabel = box.ContinueLabel

    speakerLabel.Text = line.speaker or ""
    textLabel.Text = ""  -- will typewriter in

    -- Update continue prompt
    if currentLineIndex >= #currentLines then
        continueLabel.Text = "Click or press E to close"
    else
        continueLabel.Text = "Click or press E to continue..."
    end

    -- Typewriter effect (track which line we're typing so Advance() can skip it)
    local lineBeingTyped = currentLineIndex
    task.spawn(function()
        local fullText = line.text or ""
        for i = 1, #fullText do
            if not isShowing or currentLineIndex ~= lineBeingTyped then break end
            textLabel.Text = fullText:sub(1, i)
            task.wait(0.02)
        end
        textLabel.Text = fullText
    end)
end

function DialogueUI.Close()
    isShowing = false
    currentLines = {}
    currentLineIndex = 0

    if dialogueGui then
        dialogueGui.Enabled = false
    end
end

function DialogueUI.IsShowing(): boolean
    return isShowing
end

return DialogueUI
