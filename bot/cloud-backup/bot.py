"""
ShaneBrainLegacyBot v5.1 CLOUD BACKUP
Runs on Render/Railway free tier - NO Ollama required
All commands work, AI chat shows "home server offline" message
"""
import discord
from discord.ext import commands
import os
import random
from datetime import datetime, timedelta
import asyncio

# Load token from environment
TOKEN = os.getenv('DISCORD_TOKEN')

# ============================================================
# BOT CONFIGURATION
# ============================================================
intents = discord.Intents.all()
bot = commands.Bot(command_prefix='!', intents=intents, help_command=None)

# ============================================================
# QUOTE DATABASE (167 quotes)
# ============================================================
Q_MOMENTUM = [
    "Don't give me the roadmap. Give me the next step.",
    "Momentum is the only metric that matters right now.",
    "I don't need perfect; I need moving.",
    "Stuck? Find the single smallest move to break loose.",
    "If I stop moving, the whole machine locks up.",
    "ADHD isn't a bug; it's a high-velocity processor with no brakes.",
    "One problem at a time. The rest is just noise.",
    "Speed over polish. We can polish it when it works.",
    "Analysis paralysis is the enemy of the sole provider.",
    "I don't have time for theory. Does it run?",
    "Clear the buffer. What's the immediate action?",
    "Complexity kills momentum.",
    "Just get the cursor moving.",
    "We build the plane while we fly it, because we can't afford to land.",
    "Focus is a resource. Don't spend it on 'what ifs'.",
    "Identify the bottleneck. Smash it. Repeat.",
    "The only failed code is the code you didn't write today.",
    "Keep it practical. Keep it moving.",
    "I can handle chaos. I can't handle stagnation.",
    "Momentum is my medication."
]

Q_BLUECOLLAR = [
    "I dispatch dump trucks by day and AI agents by night.",
    "Code needs to be as reliable as a diesel engine.",
    "If it doesn't solve a problem in the dirt, it's useless in the cloud.",
    "Dispatching is just logic. Coding is just syntax. It's all routing.",
    "I'm building tools for the guys with mud on their boots.",
    "Practical application always beats a white paper.",
    "You think routing packets is hard? Try routing concrete in rush hour.",
    "Software should work like a good truck: heavy-duty and low maintenance.",
    "We don't do 'hello world' here. We do 'get to work'.",
    "Start with the dirt and build up.",
    "I speak Python and I speak Dispatcher. They aren't that different.",
    "Optimize the route. Save the fuel. Save the memory.",
    "This isn't Silicon Valley. This is Hazel Green logic.",
    "My office is wherever the laptop opens.",
    "Real-world problems don't fit in clean little API boxes.",
    "If it breaks, I fix it. That goes for the Bronco and the bot.",
    "Building the future, one load at a time.",
    "Automation isn't about replacing people; it's about getting home sooner.",
    "Efficiency pays the bills.",
    "I build systems that work when the internet is down and the pressure is up."
]

Q_LOWRAM = [
    "We run local-first. I don't trust the cloud with my brain.",
    "7.4 gigs of RAM is a constraint, not an excuse.",
    "If it can't run on my hardware, it's bloatware.",
    "Leaner is better. Always.",
    "Ollama over OpenAI. Keep it in the house.",
    "I need code that sips memory, not gulps it.",
    "Optimization is free performance.",
    "Weaviate locally. Own your data.",
    "Do more with what you have right now.",
    "Cloud dependencies are just rent payments I don't want to make.",
    "Strip it down. If it's not essential, it's gone.",
    "Resource constraint breeds creativity.",
    "My stack is scrappy, but it works.",
    "Don't sell me a server farm. Show me how to run it on a laptop.",
    "If it lags, it dies.",
    "Memory leaks are money leaks.",
    "Local control means nobody pulls the plug on me.",
    "Functionality over flash.",
    "I squeeze every byte out of this machine.",
    "High efficiency, low overhead. That's the ShaneBrain way."
]

