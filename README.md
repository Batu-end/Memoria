# Memoria 🧘‍♂️
### TradingView is where you analyze the market. The Broker is where you manage the trade. Memoria is where you analyze yourself.

**Memoria** is a native macOS trading workstation designed to bridge the gap between mindless execution and professional reflection. While brokers focus on the "now," Memoria focuses on your **edge**. 

Built with **SwiftUI** and **SwiftData**, it’s a high-density, local-first environment for traders who have outgrown spreadsheets and want a tool that matches the performance of their Mac.

---

## The Philosophy: Beyond the Ledger
Most trading journals are a chore. Memoria is a workstation. It is built around these pillars:
1. **The Frictionless Entry:** A "New Trade" flow designed for a **sub-30 second** logging experience—minimizing the gap between closing a position and documenting it.
2. **The Aesthetic:** A professional, dark-mode interface with personality-driven typography and a dark glass aesthetic to turn your data into a reflective journal.

## 🔑 Key Features
* **Custom Accounting Engine**: Concurrent, background-threaded math that calculates VWAP, P&L, and Win Rates without locking the UI.
* **Trader Personas**: An identity-driven dashboard that adapts its visual language to your specific trading style.
* **Watchlist Sparklines**: Real-time context with asynchronous, lightweight charts integrated directly into your tickers.
* **Local-First Privacy**: Your alpha is yours. All trade data is stored locally via **SwiftData**, ensuring zero-latency and total privacy.
* **Power-User UX**: Full support for macOS global navigation, `Cmd+Return` shortcuts, and a "ghost-placeholder" entry system for rapid journaling.

## 🛠 Tech Stack
* **UI/UX:** SwiftUI (macOS 14+)
* **Persistence:** SwiftData
* **Engine:** Swift Structured Concurrency (Async/Await)
* **Design:** SF Symbols 6 + Apple Serif Typography

## 📦 Getting Started

### Installation (Beta)
1. Download the latest `.zip` from the [Releases](https://github.com/your-username/Memoria/releases) page.
2. Unzip and move `Memoria.app` to your **Applications** folder.
3. **Right-click > Open** to bypass macOS Gatekeeper (since this is an independent build).

### Build from Source
```bash
git clone https://github.com/Batu-end/Memoria.git
cd Memoria
open Memoria.xcodeproj