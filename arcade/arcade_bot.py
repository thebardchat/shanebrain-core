"""
Angel Arcade - Discord Economy & Casino Bot
============================================
Revenue generator for ShaneBrain Legacy
Built by Shane Brazelton & Claude

Features:
- Virtual currency (AngelCoins)
- Gambling games (slots, coinflip, blackjack, roulette)
- Premium tier support (via Ko-fi Discord role)
- Server customization
- Leaderboards

Deploy: python arcade_bot.py
"""
import discord
from discord.ext import commands
from discord import app_commands
import sqlite3
import random
import asyncio
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv
import json

# ============================================================
# PATHS - Use absolute paths
# ============================================================
ARCADE_ROOT = r"D:\Angel_Cloud\shanebrain-core\arcade"
DB_PATH = os.path.join(ARCADE_ROOT, "data", "arcade.db")

load_dotenv(os.path.join(ARCADE_ROOT, ".env"))
TOKEN = os.getenv('ARCADE_TOKEN') or os.getenv('DISCORD_TOKEN')

# ============================================================
# CONFIGURATION
# ============================================================
CURRENCY_NAME = "AngelCoins"
CURRENCY_EMOJI = "🪙"
BOT_COLOR = 0xFFD700  # Gold

# Ko-fi link
KOFI_LINK = "https://ko-fi.com/shanebrain"

# Premium role names (case-insensitive, checks if role contains these)
PREMIUM_ROLE_KEYWORDS = ["arcade premium", "premium", "supporter", "vip"]

# Cooldowns (in seconds)
DAILY_COOLDOWN = 72000  # 20 hours
WORK_COOLDOWN = 1800    # 30 min (5 min for premium)
WORK_COOLDOWN_PREMIUM = 300

# Bet limits
MAX_BET_FREE = 500
MAX_BET_PREMIUM = 50000

# ============================================================
# DATABASE SETUP
# ============================================================
def init_db():
    """Initialize SQLite database"""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    # Users table
    c.execute('''CREATE TABLE IF NOT EXISTS users (
        user_id INTEGER PRIMARY KEY,
        balance INTEGER DEFAULT 100,
        bank INTEGER DEFAULT 0,
        daily_streak INTEGER DEFAULT 0,
        last_daily TEXT,
        last_work TEXT,
        total_won INTEGER DEFAULT 0,
        total_lost INTEGER DEFAULT 0,
        games_played INTEGER DEFAULT 0,
        is_premium INTEGER DEFAULT 0,
        premium_expires TEXT,
        prestige INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )''')
    
    # Transactions log
    c.execute('''CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        type TEXT,
        amount INTEGER,
        balance_after INTEGER,
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
        details TEXT
    )''')
    
    # Server settings
    c.execute('''CREATE TABLE IF NOT EXISTS servers (
        server_id INTEGER PRIMARY KEY,
        currency_name TEXT DEFAULT 'AngelCoins',
        currency_emoji TEXT DEFAULT '🪙',
        is_premium INTEGER DEFAULT 0,
        premium_expires TEXT,
        daily_bonus INTEGER DEFAULT 100,
        work_min INTEGER DEFAULT 50,
        work_max INTEGER DEFAULT 150
    )''')
    
    conn.commit()
    conn.close()
    print(f"[DB] Database initialized at {DB_PATH}")

# ============================================================
# DATABASE HELPERS
# ============================================================
def get_db():
    return sqlite3.connect(DB_PATH)

def get_user(user_id: int) -> dict:
    """Get user data, create if doesn't exist"""
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM users WHERE user_id = ?', (user_id,))
    row = c.fetchone()
    
    if not row:
        c.execute('INSERT INTO users (user_id, created_at) VALUES (?, ?)', 
                  (user_id, datetime.now().isoformat()))
        conn.commit()
        c.execute('SELECT * FROM users WHERE user_id = ?', (user_id,))
        row = c.fetchone()
    
    conn.close()
    
    columns = ['user_id', 'balance', 'bank', 'daily_streak', 'last_daily', 
               'last_work', 'total_won', 'total_lost', 'games_played',
               'is_premium', 'premium_expires', 'prestige', 'created_at']
    return dict(zip(columns, row))

def update_user(user_id: int, **kwargs):
    """Update user fields"""
    conn = get_db()
    c = conn.cursor()
    
    sets = ', '.join([f'{k} = ?' for k in kwargs.keys()])
    values = list(kwargs.values()) + [user_id]
    
    c.execute(f'UPDATE users SET {sets} WHERE user_id = ?', values)
    conn.commit()
    conn.close()

