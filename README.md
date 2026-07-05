# FinFlow 💸

A modern, offline-first personal money manager built with Flutter. Track spending across multiple cash and bank accounts, manage money you owe / are owed, set up recurring auto-payments, and understand where your money goes — all with a clean Material 3 design, smooth animations, and full light/dark theming.

> Currency: ₹ (INR) by default. India-focused, but the data model is currency-agnostic.

---

## ✨ Features

### Home & Spending
- **Pinned** overview header (month + Balance / Income / Expenses) that stays put while the list scrolls; swipe to change month (**future months are blocked**) or tap to pick.
- Horizontally scrollable **account balance cards** — choose which accounts appear via a toggle on each account (Categories → Accounts). The header **Balance = sum of the shown accounts**.
- **Transactions grouped by day** with a per-day header showing the day's net total.
- Unified register — **income, expense, and transfers in one list**. Signed amounts: expense `-`, income `+`.
- **Expanding + button** (full-screen dim) to quickly add **Expense / Income / Transfer**.
  - Fast-add validation: an expense needs **amount + payment mode + category**; income needs **amount + account**; transfer needs **from + to + amount**.
  - Transfers move money between accounts as a **single editable record** (`Bank 1 → ₹300 → Bank 2`).
- **Receipt images**: attach up to 3 photos (gallery or camera) to a transaction; a thumbnail icon on the row opens a swipeable viewer.
- Tap any transaction to **edit or delete** (with a confirmation dialog). Balances always stay in sync.
- **Search & filter** by amount, keyword, date range, amount range, tag, or payment mode. A **SMS shortcut** icon sits next to search.

### Pending Payments
- Three list types with colored glow cards:
  - **To Pay** (you owe) — 🟧 orange
  - **To Receive** (owed to you) — 🟥 red
  - **To-Do** — 🟦 blue
  - **Done** — 🟩 green
- Mark **To Pay / To Receive** as done → automatically posts the matching **expense / income** transaction.
- Edit, delete (with warning), done, and undo.

### Categories (the control center)
Rows use **swipe gestures**: swipe **right to delete**, **left to edit**.
- **Accounts** — cash & bank balances, custom color + icon, plus a **show-on-Home toggle**.
- **Payment Modes** — Cash / GPay / BHIM / Paytm / etc., each linked to an account. Displayed as **"Name (Account)"** (e.g. *UPI 3 (SBI)*) and tinted with the account's color so the right balance is debited.
- **Categories** — daily-use categories, split into **Income** and **Expense** sections.
- **Auto-Pay** — recurring income/expense that posts itself (daily/weekly/monthly/yearly), with a **per-item notification toggle**.
- **Tags** — hashtag-style labels; a tag named `savings` counts toward savings in Analysis.

### Analysis
- Period tabs: **Daily / Weekly / Monthly / Yearly / Custom range**.
- **Income, Expenses, Net Savings** cards (+ tagged savings).
- **Income vs Expenses** bar chart and **Expenses by Category** donut (fl_chart).

### Settings
- Theme: **System / Light / Dark**.
- **Currency**: pick a symbol (₹, $, €, £, ¥, ₩, ₽, ฿, …) and **show/hide** it next to amounts (default: show, ₹).
- **Backup** (export all data to `.json`) and **Restore** (import). Receipt images are **not** embedded in the backup — only their references are saved.
- **Delete data**: all income / all expenses / everything — each guarded by a warning.
- **SMS auto-import** toggle (see below).
- App version.

### SMS auto-import (Android, optional, beta)
Off by default. When enabled, FinFlow reads bank transaction SMS **read-only** and shows detected transactions for you to **confirm before adding** — nothing is added automatically.

> ⚠️ **Honest note:** bank SMS formats vary widely, so parsing is best-effort, not 100% accurate. The `READ_SMS` permission is also restricted on the Google Play Store; this feature is intended for personal/sideloaded builds and always requires manual confirmation.

---

## 🛠 Tech Stack

| Concern | Choice |
| --- | --- |
| Language / SDK | Flutter 3.35+, Dart 3.9+ |
| State management | Riverpod (`flutter_riverpod`) |
| Local storage | Hive CE — each entity stored as a JSON string (no code-gen) |
| Routing | `go_router` (stateful shell, 5 tabs) |
| Charts | `fl_chart` |
| Animations | `flutter_animate` + built-in |
| Notifications | `flutter_local_notifications` |
| Swipe actions | `flutter_slidable` |
| Receipt images | `image_picker` (+ `path_provider` storage) |
| Backup | `dart:convert` + `file_picker` + `share_plus` + `path_provider` |
| SMS | `another_telephony` (read-only) |

### Why JSON-string storage?
Each Hive box stores `id → jsonEncode(model.toJson())`. This avoids Hive type adapters / `build_runner` entirely, keeps the data layer free of Flutter types, and makes backup/restore a straight dump-and-load.

---

## 📁 Project structure

```
lib/
  main.dart, app.dart, router.dart
  core/         theme, icons, utils, constants
  data/
    models/         Account, PaymentMode, Category, AppTag,
                    AppTransaction, PendingItem, AutoPay, AppSettings
    repositories/   hive boxes, AppData snapshot, seed data
    backup/         JSON export / import
    notifications/  local notifications
    widget/         home-screen widget bridge
    sms/            parser + import service
  providers/    app state notifier + derived/analysis providers
  features/     home, pending, categories, analysis, settings, add_transaction
  shared/widgets/  glow card, expanding FAB, pickers, dialogs, sheet scaffold
```

---

## 🚀 Getting started

```bash
flutter pub get

# Run on a connected Android device / emulator
flutter run

# Build a debug or release APK
flutter build apk --debug
flutter build apk --release
```

Regenerate the launcher icon (optional):
```bash
dart run tool/generate_icon.dart      # writes assets/icon/finflow_icon.png
dart run flutter_launcher_icons       # installs icons across platforms
```

---

## ✅ Tests

Core logic (balance math, transfers, pending completion, backup round-trip,
auto-pay idempotency, SMS parsing) is covered by headless tests:

```bash
flutter test
```

---

## 💾 Backup format

A backup is a single `.json` file:

```json
{
  "app": "FinFlow",
  "version": 1,
  "exportedAt": "2026-06-18T20:00:00.000",
  "boxes": {
    "accounts": { "<id>": "<json string>" },
    "transactions": { "...": "..." }
    /* ...all other boxes... */
  }
}
```

Restoring replaces all current data with the file's contents.

---

## 🔐 Permissions
- `READ_SMS` — optional, only for the gated SMS-import feature (read-only).
- `POST_NOTIFICATIONS` — auto-pay reminders (Android 13+).
- FinFlow does **not** use location. The `another_telephony` plugin declares `ACCESS_COARSE_LOCATION` in its own manifest; FinFlow strips it during manifest merge (`tools:node="remove"`), so the app never requests location.

## 🗺 Roadmap ideas
- Per-row account selection in SMS import & smarter bank-format detection.
- Scheduled (timezone-aware) auto-pay reminders ahead of due dates.
- Embedding receipt images in backups; cloud backup.

---

*Built with Flutter. Version 1.1.01.*
