#!/usr/bin/env bash
set -e

# ============================================================
# ANGEL CLOUD HEALTH CHECK (Linux)
# Checks: RAM, Ollama, Weaviate, Model availability
# Safe to run anytime — read-only, changes nothing
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  ══════════════════════════════════════════════════════"
echo "   ANGEL CLOUD — SYSTEM HEALTH CHECK"
echo "  ══════════════════════════════════════════════════════"
echo ""
echo "   Hardware:    Pi 5 — 16GB RAM"
echo "   Module budget: 3.0GB max per module"
echo "   Timestamp:   $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "  ──────────────────────────────────────────────────────"
echo ""

# === RAM CHECK ===
echo "  [RAM]"
FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
FREE_RAM_MB=$((FREE_RAM_KB / 1024))

TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))

USED_RAM_MB=$((TOTAL_RAM_MB - FREE_RAM_MB))

echo "    Total:     ${TOTAL_RAM_MB} MB"
echo "    Used:      ${USED_RAM_MB} MB"
echo "    Free:      ${FREE_RAM_MB} MB"

if [ "$FREE_RAM_MB" -lt 2048 ]; then
    echo -e "  \e[91m   STATUS: CRITICAL — Below 2GB free. Cannot run modules safely.\e[0m"
elif [ "$FREE_RAM_MB" -lt 4096 ]; then
    echo -e "  \e[93m   STATUS: WARNING — Below 4GB free. May be slow.\e[0m"
else
    echo -e "  \e[92m   STATUS: GOOD\e[0m"
fi
echo ""

# === OLLAMA CHECK ===
echo "  [OLLAMA]"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo -e "  \e[92m   Server:  Running on localhost:11434\e[0m"

    # Check for specific model
    if curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"; then
        echo -e "  \e[92m   Model:   llama3.2:1b available\e[0m"
    else
        echo -e "  \e[93m   Model:   llama3.2:1b NOT found — run: ollama pull llama3.2:1b\e[0m"
    fi

    # List all models
    echo "    Models installed:"
    curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for m in data.get('models', []):
        print(f\"      {m['name']}\")
except:
    print('      (could not parse model list)')
" 2>/dev/null || echo "      (could not parse model list)"
else
    echo -e "  \e[91m   Server:  NOT RUNNING\e[0m"
    echo "            Fix: Run \"ollama serve\" in a separate terminal"
fi
echo ""

# === WEAVIATE CHECK ===
echo "  [WEAVIATE]"
if curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1; then
    echo -e "  \e[92m   Server:  Running on localhost:8080\e[0m"

    # Check for schema/classes
    if curl -s http://localhost:8080/v1/schema 2>/dev/null | grep -qi "class"; then
        echo -e "  \e[92m   Schema:  Classes detected\e[0m"
    else
        echo -e "  \e[93m   Schema:  No classes found (empty database)\e[0m"
    fi
else
    echo -e "  \e[91m   Server:  NOT RUNNING\e[0m"
    echo "            Weaviate is needed for Modules 1.2+"
    echo "            Check your Docker/Weaviate service"
fi
echo ""

# === DISK CHECK ===
echo "  [DISK]"
echo "    RAID (/mnt/shanebrain-raid):"
df -h /mnt/shanebrain-raid 2>/dev/null | tail -1 | awk '{print "      Size: "$2"  Used: "$3"  Free: "$4"  Use%: "$5}'
if [ -d /media/shane/ANGEL_CLOUD ]; then
    echo "    External (ANGEL_CLOUD):"
    df -h /media/shane/ANGEL_CLOUD 2>/dev/null | tail -1 | awk '{print "      Size: "$2"  Used: "$3"  Free: "$4"  Use%: "$5}'
fi
echo ""

# === SUMMARY ===
echo "  ══════════════════════════════════════════════════════"
echo "   Health check complete. Review any warnings above."
echo "  ══════════════════════════════════════════════════════"
echo ""

exit 0
