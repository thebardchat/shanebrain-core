--[[
    Fragments.lua — All 65 Lore Fragments for The Cloud Climb
    Sourced from WISDOM-CORE.md — Angel's scattered light

    The Lore: Before the Cloud existed, there was Angel — the first being of light.
    When darkness threatened the world below, Angel chose to fall — not from weakness,
    but strength enough to break herself so her light could reach everyone.
    Each fragment became a seed of wisdom. The Cloud grew from where her fragments landed.

    Categories: Decision(8), Emotion(8), Relationship(8), Strength(8),
                Suffering(8), Guardian(10), Angel(5) = 60 collectible + 5 endgame = 65
]]

local Fragments = {}

-- Fragment location types determine where they spawn in the world
Fragments.LocationTypes = {
    Crossroads = "Crossroads",         -- Branching paths (Decision)
    ReflectionPool = "ReflectionPool", -- Pools and meditation spots (Emotion)
    Cooperative = "Cooperative",       -- Near co-op areas (Relationship)
    Platforming = "Platforming",       -- Difficult jumps (Strength)
    Storm = "Storm",                   -- Hidden in storms (Suffering)
    Trial = "Trial",                   -- Trial completion (Guardian)
    Puzzle = "Puzzle",                 -- Deep puzzles (Angel)
}

