#!/bin/bash

# Color codes for beautiful output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Default values
COUNT=10
TIMEOUT=1

# Clear screen at start
clear

# Function to draw separator
draw_line() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

draw_line_light() {
    # echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}╭────────────────────────────────────────────────────────────╮${NC}"
}

# Function to show header
show_header() {
echo -e "${CYAN}${BOLD}"
echo '╔══════════════════════════════════════════════════════════╗'
echo '║             ███╗   ███╗████████╗██╗   ██╗                ║'
echo '║             ████╗ ████║╚══██╔══╝██║   ██║                ║'
echo '║             ██╔████╔██║   ██║   ██║   ██║                ║'
echo '║             ██║╚██╔╝██║   ██║   ██║   ██║                ║'
echo '║             ██║ ╚═╝ ██║   ██║   ╚██████╔╝                ║'
echo '║             ╚═╝     ╚═╝   ╚═╝    ╚═════╝                 ║'
echo '║              PING MTU TESTER - ADVANCED                  ║'
echo '║                   « Version 3.1 »                        ║'
echo '╚══════════════════════════════════════════════════════════╝'
echo -e "${NC}"
}

# Function for single MTU test
single_mtu_test() {
    local mtu=$1
    local target=$2
    local payload=$((mtu - 28))
    echo -e "\n${BOLD}📡 Testing MTU: ${WHITE}$mtu${NC} → ${WHITE}$target${NC}"
    draw_line_light
    local successful=0
    local failed=0
    declare -a ping_times=()
    # Show header
    printf "\n${BOLD}%-4s %-15s %-10s${NC}\n" "No." "Status" "Time"
    draw_line_light
    # Perform pings
    for ((i=1; i<=$COUNT; i++)); do
        result=$(ping -c 1 -W $TIMEOUT -M do -s $payload $target 2>&1)
        if echo "$result" | grep -q "time="; then
            time_ms=$(echo "$result" | grep -oP 'time=\K[0-9.]+')
            ping_times+=($time_ms)
            ((successful++))
            printf "${GREEN}✓${NC} %-3d %-15s ${CYAN}%.1f ms${NC}\n" $i "Success" $time_ms
        else
            ((failed++))
            printf "${RED}✗${NC} %-3d %-15s ${RED}Failed${NC}\n" $i "Timeout"
        fi
        sleep 0.1
    done
    
    # Show summary
    draw_line_light
    echo -e "\n${BOLD}📊 Summary:${NC}"
    if [ $successful -gt 0 ]; then
        # Calculate statistics
        total=0
        min=${ping_times[0]}
        max=${ping_times[0]}
        for t in "${ping_times[@]}"; do
            total=$(echo "$total + $t" | bc)
            (( $(echo "$t < $min" | bc -l) )) && min=$t
            (( $(echo "$t > $max" | bc -l) )) && max=$t
        done
        avg=$(echo "scale=2; $total / $successful" | bc)
        loss=$((failed * 100 / COUNT))
        echo -e "  ${GREEN}✓ Successful:${NC} $successful/${COUNT}"
        echo -e "  ${RED}✗ Failed:${NC} $failed/${COUNT}"
        echo -e "  ${YELLOW}⚠ Loss:${NC} ${loss}%"
        echo -e "  ${CYAN}⏱  Average:${NC} ${avg} ms"
        echo -e "  ${GREEN}⬇  Min:${NC} ${min} ms"
        echo -e "  ${RED}⬆  Max:${NC} ${max} ms"
        if [ $loss -eq 0 ]; then
            echo -e "  ${GREEN}★ Status: Perfect${NC}"
        elif [ $loss -lt 20 ]; then
            echo -e "  ${YELLOW}★ Status: Acceptable${NC}"
        else
            echo -e "  ${RED}★ Status: Poor${NC}"
        fi
    else
        echo -e "  ${RED}✗ All pings failed - 100% packet loss${NC}"
    fi
}

