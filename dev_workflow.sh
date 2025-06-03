#!/bin/bash
# Enhanced Development Workflow for Pi Projects

set -e

# Configuration
PROJECT_DIR="/Users/patrickmacom/MainQuests/360/FLIP"
PI_USER="flip"
PI_EXPECTED_IP="192.168.36.63"
PI_HOSTNAME="flip.local"
NETWORK_RANGE="192.168.36"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Enhanced network health checking with automatic recovery
check_network_health() {
    log "🌐 Checking network health..."
    
    # Level 1: Quick health check
    local gateway=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
    if [ -z "$gateway" ]; then
        error "No default gateway found"
        return 1
    fi
    
    # Test gateway reachability
    if ping -c 1 -W 2 "$gateway" &>/dev/null; then
        success "Network is healthy"
        return 0
    fi
    
    # Level 2: Corruption detected - attempt automatic fix
    warning "Network corruption detected! Attempting automatic fix..."
    
    if [ -f "$SCRIPT_DIR/network_fix.sh" ]; then
        log "Running comprehensive network fix..."
        if "$SCRIPT_DIR/network_fix.sh" --quiet 2>/dev/null; then
            success "Network automatically repaired!"
            return 0
        fi
    fi
    
    # Level 3: Manual fixes
    log "Attempting manual network recovery..."
    
    # Try cache flush
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    sleep 2
    
    if ping -c 1 -W 2 "$gateway" &>/dev/null; then
        success "Cache flush fixed the issue!"
        return 0
    fi
    
    # Try ARP reset
    sudo arp -d -a 2>/dev/null || true
    sleep 2
    
    if ping -c 1 -W 2 "$gateway" &>/dev/null; then
        success "ARP reset fixed the issue!"
        return 0
    fi
    
    # Final failure - require reboot
    error "❌ CRITICAL: Network corruption requires laptop reboot"
    echo ""
    echo "🔄 REBOOT REQUIRED:"
    echo "   Your macOS network stack is corrupted beyond repair."
    echo "   This is a known Apple bug triggered by Pi reboots."
    echo ""
    echo "✨ After reboot run: $0 discover"
    echo ""
    exit 1
}