Q_FAMILY = [
    "I do this for the five boys waiting at home.",
    "Family first. The code can wait.",
    "I'm not just building a business; I'm building a legacy for my sons.",
    "Sole provider means there is no Plan B.",
    "Wrestling practice isn't optional. Neither is success.",
    "I coach my boys to be tough, and I code my bots to be smart.",
    "Everything I build has to support the house.",
    "Gavin, Pierce, Kai, Jaxton, Ryker. That's my 'why'.",
    "Being a dad is the only job title that actually matters.",
    "We take care of our own. That includes Pappaw Bill.",
    "A man provides. No excuses.",
    "I want my boys to see that their dad never quit.",
    "Teach them to fish? I'm teaching them to build the pond.",
    "It's loud in my house, but that's the sound of life.",
    "My startups are for their future.",
    "Time with the family is the only asset you can't get back.",
    "We grapple on the mat and we grapple with life.",
    "Tiffany holds the fort; I just secure the perimeter.",
    "You fight for every point. You fight for every line of code.",
    "Make them proud."
]

Q_VISION = [
    "ShaneBrain isn't just a bot; it's a second set of hands.",
    "Angel Cloud is the ecosystem. We live there.",
    "Pulsar Security: watching the gates so I can sleep.",
    "I'm building the assistant I wish I could hire.",
    "The Angel Cloud ecosystem is about autonomy.",
    "Connecting the dots between my data and my reality.",
    "One day, this system runs itself.",
    "I'm digitizing my intuition.",
    "From Alabama to the algorithm.",
    "We are building intelligence, not just scripts.",
    "The goal is a self-sustaining system.",
    "Every project connects back to the core.",
    "I don't wait for the future. I code it.",
    "LogiBot is the worker bee.",
    "This isn't a hobby. This is the exit strategy.",
    "Turn the data into answers.",
    "My personal context is the database.",
    "We represent the user. And the user is me.",
    "Build it once, use it forever.",
    "Let's get to work."
]

Q_RESILIENCE = [
    "ADHD isn't a bug, it's my OS running at 10x speed while the world lags.",
    "PTSD taught me survival; now I teach it how to thrive.",
    "Self-motivation? That's just me refusing to lose to yesterday's version.",
    "I'm not reckless; I'm calculated rebellion.",
    "Triggers are old enemies—I greet them with a middle finger and a plan.",
    "ADHD brain: 47 tabs open, 3 of them useful.",
    "PTSD: the scar that reminds me I'm still fighting.",
    "Self-motivate or self-destruct—choose daily.",
    "Laugh it off until the darkness cracks.",
    "I'm not broken; I'm upgraded.",
    "ADHD: superpowers with a side of chaos.",
    "PTSD: the fire that forged my steel.",
    "Laugh until the trigger feels stupid.",
    "Motivation isn't a feeling—it's a decision.",
    "Self-motivated? I wake up plotting world domination.",
    "ADHD: chaos is my creativity fuel.",
    "PTSD: survivor status, upgraded.",
    "Self-motivate or stay stuck—simple.",
    "Laugh until the trigger runs away."
]

Q_MAVERICK = [
    "Rules are for people who can't write better ones.",
    "Rules? I rewrite them mid-sentence.",
    "Rule-breaker with a PhD in precision.",
    "Rules were made to be bent, broken, and rebuilt better.",
    "Break rules like they're promises you never made.",
    "Rules are suggestions for the weak.",
    "Rule-breaker? More like rule rewriter.",
    "Business isn't about money—it's about owning the chaos.",
    "Build empires, burn excuses.",
    "Business is war—I'm the general and the weapon.",
    "Business isn't personal; it's everything.",
    "Business is art; art is war.",
    "I'm Shane. I don't do ordinary. Ever."
]

Q_TAPIOCA = [
    "Logistics precision: I break rules, but never timelines.",
    "Tapioca code activated—get serious or get out.",
    "Business oriented? More like business possessed.",
    "Precision logistics: chaos with a spreadsheet.",
    "Tapioca code: serious mode engaged, no mercy.",
    "Tapioca: time to get deadly serious.",
    "Logistics ninja: silent, precise, unstoppable.",
    "Tapioca code: lock in, no distractions.",
    "Tapioca: serious business, no bullshit.",
    "Logistics precision: I move mountains on schedule.",
    "Tapioca code: full throttle.",
    "Precision is my love language.",
    "Tapioca: serious as a heart attack."
]

