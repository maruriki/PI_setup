#!/usr/bin/env sh
set -eu

# ============================================================
# setup_system_optimizations.sh
# ============================================================
# Purpose:
#   - Configure persistent logging (systemd-journald)
#   - Disable WiFi power management (wlan0)
#   - Configure Hardware Watchdog (bcm2835-wdt)
#
# Usage:
#   sudo ./setup_system_optimizations.sh
#
# Note:
#   This script requires root privileges.
# ============================================================

echo ""
echo "=========================================="
echo "System Optimizations Setup (Logs, WiFi, Watchdog)"
echo "=========================================="
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] This script requires root privileges" >&2
  echo "[INFO] Run with: sudo $0" >&2
  exit 1
fi

# === 1. Persistent Logging Setup ===
echo "[INFO] === Persistent Logging Setup ==="
echo ""

JOURNAL_DIR="/var/log/journal"
JOURNALD_CONF="/etc/systemd/journald.conf"

# Create journal directory
if [ ! -d "$JOURNAL_DIR" ]; then
  echo "[INFO] Creating journal directory: $JOURNAL_DIR"
  mkdir -p "$JOURNAL_DIR"
  echo "[OK] Journal directory created"
else
  echo "[INFO] Journal directory already exists: $JOURNAL_DIR"
fi

# Configure journald
echo "[INFO] Checking journald configuration: $JOURNALD_CONF"
if [ ! -f "$JOURNALD_CONF" ]; then
  echo "[WARN] journald.conf not found, creating..."
  touch "$JOURNALD_CONF"
fi

# Add or update configuration
if grep -q "^SystemMaxUse=" "$JOURNALD_CONF" 2>/dev/null; then
  echo "[INFO] SystemMaxUse already configured, keeping existing value"
else
  echo "[INFO] Adding SystemMaxUse=500M to journald.conf"
  echo "" >> "$JOURNALD_CONF"
  echo "# OmniWatchCare - Journal size limit" >> "$JOURNALD_CONF"
  echo "SystemMaxUse=500M" >> "$JOURNALD_CONF"
fi

if grep -q "^MaxFileSec=" "$JOURNALD_CONF" 2>/dev/null; then
  echo "[INFO] MaxFileSec already configured, keeping existing value"
else
  echo "[INFO] Adding MaxFileSec=1month to journald.conf"
  echo "MaxFileSec=1month" >> "$JOURNALD_CONF"
fi

# Restart journald
echo "[INFO] Restarting systemd-journald..."
systemctl restart systemd-journald
echo "[OK] systemd-journald restarted"

# Show current usage
DISK_USAGE=$(journalctl --disk-usage 2>&1 || echo "unknown")
echo "[INFO] Current journal disk usage: $DISK_USAGE"
echo ""

# === 2. WiFi Power Management Setup ===
echo "[INFO] === WiFi Power Management Setup ==="
echo ""

WIFI_POWERSAVE_CONF="/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf"
WIFI_POWERSAVE_DIR=$(dirname "$WIFI_POWERSAVE_CONF")

# Create config directory
if [ ! -d "$WIFI_POWERSAVE_DIR" ]; then
  echo "[INFO] Creating NetworkManager config directory: $WIFI_POWERSAVE_DIR"
  mkdir -p "$WIFI_POWERSAVE_DIR"
  echo "[OK] Directory created"
else
  echo "[INFO] NetworkManager config directory exists: $WIFI_POWERSAVE_DIR"
fi

# Create or update WiFi power management configuration
if [ -f "$WIFI_POWERSAVE_CONF" ]; then
  echo "[INFO] Configuration file exists: $WIFI_POWERSAVE_CONF"
  
  # Check current setting
  if grep -q "wifi.powersave = 2" "$WIFI_POWERSAVE_CONF" 2>/dev/null; then
    echo "[OK] WiFi power management already disabled (powersave = 2)"
  else
    echo "[INFO] Updating WiFi power management setting..."
    # Remove old setting if exists
    sed -i '/wifi.powersave/d' "$WIFI_POWERSAVE_CONF"
    # Add new setting
    echo "wifi.powersave = 2" >> "$WIFI_POWERSAVE_CONF"
    echo "[OK] WiFi power management disabled (powersave = 2)"
  fi