def add_balance(user_id: int, amount: int, transaction_type: str = "other", details: str = ""):
    """Add/subtract from balance and log transaction"""
    conn = get_db()
    c = conn.cursor()
    
    # Update balance
    if amount >= 0:
        c.execute('UPDATE users SET balance = balance + ?, total_won = total_won + ? WHERE user_id = ?',
                  (amount, amount, user_id))
    else:
        c.execute('UPDATE users SET balance = balance + ?, total_lost = total_lost + ? WHERE user_id = ?',
                  (amount, abs(amount), user_id))
    
    # Get new balance
    c.execute('SELECT balance FROM users WHERE user_id = ?', (user_id,))
    new_balance = c.fetchone()[0]
    
    # Log transaction
    c.execute('''INSERT INTO transactions (user_id, type, amount, balance_after, timestamp, details)
                 VALUES (?, ?, ?, ?, ?, ?)''',
              (user_id, transaction_type, amount, new_balance, datetime.now().isoformat(), details))
    
    conn.commit()
    conn.close()
    return new_balance

def get_balance(user_id: int) -> int:
    """Get user's balance"""
    user = get_user(user_id)
    return user['balance']

def is_premium(user_id: int, guild: discord.Guild = None) -> bool:
    """Check if user has premium via Discord role OR database flag"""
    
    # Check for Discord role first (Ko-fi integration)
    if guild:
        member = guild.get_member(user_id)
        if member:
            for role in member.roles:
                role_name_lower = role.name.lower()
                for keyword in PREMIUM_ROLE_KEYWORDS:
                    if keyword in role_name_lower:
                        return True
    
    # Fallback to database check (manual premium)
    user = get_user(user_id)
    if not user['is_premium']:
        return False
    if user['premium_expires']:
        try:
            expires = datetime.fromisoformat(user['premium_expires'])
            return expires > datetime.now()
        except:
            return False
    return user['is_premium'] == 1

def get_leaderboard(limit: int = 10) -> list:
    """Get top users by balance"""
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT user_id, balance, is_premium, prestige FROM users ORDER BY balance DESC LIMIT ?', (limit,))
    rows = c.fetchall()
    conn.close()
    return rows

# ============================================================
# BOT SETUP
# ============================================================
intents = discord.Intents.default()
intents.message_content = True
intents.members = True
intents.guilds = True

bot = commands.Bot(command_prefix='!', intents=intents, help_command=None)

# ============================================================
# EVENTS
# ============================================================
@bot.event
async def on_ready():
    print("=" * 50)
    print(f"    ANGEL ARCADE ONLINE")
    print("=" * 50)
    print(f"    Bot:      {bot.user.name}")
    print(f"    Servers:  {len(bot.guilds)}")
    print(f"    Database: {DB_PATH}")
    print(f"    Ko-fi:    {KOFI_LINK}")
    print("=" * 50)
    await bot.change_presence(activity=discord.Game(name="!help | Angel Arcade"))

# ============================================================
# HELP COMMAND
# ============================================================
@bot.command(name='help', aliases=['h', 'commands'])
async def help_cmd(ctx):
    """Show all commands"""
    embed = discord.Embed(
        title="🎰 Angel Arcade Commands",
        description=f"Virtual casino with {CURRENCY_NAME}!",
        color=BOT_COLOR
    )
    
    embed.add_field(name="💰 Economy", value="""
`!daily` - Claim daily reward
`!work` - Work for coins
`!balance` - Check wallet
`!deposit [amount]` - Put in bank
`!withdraw [amount]` - Take from bank
`!give @user [amount]` - Send coins
    """, inline=True)
    
    embed.add_field(name="🎲 Games", value="""
`!slots [bet]` - Slot machine
`!coinflip [bet] [h/t]` - Flip coin
`!dice [bet]` - Roll dice
`!blackjack [bet]` - Play 21 ⭐
`!roulette [bet] [choice]` - Spin wheel ⭐
    """, inline=True)
    
    embed.add_field(name="📊 Stats", value="""
`!balance` - Your coins
`!profile [@user]` - User profile
`!leaderboard` - Top players
`!stats` - Your stats
    """, inline=True)
    
    embed.add_field(name="⭐ Premium", value=f"""
`!premium` - View benefits
`!support` - Ko-fi link
`!prestige` - Reset for bonus ⭐
    """, inline=True)
    
    embed.set_footer(text="⭐ = Premium feature | Support: ko-fi.com/shanebrain")
    await ctx.send(embed=embed)

@bot.command(name='support', aliases=['donate', 'kofi'])
async def support(ctx):
    """Show support link"""
    embed = discord.Embed(
        title="☕ Support Angel Arcade",
        description=f"""
Thank you for considering supporting us!

**Ko-fi:** {KOFI_LINK}

Your support helps fund:
• 🧠 ShaneBrain development
• ☁️ Angel Cloud wellness platform
• 🎰 New arcade features
• 👨‍👩‍👦‍👦 Shane's family

**Premium perks:** 2x daily, 5min work, 50k bets, exclusive games!
        """,
        color=BOT_COLOR
    )
    embed.set_footer(text="Every tip makes a difference!")
    await ctx.send(embed=embed)