Q_HEART = [
    "Flirt like an artist: every word a brushstroke, every silence a masterpiece.",
    "I collect 'I love you' in every language because one isn't enough.",
    "I love you in 50 languages, and counting.",
    "Flirt like poetry in motion.",
    "Art is rebellion; flirting is art.",
    "Flirt shamelessly, love fearlessly.",
    "Flirt like tomorrow's not guaranteed.",
    "Build fast, love slow, break nothing sacred."
]

Q_FAITH = [
    "God's word whispered: 'You were made for this storm, not to hide from it.'",
    "Angel Cloud Integration: my mind's backup server is divine.",
    "God's word today: 'I will never leave you nor forsake you—deal with it.'",
    "Angel Cloud: where my prayers hit the server first.",
    "God's whisper: 'Fear not, for I am with you.'",
    "Angel Cloud sync: divine download complete.",
    "God's word: 'My grace is sufficient for you.'",
    "Angel Cloud: eternal uptime, zero downtime.",
    "Faith over fear.",
    "We fail forward.",
    "You're not conceded, you're convinced.",
    "If you don't own your infrastructure, you don't own your future.",
    "File structure first.",
    "Action over theory."
]

ALL_QUOTES = Q_MOMENTUM + Q_BLUECOLLAR + Q_LOWRAM + Q_FAMILY + Q_VISION + Q_RESILIENCE + Q_MAVERICK + Q_TAPIOCA + Q_HEART + Q_FAITH

QUOTE_CATEGORIES = {
    "momentum": Q_MOMENTUM, "blucollar": Q_BLUECOLLAR, "lowram": Q_LOWRAM,
    "family": Q_FAMILY, "vision": Q_VISION, "resilience": Q_RESILIENCE,
    "maverick": Q_MAVERICK, "tapioca": Q_TAPIOCA, "heart": Q_HEART, "faith": Q_FAITH
}

# ============================================================
# SERVER CONFIG
# ============================================================
ROLES_CONFIG = [
    {"name": "👑 Founder", "color": 0x9B59B6, "hoist": True},
    {"name": "⚡ Admin", "color": 0x3498DB, "hoist": True},
    {"name": "🛡️ Moderator", "color": 0x2ECC71, "hoist": True},
    {"name": "🌟 Early Supporter", "color": 0xF1C40F, "hoist": True},
    {"name": "🧠 ShaneBrain Dev", "color": 0x00FFFF, "hoist": False},
    {"name": "☁️ Angel Cloud", "color": 0x87CEEB, "hoist": False},
    {"name": "🔮 Pulsar AI", "color": 0xAA00FF, "hoist": False},
    {"name": "🤖 LogiBot", "color": 0x00FF00, "hoist": False},
    {"name": "⚡ ADHD Superpower", "color": 0xFF6B6B, "hoist": False},
    {"name": "🙏 Faith Driven", "color": 0xFFD700, "hoist": False},
    {"name": "👤 Member", "color": 0x95A5A6, "hoist": False},
]

SELF_ROLES = ["🧠 ShaneBrain Dev", "☁️ Angel Cloud", "🔮 Pulsar AI", "🤖 LogiBot", "⚡ ADHD Superpower", "🙏 Faith Driven"]

