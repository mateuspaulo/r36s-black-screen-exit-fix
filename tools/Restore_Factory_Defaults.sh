#!/bin/bash
# ==============================================================================
# Restore: Revert Start+Select Changes to Factory Defaults
# Target: R36S on dArkOSRE-R36 / ArkOS
# ==============================================================================

exec > /dev/tty1 2>&1
printf "\033[?25l"
clear

echo "=================================================="
echo "   RESTORE FACTORY DEFAULT CONFIGURATIONS         "
echo "=================================================="
echo ""

BACKUP_DIR="/roms/backup/start_select_backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found ($BACKUP_DIR)!"
    echo "No modifications were reverted."
    sleep 5
    exit 1
fi

echo "Restoring files from safety backup..."

if [ -f "$BACKUP_DIR/perfnorm.orig" ]; then
    sudo cp -f "$BACKUP_DIR/perfnorm.orig" /usr/local/bin/perfnorm
    sudo chmod 755 /usr/local/bin/perfnorm
    echo "  -> perfnorm restored."
fi

if [ -f "$BACKUP_DIR/perfmax.orig" ]; then
    sudo cp -f "$BACKUP_DIR/perfmax.orig" /usr/local/bin/perfmax
    sudo chmod 755 /usr/local/bin/perfmax
    echo "  -> perfmax restored."
fi

if [ -f "$BACKUP_DIR/retroarch.cfg.orig" ]; then
    cp -f "$BACKUP_DIR/retroarch.cfg.orig" /home/ark/.config/retroarch/retroarch.cfg
    chown ark:ark /home/ark/.config/retroarch/retroarch.cfg
    echo "  -> retroarch.cfg restored."
fi

if [ -f "$BACKUP_DIR/retroarch32.cfg.orig" ]; then
    cp -f "$BACKUP_DIR/retroarch32.cfg.orig" /home/ark/.config/retroarch32/retroarch.cfg
    chown ark:ark /home/ark/.config/retroarch32/retroarch.cfg
    echo "  -> retroarch32.cfg restored."
fi

sync

echo ""
echo "=================================================="
echo "   RESTORATION COMPLETE!                          "
echo "=================================================="
echo "Rebooting console in 5 seconds..."
sleep 5
sudo reboot