# ============================================================
# ECONOMY COMMANDS
# ============================================================
@bot.command(name='balance', aliases=['bal', 'wallet', 'money'])
async def balance(ctx, member: discord.Member = None):
    """Check your balance"""
    user = member or ctx.author
    data = get_user(user.id)
    premium = is_premium(user.id, ctx.guild)
    
    embed = discord.Embed(
        title=f"{'⭐ ' if premium else ''}{user.display_name}'s Balance",
        color=BOT_COLOR
    )
    embed.add_field(name="Wallet", value=f"{CURRENCY_EMOJI} **{data['balance']:,}**", inline=True)
    embed.add_field(name="Bank", value=f"🏦 **{data['bank']:,}**", inline=True)
    embed.add_field(name="Total", value=f"💎 **{data['balance'] + data['bank']:,}**", inline=True)
    
    await ctx.send(embed=embed)

@bot.command(name='daily')
async def daily(ctx):
    """Claim daily reward"""
    user_id = ctx.author.id
    data = get_user(user_id)
    premium = is_premium(user_id, ctx.guild)
    
    # Check cooldown
    if data['last_daily']:
        last = datetime.fromisoformat(data['last_daily'])
        diff = datetime.now() - last
        if diff.total_seconds() < DAILY_COOLDOWN:
            remaining = DAILY_COOLDOWN - diff.total_seconds()
            hours = int(remaining // 3600)
            mins = int((remaining % 3600) // 60)
            await ctx.send(f"⏰ Daily available in **{hours}h {mins}m**")
            return
    
    # Calculate reward
    base = 100
    streak_bonus = data['daily_streak'] * 10
    prestige_bonus = data['prestige'] * 10
    premium_mult = 2 if premium else 1
    
    reward = (base + streak_bonus + prestige_bonus) * premium_mult
    
    # Update user
    new_streak = data['daily_streak'] + 1
    new_balance = add_balance(user_id, reward, "daily", f"streak:{new_streak}")
    update_user(user_id, last_daily=datetime.now().isoformat(), daily_streak=new_streak)
    
    embed = discord.Embed(
        title="☀️ Daily Reward!",
        description=f"You received {CURRENCY_EMOJI} **{reward:,}**!",
        color=0x00FF00
    )
    embed.add_field(name="Streak", value=f"🔥 {new_streak} days", inline=True)
    embed.add_field(name="Balance", value=f"{CURRENCY_EMOJI} {new_balance:,}", inline=True)
    
    if premium:
        embed.set_footer(text="⭐ 2x Premium bonus applied!")
    
    await ctx.send(embed=embed)

@bot.command(name='work')
async def work(ctx):
    """Work for coins"""
    user_id = ctx.author.id
    data = get_user(user_id)
    premium = is_premium(user_id, ctx.guild)
    
    cooldown = WORK_COOLDOWN_PREMIUM if premium else WORK_COOLDOWN
    
    # Check cooldown
    if data['last_work']:
        last = datetime.fromisoformat(data['last_work'])
        diff = datetime.now() - last
        if diff.total_seconds() < cooldown:
            remaining = cooldown - diff.total_seconds()
            mins = int(remaining // 60)
            secs = int(remaining % 60)
            await ctx.send(f"⏰ Work again in **{mins}m {secs}s**")
            return
    
    # Calculate earnings
    base_min, base_max = 50, 150
    prestige_bonus = data['prestige'] * 5
    earnings = random.randint(base_min, base_max) + prestige_bonus
    
    new_balance = add_balance(user_id, earnings, "work", "")
    update_user(user_id, last_work=datetime.now().isoformat())
    
    jobs = [
        "dispatched trucks", "delivered packages", "coded some Python",
        "mined crypto", "flipped burgers", "drove an Uber",
        "walked dogs", "tutored kids", "fixed computers"
    ]
    
    embed = discord.Embed(
        title="💼 Work Complete!",
        description=f"You {random.choice(jobs)} and earned {CURRENCY_EMOJI} **{earnings:,}**!",
        color=0x00FF00
    )
    embed.add_field(name="Balance", value=f"{CURRENCY_EMOJI} {new_balance:,}", inline=True)
    
    if premium:
        embed.set_footer(text="⭐ 5min cooldown (Premium)")
    else:
        embed.set_footer(text="30min cooldown | Premium = 5min")
    
    await ctx.send(embed=embed)

@bot.command(name='deposit', aliases=['dep'])
async def deposit(ctx, amount: str):
    """Deposit to bank"""
    user_id = ctx.author.id
    data = get_user(user_id)
    
    if amount.lower() == 'all':
        amount = data['balance']
    else:
        try:
            amount = int(amount)
        except:
            await ctx.send("❌ Invalid amount!")
            return
    
    if amount <= 0:
        await ctx.send("❌ Amount must be positive!")
        return
    
    if amount > data['balance']:
        await ctx.send(f"❌ You only have {CURRENCY_EMOJI} **{data['balance']:,}**")
        return
    
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET balance = balance - ?, bank = bank + ? WHERE user_id = ?',
              (amount, amount, user_id))
    conn.commit()
    conn.close()
    
    await ctx.send(f"🏦 Deposited {CURRENCY_EMOJI} **{amount:,}** to bank!")

@bot.command(name='withdraw', aliases=['with'])
async def withdraw(ctx, amount: str):
    """Withdraw from bank"""
    user_id = ctx.author.id
    data = get_user(user_id)
    
    if amount.lower() == 'all':
        amount = data['bank']
    else:
        try:
            amount = int(amount)
        except:
            await ctx.send("❌ Invalid amount!")
            return
    
    if amount <= 0:
        await ctx.send("❌ Amount must be positive!")
        return
    
    if amount > data['bank']:
        await ctx.send(f"❌ You only have {CURRENCY_EMOJI} **{data['bank']:,}** in bank")
        return
    
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET balance = balance + ?, bank = bank - ? WHERE user_id = ?',
              (amount, amount, user_id))
    conn.commit()
    conn.close()
    
    await ctx.send(f"🏦 Withdrew {CURRENCY_EMOJI} **{amount:,}** from bank!")

@bot.command(name='give', aliases=['send', 'pay'])
async def give(ctx, member: discord.Member, amount: int):
    """Give coins to another user"""
    if member.bot or member.id == ctx.author.id:
        await ctx.send("❌ Invalid recipient!")
        return
    
    if amount <= 0:
        await ctx.send("❌ Amount must be positive!")
        return
    
    data = get_user(ctx.author.id)
    if amount > data['balance']:
        await ctx.send(f"❌ You only have {CURRENCY_EMOJI} **{data['balance']:,}**")
        return
    
    # Transfer
    add_balance(ctx.author.id, -amount, "give", f"to:{member.id}")
    add_balance(member.id, amount, "receive", f"from:{ctx.author.id}")
    
    await ctx.send(f"✅ Sent {CURRENCY_EMOJI} **{amount:,}** to {member.mention}!")

# ============================================================
# GAMBLING GAMES
# ============================================================
@bot.command(name='slots', aliases=['slot', 'spin'])
async def slots(ctx, bet: int = 10):
    """Play slots"""
    user_id = ctx.author.id
    data = get_user(user_id)
    premium = is_premium(user_id, ctx.guild)
    max_bet = MAX_BET_PREMIUM if premium else MAX_BET_FREE
    
    if bet <= 0:
        await ctx.send("❌ Bet must be positive!")
        return
    if bet > max_bet:
        await ctx.send(f"❌ Max bet is {CURRENCY_EMOJI} **{max_bet:,}**" + (" (Premium: 50k)" if not premium else ""))
        return
    if bet > data['balance']:
        await ctx.send(f"❌ You only have {CURRENCY_EMOJI} **{data['balance']:,}**")
        return
    
    # Symbols and weights
    symbols = ['🍒', '🍋', '🍊', '🍇', '⭐', '💎', '7️⃣']
    weights = [30, 25, 20, 15, 7, 2, 1]
    
    # Spin
    result = random.choices(symbols, weights=weights, k=3)
    
    # Calculate winnings
    if result[0] == result[1] == result[2]:
        if result[0] == '7️⃣':
            mult = 100
        elif result[0] == '💎':
            mult = 50
        elif result[0] == '⭐':
            mult = 25
        else:
            mult = 10
        winnings = bet * mult
    elif result[0] == result[1] or result[1] == result[2]:
        winnings = bet * 2
    else:
        winnings = 0
    
    # Update balance
    profit = winnings - bet
    new_balance = add_balance(user_id, profit, "slots", f"result:{','.join(result)}")
    
    # Increment games played
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET games_played = games_played + 1 WHERE user_id = ?', (user_id,))
    conn.commit()
    conn.close()
    
    # Display
    embed = discord.Embed(title="🎰 Slots", color=BOT_COLOR)
    embed.add_field(name="Result", value=f"[ {' | '.join(result)} ]", inline=False)
    
    if winnings > 0:
        embed.add_field(name="Won", value=f"{CURRENCY_EMOJI} **+{winnings:,}**", inline=True)
        embed.color = 0x00FF00
    else:
        embed.add_field(name="Lost", value=f"{CURRENCY_EMOJI} **-{bet:,}**", inline=True)
        embed.color = 0xFF6B6B
    
    embed.add_field(name="Balance", value=f"{CURRENCY_EMOJI} {new_balance:,}", inline=True)
    await ctx.send(embed=embed)

@bot.command(name='coinflip', aliases=['flip', 'cf'])
async def coinflip(ctx, bet: int, choice: str = None):
    """Flip a coin"""
    user_id = ctx.author.id
    data = get_user(user_id)
    premium = is_premium(user_id, ctx.guild)
    max_bet = MAX_BET_PREMIUM if premium else MAX_BET_FREE
    
    if not choice or choice.lower() not in ['h', 't', 'heads', 'tails']:
        await ctx.send("Usage: `!coinflip [bet] [h/t]`")
        return
    
    choice = 'heads' if choice.lower() in ['h', 'heads'] else 'tails'
    
    if bet <= 0 or bet > max_bet or bet > data['balance']:
        await ctx.send(f"❌ Invalid bet! You have {CURRENCY_EMOJI} **{data['balance']:,}** (max: {max_bet:,})")
        return
    
    # Flip
    result = random.choice(['heads', 'tails'])
    won = result == choice
    
    profit = bet if won else -bet
    new_balance = add_balance(user_id, profit, "coinflip", f"{choice}:{result}")
    
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET games_played = games_played + 1 WHERE user_id = ?', (user_id,))
    conn.commit()
    conn.close()
    
    emoji = "🪙" if result == 'heads' else "🪙"
    
    embed = discord.Embed(
        title=f"{emoji} {'Heads!' if result == 'heads' else 'Tails!'}",
        color=0x00FF00 if won else 0xFF6B6B
    )
    
    if won:
        embed.description = f"You won {CURRENCY_EMOJI} **+{bet:,}**!"
    else:
        embed.description = f"You lost {CURRENCY_EMOJI} **{bet:,}**"
    
    embed.set_footer(text=f"Balance: {new_balance:,}")
    await ctx.send(embed=embed)

@bot.command(name='dice', aliases=['roll'])
async def dice(ctx, bet: int = 10):
    """Roll dice"""
    user_id = ctx.author.id
    data = get_user(user_id)
    premium = is_premium(user_id, ctx.guild)
    max_bet = MAX_BET_PREMIUM if premium else MAX_BET_FREE
    
    if bet <= 0 or bet > max_bet or bet > data['balance']:
        await ctx.send(f"❌ Invalid bet! You have {CURRENCY_EMOJI} **{data['balance']:,}** (max: {max_bet:,})")
        return
    
    # Roll
    player = random.randint(1, 6) + random.randint(1, 6)
    house = random.randint(1, 6) + random.randint(1, 6)
    
    if player > house:
        profit = bet
        result = "WIN"
    elif player < house:
        profit = -bet
        result = "LOSE"
    else:
        profit = 0
        result = "TIE"
    
    new_balance = add_balance(user_id, profit, "dice", f"{player}v{house}")
    
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET games_played = games_played + 1 WHERE user_id = ?', (user_id,))
    conn.commit()
    conn.close()
    
    embed = discord.Embed(title="🎲 Dice Roll", color=BOT_COLOR)
    embed.add_field(name="You", value=f"🎲 **{player}**", inline=True)
    embed.add_field(name="House", value=f"🎲 **{house}**", inline=True)
    
    if result == "WIN":
        embed.add_field(name="Result", value=f"🎉 Won {CURRENCY_EMOJI} **+{bet:,}**!", inline=False)
        embed.color = 0x00FF00
    elif result == "LOSE":
        embed.add_field(name="Result", value=f"💔 Lost {CURRENCY_EMOJI} **{bet:,}**", inline=False)
        embed.color = 0xFF6B6B
    else:
        embed.add_field(name="Result", value="🤝 Tie! Bet returned.", inline=False)
    
    embed.set_footer(text=f"Balance: {new_balance:,}")
    await ctx.send(embed=embed)

@bot.command(name='blackjack', aliases=['bj', '21'])
async def blackjack(ctx, bet: int):
    """Play blackjack (Premium)"""
    user_id = ctx.author.id
    premium = is_premium(user_id, ctx.guild)
    
    if not premium:
        embed = discord.Embed(
            title="⭐ Premium Feature",
            description=f"Blackjack requires **Premium**!\n\n☕ {KOFI_LINK}",
            color=BOT_COLOR
        )
        await ctx.send(embed=embed)
        return
    
    data = get_user(user_id)
    if bet <= 0 or bet > MAX_BET_PREMIUM or bet > data['balance']:
        await ctx.send(f"❌ Invalid bet! You have {CURRENCY_EMOJI} **{data['balance']:,}** (max: 50k)")
        return
    
    # Simple blackjack
    def draw():
        cards = [2,3,4,5,6,7,8,9,10,10,10,10,11]  # 11 = Ace
        return random.choice(cards)
    
    player = [draw(), draw()]
    dealer = [draw(), draw()]
    
    def hand_value(hand):
        total = sum(hand)
        aces = hand.count(11)
        while total > 21 and aces:
            total -= 10
            aces -= 1
        return total
    
    player_val = hand_value(player)
    dealer_val = hand_value(dealer)
    
    # Check for natural blackjack
    if player_val == 21:
        winnings = int(bet * 1.5)
        new_balance = add_balance(user_id, winnings, "blackjack", "natural21")
        embed = discord.Embed(title="♠️ BLACKJACK!", description=f"Won {CURRENCY_EMOJI} **+{winnings:,}**!", color=0x00FF00)
        await ctx.send(embed=embed)
        return
    
    embed = discord.Embed(title="♠️ Blackjack", color=BOT_COLOR)
    embed.add_field(name=f"Your Hand ({player_val})", value=' '.join([f"`{c}`" for c in player]), inline=True)
    embed.add_field(name=f"Dealer ({dealer[0]})", value=f"`{dealer[0]}` `?`", inline=True)
    embed.set_footer(text="React: 🇭 Hit | 🇸 Stand")
    
    msg = await ctx.send(embed=embed)
    await msg.add_reaction('🇭')
    await msg.add_reaction('🇸')
    
    def check(reaction, user):
        return user.id == ctx.author.id and str(reaction.emoji) in ['🇭', '🇸']
    
    # Game loop
    while True:
        try:
            reaction, user = await bot.wait_for('reaction_add', timeout=30.0, check=check)
            
            if str(reaction.emoji) == '🇭':
                player.append(draw())
                player_val = hand_value(player)
                
                if player_val > 21:
                    # Bust
                    new_balance = add_balance(user_id, -bet, "blackjack", "bust")
                    embed = discord.Embed(title="💥 BUST!", color=0xFF6B6B)
                    embed.add_field(name=f"Your Hand ({player_val})", value=' '.join([f"`{c}`" for c in player]))
                    embed.add_field(name="Lost", value=f"{CURRENCY_EMOJI} **{bet:,}**")
                    await msg.edit(embed=embed)
                    return
                
                # Update display
                embed = discord.Embed(title="♠️ Blackjack", color=BOT_COLOR)
                embed.add_field(name=f"Your Hand ({player_val})", value=' '.join([f"`{c}`" for c in player]), inline=True)
                embed.add_field(name=f"Dealer ({dealer[0]})", value=f"`{dealer[0]}` `?`", inline=True)
                embed.set_footer(text="React: 🇭 Hit | 🇸 Stand")
                await msg.edit(embed=embed)
                await msg.remove_reaction(reaction.emoji, user)
                
            else:
                # Stand - dealer plays
                while dealer_val < 17:
                    dealer.append(draw())
                    dealer_val = hand_value(dealer)
                
                # Determine winner
                if dealer_val > 21 or player_val > dealer_val:
                    profit = bet
                    result = "WIN"
                elif player_val < dealer_val:
                    profit = -bet
                    result = "LOSE"
                else:
                    profit = 0
                    result = "PUSH"
                
                new_balance = add_balance(user_id, profit, "blackjack", f"{player_val}v{dealer_val}")
                
                embed = discord.Embed(title="♠️ Blackjack", color=0x00FF00 if profit > 0 else (0xFF6B6B if profit < 0 else BOT_COLOR))
                embed.add_field(name=f"Your Hand ({player_val})", value=' '.join([f"`{c}`" for c in player]), inline=True)
                embed.add_field(name=f"Dealer ({dealer_val})", value=' '.join([f"`{c}`" for c in dealer]), inline=True)
                
                if result == "WIN":
                    embed.add_field(name="Result", value=f"🎉 Won {CURRENCY_EMOJI} **+{bet:,}**!", inline=False)
                elif result == "LOSE":
                    embed.add_field(name="Result", value=f"💔 Lost {CURRENCY_EMOJI} **{bet:,}**", inline=False)
                else:
                    embed.add_field(name="Result", value="🤝 Push! Bet returned.", inline=False)
                
                embed.set_footer(text=f"Balance: {new_balance:,}")
                await msg.edit(embed=embed)
                return
                
        except asyncio.TimeoutError:
            embed.title = "⏰ Timed Out"
            embed.description = "Game cancelled, bet returned."
            await msg.edit(embed=embed)
            return
    
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET games_played = games_played + 1 WHERE user_id = ?', (user_id,))
    conn.commit()
    conn.close()

@bot.command(name='roulette', aliases=['roul'])
async def roulette(ctx, bet: int, *, choice: str):
    """Play roulette (Premium)"""
    user_id = ctx.author.id
    premium = is_premium(user_id, ctx.guild)
    
    if not premium:
        embed = discord.Embed(
            title="⭐ Premium Feature",
            description=f"Roulette requires **Premium**!\n\n☕ {KOFI_LINK}",
            color=BOT_COLOR
        )
        await ctx.send(embed=embed)
        return
    
    data = get_user(user_id)
    if bet <= 0 or bet > MAX_BET_PREMIUM or bet > data['balance']:
        await ctx.send(f"❌ Invalid bet! You have {CURRENCY_EMOJI} **{data['balance']:,}**")
        return
    
    choice = choice.lower()
    
    # Spin
    result = random.randint(0, 36)
    
    # Determine color
    red = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]
    if result == 0:
        color = 'green'
    elif result in red:
        color = 'red'
    else:
        color = 'black'
    
    # Check win
    winnings = 0
    
    # Number bet
    if choice.isdigit() and int(choice) == result:
        winnings = bet * 35
    # Color bet
    elif choice == color:
        winnings = bet * 2 if color != 'green' else bet * 35
    # Even/Odd
    elif choice == 'even' and result != 0 and result % 2 == 0:
        winnings = bet * 2
    elif choice == 'odd' and result % 2 == 1:
        winnings = bet * 2
    # High/Low
    elif choice == 'high' and 19 <= result <= 36:
        winnings = bet * 2
    elif choice == 'low' and 1 <= result <= 18:
        winnings = bet * 2
    
    profit = winnings - bet if winnings > 0 else -bet
    new_balance = add_balance(user_id, profit, "roulette", f"{choice}:{result}")
    
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE users SET games_played = games_played + 1 WHERE user_id = ?', (user_id,))
    conn.commit()
    conn.close()
    
    color_emoji = '🔴' if color == 'red' else ('⚫' if color == 'black' else '🟢')
    
    embed = discord.Embed(title="🎡 Roulette", color=BOT_COLOR)
    result_str = f"{color_emoji} **{result}**"
    embed.add_field(name="Result", value=result_str, inline=True)
    embed.add_field(name="Your Bet", value=choice.upper(), inline=True)
    
    if winnings > 0:
        embed.add_field(name="Won", value=f"{CURRENCY_EMOJI} **+{winnings:,}**", inline=False)
        embed.color = 0x00FF00
    else:
        embed.add_field(name="Lost", value=f"{CURRENCY_EMOJI} **{bet:,}**", inline=False)
        embed.color = 0xFF6B6B
    
    embed.set_footer(text=f"Balance: {new_balance:,} | Bets: red/black/green, even/odd, high/low, 0-36")
    await ctx.send(embed=embed)

