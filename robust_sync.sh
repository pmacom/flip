#!/bin/bash

# Robust Pi Sync Script - handles connection issues after reboots

PI_HOST="flip.local"
PI_USER="flip"
PI_IP="192.168.36.63"  # Fallback IP
SOURCE_DIR="/Users/patrickmacom/MainQuests/360/FLIP"
DEST_DIR="/home/flip/"
MAX_RETRIES=10
RETRY_DELAY=5

# Enable verbose logging
VERBOSE=true
LOG_FILE="/tmp/pisync_debug.log"

# Logging functions
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [DEBUG] $1" | tee -a "$LOG_FILE"
    fi
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

echo "🔄 Robust Pi Sync Starting..."
log "=== Pi Sync Session Started ==="
log "Target Host: $PI_HOST"
log "Fallback IP: $PI_IP"
log "Source: $SOURCE_DIR"
log "Destination: $PI_USER@$PI_HOST:$DEST_DIR"
log "Log file: $LOG_FILE"

# Function to test network connectivity
test_network_connectivity() {
    local host=$1
    local test_type=$2
    
    log_verbose "Testing $test_type connectivity to $host"
    
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        log_verbose "✅ Ping successful to $host"
        return 0
    else
        local ping_output=$(ping -c 1 -W 2 "$host" 2>&1)
        log_error "❌ Ping failed to $host: $ping_output"
        return 1
    fi
}

