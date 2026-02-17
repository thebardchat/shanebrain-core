--[[
    Trials.lua — Guardian Trial definitions for The Cloud Climb
    7 cooperative mini-games that require communication and teamwork
]]

local Trials = {}

Trials.Definitions = {
    {
        id = "bridge_of_trust",
        name = "Bridge of Trust",
        trialNumber = 1,
        minLayer = 2,
        players = { min = 2, max = 2 },
        moteReward = 3,
        fragmentReward = "Trust Fragment",
        fragmentCategory = "Guardian",
        description = "Each player sees where the OTHER's bridge pieces should go. "
            .. "You must communicate to build the bridge together.",
        mechanic = "asymmetric_information",
        duration = 120,  -- seconds
        rules = {
            "Player A sees Player B's piece placement guides (and vice versa)",
            "Use chat to describe positions to your partner",
            "Bridge must connect both sides within time limit",
            "Falling resets your side only",
        },
    },
    {
        id = "echo_chamber",
        name = "Echo Chamber",
        trialNumber = 2,
        minLayer = 2,
        players = { min = 2, max = 3 },
        moteReward = 3,
        fragmentReward = "Echo Fragment",
        fragmentCategory = "Guardian",
        description = "A dark room where sounds create light — "
            .. "but you can only see light from OTHERS' sounds.",
        mechanic = "mutual_visibility",
        duration = 90,
        rules = {
            "Room is dark — you cannot see your own light",
            "Pressing action key creates a sound pulse visible to others",
            "Guide each other to the central resonance crystal",
            "All players must reach the crystal within 10 seconds of each other",
        },
    },
    {
        id = "weight_of_clouds",
        name = "Weight of Clouds",
        trialNumber = 3,
        minLayer = 3,
        players = { min = 3, max = 3 },
        moteReward = 4,
        fragmentReward = "Balance Fragment",
        fragmentCategory = "Guardian",
        description = "Three descending platforms — distribute weight to keep them level.",
        mechanic = "balance_coordination",
        duration = 120,
        rules = {
            "Three platforms slowly descend at different rates",
            "Player weight affects descent speed",
            "Move between platforms to keep all three level",
            "If any platform touches the void, trial fails",
            "Survive for full duration to win",
        },
    },
    {
        id = "storm_walk",
        name = "Storm Walk",
        trialNumber = 4,
        minLayer = 4,
        players = { min = 2, max = 4 },
        moteReward = 5,
        fragmentReward = "Resilience Fragment",
        fragmentCategory = "Guardian",
        description = "Cross a storm via relay chain — "
            .. "anchor while others push forward against the wind.",
        mechanic = "relay_anchor",
        duration = 180,
        rules = {
            "Strong wind pushes all players backward",
            "One player can anchor (hold action key) to resist wind",
            "Anchored player creates a safe zone behind them",
            "Leapfrog forward: front anchors, rear advances past",
            "All players must reach the calm eye of the storm",
        },
    },
    {
        id = "memory_weave",
        name = "Memory Weave",
        trialNumber = 5,
        minLayer = 4,
        players = { min = 3, max = 4 },
        moteReward = 5,
        fragmentReward = "Wisdom Fragment",
        fragmentCategory = "Guardian",
        description = "Solo symbol sequences, then reconstruct ALL sequences together from memory.",
        mechanic = "collective_memory",
        duration = 150,
        rules = {
            "Phase 1: Each player shown a unique 4-symbol sequence (30 seconds)",
            "Phase 2: Symbols disappear — players must recreate ALL sequences on a shared board",
            "Each player can only remember their own sequence",
            "Must communicate and coordinate to place all symbols correctly",
            "One attempt — wrong placement fails the trial",
        },
    },
    {
        id = "guardians_oath",
        name = "Guardian's Oath",
        trialNumber = 6,
        minLayer = 5,
        players = { min = 4, max = 4 },
        moteReward = 8,
        fragmentReward = "Guardian Fragment",
        fragmentCategory = "Guardian",
        description = "Rescue 'the Fallen' from a pit — "
            .. "they can only communicate via emotes.",
        mechanic = "limited_communication",
        duration = 240,
        rules = {
            "One random player becomes 'the Fallen' — trapped in a pit",
            "The Fallen cannot use chat, only emote gestures",
            "Three Guardians must solve environmental puzzles above",
            "The Fallen can see clues invisible to Guardians",
            "Guardians must interpret emotes to find the solution",
            "Freeing the Fallen completes the trial for all",
        },
    },
    {
        id = "cloud_core_convergence",
        name = "Cloud Core Convergence",
        trialNumber = 7,
        minLayer = 6,
        players = { min = 4, max = 4 },
        moteReward = 15,
        fragmentReward = "Angel Fragment",
        fragmentCategory = "Angel",
        description = "Synchronize 4 elements (Light/Wind/Rain/Thunder) in rhythm "
            .. "to trigger server-wide Blessing Rain.",
        mechanic = "rhythm_sync",
        duration = 300,
        rules = {
            "All 4 players must be Angel rank",
            "Each player controls one element: Light, Wind, Rain, Thunder",
            "A rhythm pattern plays — each element has its beat",
            "Press action key on YOUR element's beat",
            "Must maintain sync for 60 consecutive seconds",
            "Success triggers Blessing Rain for entire server",
            "Rewards Angel Fragment (extremely rare)",
        },
    },
}

-- Phase 1 MVP: only trials 1-2 are available
Trials.MVP_TRIAL_IDS = { "bridge_of_trust", "echo_chamber" }

function Trials.GetTrial(trialId: string)
    for _, trial in ipairs(Trials.Definitions) do
        if trial.id == trialId then
            return trial
        end
    end
    return nil
end

function Trials.GetAvailableTrials(layerIndex: number): { any }
    local available = {}
    for _, trial in ipairs(Trials.Definitions) do
        if trial.minLayer <= layerIndex then
            table.insert(available, trial)
        end
    end
    return available
end

return Trials
