#!/usr/bin/env bash
set -euo pipefail

# ─── deploy-cli-tools.sh ───────────────────────────────────────────────
# Installs CLI tools on the local machine, then deploys to all reachable
# Linux Tailscale nodes via SSH.
# -----------------------------------------------------------------------

SCRIPT_NAME="$(realpath "$0")"
ARCH="$(uname -m)"
LOG="/tmp/deploy-cli-tools.log"

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; }

# Map uname -m to GitHub-style arch names
case "$ARCH" in
  aarch64|arm64) GH_ARCH="arm64"; STAR_ARCH="aarch64" ;;
  x86_64)        GH_ARCH="amd64"; STAR_ARCH="x86_64"  ;;
  *)             fail "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# ── Helper: install a GitHub release binary ──
install_gh_binary() {
  local name="$1" repo="$2" pattern="$3"
  if command -v "$name" &>/dev/null; then
    ok "$name already installed ($(command -v "$name"))"
    return
  fi
  info "Installing $name from $repo ..."
  local tmp
  tmp="$(mktemp -d)"
  local url
  url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | jq -r --arg pat "$pattern" '.assets[] | select(.name | test($pat)) | .browser_download_url' \
    | head -1)"
  if [[ -z "$url" || "$url" == "null" ]]; then
    fail "Could not find release asset for $name (pattern: $pattern)"
    rm -rf "$tmp"
    return
  fi
  local fname="${url##*/}"
  curl -fsSL -o "$tmp/$fname" "$url"
  case "$fname" in
    *.tar.gz|*.tgz)
      tar xzf "$tmp/$fname" -C "$tmp"
      local bin_path
      bin_path="$(find "$tmp" -name "$name" -type f -executable 2>/dev/null | head -1)"
      if [[ -z "$bin_path" ]]; then
        bin_path="$(find "$tmp" -name "$name" -type f 2>/dev/null | head -1)"
      fi
      if [[ -n "$bin_path" ]]; then
        sudo install -m 755 "$bin_path" /usr/local/bin/"$name"
      else
        fail "Binary '$name' not found in archive"
        rm -rf "$tmp"
        return
      fi
      ;;
    *.deb)
      sudo dpkg -i "$tmp/$fname"
      ;;
    *)
      sudo install -m 755 "$tmp/$fname" /usr/local/bin/"$name"
      ;;
  esac
  rm -rf "$tmp"
  ok "$name installed"
}

# ══════════════════════════════════════════════════════════════════════
# PHASE 1: Install on local machine
# ══════════════════════════════════════════════════════════════════════
install_local() {
  info "═══ Phase 1: Local install on $(hostname) (${ARCH}) ═══"

  # ── APT packages ──
  info "Updating apt cache ..."
  sudo apt-get update -qq

  APT_PKGS=(git curl wget jq htop btop tmux nmap mtr-tiny fzf ripgrep speedtest-cli)
  info "Installing APT packages: ${APT_PKGS[*]}"
  sudo apt-get install -y -qq "${APT_PKGS[@]}" 2>&1 | tail -3

  # tldr - install via pip if not in apt
  if ! command -v tldr &>/dev/null; then
    if ! sudo apt-get install -y -qq tldr 2>/dev/null; then
      info "Installing tldr via pip ..."
      pip install --user --break-system-packages tldr 2>/dev/null || true
    fi
    ok "tldr installed"
  fi

  # bat is packaged as 'bat' on Debian but binary is 'batcat'
  if ! command -v bat &>/dev/null; then
    sudo apt-get install -y -qq bat 2>/dev/null || sudo apt-get install -y -qq batcat 2>/dev/null || true
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
      sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi
    ok "bat installed"
  else
    ok "bat already installed"
  fi

  # fd-find
  if ! command -v fd &>/dev/null; then
    if sudo apt-get install -y -qq fd-find 2>/dev/null; then
      sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
      ok "fd installed (via fd-find symlink)"
    fi
  else
    ok "fd already installed"
  fi

  ok "APT packages done"

  # ── eza (modern ls) ──
  if ! command -v eza &>/dev/null; then
    info "Installing eza ..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq && sudo apt-get install -y -qq eza
    ok "eza installed"
  else
    ok "eza already installed"
  fi

  # ── dust (disk usage) ──
  install_gh_binary "dust" "bootandy/dust" "dust-.*-${STAR_ARCH}.*linux.*[.]tar[.]gz"

  # ── zoxide (smart cd) ──
  if ! command -v zoxide &>/dev/null; then
    info "Installing zoxide ..."
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    ok "zoxide installed"
  else
    ok "zoxide already installed"
  fi

  # ── lazygit ──
  install_gh_binary "lazygit" "jesseduffield/lazygit" "lazygit_.*_linux_${GH_ARCH}[.]tar[.]gz"

  # ── lazydocker ──
  install_gh_binary "lazydocker" "jesseduffield/lazydocker" "lazydocker_.*_Linux_${GH_ARCH}[.]tar[.]gz"

  # ── starship prompt ──
  if ! command -v starship &>/dev/null; then
    info "Installing starship ..."
    local stmp
    stmp="$(mktemp -d)"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$stmp" 2>/dev/null
    sudo install -m 755 "$stmp/starship" /usr/local/bin/starship
    rm -rf "$stmp"
    ok "starship installed"
  else
    ok "starship already installed"
  fi

  # ── Configure bash aliases & integrations ──
  configure_bash
}

