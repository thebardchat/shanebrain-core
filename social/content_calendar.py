"""
7-day themed content calendar for ShaneBrain Social Bot.
Each day has a theme, mood, and example topics to guide content generation.
"""

from datetime import datetime

# Day-of-week themed calendar (Monday=0, Sunday=6)
CALENDAR = [
    {
        "day": "Monday",
        "theme": "Mission Monday",
        "mood": "motivational and purposeful",
        "topics": [
            "why I'm building Angel Cloud",
            "the mission to help 800 million families",
            "local AI vs Big Tech",
            "what drives me as a builder",
        ],
    },
    {
        "day": "Tuesday",
        "theme": "Tech Tuesday",
        "mood": "excited and educational",
        "topics": [
            "Raspberry Pi AI progress",
            "what I learned about Weaviate/Ollama",
            "building on a budget",
            "local-first infrastructure wins",
        ],
    },
    {
        "day": "Wednesday",
        "theme": "Wisdom Wednesday",
        "mood": "reflective and honest",
        "topics": [
            "lessons from dispatch life",
            "sobriety and growth",
            "ADHD as a superpower",
            "things I wish I knew earlier",
        ],
    },
    {
        "day": "Thursday",
        "theme": "Thankful Thursday",
        "mood": "grateful and warm",
        "topics": [
            "people who believed in me",
            "small wins this week",
            "my kids teaching me patience",
            "community support",
        ],
    },
    {
        "day": "Friday",
        "theme": "Family Friday",
        "mood": "lighthearted and real",
        "topics": [
            "dad of 5 moments",
            "chaos and joy of a big family",
            "balancing work and family",
            "funny kid stories",
        ],
    },
    {
        "day": "Saturday",
        "theme": "Side Hustle Saturday",
        "mood": "entrepreneurial and grounded",
        "topics": [
            "building revenue streams",
            "Angel Arcade progress",
            "dispatch + tech hustle",
            "making it work with what you have",
        ],
    },
    {
        "day": "Sunday",
        "theme": "Family Sunday",
        "mood": "peaceful and faith-connected",
        "topics": [
            "faith and family time",
            "recharging for the week",
            "what matters most",
            "legacy thinking",
        ],
    },
]


def get_todays_theme(dt=None):
    """Get the theme for today (or a given datetime)."""
    dt = dt or datetime.now()
    return CALENDAR[dt.weekday()]


def get_theme_for_day(day_name: str):
    """Get the theme for a named day (e.g. 'Monday')."""
    for entry in CALENDAR:
        if entry["day"].lower() == day_name.lower():
            return entry
    return None


def get_weekly_preview():
    """Return a formatted preview of the full week's themes."""
    lines = []
    for entry in CALENDAR:
        lines.append(f"  {entry['day']}: {entry['theme']} ({entry['mood']})")
    return "\n".join(lines)
