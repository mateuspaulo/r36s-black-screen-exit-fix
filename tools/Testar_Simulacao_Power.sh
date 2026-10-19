#!/bin/bash
# ==============================================================================
# Teste de Simulacao do Botao Power (Sleep e Wake Automatico via RTC)
# dArkOSRE-R36
# ==============================================================================

exec > /dev/tty1 2>&1
printf "\033[?25l"
clear

echo "=================================================="
echo "    TESTE: SIMULAR BOTAO POWER (AUTO SLEEP/WAKE)  "
echo "=================================================="
echo ""
echo "Este teste vai colocar o console em modo de espera"
echo "e acorda-lo sozinho apos 1 segundo, exatamente"
echo "como se voce apertasse o botao Power duas vezes."
echo ""
echo "Iniciando em 3 segundos..."
sleep 3

echo "Dormindo agora..."

if command -v rtcwake >/dev/null 2>&1; then
    sudo rtcwake -m mem -s 1 2>/dev/null || sudo rtcwake -m freeze -s 1 2>/dev/null
else
    echo 0 | sudo tee /sys/class/rtc/rtc0/wakealarm >/dev/null 2>&1
    echo +1 | sudo tee /sys/class/rtc/rtc0/wakealarm >/dev/null 2>&1
    echo mem | sudo tee /sys/power/state >/dev/null 2>&1
fi

clear
echo "=================================================="
echo "   SUCESSO! O CONSOLE ACORDOU AUTOMATICAMENTE!    "
echo "=================================================="
echo ""
echo "Se voce esta lendo esta mensagem com a tela acesa,"
echo "a simulacao do botao Power funcionou com perfeicao!"
echo ""
echo "Retornando ao menu em 5 segundos..."
sleep 5
exit 0
