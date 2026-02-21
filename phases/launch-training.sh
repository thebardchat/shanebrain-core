#!/usr/bin/env bash
set -e

# ============================================================
# ANGEL CLOUD AI TRAINING TOOLS — Main Launcher (Linux)
# Path: /mnt/shanebrain-raid/shanebrain-core/phases/
# RAM Ceiling: 16GB Pi 5 — modules capped at 3GB peak
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
PROGRESS_FILE="$BASE_DIR/progress/user-progress.json"
CONFIG_FILE="$BASE_DIR/config.json"
HEALTH_CHECK="$BASE_DIR/shared/utils/health-check.sh"
MCP_HEALTH_CHECK="$BASE_DIR/shared/utils/mcp-health-check.sh"

# ============================================================
# FUNCTIONS
# ============================================================

show_banner() {
    clear
    echo ""
    echo "   ╔══════════════════════════════════════════════════════════╗"
    echo "   ║                                                          ║"
    echo "   ║     █████╗ ███╗   ██╗ ██████╗ ███████╗██╗                ║"
    echo "   ║    ██╔══██╗████╗  ██║██╔════╝ ██╔════╝██║                ║"
    echo "   ║    ███████║██╔██╗ ██║██║  ███╗█████╗  ██║                ║"
    echo "   ║    ██╔══██║██║╚██╗██║██║   ██║██╔══╝  ██║                ║"
    echo "   ║    ██║  ██║██║ ╚████║╚██████╔╝███████╗███████╗           ║"
    echo "   ║    ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝           ║"
    echo "   ║                                                          ║"
    echo "   ║          ██████╗██╗      ██████╗ ██╗   ██╗██████╗        ║"
    echo "   ║         ██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗       ║"
    echo "   ║         ██║     ██║     ██║   ██║██║   ██║██║  ██║       ║"
    echo "   ║         ██║     ██║     ██║   ██║██║   ██║██║  ██║       ║"
    echo "   ║         ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝      ║"
    echo "   ║          ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝       ║"
    echo "   ║                                                          ║"
    echo "   ║          AI TRAINING TOOLS                               ║"
    echo "   ║          Local AI literacy for every person.             ║"
    echo "   ║                                                          ║"
    echo "   ╚══════════════════════════════════════════════════════════╝"
    echo ""
}

run_health_checks() {
    echo "  [SYSTEM CHECK] Running pre-flight diagnostics..."
    echo ""

    # --- RAM CHECK ---
    FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    FREE_RAM_MB=$((FREE_RAM_KB / 1024))

    if [ "$FREE_RAM_MB" -lt 2048 ]; then
        echo -e "  \e[91m  ✗ BLOCKED: Only ${FREE_RAM_MB}MB RAM free. Need at least 2048MB.\e[0m"
        echo "    Close some applications and try again."
        echo ""
        read -p "  Press Enter to exit..." _
        exit 1
    elif [ "$FREE_RAM_MB" -lt 4096 ]; then
        echo -e "  \e[93m  ⚠ WARNING: Only ${FREE_RAM_MB}MB RAM free. Recommended: 4096MB+\e[0m"
        echo "    Training will run, but performance may be slow."
    else
        echo -e "  \e[92m  ✓ RAM: ${FREE_RAM_MB}MB free — good to go\e[0m"
    fi

    # --- OLLAMA CHECK ---
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo -e "  \e[93m  ⚠ Ollama is not running.\e[0m"
        echo "    Starting Ollama..."
        nohup ollama serve >/dev/null 2>&1 &
        sleep 3
        if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo -e "  \e[91m  ✗ Could not start Ollama. Please start it manually.\e[0m"
            echo "    Run: ollama serve"
            read -p "  Press Enter to exit..." _
            exit 1
        fi
    fi
    echo -e "  \e[92m  ✓ Ollama: Running\e[0m"

    # --- WEAVIATE CHECK ---
    if ! curl -s http://localhost:8080/v1/.well-known/ready >/dev/null 2>&1; then
        echo -e "  \e[93m  ⚠ Weaviate not detected at localhost:8080\e[0m"
        echo "    Some modules require Weaviate. Start it if needed."
    else
        echo -e "  \e[92m  ✓ Weaviate: Running\e[0m"
    fi

    # --- MODEL CHECK ---
    if ! curl -s http://localhost:11434/api/tags 2>/dev/null | grep -qi "llama3.2:1b"; then
        echo -e "  \e[93m  ⚠ Model llama3.2:1b not found. Module 1.1 will help you pull it.\e[0m"
    else
        echo -e "  \e[92m  ✓ Model: llama3.2:1b loaded\e[0m"
    fi

    echo ""
    echo "  ──────────────────────────────────────────────────────────"
    echo ""
}

init_progress() {
    mkdir -p "$(dirname "$PROGRESS_FILE")"
    if [ ! -f "$PROGRESS_FILE" ]; then
        cat > "$PROGRESS_FILE" <<EOF
{
  "user": "default",
  "started": "$(date '+%Y-%m-%d %H:%M:%S')",
  "modules_completed": [],
  "current_module": "1.1"
}
EOF
    fi
}

