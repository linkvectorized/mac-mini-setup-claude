#!/usr/bin/env bash
# setup.sh — vset by linkvectorized

set -e

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

PASS="${GREEN}[✓]${NC}"
FAIL="${RED}[✗]${NC}"

# ── Intro ─────────────────────────────────────────────────────────────────────
clear
printf "${CYAN}${BOLD}"
cat << 'EOF'

  __   __  ___  ___ _____
  \ \ / / / __|| __|_   _|
   \ V /  \__ \| _|  | |
    \_/   |___/|___| |_|

EOF
printf "${NC}"
printf "${YELLOW}${BOLD}"
cat << 'EOF'
   _____________________________________________
  < question everything. especially the govt. >
   ---------------------------------------------
          \   ^__^
           \  (oo)\_______
              (__)\       )\/\
                  ||----w |
                  ||     ||

EOF
printf "${NC}"

sleep 2

# ── Pre-flight check ──────────────────────────────────────────────────────────
printf "${BOLD}── Pre-flight check ──${NC}\n\n"

# 1. Xcode CLT
printf "1. Xcode Command Line Tools\n"
if xcode-select -p &>/dev/null; then
  printf "   $PASS installed at $(xcode-select -p)\n"
else
  printf "   $FAIL not installed — will install\n"
fi

echo ""

# 2. Homebrew
printf "2. Homebrew\n"
if command -v brew &>/dev/null; then
  printf "   $PASS installed — $(brew --version | head -1)\n"
else
  printf "   $FAIL not installed — will install\n"
fi

echo ""

# 3. Brew packages
printf "3. Brew packages\n"
BREW_PACKAGES=(bash gh node go jq git)
for pkg in "${BREW_PACKAGES[@]}"; do
  if command -v "$pkg" &>/dev/null; then
    printf "   $PASS $pkg — $(command -v "$pkg")\n"
  else
    printf "   $FAIL $pkg — not installed\n"
  fi
done

echo ""

# 4. Dotfiles
printf "4. Dotfiles\n"
DOTFILES_DIR="$HOME/vset"
if [ -d "$DOTFILES_DIR/.git" ]; then
  printf "   $PASS vset repo exists at $DOTFILES_DIR\n"
else
  printf "   $FAIL vset repo not found — will clone\n"
fi

DOTFILES=(.bash_profile)
for df in "${DOTFILES[@]}"; do
  if [ -L "$HOME/$df" ] && [ "$(readlink "$HOME/$df")" = "$DOTFILES_DIR/$df" ]; then
    printf "   $PASS $df symlinked\n"
  elif [ -f "$HOME/$df" ]; then
    printf "   $FAIL $df exists but is not symlinked\n"
  else
    printf "   $FAIL $df not found — will link\n"
  fi
done

echo ""

# 5. Claude Code
printf "5. Claude Code\n"
if command -v claude &>/dev/null; then
  printf "   $PASS claude installed — $(claude --version 2>/dev/null || echo 'version unknown')\n"
else
  printf "   $FAIL claude not installed — will install\n"
fi

SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  printf "   $PASS claude settings exist at $SETTINGS\n"
else
  printf "   $FAIL claude settings not found — will create\n"
fi

echo ""

# 6. GitHub CLI auth
printf "6. GitHub CLI auth\n"
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  printf "   $PASS gh authenticated — $(gh auth status 2>&1 | grep 'Logged in' || echo 'logged in')\n"
else
  printf "   $FAIL gh not authenticated — will run gh auth login\n"
fi

echo ""

# 7. Apps
printf "7. Apps\n"
if [ -d "/Applications/Brave Browser.app" ]; then
  printf "   $PASS Brave Browser installed\n"
else
  printf "   $FAIL Brave Browser not installed — will install\n"
fi

if [ -d "/Applications/Cursor.app" ]; then
  printf "   $PASS Cursor installed\n"
else
  printf "   $FAIL Cursor not installed — will install\n"
fi

if [ -d "/Applications/Bitwarden.app" ]; then
  printf "   $PASS Bitwarden installed\n"
else
  printf "   $FAIL Bitwarden not installed — will install\n"
fi

echo ""
printf "${BOLD}── Starting install ──${NC}\n\n"

# spinner
spinner() {
  local pid=$1
  local msg=$2
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r   ${CYAN}${frames[$i]}${NC}  $msg"
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r   $PASS $msg\n"
}

# ── 1. Xcode Command Line Tools ───────────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "    Waiting for Xcode CLT install to finish (click Install in the dialog)..."
  until xcode-select -p &>/dev/null; do sleep 5; done
else
  printf "   $PASS Xcode CLT already installed\n"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  printf "   $PASS Homebrew already installed\n"
  eval "$(brew shellenv)"
fi

