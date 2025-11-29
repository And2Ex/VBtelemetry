# VB Telemetry for EdgeTX (128×64 Monochrome ELRS Radios)

[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-VBtelemetry-blue?logo=telegram)](https://t.me/VBtelemetry)
[![Monobank](https://img.shields.io/badge/Donate-Monobank-black?style=flat)](https://send.monobank.ua/jar/7VF9b8mPJj)
[![Patreon](https://img.shields.io/badge/Support-Patreon-orange?logo=patreon)](https://patreon.com/VBtelemetry)

---

## Project Description

**VB Telemetry** is an optimized set of Lua telemetry screens for EdgeTX radios with a **128×64 monochrome display**.  
The script is designed for **ELRS** and provides maximum situational awareness even in poor visibility, weak video signal, or full “blind flying” when flying in stabilization mode.

---

## Features

### 1. Main Telemetry Screen

- Drone and radio voltage bars.
- ELRS indicators:
  - small outer antennas — **Link Quality (LQ)**;
  - larger antennas — **output power (dBm)**.
- Signal direction:
  - **left** → uplink (radio → drone)
  - **right** → downlink (drone → radio)
- Flight mode, GPS data, voltage, timers — all received from ELRS telemetry.
- ARM / DISARM / TURTLE / BEEP states come from EdgeTX switches.

<img width="256" height="128" alt="Main Screen" src="https://github.com/user-attachments/assets/914708c7-aa92-4faa-bbbb-266e6560ee6f" />

---

### 2. GPS Screen

- Accurate “Home” arrow with real azimuth.
- Distance to Home.
- Absolute altitude: **MSL** (*shown as SL*).
- Relative altitude: **AGL** (*shown as AG*).
- Speed, satellites, coordinates.
- Supports metric & imperial.

<img width="256" height="128" alt="GPS Screen" src="https://github.com/user-attachments/assets/d7915a7a-81fe-445f-b043-3cc173fab2de" />

---

### 3. QR Code Generator

- Instant QR generation.
- Supports location links & coordinates.

<img width="256" height="128" alt="QR Screen" src="https://github.com/user-attachments/assets/b6ef63f3-9960-446e-9d39-cd115cffdf7e" />

---

### 4. Blind-Flying Capability (no RTH required)

VB Telemetry allows safe navigation **even with no FPV video**, e.g.:

- during video loss,
- in stabilization mode,
- in fog, dusk, or poor visibility.

Always visible:
- home direction,
- distance to home,
- relative altitude,
- speed and GPS vector.

---

### 5. Flight Statistics

- Total flights  
- Total distance  
- Total time in the air  
- Updated automatically

<img width="256" height="128" alt="Statistics" src="https://github.com/user-attachments/assets/b6d59573-a6b6-49d3-a400-365c0273769e" />

---

### 6. GPX Logging

- Logs telemetry into `.gpx` files:
  `relAlt, GSpd, RxBt, 1RSS, 2RSS, TRSS, RQly, TQly, TPWR, Sats`
- Saved to:

  ```
  /LOGS/VB_GPX
  ```

- Create the folder manually if missing.
- Starts logging **on first ARM (Home lock)**  
  and stops **when Home is reset**.

#### Resetting Home

- Select **Reset Home** in script settings  
- Replace drone battery  
- Reboot the radio  

---

## Supported Radios

VB Telemetry supports radios with:

- **128×64 monochrome display**
- **EdgeTX firmware**
- **ELRS internal/external module**

### For inverted OLED screens:
Enable **Invert UI** in script settings.

---

## How to Enable the Script in EdgeTX

1. Open **Model Menu**  
2. Go to **DISPLAY**  
3. Under **Screen 1 / 2 / 3**, select:
   - **Script**
   - **VBmain.luac**
4. Optionally assign:
   - **VBgps.luac** to another screen

<img width="256" height="128" alt="Display Setup" src="https://github.com/user-attachments/assets/550351f3-3d66-4e2c-9f15-5415c2515f73" />

---

## Timers

Configure timers on the **SETUP** page of the model.

<img width="256" height="128" alt="Timers" src="https://github.com/user-attachments/assets/fe4a465a-3da7-482a-9c8f-fdb40bf437f9" />

---

## Restrictions & Usage Policy

**Important:**  
The script is strictly prohibited for launching drones **from**:

- russia  
- belarus  
- iran  
- north korea  
- temporarily occupied territories of Ukraine  

Using the script **from other territories** while flying *toward these areas* is not technically restricted.  
This reflects the author's ethical stance.  
The author assumes no responsibility for misuse.

---

## Support the Project

If VB Telemetry helps you and you want to support further development, choose one of the options below.

### 🇺🇦 For users in Ukraine (Monobank)
Monobank accepts donations **only from Ukrainian bank cards**.

https://send.monobank.ua/jar/7VF9b8mPJj

[![Monobank](https://img.shields.io/badge/Donate-Monobank-black?style=for-the-badge)](https://send.monobank.ua/jar/7VF9b8mPJj)

---

### 🌍 For international supporters (Patreon)

Patreon works worldwide and supports all major payment methods.

https://patreon.com/VBtelemetry

[![Patreon](https://img.shields.io/badge/Support-Patreon-orange?style=for-the-badge&logo=patreon)](https://patreon.com/VBtelemetry)

---

## Summary

**VB Telemetry** is a complete, high-performance telemetry toolkit for EdgeTX monochrome radios:  
main screen, GPS navigation, statistics, GPX logging, QR generator, and full blind-flying capability.