check_module_complete() {
    # $1 = module id like "1.1"
    if grep "$1" "$PROGRESS_FILE" 2>/dev/null | grep -q "completed" 2>/dev/null; then
        echo "[✓]"
    else
        echo "[ ]"
    fi
}

load_progress() {
    M11=$(check_module_complete "1.1")
    M12=$(check_module_complete "1.2")
    M13=$(check_module_complete "1.3")
    M14=$(check_module_complete "1.4")
    M15=$(check_module_complete "1.5")
    M21=$(check_module_complete "2.1")
    M22=$(check_module_complete "2.2")
    M23=$(check_module_complete "2.3")
    M24=$(check_module_complete "2.4")
    M25=$(check_module_complete "2.5")
    M26=$(check_module_complete "2.6")
    M27=$(check_module_complete "2.7")
    M31=$(check_module_complete "3.1")
    M32=$(check_module_complete "3.2")
    M33=$(check_module_complete "3.3")
    M34=$(check_module_complete "3.4")
    M35=$(check_module_complete "3.5")
    M36=$(check_module_complete "3.6")
    M37=$(check_module_complete "3.7")
}

show_menu() {
    echo -e "  PHASE 1 — BUILDERS  \e[92m[UNLOCKED]\e[0m"
    echo "  ─────────────────────────────────────"
    echo "    $M11 1.1  Your First Local LLM         (15 min)"
    echo "    $M12 1.2  Vectors Made Simple           (15 min)"
    echo "    $M13 1.3  Build Your Brain              (15 min)"
    echo "    $M14 1.4  Prompt Engineering for Local   (15 min)"
    echo "    $M15 1.5  Ship It                        (15 min)"
    echo ""
    echo ""
    echo -e "  PHASE 2 — OPERATORS  \e[92m[UNLOCKED]\e[0m"
    echo "  ─────────────────────────────────────"
    echo "    $M21 2.1  Load Your Business Brain     (15 min)"
    echo "    $M22 2.2  The Instant Answer Desk      (15 min)"
    echo "    $M23 2.3  Draft It                      (20 min)"
    echo "    $M24 2.4  Sort and Route                (15 min)"
    echo "    $M25 2.5  Paperwork Machine             (20 min)"
    echo "    $M26 2.6  Chain Reactions                (20 min)"
    echo "    $M27 2.7  Your Operator Dashboard        (15 min)"
    echo ""
    echo -e "  PHASE 3 — EVERYDAY  \e[92m[UNLOCKED — MCP]\e[0m"
    echo "  ─────────────────────────────────────"
    echo "    $M31 3.1  Your Private Vault         (15 min)"
    echo "    $M32 3.2  Ask Your Vault             (15 min)"
    echo "    $M33 3.3  Write It Right             (15 min)"
    echo "    $M34 3.4  Lock It Down               (15 min)"
    echo "    $M35 3.5  Daily Briefing             (15 min)"
    echo "    $M36 3.6  Digital Footprint          (15 min)"
    echo "    $M37 3.7  Family Dashboard           (20 min)"
    echo ""
    echo -e "  PHASE 4 — LEGACY     \e[93m[COMING SOON]\e[0m"
    echo ""
    echo "  ─────────────────────────────────────"
    echo "    H  Health Check     M  MCP Health Check"
    echo "    R  Reset Progress   Q  Quit"
    echo ""
}

get_module_dir() {
    case "$1" in
        1.1) echo "$BASE_DIR/phases/phase-1-builders/module-1.1-first-local-llm" ;;
        1.2) echo "$BASE_DIR/phases/phase-1-builders/module-1.2-vectors" ;;
        1.3) echo "$BASE_DIR/phases/phase-1-builders/module-1.3-build-your-brain" ;;
        1.4) echo "$BASE_DIR/phases/phase-1-builders/module-1.4-prompt-engineering" ;;
        1.5) echo "$BASE_DIR/phases/phase-1-builders/module-1.5-ship-it" ;;
        2.1) echo "$BASE_DIR/phases/phase-2-operators/module-2.1-load-your-business-brain" ;;
        2.2) echo "$BASE_DIR/phases/phase-2-operators/module-2.2-instant-answer-desk" ;;
        2.3) echo "$BASE_DIR/phases/phase-2-operators/module-2.3-draft-it" ;;
        2.4) echo "$BASE_DIR/phases/phase-2-operators/module-2.4-sort-and-route" ;;
        2.5) echo "$BASE_DIR/phases/phase-2-operators/module-2.5-paperwork-machine" ;;
        2.6) echo "$BASE_DIR/phases/phase-2-operators/module-2.6-chain-reactions" ;;
        2.7) echo "$BASE_DIR/phases/phase-2-operators/module-2.7-operator-dashboard" ;;
        3.1) echo "$BASE_DIR/phases/phase-3-everyday/module-3.1-your-private-vault" ;;
        3.2) echo "$BASE_DIR/phases/phase-3-everyday/module-3.2-ask-your-vault" ;;
        3.3) echo "$BASE_DIR/phases/phase-3-everyday/module-3.3-write-it-right" ;;
        3.4) echo "$BASE_DIR/phases/phase-3-everyday/module-3.4-lock-it-down" ;;
        3.5) echo "$BASE_DIR/phases/phase-3-everyday/module-3.5-daily-briefing" ;;
        3.6) echo "$BASE_DIR/phases/phase-3-everyday/module-3.6-digital-footprint" ;;
        3.7) echo "$BASE_DIR/phases/phase-3-everyday/module-3.7-family-dashboard" ;;
        *)   echo "" ;;
    esac
}