# Function to discover Pi on network
discover_pi() {
    echo "🔍 Discovering Pi on network..."
    echo "==============================="
    
    # Check network health first
    check_network_health
    
    # Scan for Pi
    log "Scanning local network for Pi..."
    local found_ips=($(nmap -sn 192.168.36.0/24 2>/dev/null | grep "Nmap scan report" | awk '{print $5}' | grep -E "192\.168\.36\.[0-9]+"))
    
    if [ ${#found_ips[@]} -eq 0 ]; then
        error "No devices found on 192.168.36.x network"
        info "Make sure Pi is powered on and connected"
        return 1
    fi
    
    success "Found ${#found_ips[@]} devices:"
    for ip in "${found_ips[@]}"; do
        # Try to identify Pi by SSH or hostname
        if timeout 2 nc -z "$ip" 22 2>/dev/null; then
            echo "  📡 $ip (SSH available)"
            if [ "$ip" != "$PI_EXPECTED_IP" ]; then
                warning "Pi found at different IP: $ip (expected: $PI_EXPECTED_IP)"
                read -p "Update PI_IP to $ip? (y/N): " update_ip
                if [[ $update_ip =~ ^[Yy] ]]; then
                    PI_EXPECTED_IP="$ip"
                    success "PI_IP updated to $ip"
                fi
            fi
        else
            echo "  📱 $ip"
        fi
    done
}

# Function to check Pi health
check_pi_health() {
    local pi_ip=$1
    log "🏥 Checking Pi health at $pi_ip..."
    
    # Test SSH connectivity
    if ! timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "echo 'SSH OK'" &>/dev/null; then
        error "SSH connection failed"
        return 1
    fi
    
    # Get health info
    local health_info=$(timeout 30 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "
        echo '=== Pi Health Report ==='
        echo 'Hostname:' \$(hostname)
        echo 'Uptime:' \$(uptime -p)
        echo 'Load:' \$(cat /proc/loadavg)
        echo 'Memory:' \$(free -h | grep Mem | awk '{print \$3\"/\"\$2}')
        echo 'Disk:' \$(df -h / | tail -1 | awk '{print \$3\"/\"\$2\" (\"\$5\" used)\"}')
        echo 'Temp:' \$(vcgencmd measure_temp 2>/dev/null || echo 'N/A')
        echo 'SSH Status:' \$(systemctl is-active ssh)
        echo 'Last reboot:' \$(who -b | awk '{print \$3\" \"\$4}')
        echo '==================='
    " 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        success "Pi is healthy"
        echo "$health_info"
        return 0
    else
        error "Health check failed"
        return 1
    fi
}

# Function to perform safe sync
safe_sync() {
    local pi_ip=$1
    log "🚀 Starting safe sync to $pi_ip..."
    
    # Pre-sync health check
    if ! check_pi_health "$pi_ip" >/dev/null; then
        error "Pi health check failed, aborting sync"
        return 1
    fi
    
    # Backup current Pi state before sync
    log "💾 Creating backup snapshot..."
    timeout 30 ssh -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "
        sudo rsync -a /home/flip/ /home/flip_backup_\$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
        ls -la /home/ | grep flip_backup | tail -3
    " 2>/dev/null || warning "Backup creation skipped"
    
    # Perform the sync
    log "📤 Syncing files..."
    rsync -avz --progress --timeout=60 \
          -e "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no" \
          --exclude='.git' \
          --exclude='*.log' \
          --exclude='.DS_Store' \
          "$PROJECT_DIR/" "$PI_USER@$pi_ip:/home/flip/project/"
    
    if [ $? -eq 0 ]; then
        success "Sync completed successfully"
        
        # Post-sync verification
        log "🔍 Verifying sync..."
        local file_count=$(timeout 15 ssh -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "find /home/flip/project -name '*.sh' | wc -l" 2>/dev/null)
        if [ -n "$file_count" ] && [ "$file_count" -gt 0 ]; then
            success "Verified $file_count script files on Pi"
        fi
        
        return 0
    else
        error "Sync failed"
        return 1
    fi
}

# Function to execute remote command safely
remote_exec() {
    local pi_ip=$1
    local command=$2
    log "⚡ Executing on Pi: $command"
    
    timeout 60 ssh -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "$command"
}

# Function to safe shutdown Pi
safe_shutdown_pi() {
    local pi_ip=$1
    log "🛑 Initiating safe Pi shutdown..."
    
    timeout 30 ssh -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "
        echo 'Stopping services...'
        sudo systemctl stop ssh --no-block
        echo 'Syncing filesystem...'
        sync
        echo 'Shutting down...'
        sudo shutdown -h now
    " 2>/dev/null || true
    
    success "Shutdown command sent"
    log "Pi should be safely powered off in 30 seconds"
}

# Enhanced Pi prevention workflow
prevent_pi_corruption() {
    local pi_ip=$1
    log "🛡️  Running Pi corruption prevention..."
    
    # Check if hardening script exists on Pi
    if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "test -f /home/flip/pi_harden_setup.sh" 2>/dev/null; then
        log "Found hardening script on Pi - checking if applied..."
        
        local is_hardened=$(timeout 10 ssh -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "
            if systemctl is-active watchdog >/dev/null 2>&1 && 
               grep -q 'tmpfs.*tmp' /etc/fstab 2>/dev/null; then
                echo 'true'
            else
                echo 'false'
            fi
        " 2>/dev/null)
        
        if [ "$is_hardened" = "true" ]; then
            success "Pi is already hardened against corruption"
        else
            warning "Pi hardening not complete - applying now..."
            timeout 60 ssh -o StrictHostKeyChecking=no "$PI_USER@$pi_ip" "
                cd /home/flip
                sudo ./pi_harden_setup.sh
            " 2>/dev/null || warning "Hardening script execution failed"
        fi
    else
        info "Pi hardening script not found - will sync in next step"
    fi
}

# Main workflow function
main_workflow() {
    echo "🚀 Enhanced Pi Development Workflow"
    echo "=================================="
    
    case "${1:-auto}" in
        "discover")
            discover_pi
            ;;
        "health")
            if pi_ip=$(discover_pi); then
                check_pi_health "$pi_ip"
            fi
            ;;
        "sync")
            if pi_ip=$(discover_pi); then
                safe_sync "$pi_ip"
            fi
            ;;
        "exec")
            if pi_ip=$(discover_pi); then
                remote_exec "$pi_ip" "${2:-hostname}"
            fi
            ;;
        "shutdown")
            if pi_ip=$(discover_pi); then
                safe_shutdown_pi "$pi_ip"
            fi
            ;;
        "auto"|*)
            # Full workflow
            if pi_ip=$(discover_pi); then
                check_pi_health "$pi_ip"
                safe_sync "$pi_ip"
                success "Development workflow complete!"
                log "Pi is ready at: $pi_ip"
            else
                error "Cannot proceed without Pi connection"
                echo ""
                echo "💡 Troubleshooting steps:"
                echo "1. Check Pi power and boot LEDs"
                echo "2. Verify network connection"
                echo "3. Try: ./dev_workflow.sh discover"
                echo "4. Consider running Pi hardening script"
                exit 1
            fi
            ;;
    esac
}

# Execute main workflow
main_workflow "$@" 