# ══════════════════════════════════════════════════════════════════════
# Configure bash aliases and shell integrations
# ══════════════════════════════════════════════════════════════════════
configure_bash() {
  info "Configuring bash aliases and integrations ..."

  local ALIASES_FILE="$HOME/.bash_aliases"
  local MARKER="# ── deploy-cli-tools managed ──"

  # Remove old managed block if present
  if [[ -f "$ALIASES_FILE" ]] && grep -q "$MARKER" "$ALIASES_FILE" 2>/dev/null; then
    sed -i "/${MARKER}/,/${MARKER} END/d" "$ALIASES_FILE"
  fi

  cat >> "$ALIASES_FILE" <<'ALIASES'
# ── deploy-cli-tools managed ──
# ShaneBrain shortcuts
alias sb='cd /mnt/shanebrain-raid/shanebrain-core && echo "→ shanebrain-core"'
alias lg='lazygit'
alias ld='lazydocker'

# Modern CLI replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias find='fd'
alias du='dust'
alias top='btop'

# Starship prompt
eval "$(starship init bash)"

# Zoxide (smart cd)
eval "$(zoxide init bash)"

# fzf keybindings
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
# ── deploy-cli-tools managed ── END
ALIASES

  ok "Aliases written to $ALIASES_FILE"

  # Update tldr cache
  if command -v tldr &>/dev/null; then
    info "Updating tldr cache ..."
    tldr --update 2>/dev/null || true
  fi
}

# ══════════════════════════════════════════════════════════════════════
# PHASE 2: Deploy to all Tailscale Linux nodes
# ══════════════════════════════════════════════════════════════════════
deploy_to_tailscale() {
  info "═══ Phase 2: Deploying to Tailscale Linux nodes ═══"

  local local_ip
  local_ip="$(tailscale ip -4 2>/dev/null || echo "")"

  if [[ -z "$local_ip" ]]; then
    warn "Tailscale not available, skipping remote deployment"
    return
  fi

  # Get all online Tailscale peers (skip self, skip non-Linux)
  local nodes
  nodes="$(tailscale status --json 2>/dev/null \
    | jq -r '.Peer[] | select(.Online == true and .OS == "linux") | .TailscaleIPs[0]' 2>/dev/null || echo "")"

  if [[ -z "$nodes" ]]; then
    info "No other online Linux Tailscale nodes found. Only local install was performed."
    return
  fi

  for ip in $nodes; do
    info "Deploying to $ip ..."
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$ip" true 2>/dev/null; then
      scp -q "$SCRIPT_NAME" "$ip:/tmp/deploy-cli-tools.sh"
      ssh "$ip" "bash /tmp/deploy-cli-tools.sh --local-only" 2>&1 | sed "s/^/  [$ip] /"
      ok "Deployed to $ip"
    else
      warn "Cannot SSH to $ip, skipping"
    fi
  done
}

# ══════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════
main() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   ShaneBrain CLI Tools Deployment                ║${NC}"
  echo -e "${CYAN}║   $(date '+%Y-%m-%d %H:%M:%S')                            ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""

  install_local

  if [[ "${1:-}" != "--local-only" ]]; then
    deploy_to_tailscale
  fi

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   Deployment complete!                           ║${NC}"
  echo -e "${GREEN}║   Run: source ~/.bash_aliases   to activate now  ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

main "$@"