run_module() {
    local MOD_DIR="$1"

    clear
    echo ""
    echo "  ══════════════════════════════════════════════════════"
    echo "   LESSON"
    echo "  ══════════════════════════════════════════════════════"
    echo ""

    if [ -f "$MOD_DIR/lesson.md" ]; then
        cat "$MOD_DIR/lesson.md"
    else
        echo -e "  \e[91m  Module not yet built. Check back soon.\e[0m"
        read -p "  Press Enter to continue..." _
        return
    fi

    echo ""
    echo "  ══════════════════════════════════════════════════════"
    echo ""

    while true; do
        read -p "  Press E to start EXERCISE, H for HINTS, B to go back: " CONTINUE
        case "${CONTINUE^^}" in
            E)
                if [ -f "$MOD_DIR/exercise.sh" ]; then
                    bash "$MOD_DIR/exercise.sh"
                else
                    echo -e "  \e[91m  Exercise not found.\e[0m"
                fi
                break
                ;;
            H)
                if [ -f "$MOD_DIR/hints.md" ]; then
                    cat "$MOD_DIR/hints.md"
                else
                    echo -e "  \e[93m  No hints available for this module.\e[0m"
                fi
                # Loop back to let them pick E or B after reading hints
                ;;
            B)
                return
                ;;
            *)
                echo -e "  \e[91m  Invalid option. Try E, H, or B.\e[0m"
                ;;
        esac
    done

    echo ""
    echo "  ──────────────────────────────────────────────────────"
    read -p "  Press V to VERIFY your exercise, B to go back: " VERIFY
    case "${VERIFY^^}" in
        V)
            if [ -f "$MOD_DIR/verify.sh" ]; then
                set +e
                bash "$MOD_DIR/verify.sh"
                RESULT=$?
                set -e
                if [ "$RESULT" -eq 0 ]; then
                    echo ""
                    echo -e "  \e[92m  ══════════════════════════════════════════\e[0m"
                    echo -e "  \e[92m   ✓ MODULE COMPLETE — Nice work.          \e[0m"
                    echo -e "  \e[92m  ══════════════════════════════════════════\e[0m"
                else
                    echo ""
                    echo -e "  \e[91m  ✗ Not quite. Review the hints and try again.\e[0m"
                fi
            else
                echo -e "  \e[91m  Verify script not found.\e[0m"
            fi
            ;;
    esac

    echo ""
    read -p "  Press Enter to continue..." _
}

do_health_check() {
    clear
    if [ -f "$HEALTH_CHECK" ]; then
        bash "$HEALTH_CHECK"
    else
        echo "  Health check script not found at: $HEALTH_CHECK"
    fi
    read -p "  Press Enter to continue..." _
}

do_mcp_health_check() {
    clear
    if [ -f "$MCP_HEALTH_CHECK" ]; then
        bash "$MCP_HEALTH_CHECK"
    else
        echo "  MCP health check script not found at: $MCP_HEALTH_CHECK"
    fi
    read -p "  Press Enter to continue..." _
}

do_reset_progress() {
    echo ""
    read -p "  Reset all progress? This cannot be undone. (Y/N): " CONFIRM
    if [ "${CONFIRM^^}" = "Y" ]; then
        cat > "$PROGRESS_FILE" <<EOF
{
  "user": "default",
  "started": "$(date '+%Y-%m-%d %H:%M:%S')",
  "modules_completed": [],
  "current_module": "1.1"
}
EOF
        echo -e "  \e[92m  Progress reset.\e[0m"
    fi
    read -p "  Press Enter to continue..." _
}

# ============================================================
# MAIN LOOP
# ============================================================

init_progress

while true; do
    show_banner
    run_health_checks
    load_progress
    show_menu

    read -p "  Select module (1.1-3.7) or option: " CHOICE

    case "$CHOICE" in
        1.[1-5]|2.[1-7]|3.[1-7])
            MOD_DIR=$(get_module_dir "$CHOICE")
            if [ -n "$MOD_DIR" ]; then
                run_module "$MOD_DIR"
            else
                echo -e "  \e[91m  Invalid selection. Try again.\e[0m"
                read -p "  Press Enter to continue..." _
            fi
            ;;
        [Hh])
            do_health_check
            ;;
        [Mm])
            do_mcp_health_check
            ;;
        [Rr])
            do_reset_progress
            ;;
        [Qq])
            echo ""
            echo "  Keep building. Your legacy runs local."
            echo ""
            exit 0
            ;;
        *)
            echo -e "  \e[91m  Invalid selection. Try again.\e[0m"
            echo ""
            sleep 1
            ;;
    esac
done