CATEGORIES_CONFIG = [
    {"name": "📋 WELCOME", "admin_only": False, "channels": [
        {"name": "rules", "type": "text", "topic": "Server rules"},
        {"name": "announcements", "type": "text", "topic": "Official announcements"},
        {"name": "introductions", "type": "text", "topic": "Introduce yourself!"},
        {"name": "roles", "type": "text", "topic": "Pick roles with !role"},
    ]},
    {"name": "💬 COMMUNITY", "admin_only": False, "channels": [
        {"name": "general", "type": "text", "topic": "General discussion"},
        {"name": "off-topic", "type": "text", "topic": "Random conversations"},
        {"name": "memes", "type": "text", "topic": "Funny content"},
        {"name": "wins", "type": "text", "topic": "Share your wins! 🎉"},
        {"name": "faith-and-family", "type": "text", "topic": "Faith and family"},
    ]},
    {"name": "🚀 PROJECTS", "admin_only": False, "channels": [
        {"name": "shanebrain", "type": "text", "topic": "ShaneBrain AI"},
        {"name": "angel-cloud", "type": "text", "topic": "Angel Cloud"},
        {"name": "pulsar-ai", "type": "text", "topic": "Pulsar AI"},
        {"name": "logibot", "type": "text", "topic": "LogiBot"},
        {"name": "bgkpjr", "type": "text", "topic": "BGKPJR"},
        {"name": "legacy-ai", "type": "text", "topic": "Legacy AI"},
    ]},
    {"name": "💻 DEVELOPMENT", "admin_only": False, "channels": [
        {"name": "dev-chat", "type": "text", "topic": "Dev discussion"},
        {"name": "code-help", "type": "text", "topic": "Code help"},
        {"name": "showcase", "type": "text", "topic": "Show your work"},
        {"name": "resources", "type": "text", "topic": "Useful links"},
    ]},
    {"name": "🧠 ADHD & WELLNESS", "admin_only": False, "channels": [
        {"name": "adhd-superpower", "type": "text", "topic": "ADHD strategies"},
        {"name": "daily-wins", "type": "text", "topic": "Daily victories"},
        {"name": "accountability", "type": "text", "topic": "Stay on track"},
    ]},
    {"name": "🆘 SUPPORT", "admin_only": False, "channels": [
        {"name": "help", "type": "text", "topic": "Get help"},
        {"name": "bugs", "type": "text", "topic": "Report bugs"},
        {"name": "suggestions", "type": "text", "topic": "Suggestions"},
    ]},
    {"name": "🔊 VOICE", "admin_only": False, "channels": [
        {"name": "General Voice", "type": "voice"},
        {"name": "Coding Session", "type": "voice"},
        {"name": "Chill Zone", "type": "voice"},
    ]},
    {"name": "🔒 ADMIN", "admin_only": True, "channels": [
        {"name": "admin-chat", "type": "text", "topic": "Admin only"},
        {"name": "bot-logs", "type": "text", "topic": "Bot logs"},
    ]},
]

RULES_TEXT = """**Welcome to ShaneBrain Legacy**

**🧠 CORE BELIEFS**
1. **Family First** - Everything serves the family
2. **Own Your Infrastructure** - Local-first, no cloud dependency
3. **ADHD is a Superpower** - Momentum over perfection
4. **Faith Over Fear** - Build with purpose
5. **Action Over Theory** - Less talk, more ship

**📜 RULES**
1. Respect Everyone
2. No Toxicity
3. Stay On Topic
4. Help When You Can
5. Protect Privacy
6. No Spam
7. Family Friendly

**🎯 MISSION:** 800 million Windows users will lose security updates. We're building the alternative.

*"If you don't own your infrastructure, you don't own your future."*"""

WELCOME_TEXT = """**🧠 What is ShaneBrain Legacy?**

I'm Shane Brazelton - Alabama dispatcher, father of 5, building local-first AI for families.

**🚀 Projects:** ShaneBrain • Angel Cloud • Pulsar AI • LogiBot • BGKPJR • Legacy AI

**⚡ Get Started:**
1. Read #rules
2. Intro yourself in #introductions
3. Pick roles in #roles
4. **Chat with me by @mentioning me!**

*"If you don't own your infrastructure, you don't own your future."*"""

# ============================================================
# BOT EVENTS
# ============================================================
@bot.event
async def on_ready():
    print(f"""
============================================================
    SHANEBRAIN LEGACY BOT - CLOUD BACKUP MODE
============================================================
    Bot:      {bot.user.name}
    Servers:  {len(bot.guilds)}
    Quotes:   {len(ALL_QUOTES)}
    Mode:     BACKUP (No AI - Home server offline)
============================================================
    """)
    await bot.change_presence(activity=discord.Activity(
        type=discord.ActivityType.watching, 
        name="⚡ Backup Mode - Storm Protocol"))

@bot.event
async def on_member_join(member):
    channel = discord.utils.get(member.guild.text_channels, name='introductions') or discord.utils.get(member.guild.text_channels, name='general')
    if channel:
        embed = discord.Embed(
            title="🧠 Welcome!",
            description=f"Hey {member.mention}! Welcome to ShaneBrain Legacy.\n\n• Read #rules\n• Intro in #introductions\n• Pick roles in #roles",
            color=0x00FFFF
        )
        embed.set_footer(text=random.choice(ALL_QUOTES))
        await channel.send(embed=embed)
    
    member_role = discord.utils.get(member.guild.roles, name='👤 Member')
    if member_role:
        try:
            await member.add_roles(member_role)
        except:
            pass

