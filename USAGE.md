# Bug Hunter Master Pipeline v2.0 — Usage Guide

## File Structure

```
bug_hunter_pipeline.sh   <- Main script
install_tools.sh         <- Tool installer
USAGE.md                 <- This guide
```

---

## Step 1 — Installation

```bash
# 1. Clone the files
git clone https://github.com/minhaj-infosec/Bug-Hunter.git
cd Bug-Hunter

# 2. Install all tools at once
bash install_tools.sh

# 3. Make script executable
chmod +x bug_hunter_pipeline.sh

# 4. Reload PATH (if Go was freshly installed)
source ~/.bashrc
```

---

## Step 2 — Running the Script

### 2.1 Simplest — just give a domain

```bash
./bug_hunter_pipeline.sh -d target.com
```

This is enough. All five phases will run automatically.

---

### 2.2 Full pipeline — all features enabled

```bash
./bug_hunter_pipeline.sh \
  -d target.com \
  -t "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoidXNlcjEifQ.xxx" \
  -c "abc123.oast.fun" \
  -T "110201543:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw" \
  -C "1234567890" \
  -S "https://hooks.slack.com/services/T.../B.../xxx" \
  -x 80 \
  -r 150
```

**What each flag does:**

| Flag | What to provide | Purpose |
|------|----------------|---------|
| `-d` | `target.com` | **Required.** Target domain |
| `-t` | JWT token | For authenticated IDOR/BAC testing |
| `-c` | `abc.oast.fun` | OOB server for blind SQLi/SSRF/Host-header |
| `-T` | Telegram bot token | Sends Telegram alert on findings |
| `-C` | Telegram chat ID | Your Telegram chat ID |
| `-S` | Slack webhook URL | Sends Slack alert on findings |
| `-x` | Number (default 50) | Concurrent threads |
| `-r` | Number (default 100) | Rate limit per second |

---

### 2.3 Running by Mode

#### Recon only (fast subdomain scan)
```bash
./bug_hunter_pipeline.sh -d target.com -m recon
```

#### Hunt only (if recon already done)
```bash
./bug_hunter_pipeline.sh \
  -d target.com \
  -m hunt \
  -o ./hunt_target.com_20240601_120000
# Use -o to point to existing recon output folder
```

#### Monitor setup only
```bash
./bug_hunter_pipeline.sh -d target.com -m monitor
```

---

### 2.4 Skip Flags — to save time

```bash
# Skip monitor setup (useful in CI/CD)
./bug_hunter_pipeline.sh -d target.com --skip-monitor

# Skip HTML report generation
./bug_hunter_pipeline.sh -d target.com --skip-report

# Stop after Phase 1 recon
./bug_hunter_pipeline.sh -d target.com --only-recon

# Show verbose output
./bug_hunter_pipeline.sh -d target.com -v
```

---

### 2.5 Custom Output Directory

```bash
./bug_hunter_pipeline.sh -d target.com -o /home/user/hunts/target_com
```

---

## Output Folder Structure

```
hunt_target.com_20240601_120000/
|
|-- 01_recon/
|   |-- all_subs.txt              <- All unique subdomains
|   |-- subs/
|   |   |-- subfinder.txt
|   |   |-- assetfinder.txt
|   |   |-- crtsh.txt
|   |   └-- wayback_subs.txt
|   |-- live/
|   |   |-- live_hosts.txt        <- httpx output (status+title+tech)
|   |   └-- scored_targets.txt    <- Sorted by score
|   |-- cloud/
|   |   |-- s3.txt
|   |   |-- azure.txt
|   |   └-- gcp.txt
|   |-- certs/
|   |   └-- ssl_info.txt
|   └-- ports/
|       └-- nmap_results.txt
|
|-- 02_js_hunter/
|   |-- files/
|   |   └-- all_js.txt            <- All JS file URLs
|   |-- secrets/
|   |   └-- raw_secrets.txt       <- All secrets found (WARNING)
|   |-- endpoints/
|   |   |-- rest_api.txt          <- API endpoints from JS
|   |   |-- graphql_ops.txt
|   |   └-- hardcoded_urls.txt
|   └-- sourcemaps/
|       |-- found.txt             <- Exposed .map files
|       └-- original_sources.txt
|
|-- 03_param_hunter/
|   |-- urls/
|   |   |-- all_params.txt        <- All parameterized URLs
|   |   |-- xss_candidates.txt
|   |   |-- sqli_candidates.txt
|   |   └-- redirect_candidates.txt
|   |-- xss/
|   |   |-- reflected.txt
|   |   └-- confirmed.txt         <- Confirmed XSS
|   |-- sqli/
|   |   |-- error_based.txt       <- Confirmed SQLi
|   |   └-- potential_blind.txt
|   |-- ssti/
|   |   └-- confirmed.txt         <- Confirmed SSTI
|   |-- redirect/
|   |   └-- confirmed.txt
|   └-- other/
|       └-- crlf.txt
|
|-- 04_bac_finder/
|   |-- idor/
|   |   └-- numeric.txt           <- IDOR hits
|   |-- methods/
|   |   └-- bypass.txt            <- Method switching results
|   |-- 403bypass/
|   |   └-- found.txt             <- Header/path bypass results
|   |-- cors/
|   |   └-- misconfig.txt         <- CORS issues
|   |-- jwt/
|   |   └-- results.txt           <- JWT attack results
|   └-- graphql/
|       |-- findings.txt
|       └-- schema.txt
|
|-- pipeline.log                  <- Full execution log
|-- stats.env                     <- Numeric findings summary
└-- report_target.com_TIMESTAMP.html  <- HTML report
```

