--[[
    StaminaSystem.lua — Wing Gauge stamina management
    Server-authoritative stamina tracking with HALT anti-burnout system

    Max Capacity: 100 base + 20 per angel level index (Newborn=100, Angel=200)
    Drain: Glide 5/sec, Flight 15/sec, Cloud-Shape 10/action, Shield 8/sec
    Recovery: Ground 3/sec, Reflection Pool +50%, Blessing +30%, 3+ players nearby 2x, Meditation 30s full
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local Layers = require(ReplicatedStorage.Config.Layers)

local StaminaSystem = {}

-- Per-player stamina state (not persisted, session-only)
local StaminaState = {}

-- RemoteEvents
local StaminaUpdate  -- Server -> Client: sync stamina value
local HALTNotify     -- Server -> Client: HALT burnout notification

-- Constants
local BASE_STAMINA = 100
local STAMINA_PER_LEVEL = 20

local DRAIN_RATES = {
    glide = 5,       -- per second
    flight = 15,     -- per second
    cloud_shape = 10, -- per action
    shield = 8,      -- per second
}

local RECOVERY_RATES = {
    ground = 3,                -- per second on ground
    reflection_pool = 4.5,     -- 3 * 1.5 (+50%)
    blessing_boost = 3.9,      -- 3 * 1.3 (+30%)
    near_players = 6,          -- 3 * 2 (3+ nearby players)
    meditation = "full",       -- full restore after 30s sit
}

-- HALT system constants
local HALT_PLAY_THRESHOLD = 45 * 60  -- 45 minutes in seconds
local HALT_SLOW_DURATION = 5 * 60    -- 5 minutes slowdown
local HALT_REST_AFK_TIME = 120       -- 2 minutes AFK for rest bonus
local HALT_REST_BONUS = 5            -- motes

function StaminaSystem.Init()
    StaminaUpdate = Instance.new("RemoteEvent")
    StaminaUpdate.Name = "StaminaUpdate"
    StaminaUpdate.Parent = ReplicatedStorage

    HALTNotify = Instance.new("RemoteEvent")
    HALTNotify.Name = "HALTNotify"
    HALTNotify.Parent = ReplicatedStorage
end

function StaminaSystem.GetMaxStamina(player: Player): number
    local data = DataManager.GetData(player)
    if not data then
        return BASE_STAMINA
    end
    local levelIndex = Layers.GetLevelIndex(data.angelLevel)
    return BASE_STAMINA + (levelIndex - 1) * STAMINA_PER_LEVEL
end

function StaminaSystem.InitPlayer(player: Player)
    local maxStamina = StaminaSystem.GetMaxStamina(player)
    StaminaState[player.UserId] = {
        current = maxStamina,
        max = maxStamina,
        isOnGround = true,
        isGliding = false,
        isFlying = false,
        isShielding = false,
        nearReflectionPool = false,
        blessingBoost = false,
        blessingBoostExpires = 0,
        nearbyPlayerCount = 0,
        isMeditating = false,
        meditationStart = 0,
        -- HALT tracking
        sessionPlayStart = os.time(),
        haltTriggered = false,
        haltSlowdownActive = false,
        haltSlowdownExpires = 0,
        lastAFKCheck = os.time(),
        isAFK = false,
        afkStart = 0,
    }
end

function StaminaSystem.RemovePlayer(player: Player)
    StaminaState[player.UserId] = nil
end

function StaminaSystem.GetStamina(player: Player): (number, number)
    local state = StaminaState[player.UserId]
    if not state then
        return 0, BASE_STAMINA
    end
    return state.current, state.max
end

function StaminaSystem.DrainStamina(player: Player, action: string, amount: number?): boolean
    local state = StaminaState[player.UserId]
    if not state then
        return false
    end

    local drain = amount or DRAIN_RATES[action] or 0
    if state.current < drain then
        return false  -- not enough stamina
    end

    state.current = math.max(0, state.current - drain)
    StaminaUpdate:FireClient(player, {
        current = state.current,
        max = state.max,
        action = action,
    })
    return true
end

function StaminaSystem.SetPlayerState(player: Player, key: string, value: any)
    local state = StaminaState[player.UserId]
    if state then
        state[key] = value
    end
end

function StaminaSystem.ApplyBlessingBoost(player: Player)
    local state = StaminaState[player.UserId]
    if state then
        -- Immediate 30% stamina restore
        local boost = state.max * 0.3
        state.current = math.min(state.max, state.current + boost)
        state.blessingBoost = true
        state.blessingBoostExpires = os.time() + 30  -- 30 second recovery boost

        StaminaUpdate:FireClient(player, {
            current = state.current,
            max = state.max,
            action = "blessing_received",
        })
    end
end

-- Main update tick (called from GameManager every frame or heartbeat)
function StaminaSystem.Update(dt: number)
    local now = os.time()

    for userId, state in pairs(StaminaState) do
        local player = Players:GetPlayerByUserId(userId)
        if not player then
            continue
        end

        -- Calculate recovery rate
        local recoveryRate = 0

        if state.isOnGround and not state.isGliding and not state.isFlying then
            recoveryRate = RECOVERY_RATES.ground

            if state.nearReflectionPool then
                recoveryRate = RECOVERY_RATES.reflection_pool
            end

            if state.blessingBoost and now < state.blessingBoostExpires then
                recoveryRate = RECOVERY_RATES.blessing_boost
            elseif state.blessingBoost then
                state.blessingBoost = false
            end

            if state.nearbyPlayerCount >= 3 then
                recoveryRate = recoveryRate * 2
            end
        end

        -- Drain from active actions
        if state.isGliding then
            recoveryRate = -DRAIN_RATES.glide
        elseif state.isFlying then
            recoveryRate = -DRAIN_RATES.flight
        end

        if state.isShielding then
            recoveryRate = recoveryRate - DRAIN_RATES.shield
        end

        -- HALT slowdown
        if state.haltSlowdownActive then
            if now < state.haltSlowdownExpires then
                if recoveryRate > 0 then
                    recoveryRate = recoveryRate * 0.5
                end
            else
                state.haltSlowdownActive = false
            end
        end

        -- Meditation: full restore after 30s
        if state.isMeditating then
            if now - state.meditationStart >= 30 then
                state.current = state.max
                state.isMeditating = false
                StaminaUpdate:FireClient(player, {
                    current = state.current,
                    max = state.max,
                    action = "meditation_complete",
                })
            end
        end

        -- Apply recovery/drain
        if recoveryRate ~= 0 and not state.isMeditating then
            state.current = math.clamp(state.current + recoveryRate * dt, 0, state.max)
        end

        -- HALT check: 45 minutes continuous play
        if not state.haltTriggered then
            local playTime = now - state.sessionPlayStart
            if playTime >= HALT_PLAY_THRESHOLD then
                state.haltTriggered = true
                state.haltSlowdownActive = true
                state.haltSlowdownExpires = now + HALT_SLOW_DURATION

                HALTNotify:FireClient(player, {
                    message = "You've been flying for a while. Even angels need to rest. Take a breather — a Rest Bonus awaits.",
                    haltRestBonus = HALT_REST_BONUS,
                    afkRequired = HALT_REST_AFK_TIME,
                })
            end
        end

        -- HALT rest bonus: 2 min AFK = 5 motes
        if state.haltTriggered and state.isAFK then
            if now - state.afkStart >= HALT_REST_AFK_TIME then
                -- Award rest bonus (done via MoteSystem in GameManager)
                state.haltTriggered = false
                state.sessionPlayStart = now  -- reset timer
                -- Signal GameManager to award rest bonus
                local MoteSystem = require(script.Parent.MoteSystem)
                MoteSystem.AwardMotes(player, HALT_REST_BONUS, "halt_rest_bonus")
            end
        end
    end
end

return StaminaSystem
