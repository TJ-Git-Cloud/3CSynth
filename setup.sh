#!/bin/bash
# setup.sh
# 3CSynth — one-command project setup
#
# Run this once from inside the 3CSynth folder:
#   cd 3CSynth
#   chmod +x setup.sh
#   ./setup.sh
#
# What it does:
#   1. Checks for Homebrew (installs if missing)
#   2. Installs XcodeGen via Homebrew if not already present
#   3. Runs xcodegen to produce 3CSynth.xcodeproj
#   4. Opens the project in Xcode
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

header() { echo -e "\n${BOLD}▸ $1${RESET}"; }
ok()     { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
die()    { echo -e "  ${RED}✗${RESET} $1"; exit 1; }

# ── Sanity check: must be run from the 3CSynth root ────────────────────────────
if [[ ! -f "project.yml" ]]; then
    die "project.yml not found. Run this script from inside the 3CSynth folder."
fi

echo -e "\n${BOLD}╔══════════════════════════════════════╗"
echo -e "║        3CSynth  ·  Project Setup       ║"
echo -e "╚══════════════════════════════════════╝${RESET}"

# ── Step 1: Homebrew ─────────────────────────────────────────────────────────
header "Checking for Homebrew"
if ! command -v brew &>/dev/null; then
    warn "Homebrew not found. Installing…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed."
else
    ok "Homebrew already installed ($(brew --version | head -1))."
fi

# ── Step 2: XcodeGen ─────────────────────────────────────────────────────────
header "Checking for XcodeGen"
if ! command -v xcodegen &>/dev/null; then
    echo "  Installing XcodeGen…"
    brew install xcodegen
    ok "XcodeGen installed ($(xcodegen --version))."
else
    ok "XcodeGen already installed ($(xcodegen --version))."
fi

# ── Step 3: Generate .xcodeproj ──────────────────────────────────────────────
header "Generating 3CSynth.xcodeproj"
xcodegen generate --spec project.yml
ok "3CSynth.xcodeproj generated."

# ── Step 4: Remind about Team ID ─────────────────────────────────────────────
echo ""
warn "Before building, open project.yml and set your Apple Developer Team ID:"
echo "      DEVELOPMENT_TEAM: \"YOUR_TEAM_ID\""
echo "  Then re-run: xcodegen generate"
echo ""
warn "Also update the bundle ID prefix in project.yml from 'com.yourcompany'"
echo "  to your own reverse-DNS identifier."

# ── Step 5: Open in Xcode ────────────────────────────────────────────────────
header "Opening in Xcode"
if [[ -d "3CSynth.xcodeproj" ]]; then
    open 3CSynth.xcodeproj
    ok "Xcode opened."
else
    die "3CSynth.xcodeproj not found after generation — check XcodeGen output above."
fi

echo -e "\n${GREEN}${BOLD}All done! 3CSynth is ready to build.${RESET}"
echo -e "Select the ${BOLD}3CSynthIOS${RESET} scheme and a simulator or device, then press ⌘R.\n"
