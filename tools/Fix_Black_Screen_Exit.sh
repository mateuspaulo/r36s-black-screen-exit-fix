#!/bin/bash
# ==============================================================================
# Fix: Automatic Display Power-Cycle Wake on Game Exit + Volume Preservation
# Target: R36S (SoySauce Y3506 / Clones) on dArkOSRE-R36 / ArkOS
# ==============================================================================

exec > /dev/tty1 2>&1
printf "\033[?25l"
clear

echo "=================================================="
echo "   FIX: R36S SCREEN WAKE & VOLUME PRESERVATION    "
echo "=================================================="
echo ""

BACKUP_DIR="/roms/backup/start_select_backup"
mkdir -p "$BACKUP_DIR"

echo "[1/4] Verifying safety backups..."
if [ -f "/usr/local/bin/perfnorm" ] && [ ! -f "$BACKUP_DIR/perfnorm.orig" ]; then
    cp -p /usr/local/bin/perfnorm "$BACKUP_DIR/perfnorm.orig"
fi
if [ -f "/usr/local/bin/perfmax" ] && [ ! -f "$BACKUP_DIR/perfmax.orig" ]; then
    cp -p /usr/local/bin/perfmax "$BACKUP_DIR/perfmax.orig"
fi
if [ -f "/home/ark/.config/retroarch/retroarch.cfg" ] && [ ! -f "$BACKUP_DIR/retroarch.cfg.orig" ]; then
    cp -p /home/ark/.config/retroarch/retroarch.cfg "$BACKUP_DIR/retroarch.cfg.orig"
fi
if [ -f "/home/ark/.config/retroarch32/retroarch.cfg" ] && [ ! -f "$BACKUP_DIR/retroarch32.cfg.orig" ]; then
    cp -p /home/ark/.config/retroarch32/retroarch.cfg "$BACKUP_DIR/retroarch32.cfg.orig"
fi
echo "  -> Backups saved to $BACKUP_DIR"

echo ""
echo "[2/4] Installing Auto Power-Cycle & Volume Fix in perfnorm..."

cat > /tmp/new_perfnorm << 'EOF'
#!/bin/bash
echo -en "\033[?25l" > /dev/tty1 2>/dev/null || true
export SDL_VIDEO_EGL_DRIVER=libEGL.so
gpu="ff400000"

# 1. Restore CPU/GPU/DMC scaling governors
if [ -f "/sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/governor" ]; then
  echo simple_ondemand > /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/governor 2>/dev/null || true
fi
if [ -f "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor" ]; then
  echo ondemand > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || true
fi
if [ -f "/sys/devices/platform/dmc/devfreq/dmc/governor" ]; then
  echo dmc_ondemand > /sys/devices/platform/dmc/devfreq/dmc/governor 2>/dev/null || true
fi

# 2. Re-apply DRM Gamma LUT to controller
if [ -x "/usr/local/bin/gamma" ]; then
  gamma_val="0.8"
  if [ -f "/dev/shm/CURRENT_GAMMA" ]; then
    gamma_val=$(cat /dev/shm/CURRENT_GAMMA 2>/dev/null || echo "0.8")
  fi
  /usr/local/bin/gamma -s "$gamma_val" 2>/dev/null || true
fi

# 3. Capture current volume BEFORE hardware sleep
# (Power-cycle resets the audio DAC hardware registers to 100%)
cur_vol=$(amixer -c 0 -M sget 'Playback' 2>/dev/null | grep -o '[0-9]\+%' | head -1)
[ -z "$cur_vol" ] && cur_vol=$(amixer -c 0 sget 'Playback' 2>/dev/null | grep -o '[0-9]\+%' | head -1)

# 4. Simulate Power Button cycle via Hardware RTC Wakealarm
# Puts SoC into sleep for 1 second, then wakes up automatically.
# This forces the kernel driver (pm_resume) to re-init MIPI-DSI and Backlight.
if command -v rtcwake >/dev/null 2>&1; then
    sudo rtcwake -m mem -s 1 2>/dev/null || sudo rtcwake -m freeze -s 1 2>/dev/null
else
    echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo +1 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo mem > /sys/power/state 2>/dev/null
fi

# 5. Restore audio runtime power management and volume immediately after wake
echo on > /sys/class/sound/card0/power/control 2>/dev/null || true
if [ -z "$cur_vol" ] && [ -f "/etc/r36_config.ini" ]; then
    saved_vol=$(grep '^alsa_volume[ \t]*=' /etc/r36_config.ini 2>/dev/null | cut -d'=' -f2 | xargs || true)
    [ -n "$saved_vol" ] && cur_vol="${saved_vol}%"
fi
[ -z "$cur_vol" ] && cur_vol="40%"

amixer -c 0 -M sset 'Playback' "$cur_vol" 2>/dev/null || amixer -c 0 sset 'Playback' "$cur_vol" 2>/dev/null || true

# Persist last used volume to /etc/r36_config.ini so next boot retains this volume
vol_num=$(echo "$cur_vol" | tr -d '%')
if [ -f "/etc/r36_config.ini" ]; then
    if grep -q '^alsa_volume[ \t]*=' /etc/r36_config.ini; then
        sed -i "s/^alsa_volume[ \t]*=.*/alsa_volume = $vol_num/" /etc/r36_config.ini 2>/dev/null || true
    else
        echo "alsa_volume = $vol_num" >> /etc/r36_config.ini 2>/dev/null || true
    fi
fi
alsactl store 0 2>/dev/null || true

echo -en "\033[?25l" > /dev/tty1 2>/dev/null || true
EOF

sudo mv /tmp/new_perfnorm /usr/local/bin/perfnorm
sudo chmod 755 /usr/local/bin/perfnorm
echo "  -> perfnorm configured with screen wake and audio preservation."

echo ""
echo "[3/4] Initializing boot volume in /etc/r36_config.ini..."
if [ -f "/etc/r36_config.ini" ]; then
    if ! grep -q '^alsa_volume[ \t]*=' /etc/r36_config.ini; then
        cur_sys_vol=$(amixer -c 0 -M sget 'Playback' 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')
        [ -z "$cur_sys_vol" ] && cur_sys_vol="40"
        echo "alsa_volume = $cur_sys_vol" >> /etc/r36_config.ini
        echo "  -> Boot volume set to ${cur_sys_vol}%"
    else
        cur_boot_vol=$(grep '^alsa_volume[ \t]*=' /etc/r36_config.ini | cut -d'=' -f2 | xargs)
        echo "  -> Existing boot volume kept at ${cur_boot_vol}%"
    fi
fi

echo ""
echo "[4/4] Setting RetroArch clean direct exit..."
for cfg in /home/ark/.config/retroarch/retroarch.cfg /home/ark/.config/retroarch32/retroarch.cfg; do
    if [ -f "$cfg" ]; then
        sed -i 's|^input_quit_gamepad_combo.*|input_quit_gamepad_combo = "0"|' "$cfg"
        sed -i 's|^quit_press_twice.*|quit_press_twice = "false"|' "$cfg"
        chown ark:ark "$cfg" 2>/dev/null || true
    fi
done
echo "  -> RetroArch configs verified."

sync

echo ""
echo "=================================================="
echo "   INSTALLATION COMPLETE!                        "
echo "=================================================="
echo "Rebooting console in 5 seconds..."
sleep 5
sudo reboot