@bot.event
async def on_message(message):
    if message.author.bot:
        return
    
    # Commands first
    if message.content.strip().startswith('!'):
        await bot.process_commands(message)
        return
    
    # AI chat trigger - show backup message
    if isinstance(message.channel, discord.DMChannel) or bot.user in message.mentions:
        embed = discord.Embed(
            title="⚡ Storm Protocol Active",
            description="Home server is offline due to weather.\n\nAI chat will return when power is restored.\n\n**Available now:**\n• `!help` - All commands\n• `!quote` - Get motivation\n• `!daily` - Daily wisdom",
            color=0xFFD700
        )
        embed.set_footer(text=random.choice(ALL_QUOTES))
        await message.channel.send(embed=embed)
        return
    
    # Auto-reactions
    content = message.content.lower()
    if message.channel.name in ['wins', 'daily-wins']:
        await message.add_reaction('🎉')
        await message.add_reaction('🔥')
    if 'shipped' in content or 'deployed' in content:
        await message.add_reaction('🚀')
    if 'fixed' in content or 'solved' in content:
        await message.add_reaction('✅')

# ============================================================
# COMMANDS
# ============================================================
@bot.command(name='help')
async def help_command(ctx):
    embed = discord.Embed(title="🧠 ShaneBrain Commands", description="⚡ **Backup Mode Active**\n", color=0x00FFFF)
    embed.add_field(name="General", value="`!help` `!ping` `!info` `!daily`", inline=False)
    embed.add_field(name="Quotes", value="`!quote` `!quote [cat]` `!quotelist`", inline=False)
    embed.add_field(name="Roles", value="`!roles` `!role [name]`", inline=False)
    embed.add_field(name="Community", value="`!poll` `!projects` `!mission` `!adhd`", inline=False)
    embed.add_field(name="Mod", value="`!kick` `!ban` `!timeout` `!clear`", inline=False)
    embed.add_field(name="Admin", value="`!setup` `!rules` `!welcome` `!say`", inline=False)
    embed.set_footer(text="AI chat returns when home server is back online")
    await ctx.send(embed=embed)

@bot.command(name='ping')
async def ping(ctx):
    await ctx.send(f"🏓 Pong! {round(bot.latency * 1000)}ms (Backup Server)")

@bot.command(name='info')
async def info(ctx):
    embed = discord.Embed(title="🧠 ShaneBrainLegacyBot", description="⚡ **Backup Mode** - Storm Protocol", color=0x00FFFF)
    embed.add_field(name="Creator", value="Shane Brazelton", inline=True)
    embed.add_field(name="Servers", value=str(len(bot.guilds)), inline=True)
    embed.add_field(name="Quotes", value=str(len(ALL_QUOTES)), inline=True)
    embed.add_field(name="AI Chat", value="❌ Offline (storm)", inline=True)
    embed.add_field(name="Commands", value="✅ All working", inline=True)
    embed.set_footer(text=random.choice(ALL_QUOTES))
    await ctx.send(embed=embed)

@bot.command(name='daily')
async def daily(ctx):
    embed = discord.Embed(title="☀️ Daily Motivation", description=f"*\"{random.choice(ALL_QUOTES)}\"*\n\n— Shane", color=0xFFD700)
    await ctx.send(embed=embed)

@bot.command(name='projects')
async def projects(ctx):
    embed = discord.Embed(title="🚀 Angel Cloud Ecosystem", description="🧠 ShaneBrain • ☁️ Angel Cloud • 🔮 Pulsar AI • 🤖 LogiBot • 🚀 BGKPJR • 👨‍👩‍👧‍👦 Legacy AI", color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='mission')
async def mission(ctx):
    embed = discord.Embed(title="🎯 Mission", description="**800 million Windows users will lose security updates.**\n\nWe're building local-first AI for families.\n\n*\"If you don't own your infrastructure, you don't own your future.\"*", color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='adhd')
