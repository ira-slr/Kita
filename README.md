# 🏪 Kita POS (Kita: Sari-Sari Store POS)

> **Kita ang benta, kita ang kita.**  
> A modern, 100% offline-first Point of Sale (POS) and Inventory Management System tailored for Sari-Sari stores and micro-retailers in the Philippines.

---

## 🌟 Key Features

### ⚡ 100% Offline-First Architecture
- Powered by a local **SQLite** embedded database (`sqflite`).
- Operates entirely offline with zero cloud dependency or latency.
- Protects store privacy—your data never leaves your device unless explicitly exported.

### 🛒 Point of Sale & Checkout
- **Instant Cart Management**: Rapidly add products via barcode scanning, search, or visual product grid.
- **Cash & Change Calculation**: Quick cash presets (₱50, ₱100, ₱500, ₱1,000) and automatic change computation.
- **Receipt Parsing & Printing**: Generate transaction receipts with line-item breakdowns.

### 📦 Inventory & Stock Control
- **Low-Stock Notifications**: Automatic local notifications when items drop below custom reorder thresholds.
- **Quick Restock**: Batch update stock levels directly from the inventory dashboard.
- **Philippine Catalog Auto-Fill**: Pre-loaded catalog for instant barcode-to-product mapping.

### 📷 Smart Camera & Barcode Scanner
- **Live Camera Barcode Scanner**: Instant product lookup via device camera using `mobile_scanner`.
- **OCR Receipt Parsing**: Extract product items and prices from physical distributor receipts via **Google ML Kit Text Recognition**.

### 📊 Financial Overview & Analytics
- **Interactive Reports**: Track Sales, Net Profit, Costs (COGS), and Completed Transactions.
- **Visual Analytics**: Revenue and profit trends powered by `fl_chart`.
- **Top Sellers Ranking**: Identify best-performing products by quantity sold and total revenue.
- **Void Audit Trail**: Restores stock automatically when a transaction is voided.

### 💾 Local Backup & Spreadsheet Export
- **1-File JSON Snapshots**: Export complete store database (products, sales, categories, settings) to a single portable file for easy transfer and restore.
- **CSV Data Export**: Export sales logs and product inventory to standard CSV spreadsheets (`Excel`, `Google Sheets`).

### 🔐 PIN Lock Security
- Protect store data and sales logs with a customizable **4-digit PIN lock screen** on app startup.

---

## 🛠️ Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (Dart SDK ^3.12.0) |
| **State Management** | [Flutter Riverpod](https://riverpod.dev/) |
| **Local Database** | [sqflite](https://pub.dev/packages/sqflite) (SQLite) |
| **AI / Machine Learning** | [Google ML Kit Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition) |
| **Barcode Scanner** | [mobile_scanner](https://pub.dev/packages/mobile_scanner) |
| **Analytics Charts** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **Local Notifications** | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| **UI Design System** | Material Design 3 (Adaptive Light & Dark Modes) |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.12.0)
- Android Studio / VS Code
- Android Device (Android 7.0+ / API 24+) or Emulator

### Installation & Execution

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ira-slr/Kita.git
   cd Kita
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on a connected device**:
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```
lib/
├── app/                  # Theme tokens and app shell layout
├── core/
│   ├── data/             # Philippine product catalog defaults
│   ├── database/         # SQLite DatabaseHelper & migration constants
│   ├── models/           # Data models (Product, Category, Transaction, StoreSettings)
│   ├── services/         # Backup, CSV Export, Barcode Lookup, Notifications
│   └── utils/            # Currency and date formatters
└── features/
    ├── inventory/        # Inventory list, catalog, add/edit product
    ├── onboarding/       # Setup wizard for new store owners
    ├── pos/              # Checkout grid, cart state, payment modal
    ├── reports/          # Financial overview, charts, sales history
    ├── scanner/          # Camera barcode scanning & ML Kit OCR receipt parsing
    ├── security/         # PIN Lock Screen verification
    └── settings/         # Store profile, backup/restore, version info
```

---

## 📜 License & Copyright

Designed and developed for **Kita POS**. All rights reserved.
