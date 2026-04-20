# Memoria: Professional macOS Trading Workstation

Memoria is a high-performance desktop trading workstation designed for precision, speed, and deep portfolio analytics. Built natively for macOS with SwiftUI and powered by a custom asynchronous Accounting Engine, Memoria provides real-time insights into your trading edge without sacrificing desktop responsiveness.

![Dashboard Preview](https://via.placeholder.com/800x400?text=Memoria+macOS+Dashboard)

## Key Features

- **🚀 Desktop-Grade Accounting Engine**: A background-threaded math engine optimized for macOS, handling complex P&L, VWAP, and R-Multiple calculations in real-time.
- **📊 Advanced Analytics**: Visualize your equity curve, track drawdowns, and analyze your win/loss ratios with stunning, interactive charts designed for large displays.
- **📈 Portfolio Snapshot**: Monitor your net liquidity, realized/unrealized P&L, and open exposure from a centralized, elegant dashboard.
- **🌑 Modern Aesthetics**: Premium dark-mode design that feels right at home on macOS, with fluid animations and a focused, professional interface.
- **🔒 Privacy First**: Local-first data storage using SwiftData—your trades stay on your Mac.

## Installation & Running

Since Memoria is currently distributed directly via GitHub, you may need to follow these steps to run the application on your Mac:

1. **Download** the latest `.dmg` or `.app` from the [Releases](https://github.com/yourname/Memoria/releases) page.
2. **Move** Memoria to your `/Applications` folder.
3. **Right-Click** the Memoria icon and select **Open**. 
   - *Note: Because the app is not currently notarized via the Apple Developer Program, you must use the Right-Click method the first time you open it to bypass macOS Gatekeeper.*
4. Click **Open** in the security dialog that appears.

## Technology Stack

- **Framework**: SwiftUI (macOS Native)
- **Database**: SwiftData
- **Concurrency**: Swift Structured Concurrency (Async/Await)
- **Architecture**: MVVM + Background Service Worker

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+

### Installation

1. Clone the repository: `git clone https://github.com/yourname/Memoria.git`
2. Open `Memoria.xcodeproj` in Xcode.
3. Select your target (iOS or macOS) and run (`Cmd + R`).

## Author

**Batu Demirtas**

---

*Disclaimer: Memoria is a tool for portfolio tracking and analysis. It does not provide financial advice and is not integrated with direct brokerage execution.*
