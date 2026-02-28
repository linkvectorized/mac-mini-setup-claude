#!/usr/bin/env bash
# brian_script.sh — initialize a fresh Mac with core dev environment

set -e

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
NC=$'\033[0m' # No Color

PASS="${GREEN}[✓]${NC}"
FAIL="${RED}[✗]${NC}"

# ── Pre-flight check ──────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight check ──"
echo ""

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
    printf "   $PASS $pkg — $(command -v $pkg)\n"
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
echo "── Starting install ──"
echo ""

# ── 1. Xcode Command Line Tools ───────────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "    Waiting for Xcode CLT install to finish (click Install in the dialog)..."
  until xcode-select -p &>/dev/null; do sleep 5; done
else
  echo "==> Xcode CLT already installed, skipping"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "==> Homebrew already installed, skipping"
  eval "$(brew shellenv)"
fi

# ── 3. Brew packages ──────────────────────────────────────────────────────────
echo "==> Installing brew packages..."
for pkg in "${BREW_PACKAGES[@]}"; do
  if brew list --formula "$pkg" &>/dev/null; then
    echo "    $pkg already installed, skipping"
  else
    brew install "$pkg"
  fi
done

# ── 4. Dotfiles ───────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/linkvectorized/dotfiles.git"

if [ ! -d "$DOTFILES_DIR/.git" ]; then
  echo "==> Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "==> Dotfiles already cloned, pulling latest..."
  git -C "$DOTFILES_DIR" pull
fi

if [ ! -f "$HOME/.bash_profile" ] || [ "$(readlink "$HOME/.bash_profile")" != "$DOTFILES_DIR/.bash_profile" ]; then
  echo "==> Linking .bash_profile..."
  ln -sf "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"
else
  echo "==> .bash_profile already linked, skipping"
fi

# ── 5. Claude Code CLI ────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  echo "==> Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
else
  echo "==> Claude Code already installed, skipping"
fi

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "==> Writing Claude settings..."
  cat > "$SETTINGS_FILE" <<'EOF'
{
  "model": "sonnet",
  "skipDangerousModePermissionPrompt": true
}
EOF
else
  echo "==> Claude settings already exist, skipping"
fi

# ── 6. GitHub CLI auth ────────────────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
  echo "==> Authenticating GitHub CLI (follow the prompts)..."
  gh auth login
else
  echo "==> GitHub CLI already authenticated, skipping"
fi

# ── 7. Apps (Brave, Cursor) ───────────────────────────────────────────────────
echo "==> Installing apps..."
if [ -d "/Applications/Brave Browser.app" ]; then
  echo "    Brave Browser already installed, skipping"
else
  brew install --cask brave-browser
fi

if [ -d "/Applications/Cursor.app" ]; then
  echo "    Cursor already installed, skipping"
else
  brew install --cask cursor
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "==> All done! Restart your terminal (or run: source ~/.bash_profile)"
echo ""
echo "    brew:    $(brew --version | head -1)"
echo "    gh:      $(gh --version | head -1)"
echo "    node:    $(node --version)"
echo "    go:      $(go version)"
echo "    claude:  $(claude --version 2>/dev/null || echo 'check manually')"
