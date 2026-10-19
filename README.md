# R36S (SoySauce / Clones) Black Screen on Exit Fix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-R36S%20%7C%20RK3326-blue.svg)](https://github.com/southoz/dArkOSRE-R36)
[![Firmware](https://img.shields.io/badge/OS-dArkOS%20%2F%20ArkOS-orange.svg)](https://github.com/christianhaitian/arkos)

> **[Versão em Português disponível aqui (Clique para ler em Português)](./README_PT-BR.md)**

A turnkey, reversible hardware-level solution for the infamous **"Black Screen upon Exiting Games"** on the **R36S retro handheld** (specifically boards classified as **SoySauce** / `Y3506_V05_20251215 2601` and related clone variants) running **dArkOSRE-R36** or **ArkOS**.

---

## The Problem

On affected R36S units:
1. Games launch and run completely normally.
2. Upon pressing the exit hotkey (`Start + Select`), the game terminates, but the **display turns completely pitch black**.
3. **Audio keeps playing in the background**: The EmulationStation home menu music starts playing, and you can even hear sound effects when moving the D-Pad or analog stick through the game list (blind navigation).
4. **The Power Button Trick**: Tapping the physical Power button once (putting the device to sleep) and tapping it a second time (waking it up) instantly restores the display right where you were navigating.

---

## Forensic Technical Analysis & Root Cause

Through deep code inspection of kernel device trees, logs, and OS scripts, here is why this occurs:

```
[ RetroArch Exits ] 
       ↓ 
[ Drops DRM Master (/dev/dri/card0) ]
       ↓
[ Panel Loses MIPI-DSI Clock/Sync ]
       ↓
[ Panel Enters Sleep: 0x28 Display Off / 0x10 Sleep In ]
       ↓
[ EmulationStation Resumes in User-Space ]
       ↓
[ Audio Plays & Input Works, but DSI Panel Stays Asleep ]  <-- BLACK SCREEN
       ↓
[ Manual Tap on Power Button (Sleep + Wake) ]
       ↓
[ Linux Kernel pm_resume re-sends 420-byte DSI Init Packet ]
       ↓
[ Display Turns Back ON ]
```

1. **MIPI-DSI Sleep Mode:** The SoySauce motherboard revision (`Y3506_V05_20251215 2601`) uses an **Elida KD35T133** 4-lane MIPI-DSI panel (`elida,kd35t133\0simple-panel-dsi`). Its Device Tree Blob (DTB) defines a panel power-down sequence (`0x28 Display Off` and `0x10 Sleep In`).
2. **Context Teardown:** When RetroArch closes, it releases the DRM Master context (`drmDropMaster`). The momentary loss of the video stream causes the panel controller to immediately enter its internal sleep mode.
3. **Frontend Blindness:** When EmulationStation resumes execution on the CPU, it continues drawing frames to the framebuffer and plays its background music, but it does **not** send the hardware-level 420-byte DCS initialization packet (`panel-init-sequence`) to physically wake the DSI panel.
4. **Why the Power Button restores it:** Tapping Power triggers system suspend (`pm_suspend`), and tapping it again triggers resume (`pm_resume`). During `pm_resume`, the Rockchip display driver (`rockchip_drm_pm_resume`) toggles the reset GPIOs, retransmits the full 420-byte initialization sequence to the LCD, and powers on the PWM backlight, bringing the picture back.

---

## How the Solution Works

Whenever you exit a game, the system executes the script `/usr/local/bin/perfnorm` before returning to EmulationStation.

This fix automates the power-cycle wake-up sequence inside `perfnorm` using the **Linux Real-Time Clock (RTC) Hardware Wakealarm**:

```bash
# Automated Power-Cycle Simulation via Hardware RTC
if command -v rtcwake >/dev/null 2>&1; then
    sudo rtcwake -m mem -s 1 2>/dev/null || sudo rtcwake -m freeze -s 1 2>/dev/null
else
    echo 0 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo +1 > /sys/class/rtc/rtc0/wakealarm 2>/dev/null
    echo mem > /sys/power/state 2>/dev/null
fi
```

### The Sequence:
1. You press `Start + Select` to quit a game.
2. RetroArch exits.
3. `perfnorm` automatically schedules an RTC wakealarm for **1 second** in the future and puts the SoC into sleep (`mem`).
4. Exactly 1 second later, the hardware RTC alarm fires.
5. The kernel executes `pm_resume`, re-initializing the MIPI-DSI transmitter and waking the LCD panel.
6. The EmulationStation menu appears illuminated and ready—**no manual button presses required!**

---

## Included Scripts

All scripts are located in the [`tools/`](./tools/) directory and are designed to run directly from the **Tools** (or **Options**) menu in EmulationStation:

| Script | Purpose |
|---|---|
| **`Corrigir_Tela_Preta_Start_Select.sh`** | **The Main Fix:** Creates automated backups and installs the auto power-cycle routine into `/usr/local/bin/perfnorm`. |
| **`Testar_Simulacao_Power.sh`** | **Standalone Test:** Simulates the 1-second sleep/wake cycle without launching or exiting any games. |
| **`Restaurar_Padrao_Start_Select.sh`** | **Complete Rollback:** Restores all original factory backup files (`.orig`) if you ever want to revert. |

---

## Step-by-Step Installation

### Step 1: Copy Scripts to the MicroSD Card
1. Plug your R36S microSD card (the ROMs card or Partition 3: `EASYROMS`) into your PC.
2. Copy the `.sh` files from the [`tools/`](./tools/) folder of this repository into the `tools` folder on your microSD card (e.g., `E:\tools\` or `G:\tools\`).

### Step 2: Run the Fix in the R36S
1. Eject the microSD card safely and insert it back into the R36S.
2. Turn on the console and go to the **Tools** (or **Options**) menu.
3. *(Optional)* Select **`Testar_Simulacao_Power`** to see the console sleep and wake up on its own.
4. Select and run **`Corrigir_Tela_Preta_Start_Select`**.
5. The console will display the installation steps on screen and automatically reboot in 5 seconds.

### Step 3: Test
1. Launch any game.
2. Press `Start + Select` to exit.
3. The console will quickly cycle the display (1 second) and return directly to the game menu with full picture and audio!

---

## Safety & Rollback

- **Non-Destructive:** Before modifying any file, `Corrigir_Tela_Preta_Start_Select.sh` saves `.orig` backups of `perfnorm`, `perfmax`, and RetroArch configs into `/roms/backup/start_select_backup/`.
- **Easy Reversion:** If you ever wish to undo the changes, simply run **`Restaurar_Padrao_Start_Select`** from the Tools menu.

---

## License

This project is licensed under the [MIT License](./LICENSE). Feel free to adapt, share, and incorporate into custom firmware distributions.
