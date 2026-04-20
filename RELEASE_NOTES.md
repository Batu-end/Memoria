# Release Notes: Memoria v1.0.0-beta

Welcome to the first public beta of **Memoria**, the high-performance trading workstation for macOS. 

This release introduces the core foundation of the Memoria ecosystem, featuring our custom asynchronous Accounting Engine designed to handle professional-grade trade data with zero UI lag.

## What's New 🚀

### Core Engine
- **Custom Accounting Engine**: A background-processing powerhouse that calculates P&L, VWAP, and Risk metrics (R-Multiple) without blocking the main thread.
- **Support for Long & Short Positions**: Full math support for both directions, including multi-stage entries and partial profit-taking.
- **Real-Time Synchronization**: Your portfolio stats (Net Liquidity, Exposure, P&L) stay in sync with live quote data.

### Dashboard & Analytics
- **Performance Dashboard**: An elegant overview of your trading health, including unrealized gains and closed-trade performance.
- **Equity Curve Visualization**: Interactive charts showing your portfolio's growth and drawdowns over time.
- **Active Portfolio View**: Track your open positions and watchlist items with live data updates.

### Privacy & Performance
- **SwiftData Integration**: High-speed local database ensures your trading data never leaves your machine.
- **macOS Optimized**: Native desktop experience with premium dark-mode aesthetics.

## How to Install 🛠️

1. Download the `Memoria.app.zip` (or `.dmg` if available).
2. Right-click the `.app` and select **Open** to bypass macOS Gatekeeper.
3. Start tracking your edge!

## Known Issues & Feedback 📝

As this is a beta release, we are looking for feedback on:
- Calculation accuracy across different brokers/asset types.
- UI responsiveness with large (1000+) trade histories.

Please report any issues or suggest features via the [GitHub Issues](https://github.com/yourname/Memoria/issues) page.

---
*Developed by Batu Demirtas*
