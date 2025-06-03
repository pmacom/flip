#!/bin/bash
# Pi Hardening Script - Run this ONCE on your Pi to prevent zombie states

echo "🛡️ Hardening Raspberry Pi for Development..."

# === Pi Stability & Anti-Reboot Measures ===
echo "🛡️  Configuring Pi stability measures..."

# 1. Filesystem protection to prevent corruption
echo "Setting up filesystem protection..."
sudo tee -a /etc/fstab << 'EOF'
# Reduce filesystem wear and prevent corruption
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
tmpfs /var/log tmpfs defaults,noatime,mode=0755 0 0
tmpfs /var/tmp tmpfs defaults,noatime,mode=1777 0 0
EOF

# 2. Swap file configuration for memory stability
echo "Configuring swap for memory stability..."
sudo dphys-swapfile swapoff 2>/dev/null || true
echo 'CONF_SWAPSIZE=1024' | sudo tee /etc/dphys-swapfile > /dev/null
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# 3. Service auto-restart on failure
echo "Configuring service auto-restart..."
sudo tee /etc/systemd/system/ssh.service.d/restart.conf << 'EOF'
[Service]
Restart=always
RestartSec=5
EOF

# 4. Watchdog for system stability
echo "Enabling hardware watchdog..."
echo 'RuntimeWatchdogSec=30' | sudo tee -a /etc/systemd/system.conf > /dev/null
echo 'ShutdownWatchdogSec=10m' | sudo tee -a /etc/systemd/system.conf > /dev/null

# 5. Prevent unnecessary reboots
echo "Setting up graceful service management..."
sudo tee /usr/local/bin/smart_restart.sh << 'EOF'
#!/bin/bash
# Smart service restart - avoid full reboot
SERVICE=$1
echo "Smart restart requested for: $SERVICE"

case $SERVICE in
    "network"|"networking")
        sudo systemctl restart networking
        sudo systemctl restart dhcpcd
        ;;
    "video"|"flip")
        # Kill any existing flip processes
        pkill -f "flip\|ffmpeg" || true
        sleep 2
        ;;
    *)
        sudo systemctl restart "$SERVICE"
        ;;
esac
echo "Service restart completed without full reboot"
EOF
sudo chmod +x /usr/local/bin/smart_restart.sh

# 2. STABLE SSH CONFIGURATION
echo "🔑 Stabilizing SSH configuration..."

# Generate and fix SSH host keys so they don't regenerate
sudo ssh-keygen -A
sudo chmod 600 /etc/ssh/ssh_host_*
sudo chown root:root /etc/ssh/ssh_host_*

# Backup SSH keys to boot partition (survives SD corruption)
sudo mkdir -p /boot/ssh_backup
sudo cp /etc/ssh/ssh_host_* /boot/ssh_backup/

# Create restore script
sudo tee /etc/systemd/system/ssh-keys-restore.service << 'EOF'
[Unit]
Description=Restore SSH Host Keys
Before=ssh.service
ConditionPathExists=/boot/ssh_backup

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cp /boot/ssh_backup/ssh_host_* /etc/ssh/ && chmod 600 /etc/ssh/ssh_host_* && chown root:root /etc/ssh/ssh_host_*'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable ssh-keys-restore.service

# 3. NETWORK STABILITY
echo "🌐 Hardening network configuration..."

# Static IP configuration to prevent DHCP issues
sudo tee -a /etc/dhcpcd.conf << 'EOF'

# Static IP for development stability
interface eth0
static ip_address=192.168.36.63/24
static routers=192.168.36.1
static domain_name_servers=192.168.36.1 1.1.1.1

interface wlan0
static ip_address=192.168.36.63/24
static routers=192.168.36.1
static domain_name_servers=192.168.36.1 1.1.1.1
EOF

# 4. DEVELOPMENT SERVICES
echo "🚀 Setting up development services..."

# Auto-start SSH and ensure it's robust
sudo systemctl enable ssh
sudo systemctl enable systemd-networkd-wait-online.service

# Create development status beacon
sudo tee /etc/systemd/system/dev-beacon.service << 'EOF'
[Unit]
Description=Development Beacon
After=network.target ssh.service

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do echo "$(date): Pi Ready for Development" | logger -t dev-beacon; sleep 30; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable dev-beacon.service

# 5. GRACEFUL SHUTDOWN HANDLING
echo "⚡ Setting up power management..."

# Create shutdown script for clean exit
sudo tee /usr/local/bin/safe-shutdown.sh << 'EOF'
#!/bin/bash
# Graceful shutdown with development safety

echo "🛑 Initiating safe shutdown..."
systemctl stop dev-beacon.service
systemctl stop ssh.service
sync
systemctl poweroff
EOF

sudo chmod +x /usr/local/bin/safe-shutdown.sh

# Create shutdown alias
echo "alias safeshutdown='/usr/local/bin/safe-shutdown.sh'" >> ~/.bashrc

# 6. DEVELOPMENT OPTIMIZATIONS
echo "⚡ Development optimizations..."

# Disable unnecessary services to speed up boot
sudo systemctl disable bluetooth.service
sudo systemctl disable hciuart.service
sudo systemctl disable avahi-daemon.service 2>/dev/null || true
sudo systemctl disable cups.service 2>/dev/null || true

# Optimize boot speed
echo "disable_splash=1" | sudo tee -a /boot/config.txt
echo "boot_delay=0" | sudo tee -a /boot/config.txt

# 7. MONITORING AND RECOVERY
echo "📊 Setting up monitoring..."

# Create health check endpoint
sudo tee /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash
# Pi Health Check Script

