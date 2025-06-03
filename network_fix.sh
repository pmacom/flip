#!/bin/bash
# macOS Network Stack Corruption Fix Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check for quiet mode
QUIET=false
if [[ "$1" == "--quiet" ]]; then
    QUIET=true
fi

log() { 
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
    fi
}
success() { 
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}✅ $1${NC}"
    fi
}
warning() { 
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    fi
}
error() { 
    if [ "$QUIET" = false ]; then
        echo -e "${RED}❌ $1${NC}"
    fi
}

# Test if we can reach gateway
test_gateway() {
    local gateway=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
    if [ -z "$gateway" ]; then
        error "No default gateway found"
        return 1
    fi
    
    log "Testing gateway: $gateway"
    if ping -c 1 -W 2 "$gateway" &>/dev/null; then
        success "Gateway reachable"
        return 0
    else
        error "Gateway unreachable - network stack corruption detected"
        return 1
    fi
}

# Progressive fix attempts - MORE AGGRESSIVE to avoid laptop reboot
attempt_fixes() {
    log "🔧 Attempting network fixes (AGGRESSIVE MODE)..."
    
    # Level 1: Cache flush
    log "Level 1: Flushing caches..."
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    sleep 2
    
    if test_gateway; then
        success "Level 1 fix worked!"
        return 0
    fi
    
    # Level 2: ARP reset
    log "Level 2: Clearing ARP table..."
    sudo arp -d -a 2>/dev/null || true
    sleep 2
    
    if test_gateway; then
        success "Level 2 fix worked!"
        return 0
    fi
    
    # Level 3: Interface reset
    log "Level 3: Resetting network interface..."
    sudo route -n flush 2>/dev/null || true
    sudo ifconfig en0 down
    sleep 1
    sudo ifconfig en0 up
    sleep 3
    
    if test_gateway; then
        success "Level 3 fix worked!"
        return 0
    fi
    
    # Level 4: AGGRESSIVE - Try different interfaces
    log "Level 4: AGGRESSIVE - Testing alternate interfaces..."
    for iface in en1 en2 en3; do
        if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
            log "Trying interface reset on $iface..."
            sudo ifconfig "$iface" down 2>/dev/null || true
            sleep 1
            sudo ifconfig "$iface" up 2>/dev/null || true
            sleep 2
            if test_gateway; then
                success "Interface $iface reset worked!"
                return 0
            fi
        fi
    done
    
    # Level 5: NUCLEAR - Network service restart
    log "Level 5: NUCLEAR - Network service restart..."
    sudo launchctl kickstart -k system/com.apple.networkd 2>/dev/null || true
    sleep 5
    
    if test_gateway; then
        success "Network service restart worked!"
        return 0
    fi
    
    # Level 6: DESPERATE - Try manual route recovery
    log "Level 6: DESPERATE - Manual route recovery..."
    local gateway=$(netstat -rn | grep default | awk '{print $2}' | head -1)
    if [ -n "$gateway" ]; then
        sudo route delete default "$gateway" 2>/dev/null || true
        sleep 1
        sudo route add default "$gateway" 2>/dev/null || true
        sleep 2
        
        if test_gateway; then
            success "Manual route recovery worked!"
            return 0
        fi
    fi
    
    # Level 7: LAST RESORT - Try DHCP renewal
    log "Level 7: LAST RESORT - DHCP renewal..."
    sudo ipconfig set en0 DHCP 2>/dev/null || true
    sleep 5
    
    if test_gateway; then
        success "DHCP renewal worked!"
        return 0
    fi
    
    return 1
}

# Prevention recommendations
show_prevention_tips() {
    echo ""
    warning "🛡️  Prevention Tips:"
    echo "1. Add this to your .zshrc for automatic fixing:"
    echo "   alias fix-network='$PWD/network_fix.sh'"
    echo ""
    echo "2. Run before working with Pi:"
    echo "   ./network_fix.sh && pi-dev"
    echo ""
    echo "3. Consider this macOS network reset as last resort:"
    echo "   sudo launchctl kickstart -k system/com.apple.networkd"
    echo ""
}

# Main execution
main() {
    echo "🌐 macOS Network Stack Corruption Fix"
    echo "====================================="
    
    if test_gateway; then
        success "Network is healthy - no fix needed"
        exit 0
    fi
    
    if attempt_fixes; then
        success "Network fixed successfully!"
        
        # Test specific Pi connection
        log "Testing Pi connection..."
        if ping -c 1 -W 2 192.168.36.63 &>/dev/null; then
            success "Pi is now reachable!"
        else
            warning "Network fixed but Pi still not responding"
            echo "Pi might still be booting or SSH service not ready"
        fi
    else
        error "All automatic fixes failed"
        echo ""
        echo "🔄 REBOOT REQUIRED"
        echo "================="
        echo "This appears to be a deep macOS network stack corruption."
        echo "A laptop reboot will fix this issue."
        echo ""
        echo "After reboot:"
        echo "1. Run: ./dev_workflow.sh discover"
        echo "2. Transfer pi_harden_setup.sh to Pi"
        echo "3. This should prevent future occurrences"
        
        show_prevention_tips
        exit 1
    fi
}

main "$@" 