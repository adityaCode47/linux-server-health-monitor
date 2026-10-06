#!/bin/bash
# ==========================================
#   Alert demonstration
#   Runs a copy of health-check.sh with very low thresholds
#   and temporary logs, so your real logs are not touched.
# ==========================================

# No "set -e": health-check.sh exits with 1 or 2 by design.
set -uo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SRC_DIR/health-check.sh"

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: health-check.sh not found."
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

TEST="$WORKDIR/health-check-alert-test.sh"
TEST_LOG_DIR="$WORKDIR/logs"

echo "Creating temporary alert test..."
cp "$SOURCE" "$TEST"

sed -i 's/CPU_WARNING=80/CPU_WARNING=1/'   "$TEST"
sed -i 's/CPU_CRITICAL=90/CPU_CRITICAL=2/' "$TEST"
sed -i 's/MEM_WARNING=80/MEM_WARNING=1/'   "$TEST"
sed -i 's/MEM_CRITICAL=90/MEM_CRITICAL=2/' "$TEST"
sed -i 's/DISK_WARNING=80/DISK_WARNING=1/'   "$TEST"
sed -i 's/DISK_CRITICAL=90/DISK_CRITICAL=2/' "$TEST"

# Write test logs to a temporary directory instead of /var/log
sed -i "s|^LOG_DIR=.*|LOG_DIR=\"$TEST_LOG_DIR\"|" "$TEST"

chmod +x "$TEST"

echo
echo "=========================================="
echo "       ALERT TEST"
echo "=========================================="
echo
echo "Thresholds temporarily lowered."
echo "Running health check..."

"$TEST"
EXIT_CODE=$?

echo
echo "Exit code: $EXIT_CODE  (0=Healthy, 1=Warning, 2=Critical)"

echo
echo "=========================================="
echo "       ALERT LOG (test)"
echo "=========================================="
cat "$TEST_LOG_DIR/alerts.log" 2>/dev/null || echo "No alert log found."

echo
echo "Temporary test files removed. Your real logs were not modified."
echo "=========================================="