# ============================================================
# STATS & LEADERBOARD
# ============================================================
@bot.command(name='leaderboard', aliases=['lb', 'top', 'rich'])
async def leaderboard_cmd(ctx):
    """View the richest players"""
    top = get_leaderboard(10)
    
    if not top:
        await ctx.send("No players yet!")
        return
    
    medals = ['🥇', '🥈', '🥉'] + ['🏅'] * 7
    
    desc = ""
    for i, (uid, balance, db_premium, prestige) in enumerate(top):
        try:
            user = await bot.fetch_user(uid)
            name = user.display_name[:15]
        except:
            name = f"User {uid}"
        
        badges = ""
        if ctx.guild and is_premium(uid, ctx.guild):
            badges += "⭐"
        elif db_premium:
            badges += "⭐"
        if prestige > 0:
            badges += f"🏅{prestige}"
        
        desc += f"{medals[i]} **{name}** {badges} — {balance:,}\n"
    
    embed = discord.Embed(
        title=f"🏆 {CURRENCY_NAME} Leaderboard",
        description=desc,
        color=BOT_COLOR
    )
    embed.set_footer(text=f"Server: {ctx.guild.name}")
    await ctx.send(embed=embed)

@bot.command(name='stats', aliases=['statistics'])
async def stats(ctx):
    """View your gambling statistics"""
    data = get_user(ctx.author.id)
    premium = is_premium(ctx.author.id, ctx.guild)
    
    embed = discord.Embed(
        title=f"📊 {ctx.author.display_name}'s Stats {'⭐' if premium else ''}",
        color=BOT_COLOR
    )
    
    net = data['total_won'] - data['total_lost']
    net_str = f"+{net:,}" if net >= 0 else f"{net:,}"
    
    embed.add_field(name="Games Played", value=f"🎮 **{data['games_played']:,}**", inline=True)
    embed.add_field(name="Total Won", value=f"📈 **{data['total_won']:,}**", inline=True)
    embed.add_field(name="Total Lost", value=f"📉 **{data['total_lost']:,}**", inline=True)
    embed.add_field(name="Net Profit", value=f"💰 **{net_str}**", inline=True)
    embed.add_field(name="Daily Streak", value=f"🔥 **{data['daily_streak']}**", inline=True)
    embed.add_field(name="Prestige", value=f"🏅 **{data['prestige']}**", inline=True)
    
    await ctx.send(embed=embed)

