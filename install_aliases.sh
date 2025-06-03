#!/bin/bash
# Install enhanced Pi development aliases

cat >> ~/.zshrc << 'EOF'

# Enhanced Pi Development Aliases with Network Protection
alias pi-discover='cd "$FLIP_DIR" && ./dev_workflow.sh discover'
alias pi-health='cd "$FLIP_DIR" && ./dev_workflow.sh health'
alias pi-sync='cd "$FLIP_DIR" && ./dev_workflow.sh sync'
alias pi-dev='cd "$FLIP_DIR" && ./dev_workflow.sh dev'
alias pi-shutdown='cd "$FLIP_DIR" && ./dev_workflow.sh shutdown'
alias pi-logs='cd "$FLIP_DIR" && ./dev_workflow.sh logs'
alias pi-status='cd "$FLIP_DIR" && ./dev_workflow.sh status'

# Network troubleshooting with automatic recovery
alias fix-network='cd "$FLIP_DIR" && ./network_fix.sh'
alias network-health='cd "$FLIP_DIR" && ./network_fix.sh'

# ULTIMATE LAPTOP REBOOT PREVENTION ALIASES! 🚨
alias pisync_flip_mega='cd "$FLIP_DIR" && echo "🚨 MEGA PISYNC - AVOIDING LAPTOP REBOOT AT ALL COSTS!" && ./network_fix.sh --quiet || echo "Network issues detected but continuing..." && ./dev_workflow.sh sync && echo "✅ Sync complete despite network issues!"'

# Try THREE times before giving up
alias pisync_flip_retry='cd "$FLIP_DIR" && echo "🔄 RETRY MODE - 3 attempts to avoid reboot" && for i in {1..3}; do echo "Attempt $i/3..."; if ./network_fix.sh --quiet && ./dev_workflow.sh sync; then echo "✅ Success on attempt $i!"; break; elif [ $i -eq 3 ]; then echo "⚠️ All attempts failed - network recovery may be needed"; else sleep 10; fi; done'

# Emergency mode - bypass network checks entirely
alias pisync_flip_emergency='cd "$FLIP_DIR" && echo "🚨 EMERGENCY MODE - Bypassing network checks" && rsync -avz --timeout=10 -e "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no" ./ flip@192.168.36.63:/home/flip/project/ && echo "✅ Emergency sync complete!"'

# Enhanced pisync_flip - CORRUPTION PREVENTION EDITION! 🛡️
alias pisync_flip='cd "$FLIP_DIR" && echo "🛡️ ENHANCED PISYNC - Network Corruption Prevention Active!" && ./network_fix.sh --quiet && ./dev_workflow.sh sync && echo "✅ Sync complete with corruption protection!"'

# Quick commands with built-in network protection
alias pisync='cd "$FLIP_DIR" && ./network_fix.sh --quiet && ./robust_sync.sh'
alias fliptest='cd "$FLIP_DIR" && ./network_fix.sh --quiet && ./dev_workflow.sh sync && ./dev_workflow.sh dev "cd /home/flip && ./jFlip.sh"'

# Emergency recovery commands
alias network-nuclear='cd "$FLIP_DIR" && echo "☢️ NUCLEAR NETWORK RESET" && sudo route -n flush && sudo ifconfig en0 down && sleep 2 && sudo ifconfig en0 up'
alias pi-emergency='cd "$FLIP_DIR" && echo "🚨 Pi Emergency Recovery" && ./network_fix.sh && nmap -sn 192.168.36.0/24'
EOF

echo "✅ Pi development aliases installed! Restart your terminal or run 'source ~/.zshrc'" 