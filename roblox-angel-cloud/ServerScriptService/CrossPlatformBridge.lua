--[[
    CrossPlatformBridge.lua — Communication with the real Angel Cloud platform
    Uses HttpService to call gateway API at 100.67.120.6:4200 (Tailscale)
    Server-side only (HttpService is blocked on client)
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local MoteSystem = require(script.Parent.MoteSystem)
local Layers = require(ReplicatedStorage.Config.Layers)

local CrossPlatformBridge = {}

-- Configuration
local GATEWAY_URL = "http://100.67.120.6:4200"
local BOT_SECRET = ""  -- Set via game settings or environment
local RATE_LIMIT_POINTS_PER_DAY = 10  -- Max points from Roblox -> real platform per day

-- RemoteEvents
local LinkRequest      -- Client -> Server: player submits verification code
local LinkResult       -- Server -> Client: verification result
local LinkStatusCheck  -- Client -> Server: check if already linked

-- Per-player rate limiting for cross-platform points
local DailyPointsAwarded = {}  -- { UserId = { date = "YYYY-MM-DD", points = N } }

function CrossPlatformBridge.Init()
    LinkRequest = Instance.new("RemoteEvent")
    LinkRequest.Name = "LinkRequest"
    LinkRequest.Parent = ReplicatedStorage

    LinkResult = Instance.new("RemoteEvent")
    LinkResult.Name = "LinkResult"
    LinkResult.Parent = ReplicatedStorage

    LinkStatusCheck = Instance.new("RemoteEvent")
    LinkStatusCheck.Name = "LinkStatusCheck"
    LinkStatusCheck.Parent = ReplicatedStorage

    LinkRequest.OnServerEvent:Connect(function(player, code)
        CrossPlatformBridge.VerifyLink(player, code)
    end)

    LinkStatusCheck.OnServerEvent:Connect(function(player)
        local data = DataManager.GetData(player)
        LinkResult:FireClient(player, {
            type = "status",
            linked = data and data.linkedAngelCloud or false,
        })
    end)
end

function CrossPlatformBridge.SetSecret(secret: string)
    BOT_SECRET = secret
end

function CrossPlatformBridge.VerifyLink(player: Player, code: string)
    if not code or #code ~= 6 then
        LinkResult:FireClient(player, {
            type = "verify",
            success = false,
            error = "Invalid code format. Enter the 6-digit code from your Angel Cloud profile.",
        })
        return
    end

    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = GATEWAY_URL .. "/api/verify-roblox",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Bot-Secret"] = BOT_SECRET,
            },
            Body = HttpService:JSONEncode({
                roblox_user_id = tostring(player.UserId),
                roblox_username = player.Name,
                code = code,
            }),
        })
    end)

    if not success then
        warn("[CrossPlatformBridge] HTTP request failed: " .. tostring(response))
        LinkResult:FireClient(player, {
            type = "verify",
            success = false,
            error = "Could not reach Angel Cloud. Try again later.",
        })
        return
    end

    if response.StatusCode == 200 then
        local body = HttpService:JSONDecode(response.Body)
        local data = DataManager.GetData(player)
        if data then
            data.linkedAngelCloud = true
            data.angelCloudUserId = body.user_id

            -- Apply starting level from real platform
            if body.angel_level then
                local levelIndex = Layers.GetLevelIndex(body.angel_level)
                if levelIndex > (data.layerIndex or 1) then
                    data.angelLevel = body.angel_level
                    data.layerIndex = levelIndex
                end
            end

            -- Apply starting motes (capped at threshold for their level)
            if body.interaction_count then
                local threshold = Layers.PROGRESSION_THRESHOLDS[data.angelLevel] or 0
                local startingMotes = math.min(body.interaction_count, threshold)
                if startingMotes > data.motes then
                    data.motes = startingMotes
                end
            end

            -- Grant Cloud Connected badge cosmetic
            data.ownedCosmetics["cloud_connected_badge"] = true
        end

        LinkResult:FireClient(player, {
            type = "verify",
            success = true,
            username = body.username,
            angelLevel = body.angel_level,
            message = "Linked to Angel Cloud as " .. (body.username or "unknown") .. "!",
        })
    elseif response.StatusCode == 404 then
        LinkResult:FireClient(player, {
            type = "verify",
            success = false,
            error = "Code not found or expired. Generate a new code from your Angel Cloud profile.",
        })
    else
        LinkResult:FireClient(player, {
            type = "verify",
            success = false,
            error = "Verification failed. Try again later.",
        })
    end
end

-- Report activity to real Angel Cloud platform (rate-limited)
function CrossPlatformBridge.ReportActivity(player: Player, activityType: string, description: string, points: number)
    local data = DataManager.GetData(player)
    if not data or not data.linkedAngelCloud then
        return
    end

    -- Rate limit check
    local today = os.date("%Y-%m-%d")
    local limit = DailyPointsAwarded[player.UserId]
    if limit and limit.date == today and limit.points >= RATE_LIMIT_POINTS_PER_DAY then
        return  -- daily limit reached
    end

    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = GATEWAY_URL .. "/api/roblox-activity",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Bot-Secret"] = BOT_SECRET,
            },
            Body = HttpService:JSONEncode({
                roblox_user_id = tostring(player.UserId),
                points = points,
                activity_type = activityType,
                description = description,
            }),
        })
    end)

    if success and response.StatusCode == 200 then
        -- Track daily limit
        if not DailyPointsAwarded[player.UserId] or DailyPointsAwarded[player.UserId].date ~= today then
            DailyPointsAwarded[player.UserId] = { date = today, points = 0 }
        end
        DailyPointsAwarded[player.UserId].points = DailyPointsAwarded[player.UserId].points + points
    elseif not success then
        warn("[CrossPlatformBridge] Failed to report activity: " .. tostring(response))
    end
end

-- Report trial completion to real platform (2 pts, rate-limited)
function CrossPlatformBridge.ReportTrialCompletion(player: Player, trialName: string)
    CrossPlatformBridge.ReportActivity(
        player,
        "roblox_trial",
        "Completed Guardian Trial: " .. trialName,
        2
    )
end

-- Cleanup on player leave
function CrossPlatformBridge.RemovePlayer(player: Player)
    DailyPointsAwarded[player.UserId] = nil
end

return CrossPlatformBridge