@bot.command(name='profile')
async def profile(ctx, member: discord.Member = None):
    """View user profile"""
    user = member or ctx.author
    data = get_user(user.id)
    premium = is_premium(user.id, ctx.guild)
    
    embed = discord.Embed(
        title=f"{'⭐ ' if premium else ''}{user.display_name}'s Profile",
        color=BOT_COLOR
    )
    
    embed.set_thumbnail(url=user.display_avatar.url)
    embed.add_field(name="Wallet", value=f"{CURRENCY_EMOJI} {data['balance']:,}", inline=True)
    embed.add_field(name="Bank", value=f"🏦 {data['bank']:,}", inline=True)
    embed.add_field(name="Net Worth", value=f"💎 {data['balance'] + data['bank']:,}", inline=True)
    embed.add_field(name="Games", value=f"🎮 {data['games_played']:,}", inline=True)
    embed.add_field(name="Streak", value=f"🔥 {data['daily_streak']}", inline=True)
    embed.add_field(name="Prestige", value=f"🏅 {data['prestige']}", inline=True)
    
    if premium:
        embed.set_footer(text="⭐ Premium Member")
    
    await ctx.send(embed=embed)

# ============================================================
# PREMIUM COMMANDS
# ============================================================
@bot.command(name='premium')
async def premium_info(ctx):
    """View premium benefits"""
    user_premium = is_premium(ctx.author.id, ctx.guild)
    
    embed = discord.Embed(
        title="⭐ Angel Arcade Premium",
        description="Unlock the full casino experience!",
        color=BOT_COLOR
    )
    
    embed.add_field(name="🎰 Games", value="""
• ♠️ **Blackjack** - Classic 21
• 🎡 **Roulette** - Full wheel
• 🃏 **Poker** - Coming soon!
    """, inline=True)
    
    embed.add_field(name="💰 Benefits", value="""
• **2x** Daily rewards
• **5min** Work cooldown
• **50,000** Max bet
• **Prestige** system
    """, inline=True)
    
    embed.add_field(name="☕ Get Premium", value=f"""
Support on Ko-fi:
**{KOFI_LINK}**
    """, inline=False)
    
    if user_premium:
        embed.set_footer(text="✅ You have Premium!")
    else:
        embed.set_footer(text="Use !support for more info")
    
    await ctx.send(embed=embed)