---

## How to Read Output

### Check these files first — most important:

```bash
# 1. Critical findings (secrets)
cat hunt_*/02_js_hunter/secrets/raw_secrets.txt

# 2. Top juicy targets
head -20 hunt_*/01_recon/live/scored_targets.txt

# 3. Confirmed SQLi
cat hunt_*/03_param_hunter/sqli/error_based.txt

# 4. IDOR findings
cat hunt_*/04_bac_finder/idor/numeric.txt

# 5. Open HTML report in browser
firefox hunt_*/report_*.html
```

---

## Telegram Bot Setup (for notifications)

```
1. Open Telegram and message @BotFather
2. Send /newbot and follow the steps
3. You will receive a token -> use this for the -T flag
4. To get your chat ID, open this URL in browser:
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   Look for "chat":{"id":XXXXXXX} -> use this for the -C flag
```

---

## Interactsh OOB Server Setup (for -c flag)

```bash
# Option 1: Run interactsh-client yourself
interactsh-client
# It will give you something like: abc123.oast.fun
# Use that value for the -c flag

# Option 2: Use Burp Collaborator
# Burp Suite Pro -> Burp menu -> Burp Collaborator -> Copy to clipboard
```

---

## Real-World Workflow

### Scenario 1: New private program found

```bash
# Step 1: Quick recon first
./bug_hunter_pipeline.sh -d target.com -m recon -x 100

# Step 2: Review juicy targets
head -30 hunt_target.com_*/01_recon/live/scored_targets.txt

# Step 3: Run full hunt using existing recon output
./bug_hunter_pipeline.sh \
  -d target.com \
  -m hunt \
  -t "YOUR_JWT" \
  -c "YOUR_COLLAB" \
  -o hunt_target.com_*/
```

### Scenario 2: Monitor for first blood

```bash
# Set it up once — works even while you sleep
./bug_hunter_pipeline.sh \
  -d target.com \
  -m monitor \
  -T "BOT_TOKEN" \
  -C "CHAT_ID"

# When a new subdomain goes live, Telegram alert fires
# Wake up -> new target -> hunt before anyone else -> first blood
```

### Scenario 3: New scope added to existing program

```bash
# Run only on the new scope
./bug_hunter_pipeline.sh \
  -d newscope.target.com \
  -t "YOUR_JWT" \
  --skip-monitor \
  -x 100 -r 200
```

---

## Legal and Ethical Rules

```
DO    -> Run only on authorized targets and in-scope programs
DO    -> Read the bug bounty program rules before starting
DO    -> Practice responsible disclosure at all times
DO    -> Respect rate limits using the -r flag
DO NOT -> Scan unauthorized targets — this is illegal
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| command not found: subfinder | Run bash install_tools.sh |
| Go tools not in PATH | Run source ~/.bashrc or export PATH=$PATH:$HOME/go/bin |
| Permission denied | Run chmod +x bug_hunter_pipeline.sh |
| Getting rate limited or banned | Lower threads with -r 30 -x 20 |
| Empty output files | Verify the target is in scope |
| Cron monitor not working | Check with crontab -l |

---

*Bug Hunter Master Pipeline v2.0 — Authorized use only*
