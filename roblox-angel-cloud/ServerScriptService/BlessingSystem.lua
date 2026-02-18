--[[
    BlessingSystem.lua — Blessing Bluffs pay-it-forward mechanic
    Cost: 2 Motes + 20 Stamina
    Recipient: 30% stamina + 1 Mote + notification
    Chain Blessings: if recipient blesses within 5 min, both senders get bonus Mote
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)
local StaminaSystem = require(script.Parent.StaminaSystem)
local SoundManager = require(script.Parent.SoundManager)
local Layers = require(ReplicatedStorage.Config.Layers)

local BlessingSystem = {}

-- RemoteEvents
local BlessingRequest  -- Client -> Server: player wants to send blessing
local BlessingReceived -- Server -> Client: you received a blessing
local BlessingChain    -- Server -> Client: chain bonus notification
local CommunityBoard   -- Server -> Client: community board update

-- Active blessing chain tracking
local ActiveChains = {}  -- { recipientUserId = { senderUserId, timestamp } }

-- Community board stats (per server session)
local ServerStats = {
    longestChainThisWeek = 0,
    mostBlessingsThisWeek = {},  -- { userId = count }
    currentChainLength = 0,
}

-- Constants
local BLESSING_MOTE_COST = 2
local BLESSING_STAMINA_COST = 20
local BLESSING_MOTE_REWARD = 1
local CHAIN_WINDOW = 5 * 60  -- 5 minutes
local CHAIN_BONUS_MOTES = 1

function BlessingSystem.Init()
    BlessingRequest = Instance.new("RemoteEvent")
    BlessingRequest.Name = "BlessingRequest"
    BlessingRequest.Parent = ReplicatedStorage

    BlessingReceived = Instance.new("RemoteEvent")
    BlessingReceived.Name = "BlessingReceived"
    BlessingReceived.Parent = ReplicatedStorage

    BlessingChain = Instance.new("RemoteEvent")
    BlessingChain.Name = "BlessingChain"
    BlessingChain.Parent = ReplicatedStorage

    CommunityBoard = Instance.new("RemoteEvent")
    CommunityBoard.Name = "CommunityBoard"
    CommunityBoard.Parent = ReplicatedStorage

    -- Listen for blessing requests
    BlessingRequest.OnServerEvent:Connect(function(player)
        BlessingSystem.SendBlessing(player)
    end)
end

function BlessingSystem.SendBlessing(sender: Player): boolean
    local senderData = DataManager.GetData(sender)
    if not senderData then
        return false
    end

    -- Check costs
    if senderData.motes < BLESSING_MOTE_COST then
        return false
    end

    local currentStamina = StaminaSystem.GetStamina(sender)
    if currentStamina < BLESSING_STAMINA_COST then
        return false
    end

    -- Deduct costs
    MoteSystem.AwardMotes(sender, -BLESSING_MOTE_COST, "blessing_sent")
    StaminaSystem.DrainStamina(sender, "blessing", BLESSING_STAMINA_COST)

    -- Find a random recipient on a lower layer
    local senderLevel = Layers.GetLevelIndex(senderData.angelLevel)
    local candidates = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= sender then
            local playerData = DataManager.GetData(player)
            if playerData then
                local playerLevel = Layers.GetLevelIndex(playerData.angelLevel)
                if playerLevel <= senderLevel then
                    table.insert(candidates, player)
                end
            end
        end
    end

    -- If no lower-layer players, pick any other player
    if #candidates == 0 then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= sender then
                table.insert(candidates, player)
            end
        end
    end

    if #candidates == 0 then
        -- No other players; refund
        MoteSystem.AwardMotes(sender, BLESSING_MOTE_COST, "blessing_refund")
        return false
    end

    -- Select random recipient
    local recipient = candidates[math.random(#candidates)]

    -- Apply blessing to recipient
    StaminaSystem.ApplyBlessingBoost(recipient)
    MoteSystem.AwardMotes(recipient, BLESSING_MOTE_REWARD, "blessing_received")

    -- Update stats
    senderData.blessingsGiven = (senderData.blessingsGiven or 0) + 1
    local recipientData = DataManager.GetData(recipient)
    if recipientData then
        recipientData.blessingsReceived = (recipientData.blessingsReceived or 0) + 1
    end

    -- Play blessing sounds
    SoundManager.OnBlessingSent(sender)
    SoundManager.OnBlessingReceived(recipient)

    -- Notify recipient
    BlessingReceived:FireClient(recipient, {
        senderName = sender.Name,
        message = sender.Name .. " sent you a Blessing! You are not alone.",
        moteReward = BLESSING_MOTE_REWARD,
    })

    -- Check for chain blessing
    local now = os.time()
    local chainInfo = ActiveChains[sender.UserId]
    if chainInfo and (now - chainInfo.timestamp) <= CHAIN_WINDOW then
        -- This sender was recently blessed and is now passing it on — chain!
        local chainLength = (chainInfo.chainLength or 1) + 1

        -- Bonus mote to both the original sender and current sender
        local originalSender = Players:GetPlayerByUserId(chainInfo.senderUserId)
        if originalSender then
            MoteSystem.AwardMotes(originalSender, CHAIN_BONUS_MOTES, "blessing_chain_bonus")
            BlessingChain:FireClient(originalSender, {
                message = "Your blessing started a chain! Bonus Mote earned.",
                chainLength = chainLength,
            })
        end
        MoteSystem.AwardMotes(sender, CHAIN_BONUS_MOTES, "blessing_chain_bonus")
        BlessingChain:FireClient(sender, {
            message = "You extended a blessing chain! Bonus Mote earned.",
            chainLength = chainLength,
        })

        -- Track chain for recipient (they might continue it)
        ActiveChains[recipient.UserId] = {
            senderUserId = sender.UserId,
            timestamp = now,
            chainLength = chainLength,
        }

        -- Update longest chain
        if chainLength > ServerStats.longestChainThisWeek then
            ServerStats.longestChainThisWeek = chainLength
        end

        -- Update player's longest chain record
        if chainLength > (senderData.longestBlessingChain or 0) then
            senderData.longestBlessingChain = chainLength
        end
    else
        -- New chain starts
        ActiveChains[recipient.UserId] = {
            senderUserId = sender.UserId,
            timestamp = now,
            chainLength = 1,
        }
    end

    -- Track community stats
    ServerStats.mostBlessingsThisWeek[sender.UserId] = (ServerStats.mostBlessingsThisWeek[sender.UserId] or 0) + 1
    DataManager.IncrementCommunityStat("total_blessings", 1)

    -- Update quest progress
    local QuestSystem = require(script.Parent.QuestSystem)
    pcall(QuestSystem.OnBlessingGiven, sender)

    -- Check progression after mote changes
    local ProgressionSystem = require(script.Parent.ProgressionSystem)
    ProgressionSystem.OnMotesChanged(sender)
    ProgressionSystem.OnMotesChanged(recipient)

    return true
end

function BlessingSystem.GetCommunityBoard(): { [string]: any }
    -- Build community board (communal, not competitive)
    local blessingsLeader = { name = "No one yet", count = 0 }
    for userId, count in pairs(ServerStats.mostBlessingsThisWeek) do
        if count > blessingsLeader.count then
            local player = Players:GetPlayerByUserId(userId)
            blessingsLeader = {
                name = player and player.Name or "Unknown",
                count = count,
            }
        end
    end

    return {
        longestChain = ServerStats.longestChainThisWeek,
        mostBlessings = blessingsLeader,
        -- No individual Mote leaderboard — intentionally communal
    }
end

-- Cleanup expired chains periodically
function BlessingSystem.CleanupChains()
    local now = os.time()
    for userId, info in pairs(ActiveChains) do
        if now - info.timestamp > CHAIN_WINDOW * 2 then
            ActiveChains[userId] = nil
        end
    end
end

return BlessingSystem
