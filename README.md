<div align="center">

# OilPulse

**A lightweight, native, local-first energy price monitor for macOS.**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20Swift%20Charts-green)
![Status](https://img.shields.io/badge/status-MVP-yellow)

**English** | [简体中文](README.zh-CN.md)

</div>

---

## Overview

**OilPulse** is a lightweight macOS app for observing changes in the energy market. Its compact, native interface keeps the latest **Brent** and **WTI** prices, daily movements, and recent trends one click away.

The app follows a **local-first** design: there is no browser to open and no heavy background service to maintain. Market observations are stored in a local SQLite database, so the most recent valid data remains available when the network is unavailable.

## Why OilPulse

Crude oil is an important leading signal in the energy value chain, but its movements do not flow immediately or proportionally into retail gasoline prices. Refining costs, gasoline futures, inventories, taxes, and regional supply and demand all shape the final price at the pump.

OilPulse is not designed to promise that prices will rise or fall on a particular day. Instead, it turns scattered price movements into a clear, low-friction monitoring view that helps users:

- Understand the current level and direction of Brent and WTI at a glance
- Notice significant movements for market research or everyday decision support
- Eventually trace the transmission from **crude oil → refined products → retail prices** through RBOB, crack spreads, and regional pump-price data

For individuals, OilPulse can provide context when considering when to refuel, without promising guaranteed savings. For researchers, energy professionals, and fleet operators, it can serve as an extensible local foundation for monitoring energy-market signals.

## Features

- Latest **Brent** & **WTI** prices, side by side
- Absolute change and percentage change (green ↑ / red ↓)
- Trend charts for **1 Day / 1 Week / 1 Month**
- Auto-refresh on open + scheduled refresh (15 / 30 / 60 min)
- Manual refresh and **force refresh** (bypasses cooldown)
- Local **SQLite** cache — shows the last good data when offline
- Clear status indicators: normal / cached / offline / failed
- Optional launch at login

## Tech Stack

| Area | Technology |
|------|------------|
| Language | Swift |
| UI | SwiftUI + Swift Charts |
| Networking | URLSession (Yahoo Finance) |
| Local cache | SQLite |
| Preferences | UserDefaults / AppStorage |
| Launch at login | macOS Service Management |
| Build | Swift Package Manager |

## Build & Run

Requirements: **macOS 14+** and the **Swift toolchain** (Xcode or Command Line Tools).

```bash
# Clone
git clone https://github.com/Tsarwithl7/oilpulse.git
cd oilpulse

# Build a release .app bundle
bash build.sh

# Launch
open OilPulse.app
```

If macOS blocks the unsigned app on first launch, run:

```bash
xattr -cr OilPulse.app && open OilPulse.app
```

## Documentation

- [Product Requirements](product-requirements.md)

## Disclaimer

Data shown is for personal reference only and may be delayed or inaccurate. It does **not** constitute investment or trading advice.