echo "🏥 Pi Health Status:"
echo "Uptime: $(uptime)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo "SSH Status: $(systemctl is-active ssh)"
echo "Network: $(ip route get 8.8.8.8 | head -1)"
echo "Temperature: $(vcgencmd measure_temp)"
echo "Last Boot: $(who -b)"
EOF

sudo chmod +x /usr/local/bin/health-check.sh
echo "alias health='/usr/local/bin/health-check.sh'" >> ~/.bashrc

# 8. BACKUP CONFIGURATION
echo "💾 Setting up configuration backup..."

sudo tee /usr/local/bin/backup-config.sh << 'EOF'
#!/bin/bash
# Backup critical configuration to boot partition

BACKUP_DIR="/boot/config_backup"
sudo mkdir -p "$BACKUP_DIR"

# Backup critical files
sudo cp /etc/dhcpcd.conf "$BACKUP_DIR/"
sudo cp /etc/ssh/sshd_config "$BACKUP_DIR/"
sudo cp ~/.bashrc "$BACKUP_DIR/"
sudo cp /etc/fstab "$BACKUP_DIR/"

echo "✅ Configuration backed up to $BACKUP_DIR"
EOF

sudo chmod +x /usr/local/bin/backup-config.sh

# === EXTREME PI STABILITY - AVOID ALL REBOOTS ===
echo "🚨 EXTREME STABILITY MODE - Preventing ALL Pi reboots..."

# 1. Memory pressure handling - prevent OOM crashes
echo "Configuring memory protection..."
echo 'vm.panic_on_oom=0' | sudo tee -a /etc/sysctl.conf
echo 'vm.oom_kill_allocating_task=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.overcommit_memory=2' | sudo tee -a /etc/sysctl.conf
echo 'vm.overcommit_ratio=80' | sudo tee -a /etc/sysctl.conf

# 2. Disable ALL automatic reboots/updates
echo "Disabling automatic reboots..."
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.service
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl mask apt-daily.service apt-daily.timer
sudo systemctl mask apt-daily-upgrade.service apt-daily-upgrade.timer

# Disable kernel panic reboots
echo 'kernel.panic=0' | sudo tee -a /etc/sysctl.conf
echo 'kernel.panic_on_oops=0' | sudo tee -a /etc/sysctl.conf

# 3. Video/USB recovery without reboot
echo "Setting up video hardware recovery..."
sudo tee /usr/local/bin/recover_video.sh << 'EOF'
#!/bin/bash
# Recover video hardware without reboot
echo "🎥 Recovering video hardware..."

# Reset USB subsystem
echo '1-1' | sudo tee /sys/bus/usb/drivers/usb/unbind 2>/dev/null || true
sleep 2
echo '1-1' | sudo tee /sys/bus/usb/drivers/usb/bind 2>/dev/null || true

# Reset GPU memory
sudo modprobe -r bcm2835_v4l2 2>/dev/null || true
sleep 1
sudo modprobe bcm2835_v4l2 2>/dev/null || true

# Kill any stuck video processes
sudo pkill -9 -f "ffmpeg\|v4l2\|flip" 2>/dev/null || true

echo "✅ Video hardware recovery complete"
EOF
sudo chmod +x /usr/local/bin/recover_video.sh

# 4. Auto-recovery service for common issues
echo "Setting up auto-recovery service..."
sudo tee /etc/systemd/system/auto-recovery.service << 'EOF'
[Unit]
Description=Automatic Recovery Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/auto-recovery.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

sudo tee /usr/local/bin/auto-recovery.sh << 'EOF'
#!/bin/bash
# Continuous monitoring and auto-recovery

while true; do
    # Check memory usage
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$MEM_USAGE" -gt 90 ]; then
        echo "High memory usage detected: ${MEM_USAGE}% - clearing caches"
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    fi
    
    # Check for stuck video processes
    if pgrep -f "ffmpeg.*flip" > /dev/null; then
        PROCESS_AGE=$(ps -o etimes= -p $(pgrep -f "ffmpeg.*flip" | head -1) 2>/dev/null | tr -d ' ')
        if [ -n "$PROCESS_AGE" ] && [ "$PROCESS_AGE" -gt 300 ]; then
            echo "Stuck video process detected (${PROCESS_AGE}s) - recovering"
            /usr/local/bin/recover_video.sh
        fi
    fi
    
    # Check disk space
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 95 ]; then
        echo "Disk space critical: ${DISK_USAGE}% - cleaning up"
        sudo apt-get autoremove -y >/dev/null 2>&1
        sudo apt-get autoclean >/dev/null 2>&1
        find /tmp -type f -atime +1 -delete 2>/dev/null
    fi
    
    sleep 60
done
EOF
sudo chmod +x /usr/local/bin/auto-recovery.sh
sudo systemctl enable auto-recovery.service

# 5. Network recovery without reboot
echo "Setting up network recovery..."
sudo tee /usr/local/bin/recover_network.sh << 'EOF'
#!/bin/bash
# Network recovery without reboot
echo "🌐 Recovering network without reboot..."

# Restart network services in order
sudo systemctl restart dhcpcd
sleep 2
sudo systemctl restart networking
sleep 2

# Reset network interface
sudo ip link set eth0 down
sleep 1
sudo ip link set eth0 up
sleep 3

# Renew DHCP
sudo dhclient -r eth0 2>/dev/null
sudo dhclient eth0 2>/dev/null

echo "✅ Network recovery complete"
EOF
sudo chmod +x /usr/local/bin/recover_network.sh

echo "🎉 Pi hardening complete! Reboot for changes to take effect."
echo "📝 New commands available:"
echo "  - safeshutdown: Graceful shutdown"
echo "  - health: Check Pi status"
echo "  - /usr/local/bin/backup-config.sh: Backup configs" 