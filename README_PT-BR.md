# Correção de Tela Preta ao Sair de Jogos no R36S (SoySauce / Clones)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Plataforma](https://img.shields.io/badge/Plataforma-R36S%20%7C%20RK3326-blue.svg)](https://github.com/southoz/dArkOSRE-R36)
[![Firmware](https://img.shields.io/badge/OS-dArkOS%20%2F%20ArkOS-orange.svg)](https://github.com/christianhaitian/arkos)

> **[English version available here (Click to read in English)](./README.md)**

Uma solução definitiva, segura e reversível para o problema crônico de **"Tela Preta ao Sair de Jogos"** no console portátil **R36S** (especialmente placas classificadas como **SoySauce** / `Y3506_V05_20251215 2601` e variantes clone) rodando **dArkOSRE-R36** ou **ArkOS**.

---

## O Problema

Nos aparelhos afetados:
1. Os jogos abrem e funcionam com perfeito desempenho.
2. Ao pressionar o atalho de saída (`Start + Select`), o jogo fecha, mas a **tela fica completamente preta**.
3. **O áudio continua tocando ao fundo:** A música tema do menu principal do EmulationStation toca normalmente, e você consegue ouvir os cliques sonoros ao mexer no direcional analógico ou D-Pad navegando pelos jogos às cegas.
4. **O truque do botão Power:** Apertar o botão Power físico uma vez (colocando o aparelho para dormir) e apertar uma segunda vez (acordando) restaura a imagem instantaneamente exatamente onde você estava navegando.

---

## Análise Forense da Causa-Raiz

Por meio de inspeção aprofundada dos arquivos DTB (Device Tree Blob) do kernel, logs do sistema e scripts do dArkOS, a cadeia de falha foi identificada:

```
[ RetroArch Encerra ] 
       ↓ 
[ Libera o descritor de vídeo DRM Master (/dev/dri/card0) ]
       ↓
[ O barramento MIPI-DSI perde sincronismo ]
       ↓
[ O painel LCD entra em Sleep profundo: 0x28 Display Off / 0x10 Sleep In ]
       ↓
[ O EmulationStation retoma a execução no processador ]
       ↓
[ Áudio toca e controles respondem, mas o display continua dormindo ]  <-- TELA PRETA
       ↓
[ Usuário aperta Power duas vezes (Sleep + Resume) ]
       ↓
[ O driver do kernel executa pm_resume e reenvia 420 bytes de inicialização ]
       ↓
[ A tela acende e a imagem volta ]
```

1. **Modo Sleep do Painel DSI:** A revisão de placa-mãe SoySauce (`Y3506_V05_20251215 2601`) utiliza o painel **Elida KD35T133** conectado via barramento MIPI-DSI de 4 vias (`elida,kd35t133\0simple-panel-dsi`). O firmware desse painel foi programado para desligar imediatamente (`Display Off` / `Sleep In`) se houver interrupção do fluxo de dados por alguns milissegundos.
2. **Perda de DRM Master:** Quando o RetroArch fecha, ele desaloca o contexto EGL/OpenGL e libera o controle exclusivo do chip de vídeo (`drmDropMaster`). Essa fração de segundo sem sinal faz o painel dormir.
3. **Cegueira do Frontend:** O EmulationStation retoma a execução na CPU, envia novos quadros para a memória de vídeo e toca a música, mas **não retransmite** o pacote de hardware de 420 bytes (`panel-init-sequence`) para despertar o painel físico.
4. **Por que o botão Power resolve:** Apertar o botão Power aciona a suspensão do sistema (`pm_suspend`) e o despertar (`pm_resume`). No despertar, o driver do kernel (`rockchip_drm_pm_resume`) aciona os pinos físicos de reset GPIO, retransmite os 420 bytes de configuração ao painel LCD e liga a luz de fundo PWM, recuperando a imagem.

---

## Como a Solução Funciona

Toda vez que você sai de um jogo, o sistema operacional roda automaticamente o script `/usr/local/bin/perfnorm` antes de voltar ao menu.

Esta solução automatiza o ciclo do botão Power via hardware dentro do `perfnorm` utilizando o **Temporizador de Alarme em Tempo Real do Linux (RTC Wakealarm)**:

```bash
# Simulacao Automatica do Botao Power via RTC Hardware Wakealarm
if command -v rtcwake >/dev/null 2>&1; then
    sudo rtcwake -m mem -s 1 2>/dev/null || sudo rtcwake -m freeze -s 1 2>/dev/null
else
    echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo +1 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo mem > /sys/power/state 2>/dev/null
fi
```

### O Fluxo Automático:
1. Você aperta `Start + Select` para sair de um jogo.
2. O RetroArch fecha.
3. O script `perfnorm` agenda um alarme de hardware para **1 segundo** no futuro e coloca o processador em modo de espera (`mem`).
4. Exatamente 1 segundo depois, o alarme de hardware do chip PMIC dispara.
5. O kernel executa a rotina `pm_resume`, reinicializando eletricamente o transmissor DSI e ligando a tela LCD.
6. O menu do EmulationStation reaparece aceso na sua frente — **sem você precisar apertar nenhum botão físico!**

---

## Scripts Disponíveis

Todos os scripts estão na pasta [`tools/`](./tools/) e foram desenvolvidos para rodar diretamente pelo menu **Tools** (ou **Opções**) do EmulationStation:

| Script | Finalidade |
|---|---|
| **`Fix_Black_Screen_Exit.sh`** | **A Correção Principal:** Cria backups automáticos e instala o Auto Power-Cycle no `/usr/local/bin/perfnorm`. |
| **`Test_Power_Cycle.sh`** | **Teste Isolado:** Testa o ciclo de dormir e acordar sozinho em 1 segundo sem precisar abrir jogos. |
| **`Restore_Factory_Defaults.sh`** | **Restauração Completa:** Restaura todos os arquivos originais de fábrica (`.orig`) caso deseje desfazer tudo. |

---

## Guia de Instalação Passo a Passo

### Passo 1: Copiar os Scripts para o Cartão MicroSD
1. Conecte o cartão microSD do R36S (cartão de ROMs ou a partição `EASYROMS`) no computador.
2. Copie os arquivos `.sh` presentes na pasta [`tools/`](./tools/) deste repositório para a pasta `tools` do seu cartão (ex: `E:\tools\` ou `G:\tools\`).

### Passo 2: Executar a Correção no R36S
1. Ejete o cartão com segurança e insira-o no R36S.
2. Ligue o console.
3. Na tela inicial principal (EmulationStation), pressione o botão **Start** para abrir o menu principal.
4. Navegue até **Options**, depois entre em **Tools**.
5. *(Opcional)* Selecione e execute **`Test_Power_Cycle`** para ver o aparelho dormir e acordar sozinho na sua frente.
6. Selecione e execute o script **`Fix_Black_Screen_Exit`**.
7. O console exibirá as etapas na tela e reiniciará automaticamente em 5 segundos.

### Passo 3: Testar
1. Entre em qualquer jogo.
2. Pressione `Start + Select` para sair.
3. O console fará um ciclo rápido de 1 segundo e retornará imediatamente ao menu com vídeo e áudio!

---

## Segurança e Reversibilidade

- **Não-Destrutivo:** Antes de alterar qualquer linha, o script `Fix_Black_Screen_Exit.sh` salva backups `.orig` de todos os arquivos modificados em `/roms/backup/start_select_backup/`.
- **Desfazer a Qualquer Momento:** Basta executar **`Restore_Factory_Defaults`** pelo menu Tools para reverter o sistema ao estado original.

---

## Licença

Este projeto é disponibilizado sob a licença [MIT](./LICENSE). Sinta-se livre para utilizar, modificar e incorporar em distribuições de firmware customizado.