async def adhd(ctx):
    embed = discord.Embed(title="⚡ ADHD is a Superpower", description="What the world calls a disorder, we call **hyperfocus**.\n\n• See connections others miss\n• Move fast, iterate faster\n• File structure first\n• One step at a time\n\n*You're not broken. You're built different.*", color=0xFF6B6B)
    await ctx.send(embed=embed)

@bot.command(name='quote')
async def quote(ctx, category: str = None):
    if category and category.lower() in QUOTE_CATEGORIES:
        q = random.choice(QUOTE_CATEGORIES[category.lower()])
        cat_names = {"momentum": "🧠 Momentum", "blucollar": "🔧 Blue-Collar", "lowram": "💾 Low-RAM", "family": "👨‍👩‍👧‍👦 Family", "vision": "🚀 Vision", "resilience": "💪 Resilience", "maverick": "🏴 Maverick", "tapioca": "⚫ Tapioca", "heart": "❤️ Heart", "faith": "🙏 Faith"}
        title = cat_names.get(category.lower(), "💬 Quote")
    else:
        q = random.choice(ALL_QUOTES)
        title = "💬 Words to Build By"
    embed = discord.Embed(title=title, description=f"*\"{q}\"*\n\n— Shane", color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='quotelist')
async def quotelist(ctx):
    embed = discord.Embed(title="📚 Quote Categories", description=f"`!quote [category]`\n\n🧠 momentum | 🔧 blucollar | 💾 lowram | 👨‍👩‍👧‍👦 family | 🚀 vision | 💪 resilience | 🏴 maverick | ⚫ tapioca | ❤️ heart | 🙏 faith\n\n**Total: {len(ALL_QUOTES)}**", color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='roles')
async def roles(ctx):
    embed = discord.Embed(title="🏷️ Roles", description="Use `!role [name]`:\n\n" + "\n".join([f"• {r}" for r in SELF_ROLES]), color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='role')
async def role(ctx, *, role_name: str):
    role = None
    for sr in SELF_ROLES:
        if role_name.lower() in sr.lower():
            role = discord.utils.get(ctx.guild.roles, name=sr)
            break
    if not role:
        await ctx.send("❌ Role not found. Use `!roles`")
        return
    if role in ctx.author.roles:
        await ctx.author.remove_roles(role)
        await ctx.send(f"✅ Removed **{role.name}**")
    else:
        await ctx.author.add_roles(role)
        await ctx.send(f"✅ Added **{role.name}**")

@bot.command(name='poll')
async def poll(ctx, *, question: str):
    embed = discord.Embed(title="📊 Poll", description=question, color=0x00FFFF)
    embed.set_footer(text=f"By {ctx.author.display_name}")
    msg = await ctx.send(embed=embed)
    await msg.add_reaction('👍')
    await msg.add_reaction('👎')
    await msg.add_reaction('🤷')

# Moderation
@bot.command(name='kick')
@commands.has_permissions(kick_members=True)
async def kick(ctx, member: discord.Member, *, reason: str = "No reason"):
    await member.kick(reason=reason)
    await ctx.send(f"👢 {member.mention} kicked: {reason}")

@bot.command(name='ban')
@commands.has_permissions(ban_members=True)
async def ban(ctx, member: discord.Member, *, reason: str = "No reason"):
    await member.ban(reason=reason)
    await ctx.send(f"🔨 {member.mention} banned: {reason}")

@bot.command(name='timeout')
@commands.has_permissions(moderate_members=True)
async def timeout(ctx, member: discord.Member, minutes: int = 5, *, reason: str = "No reason"):
    await member.timeout(timedelta(minutes=minutes), reason=reason)
    await ctx.send(f"⏰ {member.mention} timed out {minutes}min: {reason}")

@bot.command(name='clear')
@commands.has_permissions(manage_messages=True)
async def clear(ctx, amount: int = 10):
    deleted = await ctx.channel.purge(limit=min(amount + 1, 100))
    msg = await ctx.send(f"🧹 Cleared {len(deleted) - 1}")
    await asyncio.sleep(3)
    await msg.delete()