# Function for multi MTU scan
multi_mtu_scan() {
    local target=$1
    echo -e "\n${BOLD}🔍 SCANNING MULTIPLE MTU VALUES${NC}"
    draw_line
    # MTU values to test
    mtu_values=(700 800 900 1000 1150 1200 1400 1450 1472 1480 1500)
    echo -e "${YELLOW}Target:${NC} $target"
    echo -e "${YELLOW}Testing:${NC} ${#mtu_values[@]} MTU sizes\n"
    # Arrays for results
    declare -a results=()
    for mtu in "${mtu_values[@]}"; do
        payload=$((mtu - 28))
        echo -ne "${BOLD}MTU ${WHITE}$mtu${NC}: Testing "
        # Quick test with 3 pings
        success=0
        for ((i=1; i<=3; i++)); do
            if ping -c 1 -W 1 -M do -s $payload $target >/dev/null 2>&1; then
                ((success++))
                echo -ne "${GREEN}✓${NC} "
            else
                echo -ne "${RED}✗${NC} "
            fi
            sleep 0.1
        done
        # Calculate result
        if [ $success -eq 3 ]; then
            echo -e " → ${GREEN}WORKS PERFECTLY${NC}"
            results+=("$mtu|perfect")
        elif [ $success -gt 0 ]; then
            echo -e " → ${YELLOW}PARTIAL ($success/3)${NC}"
            results+=("$mtu|partial")
        else
            echo -e " → ${RED}FAILED${NC}"
            results+=("$mtu|failed")
        fi
    done
    # Show summary table
    echo -e "\n${BOLD}📋 SCAN RESULTS${NC}"
    draw_line
    printf "${BOLD}%-8s %-12s %s${NC}\n" "MTU" "Status" "Recommendation"
    draw_line_light
    perfect_count=0
    for result in "${results[@]}"; do
        IFS='|' read -r mtu status <<< "$result"
        case $status in
            "perfect")
                echo -e "${GREEN}✓${NC} ${WHITE}$mtu${NC}    ${GREEN}Working${NC}      ✅ Best choice"
                ((perfect_count++))
                ;;
            "partial")
                echo -e "${YELLOW}~${NC} ${WHITE}$mtu${NC}    ${YELLOW}Partial${NC}      ⚠ May have issues"
                ;;
            "failed")
                echo -e "${RED}✗${NC} ${WHITE}$mtu${NC}    ${RED}Failed${NC}       ❌ Not usable"
                ;;
        esac
    done
    draw_line
    # Recommendations
    if [ $perfect_count -gt 0 ]; then
        echo -e "\n${GREEN}✅ RECOMMENDATIONS:${NC}"
        # Find highest working MTU
        highest=0
        for result in "${results[@]}"; do
            IFS='|' read -r mtu status <<< "$result"
            if [[ "$status" == "perfect" ]] && [ $mtu -gt $highest ]; then
                highest=$mtu
            fi
        done
        echo -e "  • Best performance: ${GREEN}MTU $highest${NC}"
        echo -e "  • Most compatible: ${GREEN}MTU 1460${NC} or ${GREEN}MTU 1472${NC}"
        echo -e "  • Maximum working: ${GREEN}MTU $highest${NC}"
        if [ $highest -ge 1500 ]; then
            echo -e "  ${GREEN}★ Your connection supports standard 1500 MTU${NC}"
        elif [ $highest -ge 1472 ]; then
            echo -e "  ${YELLOW}★ Your connection supports PPPoE (1492) or similar${NC}"
        else
            echo -e "  ${RED}★ Your connection has MTU restrictions${NC}"
        fi
    else
        echo -e "\n${RED}❌ No fully working MTUs found!${NC}"
    fi
}

