#!/usr/bin/env bash
# ShaneBrain Dashboard - tmux session with service logs, monitoring, and shell
SESSION="shanebrain"

# Attach if session already exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already running, attaching..."
    exec tmux attach-session -t "$SESSION"
fi

# ── Window 1: logs (4 panes) ──
tmux new-session -d -s "$SESSION" -n "logs" "journalctl -fu shanebrain-discord"
tmux split-window -h -t "$SESSION:logs" "journalctl -fu shanebrain-arcade"
tmux split-window -v -t "$SESSION:logs.2" "journalctl -fu angel-cloud-gateway"
tmux split-window -v -t "$SESSION:logs.1" "journalctl -fu shanebrain-social"
tmux select-layout -t "$SESSION:logs" tiled

# ── Window 2: monitor (2 panes) ──
tmux new-window -t "$SESSION" -n "monitor" "btop"
tmux split-window -h -t "$SESSION:monitor" "lazydocker"

# ── Window 3: shell ──
tmux new-window -t "$SESSION" -n "shell" -c "/mnt/shanebrain-raid/shanebrain-core"

# Start on logs window
tmux select-window -t "$SESSION:logs"

# Attach
exec tmux attach-session -t "$SESSION"
