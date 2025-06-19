#!/bin/bash

# System Health Check Script v2.2
# Consistent color scheme with cyan process headers
# Add to global /etc/zsh/zshrc if you are on zsh or /etc/bash.bashrc if you're on bash.

# Color Definitions (ANSI codes)
BOLD='\033[1m'
RED='\033[1;31m'       # Critical issues
GREEN='\033[1;32m'     # Good status
YELLOW='\033[1;33m'    # Warnings
BLUE='\033[1;34m'      # Information
PURPLE='\033[1;35m'    # Section headers
CYAN='\033[1;36m'      # Data values
NC='\033[0m'           # No Color

# System Info
HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")
DATE=$(date +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "date unknown")

# Header
echo -e "${PURPLE}╔════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   ${BLUE}SYSTEM HEALTH REPORT - ${GREEN}$HOSTNAME${PURPLE}   ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════╝${NC}"
echo -e "${BLUE}Generated: ${CYAN}$DATE${NC}\n"

# 1. Disk Usage
echo -e "${PURPLE}▓▓ DISK USAGE ▓▓${NC}"
df_output=$(df -h --output=source,size,used,avail,pcent,target 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${BLUE}Filesystem          Size  Used  Avail Use% Mounted on${NC}"
    echo "$df_output" | tail -n +2 | while read -r line; do
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        if [ "$usage" -gt 90 ]; then
            color="$RED"
        elif [ "$usage" -gt 80 ]; then
            color="$YELLOW"
        else
            color="$GREEN"
        fi
        echo -e "$line" | awk -v c="$color" -v nc="$NC" \
            '{printf "%-20s %-6s %-6s %-6s ", $1,$2,$3,$4;
              printf "%s%-5s%s %s\n", c, $5, nc, $6}'
    done
else
    echo -e "${RED}✗ Error checking disk usage${NC}"
fi

# 2. CPU and Memory
echo -e "\n${PURPLE}▓▓ CPU & MEMORY ▓▓${NC}"

# CPU Load
load=$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}')
if [ -n "$load" ]; then
    echo -e "${BLUE}Load Averages: ${CYAN}$load${NC}"
else
    echo -e "${YELLOW}⚠ Could not determine CPU load${NC}"
fi

# Memory Usage
mem_output=$(free -h 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "\n${BLUE}Memory Type   Total  Used   Free   Shared Buff/Cache Available${NC}"
    echo "$mem_output" | awk -v bl="$BLUE" -v cy="$CYAN" -v nc="$NC" \
        'NR==2 {printf "%-12s %-6s %-6s %-6s %-6s %-6s %-6s\n",
                cy "RAM:" nc, $2, $3, $4, $5, $6, $7}
         NR==3 {printf "%-12s %-6s %-6s %-6s %-6s %-6s %-6s\n",
                cy "Swap:" nc, $2, $3, $4, $5, $6, $7}'
else
    echo -e "${YELLOW}⚠ Could not check memory usage${NC}"
fi

# 3. System Services
echo -e "\n${PURPLE}▓▓ SERVICES ▓▓${NC}"
if command -v systemctl >/dev/null 2>&1; then
    failed_count=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [ "$failed_count" -eq 0 ]; then
        echo -e "${GREEN}✓ All services running normally${NC}"
    else
        echo -e "${RED}✗ Failed services ($failed_count):${NC}"
        systemctl --failed --no-legend 2>/dev/null | \
            awk -v rd="$RED" -v nc="$NC" '{print "  " rd "• " $1 nc " - " $2}'
    fi
else
    echo -e "${YELLOW}⚠ systemctl not available${NC}"
fi

# 4. Process Status
echo -e "\n${PURPLE}▓▓ PROCESS STATUS ▓▓${NC}"

# Top Memory Processes
echo -e "${BLUE}Top Memory Consumers:${NC}"
echo -e "${CYAN}  PID    USER     %MEM  COMMAND${NC}"
ps -eo pid,user,%mem,command --sort=-%mem 2>/dev/null | head -n 6 | \
    awk -v cy="$CYAN" -v nc="$NC" \
    'NR>1 {printf "  %-6s %-8s %s%-5s%s %s\n", $1, $2, cy, $3, nc, $4}'

# Top CPU Processes
echo -e "\n${BLUE}Top CPU Consumers:${NC}"
echo -e "${CYAN}  PID    USER     %CPU  COMMAND${NC}"
ps -eo pid,user,%cpu,command --sort=-%cpu 2>/dev/null | head -n 6 | \
    awk -v cy="$CYAN" -v nc="$NC" \
    'NR>1 {printf "  %-6s %-8s %s%-5s%s %s\n", $1, $2, cy, $3, nc, $4}'

# 5. Package Updates
echo -e "\n${PURPLE}▓▓ PACKAGE UPDATES ▓▓${NC}"
update_check() {
    if command -v apt-get >/dev/null 2>&1; then
        apt update >/dev/null 2>&1
        updates=$(apt list --upgradable 2>/dev/null | grep -vc "Listing...")
        echo "$updates"
    elif command -v dnf >/dev/null 2>&1; then
        updates=$(dnf check-update -q 2>/dev/null | grep -vc "^$")
        echo "$updates"
    elif command -v yum >/dev/null 2>&1; then
        updates=$(yum check-update -q 2>/dev/null | grep -vc "^$")
        echo "$updates"
    else
        echo "-1"
    fi
}

updates=$(update_check)
case $updates in
    -1) echo -e "${YELLOW}⚠ Package manager not found${NC}" ;;
    0)  echo -e "${GREEN}✓ System is up-to-date${NC}" ;;
    *)  echo -e "${YELLOW}⚠ $updates updates available${NC}" ;;
esac

# System Uptime
echo -e "\n${PURPLE}▓▓ SYSTEM UPTIME ▓▓${NC}"
uptime_output=$(uptime -p 2>/dev/null || echo "unknown")
echo -e "${BLUE}Uptime: ${CYAN}$uptime_output${NC}"

# User Data Section
echo -e "\n${PURPLE}▓▓ USER DATA ▓▓${NC}"

# Active Users Count
active_users=$(who | wc -l)
echo -e "${BLUE}Active Users: ${CYAN}$active_users${NC}"

# Logged In Users Details
echo -e "${BLUE}Logged In Users:${NC}"
who | awk -v cyan="${CYAN}" -v nc="${NC}" '{
    printf "%s%s%s\t", cyan, $1, nc
    for(i=2; i<=NF; i++) printf "%s ", $i
    printf "\n"
}'

# Footer
echo -e "\n${PURPLE}╔════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║          ${BLUE}SYSTEM CHECK COMPLETE          ${PURPLE}║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════╝${NC}"

