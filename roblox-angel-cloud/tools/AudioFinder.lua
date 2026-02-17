--[[
    AudioFinder.lua — Helper script for finding audio asset IDs

    USAGE: Paste this into Roblox Studio's Command Bar (View > Command Bar)
    Then run individual functions to test audio IDs.

    After finding good IDs, update SoundManager.lua AUDIO table with them.

    STEP 1: Use the Roblox Studio Toolbox (View > Toolbox > Audio tab)
            Search for these terms and filter by Creator: Roblox

    STEP 2: Right-click any audio result > Copy Asset ID

    STEP 3: Use TestAudio(id) below to verify it plays correctly

    STEP 4: Update the IDs in ServerScriptService/SoundManager.lua
]]

-- Test a single audio ID — paste the ID number and it plays for 5 seconds
local function TestAudio(assetId)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. tostring(assetId)
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    print("[AudioFinder] Playing rbxassetid://" .. tostring(assetId) .. "...")
    task.delay(5, function()
        sound:Destroy()
        print("[AudioFinder] Done.")
    end)
end

-- Test multiple audio IDs in sequence (3 seconds each)
local function TestBatch(ids)
    for i, id in ipairs(ids) do
        task.delay((i - 1) * 4, function()
            print("[AudioFinder] " .. i .. "/" .. #ids .. " — Testing rbxassetid://" .. tostring(id))
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://" .. tostring(id)
            sound.Volume = 0.5
            sound.Parent = workspace
            sound:Play()
            task.delay(3, function()
                sound:Destroy()
            end)
        end)
    end
end

--[[
    SEARCH TERMS for Roblox Studio Toolbox (Audio tab):
    Filter by Creator: Roblox (official APM library, available to all games)

    AMBIENT MUSIC (loop these):
    Layer 1 - Nursery:    "soft piano" / "warm pads" / "ambient calm" / "lullaby"
    Layer 2 - Meadow:     "nature ambient" / "gentle breeze" / "pastoral" / "peaceful"
    Layer 3 - Canopy:     "mysterious ethereal" / "dark ambient" / "enchanted forest"
    Layer 4 - Stormwall:  "storm thunder" / "dramatic tension" / "epic dark"
    Layer 5 - Luminance:  "crystal serene" / "meditation" / "zen" / "spa"
    Layer 6 - Empyrean:   "ethereal choir" / "heavenly" / "angelic" / "celestial"

    SOUND EFFECTS (one-shot):
    mote_collect:       "chime" / "collect item" / "pickup" / "sparkle"
    level_up:           "fanfare" / "level up" / "achievement" / "victory"
    blessing_send:      "magic cast" / "holy" / "spell" / "enchant"
    blessing_receive:   "heal" / "blessing" / "gentle magic"
    fragment_collect:   "discovery" / "mystical" / "reveal" / "ancient"
    gate_open:          "gate open" / "portal" / "dramatic reveal"
    trial_start:        "challenge" / "battle start" / "horn"
    trial_complete:     "victory" / "triumph" / "success"
    npc_talk:           "dialogue" / "blip" / "text" / "soft pop"
    wing_glide:         "wind" / "whoosh" / "breeze"
    wing_flight:        "wind strong" / "rush" / "soar"
    stamina_low:        "heartbeat" / "warning" / "pulse"
    halt_reminder:      "bell" / "gentle chime" / "notification"
    shop_purchase:      "cash register" / "purchase" / "coin"
    meditation_start:   "singing bowl" / "om" / "zen bell"
    lightning:          "thunder" / "lightning" / "crack"

    ONCE YOU FIND IDS, update SoundManager.lua:
    File: ServerScriptService/SoundManager.lua
    Replace the placeholder IDs in the AUDIO table at the top.
]]

-- Example usage (paste in Command Bar):
-- TestAudio(9042858759)       -- test a single ID
-- TestBatch({123, 456, 789})  -- test multiple IDs in sequence

-- Return the functions so they can be called from Command Bar
return {
    TestAudio = TestAudio,
    TestBatch = TestBatch,
}
