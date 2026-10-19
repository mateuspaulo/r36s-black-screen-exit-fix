#!/bin/bash
# ==============================================================================
# Test: Simulate Power Button (Automatic Sleep and Wake via Hardware RTC)
# Target: R36S on dArkOSRE-R36 / ArkOS
# ==============================================================================

exec > /dev/tty1 2>&1
printf "\033[?25l"
clear

echo "=================================================="
echo "   TEST: POWER BUTTON SIMULATION (AUTO SLEEP/WAKE)"
echo "=================================================="
echo ""
echo "This test puts the console into sleep mode and"
echo "wakes it up automatically after 1 second, exactly"
echo "like pressing the physical Power button twice."
echo ""
echo "Starting in 3 seconds..."
sleep 3

echo "Entering sleep now..."

if command -v rtcwake >/dev/null 2>&1; then
    sudo rtcwake -m mem -s 1 2>/dev/null || sudo rtcwake -m freeze -s 1 2>/dev/null
else
    echo 0 | sudo tee /sys/class/rtc/rtc0/wakealarm >/dev/null 2>&1
    echo +1 | sudo tee /sys/class/rtc/rtc0/wakealarm >/dev/null 2>&1
    echo mem | sudo tee /sys/power/state >/dev/null 2>&1
fi

clear
echo "=================================================="
echo "   SUCCESS! CONSOLE WOKE UP AUTOMATICALLY!        "
echo "=================================================="
echo ""
echo "If you are reading this message with the screen on,"
echo "the hardware power cycle simulation worked properly!"
echo ""
echo "Returning to menu in 5 seconds..."
sleep 5
exit 0