# Function for quick test
quick_test() {
    local target=$1
    echo -e "\n${BOLD}⚡ QUICK MTU TEST${NC}"
    draw_line
    echo -e "Testing most common MTU values...\n"
    # Test most important MTUs
    critical_mtus=(700 800 900 1000 1150 1200 1400 1450 1472 1480 1500)
    working=()
    printf "${BOLD}%-8s %-12s %s${NC}\n" "MTU" "Result" "Usage"
    draw_line_light
    for mtu in "${critical_mtus[@]}"; do
        payload=$((mtu - 28))
        if ping -c 2 -W 1 -M do -s $payload $target >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} ${WHITE}$mtu${NC}    ${GREEN}Working${NC}      ✔ Good"
            working+=($mtu)
        else
            echo -e "${RED}✗${NC} ${WHITE}$mtu${NC}    ${RED}Failed${NC}       ✘ Not working"
        fi
    done
    draw_line
    if [ ${#working[@]} -gt 0 ]; then
        echo -e "\n${GREEN}✅ Best MTU for you: ${WHITE}${working[-1]}${NC}"
    else
        echo -e "\n${RED}❌ Try lower MTU values (1300-1450)${NC}"
    fi
}

# Function for path discovery
path_discovery() {
    local target=$1
    echo -e "\n${BOLD}🔎 PATH MTU DISCOVERY${NC}"
    draw_line
    echo -e "Finding maximum MTU to ${WHITE}$target${NC}...\n"
    local low=800
    local high=1500
    local last_working=1150
    printf "${BOLD}%-10s %-15s${NC}\n" "Testing" "Result"
    draw_line_light
    while [ $low -le $high ]; do
        local mid=$(( (low + high) / 2 ))
        local payload=$((mid - 28))
        printf "MTU %-6s" "$mid"
        if ping -c 2 -W 1 -M do -s $payload $target >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Working${NC}"
            last_working=$mid
            low=$((mid + 1))
        else
            echo -e "${RED}✗ Failed${NC}"
            high=$((mid - 1))
        fi
    done
    draw_line
    echo -e "\n${GREEN}🎯 Path MTU: ${WHITE}$last_working${NC}"
    # Additional info
    if [ $last_working -eq 1500 ]; then
        echo -e "${GREEN}✓ Your path supports standard Ethernet MTU${NC}"
    elif [ $last_working -ge 1492 ]; then
        echo -e "${YELLOW}⚠ Your path supports PPPoE (1492)${NC}"
    elif [ $last_working -ge 1472 ]; then
        echo -e "${YELLOW}⚠ Your path supports VPN/PPTP ranges${NC}"
    else
        echo -e "${RED}✗ Your path has significant MTU restrictions${NC}"
    fi
}

# Main menu
while true; do
    clear
    show_header
    echo -e "${BOLD}📋 MENU${NC}"
    draw_line
    echo -e "${GREEN}1)${NC} Single MTU Test     ${DIM}(detailed ping results)${NC}"
    echo -e "${GREEN}2)${NC} Multi-MTU Scan      ${DIM}(find best MTU)${NC}"
    echo -e "${GREEN}3)${NC} Quick Test          ${DIM}(test common values)${NC}"
    echo -e "${GREEN}4)${NC} Path Discovery      ${DIM}(find max MTU)${NC}"
    echo -e "${RED}5)${NC} Exit"
    draw_line
    echo -n -e "${CYAN}► Choose [1-5]: ${NC}"
    read choice
    case $choice in
        1|2|3|4)
            echo -n -e "${YELLOW}► Target IP: ${NC}"
            read target_ip
            if [[ ! "$target_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "\n${RED}Invalid IP!${NC}"
                echo -e "${YELLOW}Press Enter${NC}"
                read
                continue
            fi
            clear
            show_header
            case $choice in
                1)
                    echo -n -e "${YELLOW}► MTU size [68-1500]: ${NC}"
                    read mtu_size
                    if [[ "$mtu_size" =~ ^[0-9]+$ ]] && [ "$mtu_size" -ge 68 ] && [ "$mtu_size" -le 1500 ]; then
                        single_mtu_test $mtu_size $target_ip
                    else
                        echo -e "\n${RED}Invalid MTU!${NC}"
                    fi
                    ;;
                2)
                    multi_mtu_scan $target_ip
                    ;;
                3)
                    quick_test $target_ip
                    ;;
                4)
                    path_discovery $target_ip
                    ;;
            esac
            
            echo -e "\n${YELLOW}Press Enter to continue...${NC}"
            read
            ;;
        5)
            clear
            echo -e "${GREEN}"
            echo '    ╔═════════════════════════════════════════════════════╗'
            echo '    ║      Thanks for using MTU Tester! Goodbye! 👋       ║'
            echo '    ╚═════════════════════════════════════════════════════╝'
            echo -e "${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option!${NC}"
            echo -e "${YELLOW}Press Enter${NC}"
            read
            ;;
    esac
done
