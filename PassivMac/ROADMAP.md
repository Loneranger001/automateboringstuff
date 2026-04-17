# PassivMac — Product Roadmap

A personal Mac desktop app for portfolio rebalancing, inspired by Passiv.
Built with SwiftUI + SwiftData. No paywall — all features available.

---

## Phase 1 — MVP: Questrade Integration ✅ (Current)

Core loop: connect Questrade → sync holdings → set targets → see rebalancing trades.

- [x] Project scaffold (SPM, folder structure, all layers)
- [ ] Questrade OAuth 2.0 (ASWebAuthenticationSession)
- [ ] Keychain token storage
- [ ] Account + position + balance sync
- [ ] Portfolio group creation and account assignment
- [ ] Target allocation editor (% mode)
- [ ] Rebalancing engine — buy-only mode, single currency
- [ ] Calculated trades display (no execution yet)
- [ ] Dashboard with portfolio group cards
- [ ] Basic portfolio snapshots (for future charting)

---

## Phase 2 — Feature Complete

Full parity with Passiv's core feature set.

- [ ] One-click trade execution via Questrade API
- [ ] Order confirmation sheet (market / limit)
- [ ] Full rebalance mode (buy + sell)
- [ ] Fixed-dollar target allocation mode
- [ ] CAD / USD multi-currency support (Bank of Canada FX rates)
- [ ] Portfolio accuracy % + drift threshold setting
- [ ] Drift notification (macOS UserNotifications)
- [ ] Cash available notification
- [ ] Performance chart (Swift Charts — 1W/1M/3M/6M/1Y/All)
- [ ] Time-weighted return (Modified Dietz)
- [ ] Dividend history display
- [ ] Symbol search (Questrade symbol search API)
- [ ] Background sync (BGTaskScheduler, every 4 hours)

---

## Phase 3 — IBKR Integration

Add Interactive Brokers as a second supported brokerage.

- [ ] IBKR Client Portal API adapter (IBKRProvider)
- [ ] IBKR OAuth / session-based authentication
- [ ] IBKR account, position, and balance sync
- [ ] IBKR order execution
- [ ] Multi-broker portfolio groups (mix Questrade + IBKR accounts in one group)
- [ ] USD-primary account handling for IBKR

---

## Phase 4 — Polish

- [ ] Keyboard shortcuts
- [ ] Accessibility (VoiceOver labels on charts and tables)
- [ ] CSV / PDF export of holdings and performance
- [ ] Per-account tax-efficiency rules (e.g. keep US ETFs in RRSP)
- [ ] App icon + menubar presence (optional)