# Function to test SSH connectivity with detailed error reporting
test_ssh_connection() {
    local host=$1
    local test_type=$2
    
    log_verbose "Testing SSH connection to $PI_USER@$host"
    
    # First, test if SSH port is open
    if nc -z -w 3 "$host" 22 2>/dev/null; then
        log_verbose "✅ SSH port 22 is open on $host"
    else
        log_error "❌ SSH port 22 is not accessible on $host"
        return 1
    fi
    
    # Test SSH authentication
    local ssh_output=$(timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$PI_USER@$host" "echo 'SSH Connection Test Successful'" 2>&1)
    local ssh_exit_code=$?
    
    if [ $ssh_exit_code -eq 0 ]; then
        log_verbose "✅ SSH authentication successful to $PI_USER@$host"
        log_verbose "SSH response: $ssh_output"
        return 0
    else
        log_error "❌ SSH connection failed to $PI_USER@$host (exit code: $ssh_exit_code)"
        log_error "SSH error output: $ssh_output"
        
        # Analyze common SSH errors
        if echo "$ssh_output" | grep -q "Permission denied"; then
            log_error "→ Authentication issue: Check SSH keys or password"
        elif echo "$ssh_output" | grep -q "Connection refused"; then
            log_error "→ SSH service not running on Pi"
        elif echo "$ssh_output" | grep -q "No route to host"; then
            log_error "→ Network routing issue"
        elif echo "$ssh_output" | grep -q "Host key verification failed"; then
            log_error "→ SSH host key mismatch (run: ssh-keygen -R $host)"
        fi
        
        return 1
    fi
}

# Function to check DNS resolution
test_dns_resolution() {
    log_verbose "Testing DNS resolution for $PI_HOST"
    
    local resolved_ip=$(dig +short "$PI_HOST" 2>/dev/null | head -n1)
    if [ -n "$resolved_ip" ]; then
        log "✅ DNS resolution: $PI_HOST → $resolved_ip"
        if [ "$resolved_ip" != "$PI_IP" ]; then
            log "⚠️  DNS resolved IP ($resolved_ip) differs from expected IP ($PI_IP)"
        fi
        return 0
    else
        log_error "❌ DNS resolution failed for $PI_HOST"
        
        # Try alternative resolution methods
        local nslookup_result=$(nslookup "$PI_HOST" 2>&1)
        log_error "nslookup output: $nslookup_result"
        
        # Check if mDNS is working
        if command -v dns-sd >/dev/null 2>&1; then
            log_verbose "Checking mDNS/Bonjour resolution..."
            timeout 5 dns-sd -G v4 "$PI_HOST" 2>&1 | head -5 | while read line; do
                log_verbose "mDNS: $line"
            done
        fi
        
        return 1
    fi
}

# Function to wait for Pi to be ready
wait_for_pi() {
    log "⏳ Waiting for Pi to be ready..."
    
    # Initial system checks
    log "🔍 Running initial diagnostics..."
    test_dns_resolution
    
    for ((i=1; i<=MAX_RETRIES; i++)); do
        log "📡 Connection attempt $i/$MAX_RETRIES..."
        
        # First try hostname resolution
        if test_network_connectivity "$PI_HOST" "hostname"; then
            log "✅ Pi responding to ping via hostname ($PI_HOST)"
            if test_ssh_connection "$PI_HOST" "hostname"; then
                log "✅ SSH connection successful via hostname"
                return 0
            else
                log_error "❌ SSH failed despite ping success (hostname)"
            fi
        else
            log_error "❌ Ping failed to hostname ($PI_HOST)"
        fi
        
        # Fallback to direct IP
        if test_network_connectivity "$PI_IP" "IP"; then
            log "✅ Pi responding to ping via IP ($PI_IP)"
            if test_ssh_connection "$PI_IP" "IP"; then
                log "✅ SSH connection successful via IP"
                PI_HOST="$PI_IP"  # Use IP for rsync
                return 0
            else
                log_error "❌ SSH failed despite ping success (IP)"
            fi
        else
            log_error "❌ Ping failed to IP ($PI_IP)"
        fi
        
        # Additional diagnostics on failure
        if [ $i -eq 1 ]; then
            log "🔧 Running network diagnostics..."
            
            # Check local network interface
            local local_ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
            log "Local IP: $local_ip"
            
            # Check ARP table
            local arp_entry=$(arp -n | grep "$PI_IP" 2>/dev/null)
            if [ -n "$arp_entry" ]; then
                log "ARP entry found: $arp_entry"
            else
                log "No ARP entry for $PI_IP"
            fi
            
            # Check routing
            local route_info=$(route get "$PI_IP" 2>/dev/null)
            log_verbose "Route to Pi: $route_info"
        fi
        
        log "⏰ Pi not ready yet, waiting ${RETRY_DELAY}s before retry..."
        sleep $RETRY_DELAY
    done
    
    log_error "❌ Failed to connect to Pi after $MAX_RETRIES attempts"
    return 1
}

# Function to perform the sync
do_sync() {
    log "🚀 Starting rsync to $PI_USER@$PI_HOST..."
    log "Source: $SOURCE_DIR/"
    log "Destination: $PI_USER@$PI_HOST:$DEST_DIR"
    
    # Show what will be synced
    log_verbose "Files to sync:"
    find "$SOURCE_DIR" -name "*.sh" -o -name "*.md" | head -10 | while read file; do
        log_verbose "  - $file"
    done
    
    local rsync_start_time=$(date +%s)
    
    rsync -avz --timeout=30 --progress \
          -e "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -v" \
          "$SOURCE_DIR/" "$PI_USER@$PI_HOST:$DEST_DIR" 2>&1 | while read line; do
        log_verbose "rsync: $line"
    done
    
    local exit_code=${PIPESTATUS[0]}
    local rsync_end_time=$(date +%s)
    local duration=$((rsync_end_time - rsync_start_time))
    
    if [ $exit_code -eq 0 ]; then
        log "✅ Sync completed successfully in ${duration}s!"
    else
        log_error "❌ Sync failed with exit code: $exit_code after ${duration}s"
        
        # Common rsync error explanations
        case $exit_code in
            1)  log_error "→ Syntax or usage error" ;;
            2)  log_error "→ Protocol incompatibility" ;;
            3)  log_error "→ Errors selecting input/output files" ;;
            5)  log_error "→ Error starting client-server protocol" ;;
            10) log_error "→ Error in socket I/O" ;;
            11) log_error "→ Error in file I/O" ;;
            12) log_error "→ Error in rsync protocol data stream" ;;
            13) log_error "→ Errors with program diagnostics" ;;
            14) log_error "→ Error in IPC code" ;;
            20) log_error "→ Received SIGUSR1 or SIGINT" ;;
            21) log_error "→ Some error returned by waitpid()" ;;
            22) log_error "→ Error allocating core memory buffers" ;;
            23) log_error "→ Partial transfer due to error" ;;
            24) log_error "→ Partial transfer due to vanished source files" ;;
            25) log_error "→ The --max-delete limit stopped deletions" ;;
            30) log_error "→ Timeout in data send/receive" ;;
            35) log_error "→ Timeout waiting for daemon connection" ;;
            255) log_error "→ SSH connection failed" ;;
            *) log_error "→ Unknown error code: $exit_code" ;;
        esac
        
        return $exit_code
    fi
}

# Main execution
log "🏁 Starting main execution..."

if wait_for_pi; then
    do_sync
    log "=== Pi Sync Session Completed Successfully ==="
else
    log_error "=== Pi Sync Session Failed ==="
    echo ""
    echo "💡 Troubleshooting tips:"
    echo "   - Ensure Pi is powered on and fully booted (wait 2-3 minutes)"
    echo "   - Check network connection and cables"
    echo "   - Verify SSH is enabled on Pi: sudo systemctl status ssh"
    echo "   - Try connecting directly: ssh $PI_USER@$PI_HOST"
    echo "   - Check the detailed log: cat $LOG_FILE"
    echo "   - Clear SSH keys if needed: ssh-keygen -R $PI_HOST"
    exit 1
fi 