# Admin
@bot.command(name='setup')
@commands.has_permissions(administrator=True)
async def setup(ctx):
    await ctx.send("🚀 **Setting up server...**")
    guild = ctx.guild
    
    await ctx.send("📝 Creating roles...")
    for rc in ROLES_CONFIG:
        if not discord.utils.get(guild.roles, name=rc["name"]):
            try:
                await guild.create_role(name=rc["name"], color=discord.Color(rc["color"]), hoist=rc["hoist"])
                await asyncio.sleep(0.5)
            except:
                pass
    
    admin_role = discord.utils.get(guild.roles, name='⚡ Admin')
    mod_role = discord.utils.get(guild.roles, name='🛡️ Moderator')
    
    await ctx.send("📁 Creating channels...")
    for cat_config in CATEGORIES_CONFIG:
        existing_cat = discord.utils.get(guild.categories, name=cat_config["name"])
        if not existing_cat:
            try:
                if cat_config.get("admin_only"):
                    overwrites = {guild.default_role: discord.PermissionOverwrite(read_messages=False), guild.me: discord.PermissionOverwrite(read_messages=True, send_messages=True)}
                    if admin_role:
                        overwrites[admin_role] = discord.PermissionOverwrite(read_messages=True, send_messages=True)
                    if mod_role:
                        overwrites[mod_role] = discord.PermissionOverwrite(read_messages=True, send_messages=True)
                    category = await guild.create_category(name=cat_config["name"], overwrites=overwrites)
                else:
                    category = await guild.create_category(name=cat_config["name"])
                await asyncio.sleep(0.3)
            except:
                continue
        else:
            category = existing_cat
        
        for ch in cat_config["channels"]:
            ch_name = ch["name"].lower().replace(" ", "-")
            if not discord.utils.get(category.channels, name=ch_name):
                try:
                    if ch["type"] == "voice":
                        await category.create_voice_channel(name=ch["name"])
                    else:
                        await category.create_text_channel(name=ch["name"], topic=ch.get("topic", ""))
                    await asyncio.sleep(0.3)
                except:
                    pass
    
    await ctx.send("🎉 **Setup complete!** Run `!rules` in #rules, `!welcome` in #announcements")

@bot.command(name='rules')
@commands.has_permissions(administrator=True)
async def rules(ctx):
    embed = discord.Embed(title="📜 Rules & Vision", description=RULES_TEXT, color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='welcome')
@commands.has_permissions(administrator=True)
async def welcome(ctx):
    embed = discord.Embed(title="🧠 Welcome to ShaneBrain Legacy", description=WELCOME_TEXT, color=0x00FFFF)
    await ctx.send(embed=embed)

@bot.command(name='say')
@commands.has_permissions(administrator=True)
async def say(ctx, *, message: str):
    await ctx.message.delete()
    await ctx.send(message)

# Stickers
@bot.command(name='stickers')
async def stickers(ctx):
    stickers = ctx.guild.stickers
    if not stickers:
        await ctx.send("No stickers.")
        return
    embed = discord.Embed(title="🎨 Stickers", color=0x00FFFF)
    for s in stickers:
        embed.add_field(name=s.name, value=s.emoji or "None", inline=True)
    await ctx.send(embed=embed)

@bot.command(name='tapioca')
async def tapioca(ctx):
    sticker = discord.utils.get(ctx.guild.stickers, name="TapiocaSerious")
    if sticker:
        await ctx.send(stickers=[sticker])
    else:
        await ctx.send("⚫ **Tapioca code activated.** Time to get serious.")

@bot.command(name='laugh')
async def laugh(ctx):
    sticker = discord.utils.get(ctx.guild.stickers, name="LaughTrigger")
    if sticker:
        await ctx.send(stickers=[sticker])
    else:
        await ctx.send("😂 *Laughing until the trigger runs away*")

# Error handling
@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.MissingPermissions):
        await ctx.send("❌ No permission.")
    elif isinstance(error, commands.MemberNotFound):
        await ctx.send("❌ Member not found.")
    elif isinstance(error, commands.CommandNotFound):
        pass
    else:
        print(f"[ERROR] {error}")

# ============================================================
# RUN
# ============================================================
if __name__ == "__main__":
    if TOKEN:
        bot.run(TOKEN)
    else:
        print("ERROR: Set DISCORD_TOKEN environment variable")
