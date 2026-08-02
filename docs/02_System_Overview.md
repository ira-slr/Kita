# CHAPTER 2: SYSTEM OVERVIEW

## 2.1 Overall Architecture
SariSmart is engineered as a standalone mobile application with a decentralized, offline-first philosophy. The architecture is primarily client-heavy, meaning the vast majority of processing, data storage, and machine learning inference occurs directly on the user's Android device. The application is built using the Flutter framework, allowing for a highly responsive, native-feeling user interface while maintaining a single codebase.

The system is divided into three primary layers:
1.  **Presentation Layer (UI/UX):** The Flutter-based frontend that users interact with.
2.  **Business Logic Layer:** The core services handling POS transactions, inventory updates, and report generation.
3.  **Data & Intelligence Layer:** The local SQLite database, shared preferences, and on-device TensorFlow Lite machine learning models.

## 2.2 Offline Architecture
The defining characteristic of SariSmart is its strict adherence to an offline-first paradigm. 
*   **Local Database:** All application data—including inventory items, transaction history, supplier details, and user settings—is stored locally in a robust SQLite database on the mobile device. 
*   **Zero-Latency Operations:** Because data is read from and written to the local disk, POS transactions and inventory updates occur with near-zero latency. There are no loading spinners waiting for server responses.
*   **Asset Bundling:** All required assets, including standard product placeholder images, ML model weights, and UI components, are bundled within the APK/AAB during compilation.

## 2.3 Cloud Architecture
Cloud connectivity in SariSmart is treated as an enhancement, never a dependency.
*   **Opt-in Cloud Sync:** When an internet connection is detected and the user has authenticated (e.g., via Google Sign-In or a dedicated account), the application can perform a background synchronization.
*   **Data Backup:** The local SQLite database is encrypted and securely backed up to a cloud storage provider (e.g., Firebase Cloud Storage or AWS S3).
*   **Conflict Resolution:** If cloud sync is utilized across a device replacement, a "Last Write Wins" or timestamp-based conflict resolution strategy is employed, though the primary use case is single-device backup rather than multi-device real-time collaboration.

## 2.4 Local AI
To circumvent the need for cloud-based APIs (which require internet and incur recurring costs), SariSmart utilizes On-Device Machine Learning.
*   **TensorFlow Lite:** The application embeds lightweight TensorFlow Lite models to handle complex pattern recognition tasks directly on the smartphone's CPU/NPU.
*   **Privacy-Preserving:** Because images of receipts and products never leave the device for processing, user privacy and proprietary business data are strictly protected.

## 2.5 Optical Character Recognition (OCR)
The Receipt Scanner module is the technological centerpiece of SariSmart.
*   **On-Device ML Kit:** The application utilizes Google's ML Kit (or a customized TFLite OCR model) to perform text recognition entirely offline.
*   **Bounding Box Extraction:** When a photo is taken, the OCR engine identifies text blocks (bounding boxes) and groups them into logical rows, attempting to associate product descriptions with their corresponding quantities and prices based on spatial proximity.
*   **Fuzzy Matching Engine:** Raw OCR text is often imperfect (e.g., "N3SCAFE BLK" instead of "Nescafe Black"). SariSmart employs a local fuzzy string matching algorithm (e.g., Levenshtein distance) to compare extracted receipt text against the user's existing inventory database to suggest the most likely matches.

## 2.6 Inventory System
The Inventory module manages the lifecycle of physical goods.
*   **Data Structure:** It tracks dynamic fields such as SKU (optional), Product Name, Category, Cost Price, Selling Price, Stock Quantity, Supplier, and Expiration Date.
*   **Alias Management:** The system maintains a localized "dictionary" of supplier aliases. If a supplier receipt prints "COKE MISMO 290" and the user saves it to their inventory as "Coca-Cola Mismo 290ml," the system learns this association for future receipts.

## 2.7 Point of Sale (POS)
The POS module is designed for speed and visual navigation.
*   **Scanner-Free Design:** Recognizing that hardware barcode scanners are impractical for this target market, the POS interface utilizes large, color-coded, image-rich buttons for product selection.
*   **Search and Categories:** Users can rapidly filter the POS view by tapping categories (e.g., "Drinks," "Canned Goods") or using a highly optimized, debounced search bar.
*   **Transaction Handling:** The POS calculates subtotals, manages cash tendered, calculates change, and permanently records the transaction, immediately decrementing the inventory upon confirmation.

## 2.8 Reporting
The Reporting engine transforms raw transaction data into actionable business intelligence.
*   **Local Aggregation:** The system performs SQL aggregations locally to generate daily, weekly, and monthly summaries of total revenue, total cost of goods sold (COGS), and net profit.
*   **Visualizations:** Data is presented using native Flutter charting libraries (e.g., fl_chart) to display line graphs for sales trends and pie charts for category breakdowns.

## 2.9 Settings
The Settings module allows extensive customization of the application environment.
*   It governs store profiling (name, logo), regional settings (currency, language), UI preferences (dark mode, layout), and manages the parameters for data backups and notifications.

## 2.10 Synchronization
The synchronization engine (when online) operates as a background worker.
*   It monitors a local `last_modified` timestamp on database tables.
*   It compresses the delta changes (or the entire SQLite file for simpler architectures) and uploads it securely to the cloud.
*   It handles network interruptions gracefully, pausing the upload and resuming when connectivity is restored, ensuring the UI thread is never blocked.

## 2.11 Security
Security is paramount, even for an offline application.
*   **Data at Rest:** The SQLite database is encrypted using SQLCipher.
*   **Authentication:** The application supports local biometric authentication (Fingerprint/Face Unlock) or a custom PIN to prevent unauthorized access to the application, protecting sensitive financial data from being viewed by customers or unauthorized personnel if the device is left unattended.
*   **No Telemetry Without Consent:** Analytics and crash reporting (if implemented) are strictly opt-in, respecting the user's data privacy.
