#!/bin/bash
# ==============================================================================
# Script de Restauracao: Desfazer Alteracoes de Start + Select
# dArkOSRE-R36
# ==============================================================================

exec > /dev/tty1 2>&1
printf "\033[?25l"
clear

echo "=================================================="
echo "   RESTAURAR CONFIGURACOES ORIGINAIS              "
echo "=================================================="
echo ""

BACKUP_DIR="/roms/backup/start_select_backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERRO: Pasta de backup nao encontrada ($BACKUP_DIR)!"
    echo "Nenhuma alteracao foi desfeita."
    sleep 5
    exit 1
fi

echo "Restaurando arquivos a partir do backup..."

if [ -f "$BACKUP_DIR/perfnorm.orig" ]; then
    sudo cp -f "$BACKUP_DIR/perfnorm.orig" /usr/local/bin/perfnorm
    sudo chmod 755 /usr/local/bin/perfnorm
    echo "  -> perfnorm restaurado."
fi

if [ -f "$BACKUP_DIR/perfmax.orig" ]; then
    sudo cp -f "$BACKUP_DIR/perfmax.orig" /usr/local/bin/perfmax
    sudo chmod 755 /usr/local/bin/perfmax
    echo "  -> perfmax restaurado."
fi

if [ -f "$BACKUP_DIR/retroarch.cfg.orig" ]; then
    cp -f "$BACKUP_DIR/retroarch.cfg.orig" /home/ark/.config/retroarch/retroarch.cfg
    chown ark:ark /home/ark/.config/retroarch/retroarch.cfg
    echo "  -> retroarch.cfg restaurado."
fi

if [ -f "$BACKUP_DIR/retroarch32.cfg.orig" ]; then
    cp -f "$BACKUP_DIR/retroarch32.cfg.orig" /home/ark/.config/retroarch32/retroarch.cfg
    chown ark:ark /home/ark/.config/retroarch32/retroarch.cfg
    echo "  -> retroarch32.cfg restaurado."
fi

sync

echo ""
echo "=================================================="
echo "   RESTAURACAO CONCLUIDA COM SUCESSO!             "
echo "=================================================="
echo "O aparelho reiniciara em 5 segundos..."
sleep 5
sudo reboot
