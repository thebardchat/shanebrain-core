--[[
    BadgeHandler.lua — Founder badge and special cosmetic awards
    Awards "Founder's Halo" cosmetic to players who join during launch week.
    Also handles Ko-fi code redemption for the Founder's Halo.
    Inspired by Gemini's BadgeHandler pattern with time-window checks.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.DataManager)

local BadgeHandler = {}

-- Configure these after uploading badges in Roblox Creator Dashboard
local FOUNDER_BADGE_ID = 0  -- Replace with real Badge ID after upload
local CLOUD_CONNECTED_BADGE_ID = 0  -- Replace with real Badge ID

-- Launch week window — players joining before this date get Founder's Halo
local LAUNCH_WEEK_END = os.time({ year = 2026, month = 3, day = 31 })

-- RemoteEvents
local KofiRedeem  -- Client -> Server: player submits Ko-fi code

-- Valid Ko-fi donor codes (in production, validate against a database or API)
-- For now, codes are generated manually and added here
local validKofiCodes = {}

function BadgeHandler.Init()
    KofiRedeem = Instance.new("RemoteEvent")
    KofiRedeem.Name = "KofiRedeem"
    KofiRedeem.Parent = ReplicatedStorage

    KofiRedeem.OnServerEvent:Connect(function(player, code)
        BadgeHandler.RedeemKofiCode(player, code)
    end)
end

function BadgeHandler.OnPlayerAdded(player: Player)
    task.wait(3)  -- let DataManager load first

    -- Launch week Founder's Halo
    if os.time() <= LAUNCH_WEEK_END then
        BadgeHandler.AwardFounderHalo(player)
    end
end

function BadgeHandler.AwardFounderHalo(player: Player)
    local data = DataManager.GetData(player)
    if not data then
        return
    end

    -- Grant cosmetic
    if not data.ownedCosmetics["founders_halo"] then
        data.ownedCosmetics["founders_halo"] = true
        data.founderHalo = true
        print("[BadgeHandler] Awarded Founder's Halo to " .. player.Name)
    end

    -- Award Roblox badge (if configured)
    if FOUNDER_BADGE_ID > 0 then
        local success, hasBadge = pcall(function()
            return BadgeService:UserHasBadgeAsync(player.UserId, FOUNDER_BADGE_ID)
        end)

        if success and not hasBadge then
            pcall(function()
                BadgeService:AwardBadge(player.UserId, FOUNDER_BADGE_ID)
            end)
        end
    end
end

function BadgeHandler.AwardCloudConnectedBadge(player: Player)
    if CLOUD_CONNECTED_BADGE_ID > 0 then
        local success, hasBadge = pcall(function()
            return BadgeService:UserHasBadgeAsync(player.UserId, CLOUD_CONNECTED_BADGE_ID)
        end)

        if success and not hasBadge then
            pcall(function()
                BadgeService:AwardBadge(player.UserId, CLOUD_CONNECTED_BADGE_ID)
            end)
        end
    end
end

function BadgeHandler.RedeemKofiCode(player: Player, code: string)
    if not code or code == "" then
        return
    end

    local data = DataManager.GetData(player)
    if not data then
        return
    end

    -- Already has Founder's Halo
    if data.ownedCosmetics["founders_halo"] then
        local ServerMessage = ReplicatedStorage:FindFirstChild("ServerMessage")
        if ServerMessage then
            ServerMessage:FireClient(player, {
                type = "info",
                message = "You already have the Founder's Halo!",
            })
        end
        return
    end

    -- Validate code
    if validKofiCodes[code] then
        validKofiCodes[code] = nil  -- single use
        data.ownedCosmetics["founders_halo"] = true
        data.founderHalo = true

        local ServerMessage = ReplicatedStorage:FindFirstChild("ServerMessage")
        if ServerMessage then
            ServerMessage:FireClient(player, {
                type = "info",
                message = "Ko-fi code accepted! Founder's Halo + Supporter tag unlocked.",
            })
        end

        print("[BadgeHandler] Ko-fi Founder's Halo redeemed by " .. player.Name)

        if FOUNDER_BADGE_ID > 0 then
            pcall(function()
                BadgeService:AwardBadge(player.UserId, FOUNDER_BADGE_ID)
            end)
        end
    else
        local ServerMessage = ReplicatedStorage:FindFirstChild("ServerMessage")
        if ServerMessage then
            ServerMessage:FireClient(player, {
                type = "info",
                message = "Invalid or already-used Ko-fi code.",
            })
        end
    end
end

-- Add Ko-fi codes at runtime (called by admin or from a secure source)
function BadgeHandler.AddKofiCode(code: string)
    validKofiCodes[code] = true
end

return BadgeHandler
