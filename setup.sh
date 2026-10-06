#!/bin/bash
# ==========================================
#   Linux Health Monitor - Setup
#   Installs the script, log rotation, and cron job.
# ==========================================

set -euo pipefail

PROJECT_DIR="/opt/linux-health-monitor"
LOG_DIR="/var/log/linux-health-monitor"
SCRIPT="$PROJECT_DIR/health-check.sh"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root:  sudo ./setup.sh"
    exit 1
fi

for f in "$SRC_DIR/health-check.sh" "$SRC_DIR/config/linux-health-monitor.logrotate"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Required file not found: $f"
        exit 1
    fi
done

echo "=========================================="
echo " Linux Health Monitor - Setup"
echo "=========================================="

echo "[1/5] Installing script to $PROJECT_DIR ..."
mkdir -p "$PROJECT_DIR"
install -m 755 "$SRC_DIR/health-check.sh" "$SCRIPT"

echo "[2/5] Creating log directory and files..."
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/health.log" "$LOG_DIR/alerts.log"

echo "[3/5] Installing logrotate configuration..."
install -m 644 "$SRC_DIR/config/linux-health-monitor.logrotate" /etc/logrotate.d/linux-health-monitor

echo "[4/5] Configuring cron (every minute)..."
CRON_JOB="* * * * * $SCRIPT >/dev/null 2>&1"
( crontab -l 2>/dev/null | grep -vF "$SCRIPT" || true
  echo "$CRON_JOB"
) | crontab -

echo "[5/5] Verifying setup..."
echo
echo "Cron:"
crontab -l | grep -F "$SCRIPT"

echo
echo "Logrotate config check:"
if logrotate -d /etc/logrotate.d/linux-health-monitor >/dev/null 2>&1; then
    echo "OK"
else
    echo "WARNING: logrotate reported a problem with the config."
fi

echo
echo "Log directory:"
ls -lh "$LOG_DIR"

echo
echo "=========================================="
echo " Setup completed successfully!"
echo "=========================================="