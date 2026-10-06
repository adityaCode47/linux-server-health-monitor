#!/bin/bash

# ==========================================
#       LINUX SERVER HEALTH MONITOR
# ==========================================

# ---------- THRESHOLDS ----------
CPU_WARNING=80
CPU_CRITICAL=90

MEM_WARNING=80
MEM_CRITICAL=90

DISK_WARNING=80
DISK_CRITICAL=90

LOG_DIR="/var/log/linux-health-monitor"
LOG_FILE="$LOG_DIR/health.log"
ALERT_FILE="$LOG_DIR/alerts.log"

mkdir -p "$LOG_DIR"

HOSTNAME=$(hostname)
DATE=$(date)
UPTIME=$(uptime -p)

STATUS=0

# ---------- CPU ----------
read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat

TOTAL1=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE1=$((idle + iowait))

sleep 1

read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat

TOTAL2=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE2=$((idle + iowait))

TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))

CPU_USAGE=$((100 * (TOTAL_DIFF - IDLE_DIFF) / TOTAL_DIFF))


# ---------- MEMORY ----------
MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/^Mem:/ {print $3}')
MEM_AVAILABLE=$(free -m | awk '/^Mem:/ {print $7}')

MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))


# ---------- DISK ----------
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')


# ---------- LOAD ----------
LOAD=$(awk '{print $1, $2, $3}' /proc/loadavg)


# ---------- PROCESSES ----------
PROCESS_COUNT=$(ps -e --no-headers | wc -l)


# ---------- TOP CPU PROCESSES ----------
TOP_PROCESS=$(ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6)


# ---------- STATUS ----------
CPU_STATUS="OK"
MEM_STATUS="OK"
DISK_STATUS="OK"

if [ "$CPU_USAGE" -ge "$CPU_CRITICAL" ]; then
    CPU_STATUS="CRITICAL"
    STATUS=2
elif [ "$CPU_USAGE" -ge "$CPU_WARNING" ]; then
    CPU_STATUS="WARNING"
    [ "$STATUS" -lt 1 ] && STATUS=1
fi

if [ "$MEM_PERCENT" -ge "$MEM_CRITICAL" ]; then
    MEM_STATUS="CRITICAL"
    STATUS=2
elif [ "$MEM_PERCENT" -ge "$MEM_WARNING" ]; then
    MEM_STATUS="WARNING"
    [ "$STATUS" -lt 1 ] && STATUS=1
fi

if [ "$DISK_PERCENT" -ge "$DISK_CRITICAL" ]; then
    DISK_STATUS="CRITICAL"
    STATUS=2
elif [ "$DISK_PERCENT" -ge "$DISK_WARNING" ]; then
    DISK_STATUS="WARNING"
    [ "$STATUS" -lt 1 ] && STATUS=1
fi


# ---------- OVERALL STATUS ----------
if [ "$STATUS" -eq 0 ]; then
    SYSTEM_STATUS="HEALTHY"
elif [ "$STATUS" -eq 1 ]; then
    SYSTEM_STATUS="WARNING"
else
    SYSTEM_STATUS="CRITICAL"
fi


# ---------- SCREEN OUTPUT ----------
echo
echo "=========================================="
echo "        LINUX SERVER HEALTH MONITOR"
echo "=========================================="

echo "Hostname        : $HOSTNAME"
echo "Date            : $DATE"
echo "Uptime          : $UPTIME"

echo "------------------------------------------"
echo "SYSTEM RESOURCES"
echo "------------------------------------------"

echo "CPU Usage       : ${CPU_USAGE}% [$CPU_STATUS]"
echo "Memory Usage    : ${MEM_PERCENT}% [$MEM_STATUS]"
echo "Memory Used     : ${MEM_USED} MB"
echo "Memory Total    : ${MEM_TOTAL} MB"
echo "Memory Available: ${MEM_AVAILABLE} MB"

echo "Disk Usage      : ${DISK_PERCENT}% [$DISK_STATUS]"
echo "Disk Used       : ${DISK_USED}"
echo "Disk Total      : ${DISK_TOTAL}"

echo "Load Average    : $LOAD"
echo "Processes       : $PROCESS_COUNT"

echo "------------------------------------------"
echo "TOP CPU PROCESSES"
echo "------------------------------------------"

echo "$TOP_PROCESS"

echo "------------------------------------------"
echo "SYSTEM STATUS   : $SYSTEM_STATUS"
echo "=========================================="
echo "              HEALTH CHECK DONE"
echo "=========================================="


# ---------- HEALTH LOG ----------
{
    echo "[$DATE]"
    echo "Hostname: $HOSTNAME"
    echo "CPU: ${CPU_USAGE}% [$CPU_STATUS]"
    echo "Memory: ${MEM_PERCENT}% [$MEM_STATUS]"
    echo "Disk: ${DISK_PERCENT}% [$DISK_STATUS]"
    echo "Load: $LOAD"
    echo "Processes: $PROCESS_COUNT"
    echo "Status: $SYSTEM_STATUS"
    echo "------------------------------------------"
} >> "$LOG_FILE"


# ---------- ALERT LOG ----------
if [ "$STATUS" -eq 2 ]; then
    {
        echo "[$DATE] CRITICAL ALERT"
        echo "Hostname: $HOSTNAME"
        echo "CPU: ${CPU_USAGE}% [$CPU_STATUS]"
        echo "Memory: ${MEM_PERCENT}% [$MEM_STATUS]"
        echo "Disk: ${DISK_PERCENT}% [$DISK_STATUS]"
        echo "Load: $LOAD"
        echo "------------------------------------------"
    } >> "$ALERT_FILE"
fi


# ---------- EXIT CODE ----------
exit "$STATUS"