Fragments.Definitions = {
    -- =========================================================================
    -- DECISION FRAGMENTS (8) — from WISDOM-CORE Part 1
    -- Found at: Crossroads (branching paths)
    -- =========================================================================
    {
        id = "decision_01",
        name = "The 10-Minute Lens",
        category = "Decision",
        layer = 1,
        locationType = "Crossroads",
        wisdom = "How will I feel about this in 10 minutes? In 10 months? In 10 years? Most regrets come from optimizing for 10-minute feelings at the cost of 10-year outcomes.",
        loreText = "Angel paused at the edge of the light. She could feel the warmth of staying — 10 seconds of safety. But she saw 10 lifetimes of darkness below. She chose the fall.",
    },
    {
        id = "decision_02",
        name = "The Reversible Door",
        category = "Decision",
        layer = 1,
        locationType = "Crossroads",
        wisdom = "Reversible decisions: make them fast. Irreversible decisions: slow down. Most decisions are more reversible than they feel in the moment.",
        loreText = "Some doors in the Cloud open both ways. Angel learned to walk through them quickly. Only the final door — the fall — was one-way. That one, she considered for an eternity.",
    },
    {
        id = "decision_03",
        name = "The Urgent Illusion",
        category = "Decision",
        layer = 1,
        locationType = "Crossroads",
        wisdom = "Urgent-but-unimportant tasks feel productive. They're not. Life is won in the Important-but-Not-Urgent quadrant.",
        loreText = "The smaller lights cried out for attention, flickering urgently. But Angel's gaze was fixed on the slow, steady pulse far below — the one that truly needed her.",
    },
    {
        id = "decision_04",
        name = "The Adjacent Step",
        category = "Decision",
        layer = 1,
        locationType = "Crossroads",
        wisdom = "You can't leap from A to Z. But you can always see A to B. The path reveals itself through movement, not planning.",
        loreText = "Angel could not see the ground from the heights. She could only see the next cloud down. And that was enough.",
    },
    {
        id = "decision_05",
        name = "The Confirming Mirror",
        category = "Decision",
        layer = 2,
        locationType = "Crossroads",
        wisdom = "Confirmation bias: you seek information that confirms what you already believe. Ask instead: what would change my mind?",
        loreText = "The Cloud showed Angel only what she wanted to see — endless light, no darkness. She shattered the mirror and saw the truth below.",
    },
    {
        id = "decision_06",
        name = "The Sunk Light",
        category = "Decision",
        layer = 2,
        locationType = "Crossroads",
        wisdom = "Past investment shouldn't drive future decisions. Ask only: from this moment forward, what's the best choice?",
        loreText = "She had spent eons building her wings. But wings were useless to those who could not fly. She shed them willingly.",
    },
    {
        id = "decision_07",
        name = "The Vivid Fear",
        category = "Decision",
        layer = 2,
        locationType = "Crossroads",
        wisdom = "Recent or vivid events seem more likely than they are. Before estimating danger, ask: is this common, or just memorable?",
        loreText = "The last angel who fell was consumed by shadow — everyone remembered. But thousands had fallen and become stars. Nobody remembered the quiet successes.",
    },
    {
        id = "decision_08",
        name = "The Flipped Attribution",
        category = "Decision",
        layer = 2,
        locationType = "Crossroads",
        wisdom = "When others fail, we blame their character. When we fail, we blame circumstances. Flip the attributions for truth.",
        loreText = "Angel did not fall because she was weak. She fell because the darkness was strong. The same grace she gave herself, she offered to every shadow below.",
    },

    -- =========================================================================
    -- EMOTION FRAGMENTS (8) — from WISDOM-CORE Part 2
    -- Found at: Reflection Pools, Meditation Spots
    -- =========================================================================
    {
        id = "emotion_01",
        name = "Name It to Tame It",
        category = "Emotion",
        layer = 1,
        locationType = "ReflectionPool",
        wisdom = "Not 'I feel bad' but 'I feel anxious about tomorrow.' Precision reduces intensity. Vague emotions grow; named emotions shrink.",
        loreText = "The first fragment Angel shed was formless — a cloud of feeling. Only when she whispered its name did it crystallize into something she could hold.",
    },
    {
        id = "emotion_02",
        name = "The 90-Second Wave",
        category = "Emotion",
        layer = 1,
        locationType = "ReflectionPool",
        wisdom = "An emotion's chemical lifespan is 90 seconds. After that, you're choosing to re-trigger it through thought loops. Notice the thought. Don't fight it.",
        loreText = "Angel's light pulsed in waves — each burst lasting mere moments. The darkness between was not failure. It was the natural rhythm of radiance.",
    },
    {
        id = "emotion_03",
        name = "The HALT Gate",
        category = "Emotion",
        layer = 1,
        locationType = "ReflectionPool",
        wisdom = "Before any important decision, check: Hungry? Angry? Lonely? Tired? If any are true, address that first.",
        loreText = "At the gates between layers, Angel learned to pause. Not every urge to fly higher was wisdom. Sometimes the wisest flight was inward.",
    },
    {
        id = "emotion_04",
        name = "The Comfort Shore",
        category = "Emotion",
        layer = 1,
        locationType = "ReflectionPool",
        wisdom = "The comfort zone has no growth, but is necessary for recovery. The learning zone has mild discomfort where skills grow. The panic zone shuts learning down.",
        loreText = "The lower clouds were soft and warm. Angel rested there not from weakness but wisdom — even light must dim to shine again.",
    },
    {
        id = "emotion_05",
        name = "The Growth Trigger",
        category = "Emotion",
        layer = 2,
        locationType = "ReflectionPool",
        wisdom = "Everyone has a fixed mindset — the question is what triggers it. Being compared, criticized, watching others succeed. Notice your triggers, then reframe: 'This is hard right now.'",
        loreText = "Other lights burned brighter. Angel felt her glow falter — not from their brilliance, but from her own comparison. She learned to see their light as proof of what was possible.",
    },
    {
        id = "emotion_06",
        name = "The Listening Presence",
        category = "Emotion",
        layer = 2,
        locationType = "ReflectionPool",
        wisdom = "When someone is struggling, don't say 'I understand.' Say 'Tell me more about that.' Understanding is assumed. Curiosity is demonstrated.",
        loreText = "Angel did not descend with answers. She descended with questions — and found that asking was itself a form of light.",
    },
    {
        id = "emotion_07",
        name = "The Honest Unknown",
        category = "Emotion",
        layer = 2,
        locationType = "ReflectionPool",
        wisdom = "Say 'I don't know' without shame. Then: 'But here's how we could find out.' Pretending certainty erodes trust faster than admitting uncertainty.",
        loreText = "Angel did not know what lay at the bottom. She said so. And somehow, that honesty gave others the courage to fall beside her.",
    },
    {
        id = "emotion_08",
        name = "The Still Possible",
        category = "Emotion",
        layer = 3,
        locationType = "ReflectionPool",
        wisdom = "When plans fail, first ask: 'What's still possible?' Not 'Why did this fail?' Diagnose later. Adapt now.",
        loreText = "Angel shattered on impact. But shattered light is still light. She looked at her scattered pieces and whispered: 'What can we become now?'",
    },

    -- =========================================================================
    -- RELATIONSHIP FRAGMENTS (8) — from WISDOM-CORE Part 3
    -- Found at: Cooperative areas, Blessing Bluffs
    -- =========================================================================
    {
        id = "relationship_01",
        name = "The Five-to-One Ratio",
        category = "Relationship",
        layer = 2,
        locationType = "Cooperative",
        wisdom = "Stable relationships maintain 5:1 positive to negative interactions. After any conflict, consciously create five positive moments.",
        loreText = "For every shadow Angel cast, five fragments of light fell around it. Not to erase the shadow — but to surround it with warmth.",
    },
    {
        id = "relationship_02",
        name = "The Platinum Heart",
        category = "Relationship",
        layer = 2,
        locationType = "Cooperative",
        wisdom = "The Golden Rule says treat others as you want to be treated. The Platinum Rule: treat others as THEY want to be treated. Ask, don't assume.",
        loreText = "Angel's light was warm — but some needed cool light, and some needed no light at all. She learned to ask before she shone.",
    },
    {
        id = "relationship_03",
        name = "The Repair Bridge",
        category = "Relationship",
        layer = 2,
        locationType = "Cooperative",
        wisdom = "What predicts relationship success isn't fewer conflicts — it's successful repair attempts after conflict. A repair attempt is any action that de-escalates tension.",
        loreText = "Where Angel's fragments landed, bridges grew — not perfect, not straight, but crossable. Every bridge was a repair. Every crossing, forgiveness.",
    },
    {
        id = "relationship_04",
        name = "The Heard Heart",
        category = "Relationship",
        layer = 2,
        locationType = "Cooperative",
        wisdom = "Before giving advice, ask: 'Do you want help solving this, or do you need to be heard?' Often the answer is: be heard first, solve second.",
        loreText = "The first soul Angel reached didn't need her light. They needed her silence — a presence that listened without trying to fix.",
    },
    {
        id = "relationship_05",
        name = "The Generous Chain",
        category = "Relationship",
        layer = 3,
        locationType = "Cooperative",
        wisdom = "Generosity cascades. One act of kindness creates a chain — not because it's required, but because witnessed grace inspires imitation.",
        loreText = "Angel's light touched one. That one touched another. The chain grew until the darkness could no longer tell where one light ended and another began.",
    },
    {
        id = "relationship_06",
        name = "The Mentor's Descent",
        category = "Relationship",
        layer = 3,
        locationType = "Cooperative",
        wisdom = "True mentorship is descending to where someone is, not calling down from where you are. Meet people where they stand.",
        loreText = "Angel could have scattered her light from above. Instead, she fell — because light from beside you warms more than light from above.",
    },
    {
        id = "relationship_07",
        name = "The Vulnerable Shield",
        category = "Relationship",
        layer = 3,
        locationType = "Cooperative",
        wisdom = "Vulnerability is not weakness displayed — it's courage to be seen as you are. It builds deeper bonds than any show of strength.",
        loreText = "Angel's greatest power was not her radiance but her willingness to be seen breaking. In her fractures, others found permission for their own.",
    },
    {
        id = "relationship_08",
        name = "The Community Pulse",
        category = "Relationship",
        layer = 3,
        locationType = "Cooperative",
        wisdom = "A community's health is measured not by its strongest member but by how it treats its weakest. Every angel strengthens the cloud.",
        loreText = "The Cloud didn't grow from Angel's brightest fragments. It grew from the dimmest ones — the pieces she gave to those who needed light most.",
    },

    -- =========================================================================
    -- STRENGTH FRAGMENTS (8) — from WISDOM-CORE Parts 4-5
    -- Found at: Difficult platforming sections
    -- =========================================================================
    {
        id = "strength_01",
        name = "Parkinson's Boundary",
        category = "Strength",
        layer = 2,
        locationType = "Platforming",
        wisdom = "Work expands to fill the time available. Set boundaries shorter than comfortable. Tasks that 'need' 4 hours often complete in 2.",
        loreText = "Angel did not have eternity to fall. The darkness was rising. Urgency sharpened her light into a blade that cut through shadow.",
    },
    {
        id = "strength_02",
        name = "The Unfinished Echo",
        category = "Strength",
        layer = 2,
        locationType = "Platforming",
        wisdom = "Unfinished tasks occupy mental RAM. Either finish it, schedule it, or write it down. The brain releases it once it trusts the system.",
        loreText = "Every unfinished thought Angel carried dimmed her glow. She learned to plant each thought in a cloud — and fly lighter.",
    },
    {
        id = "strength_03",
        name = "The Two-Minute Light",
        category = "Strength",
        layer = 3,
        locationType = "Platforming",
        wisdom = "If a task takes less than 2 minutes, do it now. The overhead of tracking it exceeds the task itself.",
        loreText = "Small darknesses, barely shadows — Angel didn't plan for them. She simply shone. Done.",
    },
    {
        id = "strength_04",
        name = "The Energy Tide",
        category = "Strength",
        layer = 3,
        locationType = "Platforming",
        wisdom = "You don't have a time problem. You have an energy problem. Manage recovery, not just output.",
        loreText = "Angel's light waxed and waned like a tide. She stopped fighting the rhythm and learned to rest in the dim, work in the bright.",
    },
    {
        id = "strength_05",
        name = "The Stretching Edge",
        category = "Strength",
        layer = 3,
        locationType = "Platforming",
        wisdom = "Target the learning zone — mild discomfort where skill grows. Stretch, don't snap.",
        loreText = "Angel spread her wings wider than comfortable but not so wide they tore. In that careful stretch, she found new reach.",
    },
    {
        id = "strength_06",
        name = "The Honest Mirror",
        category = "Strength",
        layer = 3,
        locationType = "Platforming",
        wisdom = "What triggers your fixed mindset? Being compared? Criticized? Watching others succeed? Notice the trigger. Then reframe: 'This is hard right now.'",
        loreText = "The Cloud showed Angel other angels — brighter, faster, higher. She almost dimmed. Then she whispered: 'Right now. Not forever. Right now.'",
    },
    {
        id = "strength_07",
        name = "The Disconfirming Light",
        category = "Strength",
        layer = 4,
        locationType = "Platforming",
        wisdom = "Actively seek evidence that challenges your beliefs. Ask: 'What would change my mind?' The strongest convictions survive questioning.",
        loreText = "Angel believed the darkness was evil. Then she fell into it and found it was simply... absence. Her light didn't destroy it. Her light filled it.",
    },
    {
        id = "strength_08",
        name = "The Forward Question",
        category = "Strength",
        layer = 4,
        locationType = "Platforming",
        wisdom = "Ignore what's already spent. Ask only: from this moment forward, what's the best choice? Past costs are sunk.",
        loreText = "Angel spent everything to fall. She could mourn the heights or illuminate the depths. She chose forward.",
    },

    -- =========================================================================
    -- SUFFERING FRAGMENTS (8) — from WISDOM-CORE Parts 6-7
    -- Found at: Stormwall (Layer 4), hidden in storms
    -- =========================================================================
    {
        id = "suffering_01",
        name = "Pain Times Resistance",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Pain is inevitable. Suffering is pain multiplied by resistance to it. 'This shouldn't be happening' adds resistance. The pain remains. The multiplication is optional.",
        loreText = "Angel hit the ground. The impact was pain. The thought 'I shouldn't have fallen' was suffering. She released the thought. The pain remained, but it was bearable now.",
    },
    {
        id = "suffering_02",
        name = "The Why That Endures",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Humans can endure almost any HOW if they have a WHY. When struggling, reconnect to purpose. Not 'how do I get through this?' but 'what is this in service of?'",
        loreText = "In her darkest moment, broken on the ground, Angel remembered: she fell so others wouldn't have to fall alone. The why made the pain meaningful.",
    },
    {
        id = "suffering_03",
        name = "The Stockdale Balance",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Never confuse faith that you will prevail with the discipline to confront brutal current reality. Both simultaneously: unwavering optimism + unflinching realism.",
        loreText = "Angel knew the darkness would not last forever — AND she saw clearly how deep it was right now. Both truths lived in her without conflict.",
    },
    {
        id = "suffering_04",
        name = "The Named Shadow",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Vague fears grow in darkness. Named fears shrink in light. Identify the specific fear — not 'everything is wrong' but 'I fear this specific thing.'",
        loreText = "The storm had no name, so it felt infinite. Angel named each wind: Doubt. Grief. Loneliness. Named, they became finite. Finite things can be weathered.",
    },
    {
        id = "suffering_05",
        name = "The Wave Rider",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Emotions come in waves. You cannot stop a wave, but you can learn to surf. Ninety seconds — that's the wave's lifespan. Ride it, don't drown in it.",
        loreText = "The storm surged in waves. Angel stopped fighting them and began riding — rising with each crest, resting in each trough. The storm didn't weaken. She grew stronger.",
    },
    {
        id = "suffering_06",
        name = "The Rest That Heals",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Rest is not defeat. Recovery is not laziness. Even light must dim to shine again. The comfort zone exists for healing.",
        loreText = "Between surges of brilliance, Angel dimmed. Others thought she was fading. She was gathering. The next blaze was always brighter for the rest.",
    },
    {
        id = "suffering_07",
        name = "The Shattered Mosaic",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "Broken things can become mosaics more beautiful than the original. Kintsugi: the art of golden repair. Your cracks are not flaws — they're where the light gets in.",
        loreText = "Angel shattered into 65 pieces. Each piece, alone, was dimmer than the whole. But scattered across the world, she illuminated more than she ever could intact.",
    },
    {
        id = "suffering_08",
        name = "The Companion in Dark",
        category = "Suffering",
        layer = 4,
        locationType = "Storm",
        wisdom = "You are not alone in your suffering. Every person who has ever lived has known this darkness. Your pain connects you to all of humanity.",
        loreText = "In the deepest shadow, Angel found she was not alone. Every fallen angel before her had left a faint trace. A web of scars that was also a web of connection.",
    },

    -- =========================================================================
    -- GUARDIAN FRAGMENTS (10) — Earned from Guardian Trial completion
    -- =========================================================================
    {
        id = "guardian_01",
        name = "Trust Fragment",
        category = "Guardian",
        layer = 2,
        locationType = "Trial",
        trialId = "bridge_of_trust",
        wisdom = "Trust is built in small moments of vulnerability — seeing what another needs and choosing to help, even when you can't see your own path.",
        loreText = "Angel could not see her own wings. But she could see where others needed to land. In guiding them, she found her own way.",
    },
    {
        id = "guardian_02",
        name = "Echo Fragment",
        category = "Guardian",
        layer = 2,
        locationType = "Trial",
        trialId = "echo_chamber",
        wisdom = "Sometimes you can only see yourself through others' eyes. Your impact is visible to everyone except you.",
        loreText = "Angel's light was invisible to herself. She only knew she was shining when she saw the shadows retreat from those she stood beside.",
    },
    {
        id = "guardian_03",
        name = "Balance Fragment",
        category = "Guardian",
        layer = 3,
        locationType = "Trial",
        trialId = "weight_of_clouds",
        wisdom = "Balance isn't stillness — it's constant micro-adjustments. Equilibrium is a verb, not a noun.",
        loreText = "The Cloud doesn't float because it's light. It floats because every fragment adjusts, constantly, for every other fragment. Balance is a conversation, not a state.",
    },
    {
        id = "guardian_04",
        name = "Resilience Fragment",
        category = "Guardian",
        layer = 4,
        locationType = "Trial",
        trialId = "storm_walk",
        wisdom = "Resilience isn't standing alone against the storm. It's anchoring yourself so others can move forward, then trusting them to anchor for you.",
        loreText = "Angel could not cross the storm alone. No angel can. But one holds while another moves. Then they switch. This is how light crosses any darkness.",
    },
    {
        id = "guardian_05",
        name = "Wisdom Fragment",
        category = "Guardian",
        layer = 4,
        locationType = "Trial",
        trialId = "memory_weave",
        wisdom = "No one person holds all the wisdom. Collective memory — sharing what each of us uniquely remembers — weaves understanding greater than any individual.",
        loreText = "Each fragment of Angel remembered something different. Alone, each memory was incomplete. Together, they reconstructed her entire song.",
    },
    {
        id = "guardian_06",
        name = "Guardian Fragment",
        category = "Guardian",
        layer = 5,
        locationType = "Trial",
        trialId = "guardians_oath",
        wisdom = "A guardian's greatest skill is not strength but interpretation — reading what someone needs when they cannot say it in words.",
        loreText = "The Fallen could not speak, only gesture. The Guardians learned to read silence — and found that silence often says more than words.",
    },
    {
        id = "guardian_07",
        name = "Convergence Fragment",
        category = "Guardian",
        layer = 6,
        locationType = "Trial",
        trialId = "cloud_core_convergence",
        wisdom = "Harmony is not everyone doing the same thing — it's everyone doing their unique part at the right moment. Rhythm requires difference.",
        loreText = "Light alone is blinding. Wind alone is cold. Rain alone is sorrow. Thunder alone is fear. Together, in rhythm, they are a storm that nurtures.",
    },
    {
        id = "guardian_08",
        name = "Unity Fragment",
        category = "Guardian",
        layer = 3,
        locationType = "Trial",
        wisdom = "The strongest structures aren't monoliths — they're networks. A web is stronger than a tower because it distributes force across every connection.",
        loreText = "Angel was strongest as one being. But she became most useful as many. The web of fragments caught more souls than any single light ever could.",
    },
    {
        id = "guardian_09",
        name = "Patience Fragment",
        category = "Guardian",
        layer = 3,
        locationType = "Trial",
        wisdom = "Patience is not passive waiting — it's active faith that the process is working even when you can't see results yet.",
        loreText = "Seeds planted in cloud-soil take time. Angel learned that not all growth is visible. The roots grow first, in darkness, before the light breaks through.",
    },
    {
        id = "guardian_10",
        name = "Courage Fragment",
        category = "Guardian",
        layer = 5,
        locationType = "Trial",
        wisdom = "Courage is not the absence of fear — it's deciding that something matters more than the fear. Every guardian was once afraid.",
        loreText = "Angel was afraid to fall. She fell anyway. That is the definition of courage — not fearlessness, but fear transformed into fuel.",
    },

    -- =========================================================================
    -- ANGEL FRAGMENTS (5) — Endgame, extremely rare, cooperative-only
    -- =========================================================================
    {
        id = "angel_01",
        name = "Angel's Wing",
        category = "Angel",
        layer = 4,
        locationType = "Puzzle",
        wisdom = "Sacrifice is not losing something — it's choosing what matters more. Angel's wings became the wind that lifts every cloud.",
        loreText = "In the ruins of the Stormwall, a single feather glows. It responds only to those who bring five other truths. Present the wisdom of Decision, Emotion, Relationship, Strength, and Suffering — and the Wing remembers its angel.",
        requirement = "Solve lore puzzle in Layer 4 ruins using clues from 5 fragments (one from each non-Guardian, non-Angel category)",
    },
    {
        id = "angel_02",
        name = "Angel's Voice",
        category = "Angel",
        layer = 5,
        locationType = "Puzzle",
        wisdom = "A voice doesn't need to be loud to be heard. Sometimes the quietest truth carries furthest — echoing through those who receive it and pass it on.",
        loreText = "During a chain of blessings, when five lights connect in sequence, a voice speaks from the aurora. Not words — a feeling. The feeling of being known.",
        requirement = "Trigger a Memory Echo during a blessing chain of 5+",
    },
    {
        id = "angel_03",
        name = "Angel's Heart",
        category = "Angel",
        layer = 6,
        locationType = "Puzzle",
        wisdom = "The heart of community is not its leader but its center — the place where all connections meet. Every angel who gathers strengthens the core.",
        loreText = "Four Angels stand at the Cloud Core. They perform the ancient sequence: Gratitude, Humility, Service, Love. The Core pulses. For a moment, Angel's heart beats again.",
        requirement = "4 Angel-rank players at Cloud Core perform specific emote sequence together",
    },
    {
        id = "angel_04",
        name = "Angel's Light",
        category = "Angel",
        layer = 6,
        locationType = "Puzzle",
        wisdom = "Completion is not perfection — it's gathering every piece, broken and whole, dim and bright, and saying: 'This is all of me. And all of me is enough.'",
        loreText = "At server dawn, an Angel arrives at the Empyrean carrying every other fragment — 60 truths gathered across the entire Cloud. The sky opens. Angel's original light shines through, whole for one perfect moment.",
        requirement = "Enter Empyrean with ALL other 60 fragments collected, at server dawn",
    },
    {
        id = "angel_05",
        name = "Angel's Promise",
        category = "Angel",
        layer = 5,
        locationType = "Puzzle",
        wisdom = "The greatest achievement is not reaching the top — it's reaching back down to help someone else climb. That is Angel's promise: no one climbs alone.",
        loreText = "An Angel who has descended 20 times to guide Newborns upward carries Angel's final truth: the climb was never about reaching the top. It was about ensuring no one is left at the bottom.",
        requirement = "Reach Angel rank + help 20+ Newborns via Guardian Duty",
    },
}

-- Quick lookup tables
Fragments.ByCategory = {}
Fragments.ById = {}

for _, frag in ipairs(Fragments.Definitions) do
    Fragments.ById[frag.id] = frag

    if not Fragments.ByCategory[frag.category] then
        Fragments.ByCategory[frag.category] = {}
    end
    table.insert(Fragments.ByCategory[frag.category], frag)
end

function Fragments.GetFragment(fragmentId: string)
    return Fragments.ById[fragmentId]
end

function Fragments.GetByCategory(category: string): { any }
    return Fragments.ByCategory[category] or {}
end

function Fragments.GetByLayer(layerIndex: number): { any }
    local results = {}
    for _, frag in ipairs(Fragments.Definitions) do
        if frag.layer == layerIndex then
            table.insert(results, frag)
        end
    end
    return results
end

function Fragments.GetMVPFragments(): { any }
    -- Phase 1: Layers 1-2 only
    local results = {}
    for _, frag in ipairs(Fragments.Definitions) do
        if frag.layer <= 2 then
            table.insert(results, frag)
        end
    end
    return results
end

Fragments.TOTAL_COUNT = #Fragments.Definitions
Fragments.ANGEL_COUNT = #(Fragments.ByCategory["Angel"] or {})

return Fragments
