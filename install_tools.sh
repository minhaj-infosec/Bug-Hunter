#!/bin/bash
# ═══════════════════════════════════════════════════════
#  Bug Hunter Pipeline — Dependency Installer
#  Supports: Ubuntu/Debian, Kali, Parrot, Arch
#  Usage: bash install_tools.sh
# ═══════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; RESET='\033[0m'

OK()   { echo -e "${GREEN}[✓] $1${RESET}"; }
INFO() { echo -e "${CYAN}[*] $1${RESET}"; }
WARN() { echo -e "${YELLOW}[!] $1${RESET}"; }
FAIL() { echo -e "${RED}[✗] $1${RESET}"; }

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Bug Hunter Pipeline — Tool Installer       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${RESET}"

# ── Check Go ─────────────────────────────────────────
if ! command -v go &>/dev/null; then
  INFO "Installing Go 1.22..."
  wget -q "https://go.dev/dl/go1.22.3.linux-amd64.tar.gz" -O /tmp/go.tar.gz
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
  export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
  OK "Go installed: $(go version)"
else
  OK "Go already installed: $(go version)"
  export PATH=$PATH:$HOME/go/bin
fi

# ── Go-based tools ───────────────────────────────────
GO_TOOLS=(
  "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  "github.com/projectdiscovery/httpx/cmd/httpx@latest"
  "github.com/lc/gau/v2/cmd/gau@latest"
  "github.com/tomnomnom/anew@latest"
  "github.com/tomnomnom/uro@latest"
  "github.com/tomnomnom/gf@latest"
  "github.com/tomnomnom/qsreplace@latest"
  "github.com/tomnomnom/assetfinder@latest"
  "github.com/sensepost/gowitness@latest"
  "github.com/projectdiscovery/katana/cmd/katana@latest"
  "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
)

INFO "Installing Go tools..."
for tool in "${GO_TOOLS[@]}"; do
  NAME=$(basename ${tool%%@*})
  if command -v "$NAME" &>/dev/null; then
    OK "$NAME already installed"
  else
    INFO "Installing $NAME..."
    go install -v "$tool" 2>/dev/null && OK "$NAME installed" || FAIL "$NAME failed"
  fi
done

# ── gf patterns ──────────────────────────────────────
if command -v gf &>/dev/null; then
  INFO "Installing gf patterns..."
  GF_DIR="$HOME/.gf"
  mkdir -p "$GF_DIR"
  if [[ ! -d /tmp/gf-patterns ]]; then
    git clone -q https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns 2>/dev/null || true
    cp /tmp/gf-patterns/*.json "$GF_DIR/" 2>/dev/null || true
  fi
  OK "gf patterns installed to $GF_DIR"
fi

# ── System tools ─────────────────────────────────────
INFO "Installing system tools (nmap, wafw00f, python3)..."
if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq nmap python3 python3-pip curl wget git openssl dnsutils 2>/dev/null
  pip3 install wafw00f --quiet 2>/dev/null || true
  OK "System tools installed via apt"
elif command -v pacman &>/dev/null; then
  sudo pacman -Sy --noconfirm nmap python curl wget git openssl bind-tools 2>/dev/null
  pip3 install wafw00f --quiet 2>/dev/null || true
  OK "System tools installed via pacman"
else
  WARN "Unknown OS — install manually: nmap python3 curl wget git openssl"
fi

# ── Verify ───────────────────────────────────────────
echo ""
INFO "Verification:"
TOOLS=(subfinder httpx gau uro gf qsreplace anew python3 nmap curl openssl dig)
for t in "${TOOLS[@]}"; do
  command -v "$t" &>/dev/null && OK "$t" || FAIL "$t NOT FOUND"
done

echo ""
OK "Installation complete! Reload shell: source ~/.bashrc"