@bot.command(name='prestige')
async def prestige(ctx):
    """Reset for permanent bonuses (Premium only)"""
    user_id = ctx.author.id
    premium = is_premium(user_id, ctx.guild)
    
    if not premium:
        embed = discord.Embed(
            title="⭐ Premium Feature",
            description=f"Prestige requires **Premium**!\n\n☕ {KOFI_LINK}",
            color=BOT_COLOR
        )
        await ctx.send(embed=embed)
        return
    
    data = get_user(user_id)
    required = 100000 * (data['prestige'] + 1)
    total = data['balance'] + data['bank']
    
    if total < required:
        embed = discord.Embed(
            title="🏅 Prestige",
            description=f"Need **{required:,}** total to prestige.\nYou have **{total:,}**.",
            color=0xFF6B6B
        )
        await ctx.send(embed=embed)
        return
    
    embed = discord.Embed(
        title="🏅 Confirm Prestige",
        description=f"Reset to **0** coins for **+10%** permanent bonus?\nReact ✅ to confirm",
        color=BOT_COLOR
    )
    
    msg = await ctx.send(embed=embed)
    await msg.add_reaction('✅')
    await msg.add_reaction('❌')
    
    def check(reaction, user):
        return user.id == ctx.author.id and str(reaction.emoji) in ['✅', '❌']
    
    try:
        reaction, user = await bot.wait_for('reaction_add', timeout=30.0, check=check)
        
        if str(reaction.emoji) == '✅':
            update_user(user_id, balance=100, bank=0, prestige=data['prestige'] + 1)
            embed = discord.Embed(
                title=f"🏅 Prestige {data['prestige'] + 1}!",
                description=f"**+{(data['prestige'] + 1) * 10}%** permanent bonus!",
                color=0x00FF00
            )
            await msg.edit(embed=embed)
        else:
            await msg.edit(embed=discord.Embed(title="❌ Cancelled", color=0xFF6B6B))
            
    except asyncio.TimeoutError:
        await msg.edit(embed=discord.Embed(title="⏰ Timed Out", color=0xFF6B6B))

# ============================================================
# ERROR HANDLING
# ============================================================
@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.MissingRequiredArgument):
        await ctx.send(f"❌ Missing: `{error.param.name}`")
    elif isinstance(error, commands.BadArgument):
        await ctx.send("❌ Invalid argument!")
    elif isinstance(error, commands.CommandNotFound):
        pass
    else:
        print(f"[ERROR] {error}")

# ============================================================
# RUN
# ============================================================
if __name__ == "__main__":
    init_db()
    
    if TOKEN:
        print("[ARCADE] Starting Angel Arcade...")
        bot.run(TOKEN)
    else:
        print("ERROR: No ARCADE_TOKEN in .env")
        print(f"Add to: {os.path.join(ARCADE_ROOT, '.env')}")
        print("ARCADE_TOKEN=your_bot_token_here")