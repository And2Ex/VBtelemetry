# VB Telemetry for EdgeTX (128×64 Monochrome ELRS Radios)

[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-VBtelemetry-blue?logo=telegram)](https://t.me/VBtelemetry)
[![Monobank](https://img.shields.io/badge/Donate-Monobank-black?style=flat)](https://send.monobank.ua/jar/7VF9b8mPJj)
[![Patreon](https://img.shields.io/badge/Support-Patreon-orange?logo=patreon)](https://patreon.com/VBtelemetry)

---

## Overview

**VB Telemetry** is a Lua telemetry suite for **EdgeTX radios with a 128×64 monochrome display** and **ELRS telemetry** support.

It provides compact and readable flight telemetry designed specifically for small monochrome radio screens.

The interface focuses on:

- quick readability  
- GPS navigation  
- blind-flying support  
- minimal screen clutter  
- statistics and GPX logging  

---

## Beta Status

**Important:** this is a **beta build**.

The script **has not been tested on real drones by the author**, because the author currently does not have drones available for live testing.

Development and verification were done only on the radio and Lua script side.

Because of this:

- use it at your own risk  
- expect possible bugs or telemetry edge cases  
- verify all functions carefully before real flight  

---

## Main Features

### 1. Main Telemetry Screen
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/022a98c2-4926-4b94-96f1-8dadee11f62a" />

The main screen provides the most important flight data in a compact layout.

Displayed data includes:

- model name  
- radio battery voltage  
- drone battery bar  
- ELRS packet rate or RF mode  
- ARM / DISARM state  
- flight mode  
- timers  
- uplink and downlink signal blocks  
- transmit power  
- Link Quality indicators  

Signal direction is separated:

- **left side** — radio → drone  
- **right side** — drone → radio  

ARM, TURTLE and BEEPER states are read from EdgeTX switches.

---

### 2. GPS Screen
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/e314b506-a974-4443-8939-a003fdfdfcd5" />

The GPS screen focuses on navigation.

It displays:

- **Home direction arrow**
- distance to Home  
- absolute altitude (**SL**)  
- relative altitude (**AG**)  
- GPS speed  
- satellites count  
- live coordinates  

Even without video feed the pilot can still see:

- where Home is  
- how far the drone is  
- current altitude  
- movement speed  

Supports:

- **Metric**
- **Imperial**

---

### 3. Coordinates QR Screen
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/b1ed967c-edde-44be-b890-b5fa37bd68e4" />

The script can generate a QR code from current coordinates.

This allows:

- quickly sharing the location  
- opening coordinates on a phone  
- sending recovery position  
- saving drone location  

Latitude and longitude are also displayed as text.

---

### 4. Flight Statistics Screen
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/1a03f54e-5161-4c13-bb9e-efed549bd702" />

The statistics page stores and displays flight results.

Tracked values include:

- last flight time  
- total flight time  
- last maximum altitude  
- total maximum altitude  
- last maximum distance  
- total maximum distance  
- last maximum speed  
- total maximum speed  
- number of arms  
- total flights  

Both **Last** and **Total** values are displayed.

---

### 5. GPX Logging

VB Telemetry can record telemetry data into GPX tracks.

Tracks are saved to:

`/LOGS/VB_GPX`

If this folder does not exist, create it manually.

GPX logging is intended for post-flight review and route analysis.

Logged values may include:

- relative altitude  
- GPS speed  
- radio battery voltage  
- RSS values  
- link quality  
- transmit power  
- satellites count  

Logging starts on first ARM after Home is established and stops when Home is reset.

#### Resetting Home

- Select **Reset Home** in script settings  
- Replace drone battery  
- Reboot the radio  

---

### 6. Blind-Flying Support

The script allows navigation even without FPV video.

This can help during:

- video signal loss  
- fog  
- poor visibility  
- dusk  
- stabilization-mode flight  

Telemetry still shows:

- home direction  
- distance to home  
- altitude  
- speed  

This **does not replace** failsafe systems or safe flight procedures.

---

### 7. Quick Screen Switching

The script allows fast switching between telemetry screens.

To switch screens quickly:

```
Double press ENTER
```

Pressing **ENTER twice quickly** toggles between available telemetry screens.

---

### 8. Quick Menu

The script includes an internal menu for quick navigation.

Menu items include:

- main screen  
- reset Home point  
- coordinates QR  
- statistics  
- GPX tracks  
- info page  
- settings  

---

### 9. Script Settings
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/c3c3c875-94db-4656-b0ec-86aff7f7a85c" />

The settings page allows configuration of:

- **Arm switch**  
- **Turtle switch**  
- **Beeper switch**  
- **Units**  
- **Invert UI**

For radios with inverted OLED displays you can enable **Invert UI** so the interface is rendered correctly.

---

## Supported Hardware

VB Telemetry is designed for radios with:

- **EdgeTX firmware**
- **128×64 monochrome display**
- **ELRS internal or external module**

---

## Memory and RAM Limitations

EdgeTX monochrome radios have very limited Lua memory.

Because of this, some features require enough free RAM.

These features include:

- **Statistics**
- **GPX logging**

If RAM is insufficient:

- the main telemetry screen may still work  
- statistics or GPX logging may not function  

This is a hardware limitation of small radios.

---

## Installation

Copy the script files to SD root.

---

## Enabling the Script in EdgeTX
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/455a8fe7-88a6-46b5-8460-bf37ba157902" />

1. Open **Model Menu**
2. Go to **DISPLAY**
3. Select a screen
4. Choose:
   - **Type:** Script
   - **Script:** `VBmain.luac`

Optionally assign `VBgps.luac` to another screen.

---

## Timers
<img width="256" height="128" alt="image" src="https://github.com/user-attachments/assets/bc7ff1c0-5dda-4699-a49b-b5ce0e6b2a01" />

Flight timers must be configured in the model **SETUP** page of EdgeTX.

The script reads and displays timer data from the radio.

---

## Restrictions and Usage Policy

Use of this project is prohibited by the author's policy for launches from:

russia, belarus, iran, north korea, syria, iraq, afghanistan, yemen, kazakhstan, turkmenistan, uzbekistan, kyrgyzstan, tajikistan, china, mongolia, myanmar, eritrea, ethiopia, somalia, south sudan, sudan, libya, chad, niger, mali, burkina faso, guinea, democratic republic of congo, congo, zimbabwe, cuba, nicaragua, venezuela, temporarily occupied territories of ukraine.

This reflects the author's ethical position.

The author assumes no responsibility for misuse.

---

## Safety Notice

This project is **not a certified safety system**.

It does not replace:

- pilot training  
- legal compliance  
- failsafe configuration  
- Return-to-Home logic  
- visual awareness  

Always verify telemetry and system behavior before real flight.

---

## Support the Project

If you want to support development:

### Ukraine (Monobank)

https://send.monobank.ua/jar/7VF9b8mPJj

---

### International (Patreon)

https://patreon.com/VBtelemetry

---

## Telegram

Project updates:

https://t.me/VBtelemetry

---

## Download

Latest release:

https://github.com/And2Ex/VBtelemetry/releases/tag/v26.03.09-beta