# ── 3. Brew packages ──────────────────────────────────────────────────────────
echo ""
echo "==> Installing brew packages..."
for pkg in "${BREW_PACKAGES[@]}"; do
  if brew list --formula "$pkg" &>/dev/null; then
    printf "   $PASS $pkg already installed\n"
  else
    brew install "$pkg" &>/dev/null &
    spinner $! "Installing $pkg..."
  fi
done

# ── 4. Dotfiles ───────────────────────────────────────────────────────────────
SETUP_REPO="https://github.com/linkvectorized/vset.git"

echo ""
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  git clone "$SETUP_REPO" "$DOTFILES_DIR" &>/dev/null &
  spinner $! "Cloning vset..."
else
  git -C "$DOTFILES_DIR" pull &>/dev/null &
  spinner $! "vset up to date"
fi

for df in "${DOTFILES[@]}"; do
  if [ ! -L "$HOME/$df" ] || [ "$(readlink "$HOME/$df")" != "$DOTFILES_DIR/$df" ]; then
    ln -sf "$DOTFILES_DIR/$df" "$HOME/$df"
    printf "   $PASS $df linked\n"
  else
    printf "   $PASS $df already linked\n"
  fi
done
printf "   $PASS dotfiles installed\n"

if [ "$SHELL" != "/opt/homebrew/bin/bash" ]; then
  if ! grep -qF '/opt/homebrew/bin/bash' /etc/shells; then
    sudo bash -c "echo '/opt/homebrew/bin/bash' >> /etc/shells"
    printf "   $PASS added Homebrew bash to /etc/shells\n"
  fi
  sudo dscl . -create "/Users/$(whoami)" UserShell /opt/homebrew/bin/bash
  printf "   $PASS default shell switched to bash 5 — restart terminal after setup\n"
else
  printf "   $PASS default shell is already bash 5\n"
fi

# ── 5. Claude Code CLI ────────────────────────────────────────────────────────
echo ""
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code &>/dev/null &
  spinner $! "Installing Claude Code..."
else
  printf "   $PASS Claude Code already installed\n"
fi

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
  cat > "$SETTINGS_FILE" <<'EOF'
{
  "model": "sonnet",
  "skipDangerousModePermissionPrompt": true
}
EOF
  printf "   $PASS Claude settings written\n"
else
  printf "   $PASS Claude settings already exist\n"
fi

# ── 6. GitHub CLI auth ────────────────────────────────────────────────────────
echo ""
if ! gh auth status &>/dev/null; then
  echo "==> Authenticating GitHub CLI (follow the prompts)..."
  gh auth login
else
  printf "   $PASS GitHub CLI already authenticated\n"
fi

# ── 7. Apps (Brave, Cursor) ───────────────────────────────────────────────────
echo ""
echo "==> Installing apps..."
if [ -d "/Applications/Brave Browser.app" ]; then
  printf "   $PASS Brave Browser already installed\n"
else
  brew install --cask brave-browser &>/dev/null &
  spinner $! "Installing Brave Browser..."
fi

if [ -d "/Applications/Cursor.app" ]; then
  printf "   $PASS Cursor already installed\n"
else
  brew install --cask cursor &>/dev/null &
  spinner $! "Installing Cursor..."
fi

if [ -d "/Applications/Bitwarden.app" ]; then
  printf "   $PASS Bitwarden already installed\n"
else
  brew install --cask bitwarden &>/dev/null &
  spinner $! "Installing Bitwarden..."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}"
cat << 'EOF'
  ╔══════════════════════════════════════════════╗
  ║              ALL DONE. YOU'RE SET.           ║
  ╚══════════════════════════════════════════════╝
EOF
printf "${NC}\n"

source ~/.bash_profile 2>/dev/null || true
printf "  ${CYAN}source ~/.bash_profile${NC} applied — restart terminal to get bash 5 as login shell\n\n"

printf "  ${BOLD}Versions:${NC}\n"
printf "    bash:      $(/opt/homebrew/bin/bash --version | head -1)\n"
printf "    brew:      $(brew --version | head -1)\n"
printf "    gh:        $(gh --version | head -1)\n"
printf "    node:      $(node --version)\n"
printf "    go:        $(go version)\n"
printf "    claude:    $(claude --version 2>/dev/null || echo 'check manually')\n"
printf "    brave:     $([ -d '/Applications/Brave Browser.app' ] && echo 'installed' || echo 'not found')\n"
printf "    cursor:    $([ -d '/Applications/Cursor.app' ] && echo 'installed' || echo 'not found')\n"
printf "    bitwarden: $([ -d '/Applications/Bitwarden.app' ] && echo 'installed' || echo 'not found')\n"

echo ""
printf "${YELLOW}  Stay curious. Question narratives. Build cool things.${NC}\n\n"