else
  echo "[INFO] Creating WiFi power management configuration: $WIFI_POWERSAVE_CONF"
  cat > "$WIFI_POWERSAVE_CONF" << 'EOF'
[connection]
wifi.powersave = 2
EOF
  echo "[OK] Configuration file created"
fi

# Restart NetworkManager
echo "[INFO] Restarting NetworkManager..."
systemctl restart NetworkManager
sleep 2
echo "[OK] NetworkManager restarted"
echo ""

# === 3. Hardware Watchdog Setup ===
echo "[INFO] === Hardware Watchdog Setup ==="
echo ""

SYSTEM_CONF="/etc/systemd/system.conf"
BACKUP_FILE="/etc/systemd/system.conf.bak_$(date +%Y%m%d_%H%M%S)"

# Backup configuration
echo "[INFO] Creating backup of system.conf: $BACKUP_FILE"
cp "$SYSTEM_CONF" "$BACKUP_FILE"

# Configure RuntimeWatchdogSec
if grep -q "^#*RuntimeWatchdogSec=" "$SYSTEM_CONF" 2>/dev/null; then
  echo "[INFO] Updating RuntimeWatchdogSec to 10"
  sed -i 's/^#*RuntimeWatchdogSec=.*/RuntimeWatchdogSec=10/' "$SYSTEM_CONF"
else
  echo "[INFO] Adding RuntimeWatchdogSec=10 to system.conf"
  echo "RuntimeWatchdogSec=10" >> "$SYSTEM_CONF"
fi

# Configure RebootWatchdogSec
if grep -q "^#*RebootWatchdogSec=" "$SYSTEM_CONF" 2>/dev/null; then
  echo "[INFO] Updating RebootWatchdogSec to 2min"
  sed -i 's/^#*RebootWatchdogSec=.*/RebootWatchdogSec=2min/' "$SYSTEM_CONF"
else
  echo "[INFO] Adding RebootWatchdogSec=2min to system.conf"
  echo "RebootWatchdogSec=2min" >> "$SYSTEM_CONF"
fi

echo "[OK] Watchdog configuration applied"
echo ""

# === 4. Verification ===
echo "[INFO] === Verification ==="
echo ""

# Check journald status
echo "[INFO] Checking systemd-journald status..."
systemctl is-active systemd-journald > /dev/null && \
  echo "[OK] systemd-journald is running" || \
  echo "[WARN] systemd-journald is not running"

# Check NetworkManager status
echo "[INFO] Checking NetworkManager status..."
systemctl is-active NetworkManager > /dev/null && \
  echo "[OK] NetworkManager is running" || \
  echo "[WARN] NetworkManager is not running"

# Show WiFi interface status
echo "[INFO] Checking WiFi interfaces..."
if command -v iwconfig > /dev/null 2>&1; then
  WLAN_INTERFACES=$(iwconfig 2>/dev/null | grep "^wlan" | awk '{print $1}' || echo "none")
  if [ "$WLAN_INTERFACES" != "none" ]; then
    echo "[OK] Found WiFi interfaces: $WLAN_INTERFACES"
  else
    echo "[WARN] No WiFi interfaces found"
  fi
else
  echo "[WARN] iwconfig not available (wireless-tools not installed)"
fi

# Check Watchdog configuration
echo "[INFO] Checking Watchdog configurations in system.conf..."
grep "WatchdogSec=" "$SYSTEM_CONF" | sed 's/^/  [OK] /'

# Show current configuration paths
echo ""
echo "[INFO] Current configurations:"
echo "  Journal dir: $JOURNAL_DIR"
echo "  Journald conf: $JOURNALD_CONF"
echo "  WiFi powersave conf: $WIFI_POWERSAVE_CONF"
echo "  System conf (Watchdog): $SYSTEM_CONF"

echo ""
echo "=========================================="
echo "[OK] Setup complete!"
echo "[!!] A SYSTEM REBOOT IS REQUIRED to activate the Watchdog timer."
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  Reboot system:        sudo reboot"
echo "  Check journal usage:  journalctl --disk-usage"
echo "  View journal logs:    journalctl -u omniwatchcare-pi-app.service -f"
echo "  Check WiFi status:    nmcli device show wlan0"
echo "  Test Watchdog:        echo c | sudo tee /proc/sysrq-trigger (WARNING: Crashes system)"
echo ""
