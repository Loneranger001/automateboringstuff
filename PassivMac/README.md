# PassivMac

A personal Mac desktop app for passive portfolio management and rebalancing — inspired by [Passiv](https://passiv.com). Built with SwiftUI and SwiftData. No subscription, no paywall, all features available.

---

## What It Does

PassivMac connects to your Questrade brokerage account, lets you define target allocations for your ETFs, and shows you exactly what to buy to stay on target every time you have cash to invest. It also tracks your portfolio performance over time.

---

## Features

### Brokerage Integration
- **Questrade** — full read + trade access via the official Questrade REST API
- **Interactive Brokers** — planned (Phase 3, see [ROADMAP.md](ROADMAP.md))
- OAuth 2.0 authentication — your credentials are never stored in the app; tokens are kept in the macOS Keychain
- Automatic token refresh before expiry

### Portfolio Groups
- Group multiple accounts (TFSA, RRSP, non-registered, etc.) into one unified portfolio view
- Manage accounts from different registered account types together
- Each group has its own target allocation, drift threshold, and cash notification settings

### Target Allocation
- Set a target percentage for each ETF or stock (e.g. VFV 40%, XAW 40%, ZAG 20%)
- Portfolio accuracy shown as a percentage — how close your current holdings are to your targets
- Exclude individual securities from rebalance calculations without deleting them
- Symbol search powered by the Questrade API

### Rebalancing
- **Buy-only mode** (default) — allocates available cash to underweight positions only; never generates sell orders
- **Full rebalance mode** — generates both buy orders (underweight) and sell orders (overweight)
- Trades are calculated automatically when you open the Rebalance tab
- Each trade shows: symbol, action, quantity, estimated price, estimated cost
- Exclude individual trades from the batch with a single click before placing
- Proportional cash scaling — if calculated buys exceed available cash, quantities are scaled down proportionally while staying within your budget

### One-Click Trade Execution
- Place all calculated trades in a single click
- Choose market or limit orders before confirming
- Order confirmation sheet shows a summary before anything is submitted
- Live per-order status updates during execution (submitted → filled / failed)
- Failed orders are shown individually with the error — retry without re-placing successful ones

### Performance Tracking
- Portfolio value chart powered by Apple Swift Charts
- Time ranges: 1W, 1M, 3M, 6M, 1Y, All
- Time-weighted return (TWR) using the Modified Dietz method
- Total return (simple)
- Contribution tracking
- Dividend history per account

### Notifications
- **Cash available** — notified when new cash or dividends arrive above a configurable threshold
- **Portfolio drift** — notified when portfolio accuracy drops below your drift threshold
- **Order filled** — notified when a placed order is confirmed
- Delivered as native macOS system notifications

### Account Management
- Rename accounts and assign types (TFSA, RRSP, FHSA, Margin, etc.)
- Disconnect a brokerage — removes all synced data and revokes the token from Keychain
- Sync all accounts manually (⌘⇧R) or wait for background sync

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.0 or later |
| Swift | 5.10 or later |
| Questrade account | Required for Phase 1 |

---

## Getting Started

### 1. Register a Questrade API App

Questrade requires you to register a personal app to get a Client ID:

1. Log in to your Questrade account
2. Go to **Account Management → Apps → Authorized Apps**
3. Click **Add new app**
4. Set the **Redirect URI** to exactly: `passivapp://oauth/questrade`
5. Copy the **Client ID** — you'll need it in step 4

### 2. Add the URL Scheme in Xcode

After opening the project, add the custom URL scheme so the OAuth redirect works:

1. Select the `PassivMac` target in Xcode
2. Go to the **Info** tab
3. Under **URL Types**, click **+**
4. Set **Identifier** to `com.passivmac` and **URL Schemes** to `passivapp`

### 3. Open the Project

```bash
# Clone the repo (if not already done)
git clone <repo-url>

# Open in Xcode
open PassivMac/Package.swift
```

Xcode will resolve the `KeychainAccess` SPM dependency automatically.

### 4. Build and Run

Press **⌘R** in Xcode. The Welcome screen will appear on first launch.

Enter your **Client ID** from step 1, click **Connect Brokerage Account**, and complete the Questrade login in the browser window that appears.

### 5. Set Up Your Portfolio

1. After connecting, your accounts are imported automatically
2. Name each account and assign a type (TFSA, RRSP, etc.)
3. They're placed into a default portfolio group — rename it if you like
4. Go to the **Targets** tab and add your ETFs with target percentages
5. Open the **Rebalance** tab to see your first set of calculated trades

---

## Project Structure

```
PassivMac/
├── Package.swift                          # SPM manifest (macOS 14+, KeychainAccess dep)
├── ROADMAP.md                             # Feature phases and backlog
├── Sources/PassivMac/
│   ├── PassivMacApp.swift                 # @main App entry, NavigationSplitView root
│   ├── Core/
│   │   ├── Enums/                         # BrokerageType, AccountType, Currency, TradeEnums…
│   │   ├── Models/                        # SwiftData @Model entities (11 models)
│   │   └── Persistence/
│   │       └── PersistenceController.swift
│   ├── Brokerages/
│   │   ├── BrokerageProvider.swift        # Protocol all adapters conform to
│   │   ├── KeychainService.swift          # Token storage — tokens never touch SwiftData
│   │   ├── Questrade/                     # OAuth coordinator, endpoints, models, provider
│   │   └── IBKR/                          # Placeholder — Phase 3
│   ├── Services/
│   │   ├── RebalanceEngine.swift          # Pure math — buy/sell calculation, cash scaling
│   │   ├── PortfolioCalculator.swift      # Accuracy %, drift, TWR, total return
│   │   ├── SyncService.swift              # Orchestrates brokerage sync into SwiftData
│   │   ├── FXRateService.swift            # CAD/USD rates via Bank of Canada API
│   │   └── NotificationService.swift      # macOS UNUserNotifications
│   ├── Networking/
│   │   ├── HTTPClient.swift               # URLSession + async/await wrapper
│   │   ├── APIError.swift
│   │   └── RateLimiter.swift              # Per-brokerage token bucket
│   ├── Features/
│   │   ├── Onboarding/                    # Welcome, ConnectBrokerage, AccountImport
│   │   ├── Dashboard/                     # Dashboard grid, portfolio group cards
│   │   ├── PortfolioGroup/                # Holdings table, targets editor
│   │   ├── Rebalance/                     # Trade list, order confirmation sheet
│   │   ├── Performance/                   # Swift Charts, TWR, dividend history
│   │   ├── Accounts/                      # Account list, disconnect
│   │   ├── SymbolSearch/                  # Debounced symbol search sheet
│   │   └── Settings/                      # General, notifications, about
│   └── Utilities/
│       ├── FormatUtils.swift              # Currency, percent, shares, date formatters
│       ├── ColorExtensions.swift          # Green/red P&L and accuracy colors
│       └── DecimalExtensions.swift
└── Tests/PassivMacTests/
    ├── RebalanceEngineTests.swift          # 11 tests covering all rebalance scenarios
    └── PortfolioCalculatorTests.swift      # 11 tests covering accuracy, TWR, drift
```

---

## Data and Privacy

- **No data leaves your device** (except to Questrade's own servers during sync)
- OAuth tokens are stored exclusively in the macOS Keychain — never in SwiftData, UserDefaults, or any file
- No analytics, no telemetry, no third-party tracking
- No backend server — the app talks directly to Questrade

---

## Dependencies

| Package | Purpose |
|---|---|
| [KeychainAccess](https://github.com/kishikawakatsuki/KeychainAccess) | Keychain wrapper for OAuth token storage |

All other functionality uses Apple frameworks: SwiftUI, SwiftData, Swift Charts, AuthenticationServices, UserNotifications, URLSession.

---

## Running the Tests

```bash
cd PassivMac
swift test
```

Or in Xcode: **⌘U**

The test suite covers `RebalanceEngine` and `PortfolioCalculator` — the two pure-math modules with no I/O dependencies. Brokerage and UI tests require mocks and are planned for Phase 2.

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full plan. In brief:

| Phase | Focus |
|---|---|
| **Phase 1 (current)** | Questrade OAuth, sync, target allocation, rebalance calculation |
| **Phase 2** | One-click trade execution, performance charts, notifications, multi-currency |
| **Phase 3** | Interactive Brokers integration |
| **Phase 4** | CSV/PDF export, accessibility, keyboard shortcuts |
