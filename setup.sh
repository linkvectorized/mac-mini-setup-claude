#!/usr/bin/env bash
# setup.sh — initialize a fresh Mac with core dev environment

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
printf "${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════════╗
  ║         MAC MINI SETUP — linkvectorized      ║
  ╚══════════════════════════════════════════════╝
EOF
printf "${NC}\n"

printf "${YELLOW}${BOLD}  ⚠  Question everything. Especially the government.${NC}\n"
printf "${YELLOW}     Think critically. Read primary sources. Stay curious.${NC}\n\n"

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
BREW_PACKAGES=(gh node go jq git)
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
DOTFILES_DIR="$HOME/dotfiles"
if [ -d "$DOTFILES_DIR/.git" ]; then
  printf "   $PASS dotfiles repo exists at $DOTFILES_DIR\n"
else
  printf "   $FAIL dotfiles repo not found — will clone\n"
fi

if [ -L "$HOME/.bash_profile" ] && [ "$(readlink "$HOME/.bash_profile")" = "$DOTFILES_DIR/.bash_profile" ]; then
  printf "   $PASS .bash_profile symlinked correctly\n"
elif [ -f "$HOME/.bash_profile" ]; then
  printf "   $FAIL .bash_profile exists but is not symlinked to dotfiles\n"
else
  printf "   $FAIL .bash_profile not found — will link\n"
fi

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
DOTFILES_REPO="https://github.com/linkvectorized/dotfiles.git"

echo ""
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR" &>/dev/null &
  spinner $! "Cloning dotfiles..."
else
  git -C "$DOTFILES_DIR" pull &>/dev/null &
  spinner $! "Dotfiles up to date"
fi

if [ ! -f "$HOME/.bash_profile" ] || [ "$(readlink "$HOME/.bash_profile")" != "$DOTFILES_DIR/.bash_profile" ]; then
  ln -sf "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"
  printf "   $PASS .bash_profile linked\n"
else
  printf "   $PASS .bash_profile already linked\n"
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

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}"
cat << 'EOF'
  ╔══════════════════════════════════════════════╗
  ║              ALL DONE. YOU'RE SET.           ║
  ╚══════════════════════════════════════════════╝
EOF
printf "${NC}\n"

printf "  Restart your terminal or run: ${CYAN}source ~/.bash_profile${NC}\n\n"

printf "  ${BOLD}Versions:${NC}\n"
printf "    brew:   $(brew --version | head -1)\n"
printf "    gh:     $(gh --version | head -1)\n"
printf "    node:   $(node --version)\n"
printf "    go:     $(go version)\n"
printf "    claude: $(claude --version 2>/dev/null || echo 'check manually')\n"

echo ""
printf "${YELLOW}  Stay curious. Question narratives. Build cool things.${NC}\n\n"
