# CHAPTER 16: TECHNICAL ARCHITECTURE

SariSmart's architecture is explicitly designed to solve the two biggest constraints of micro-retailers in developing nations: lack of reliable internet and low-end hardware. The system is a "Thick Client," meaning the vast majority of processing power resides on the device itself.

## 16.1 Technology Stack Selection
*   **Frontend Framework:** Flutter (Dart).
    *   *Rationale:* Allows for a single codebase that compiles natively to Android (and iOS in the future) while delivering a highly responsive, custom UI capable of smooth 60fps animations, which is critical for making the POS feel fast.
*   **Local Database:** SQLite (via the `sqflite` or `drift` Flutter packages).
    *   *Rationale:* The industry standard for on-device relational data. It is lightweight, ACID-compliant, and capable of handling hundreds of thousands of transactions without noticeable latency.
*   **Machine Learning Engine:** TensorFlow Lite (TFLite) & Google ML Kit.
    *   *Rationale:* ML Kit provides highly optimized, on-device OCR out-of-the-box. TFLite allows for running custom `.tflite` models for visual product recognition (e.g., MobileNetV2) with minimal memory footprint.

## 16.2 Core Modules Architecture
1.  **UI/Presentation Layer:** Handles state management (e.g., using Riverpod or Provider), routing, and rendering. It strictly observes the Data Layer and never performs direct computations.
2.  **Domain/Service Layer:** Contains the business logic. Examples include the `TransactionService` (calculates change, handles voids) and the `InventoryService` (calculates low stock thresholds).
3.  **Data Layer:** 
    *   *LocalDB Provider:* Abstracts SQLite queries.
    *   *ML Provider:* Wraps the TFLite interpreters.
    *   *Secure Storage:* Manages encryption keys and sensitive user preferences using the Android Keystore system.

## 16.3 OCR and Image Processing Pipeline
When a user scans a receipt, the process follows this strict pipeline:
1.  `CameraPreview` captures a high-resolution frame.
2.  Image is passed to an asynchronous `Isolate` (Dart's implementation of worker threads) to prevent freezing the UI.
3.  The Isolate performs pre-processing (Grayscale, Thresholding) using an embedded image processing library.
4.  The processed image buffer is passed to ML Kit Vision API.
5.  ML Kit returns a `RecognizedText` object.
6.  A Regex/Spatial parser in the Isolate extracts structural data.
7.  The Isolate executes a Fuzzy Matching algorithm against a cached copy of the `product_aliases` and `inventory` tables.
8.  The Isolate returns the parsed, matched list back to the main UI thread for user review.

## 16.4 Performance Optimization and Caching
*   **Image Caching:** Product thumbnails are cached heavily in memory (RAM) during POS operations to ensure scrolling the grid is frictionless. When not in the POS, these are evicted to save memory.
*   **Search Debouncing:** In both the POS and Inventory search bars, RxDart (or simple Timer logic) is used to debounce inputs by 300ms. This prevents the database from executing a `LIKE '%query%'` search on every single keystroke.
*   **Analytics Rollups:** As detailed in Chapter 10, a background worker aggregates granular transaction data daily. This prevents the UI from having to sum millions of rows when loading the "Year to Date" report.

## 16.5 Offline Synchronization (The Sync Engine)
When the user opts into cloud backup, the architecture utilizes an Eventual Consistency model.
*   **State Tracking:** Every row in the SQLite database has an `updated_at` timestamp.
*   **Trigger:** The native OS (Android WorkManager) triggers a sync job when it detects an unmetered Wi-Fi connection and the device is charging.
*   **Payload:** The app queries the local database for all rows where `updated_at > last_successful_sync_timestamp`.
*   **Upload:** These delta changes are serialized to JSON and pushed to a serverless backend (e.g., Firebase Cloud Functions or AWS Lambda), which updates a cloud database (e.g., Firestore). 
*   **Conflict Resolution:** If the user restores their data to a new phone, the cloud timestamp acts as the source of truth, pulling down the latest state and overwriting the local SQLite file.
