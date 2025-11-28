# VB Telemetry for EdgeTX (RadioMaster Pocket)

VB Telemetry is a custom Lua telemetry suite for **RadioMaster Pocket** transmitters running **EdgeTX** with a 128×64 B/W screen.

It adds rich, optimized telemetry screens for FPV quads, including:
- Main flight screen with dynamic bars and battery icons
- Advanced GPS screen with home indicator, relative altitude, distance and compass
- Statistics screen (total flights, time in air, distance, etc.)
- GPX tracks recorder
- Info / Donate screen with QR codes (GitHub, Telegram, donations)

The project focuses on:
- **Memory optimization** (safe for Pocket)
- **Readability** – clear layout and fonts
- **Ease of use** with logical navigation

---

## Features

- **Main telemetry screen**
  - Voltage bars for quad and radio
  - Timers, model name, RSSI/LQ, sats, speed, altitude
  - Invert UI mode (light/dark) with proper element inversion

- **GPS screen (VB GPS)**
  - Home arrow
  - Relative distance and altitude
  - Compass with cardinal directions
  - Coordinates and QR sharing (future)

- **Statistics screen**
  - Total distance
  - Total flight time
  - Number of flights
  - Milestone notifications (every X km / minutes / flights)

- **GPX Tracks**
  - Logs telemetry fields into `.gpx` files
  - Stored under:
    ```
    /LOGS/VB_GPX
    ```
  - If the folder does not exist, create it manually.

- **Info / Donate screen**
  - Script version
  - GitHub QR
  - Telegram QR
  - Donate submenu (Monobank, Ko-fi in future)

- **Invert UI**
  - Global light/dark toggle
  - Proper inversion for bars, headers, icons

---

## Requirements

- **RadioMaster Pocket**
- **EdgeTX**
- Display: **128×64 monochrome**
- Lua scripts enabled

Other radios with the same screen may work, but only Pocket is officially tested.

---

## Installation

1. Download the latest release ZIP from the [Releases](../../releases) page  
   (for example: `VBtelemetry_v1.4.zip`).

2. Unzip the archive and copy folders to your SD card, preserving paths:

    ```text
    /SCRIPTS/TELEMETRY/VBmain.lua
    /SCRIPTS/TELEMETRY/VBgps.lua
    /SCRIPTS/TELEMETRY/VBlib/...
    ```

3. In EdgeTX:
    - Open your **model settings**
    - Go to the **Telemetry** tab
    - Assign `VBmain.lua` as a telemetry script (page)
    - Optionally bind `VBgps.lua` as a second GPS-oriented screen

4. Reboot the radio or reload scripts and open the telemetry pages.

---

## Basic usage

- Use the **main screen** for most flights.
- Switch to the **GPS screen** when flying far or high.
- The **statistics screen** shows:
  - total flights,
  - time in the air,
  - distance flown.
- GPX tracks:
  - Start automatically on arm (depending on settings).
  - Saved to `/LOGS/VB_GPX`.

---

## Telegram

Join the official Telegram channel  
**https://t.me/VBtelemetry**  
for:
- updates  
- beta versions  
- help  
- news  

---

## Donate

Support development:

**Monobank (UA):**  
https://send.monobank.ua/jar/7VF9b8mPJj

International options will be added soon.

---

## Roadmap

Planned improvements:

- Better no-fly alerts
- More GPS tools
- Expanded statistics
- Activation system for PRO features
- Advanced QR tools
- More optimization

---

## License

Released under the **MIT License**.  
See the `LICENSE` file.

---

## Short summary (UA)

**VB Telemetry** — це комплект Lua-екранів телеметрії для RadioMaster Pocket:  
основний екран, GPS, статистика, GPX-треки та меню інформації/донату.

Докладний опис — вище.
