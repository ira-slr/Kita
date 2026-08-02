# CHAPTER 20: APPENDICES

This section contains the formal engineering and business analysis artifacts required for QA testing and final project sign-off.

## 20.1 Glossary of Terms
*   **Sari-Sari Store:** A neighborhood convenience store in the Philippines, typically operated out of a portion of the owner's home.
*   **Nanay/Tatay:** Tagalog terms for Mother/Father, commonly used to respectfully refer to the store owners.
*   **Lista:** The traditional credit system where customers buy items on debt, recorded in a notebook.
*   **TFLite (TensorFlow Lite):** A set of tools to help developers run machine learning models on mobile, embedded, and IoT devices.
*   **OCR (Optical Character Recognition):** Technology that converts different types of documents, such as scanned paper receipts, into editable and searchable data.
*   **Fuzzy Matching:** A technique for finding strings that match a pattern approximately (rather than exactly).

## 20.2 Functional Requirements (Selected Samples)
*   **REQ-001 (Inventory):** The system MUST allow the user to manually add a product with a Name, Selling Price, and Initial Quantity.
*   **REQ-002 (OCR):** The system MUST process a photo of a receipt and extract text blocks containing at least one recognizable product description and price.
*   **REQ-003 (POS):** The system MUST calculate the total transaction amount correctly when multiple items and quantities are added to the cart.
*   **REQ-004 (Offline):** The system MUST be able to execute a complete POS transaction and update the inventory while the device is in Airplane Mode.

## 20.3 Non-Functional Requirements (Selected Samples)
*   **NFR-001 (Performance):** The POS module MUST reflect a tapped item in the cart within 100 milliseconds.
*   **NFR-002 (Storage):** The application installation size (APK/AAB) MUST NOT exceed 100 Megabytes, including all embedded ML models.
*   **NFR-003 (Security):** The local SQLite database MUST be encrypted using AES-256 (via SQLCipher).
*   **NFR-004 (Reliability):** The AI fuzzy matching engine MUST return a result within 2.0 seconds on a standard mid-range device (e.g., Snapdragon 6-series processor).

## 20.4 Acceptance Criteria (Sample: Receipt Scanner)
**User Story:** As a store owner, I want to scan a receipt so that my inventory updates automatically without manual typing.
*   **Scenario 1: Perfect Match**
    *   *Given* the user has "Coca-Cola 8oz" in their inventory with 10 stock.
    *   *When* the user scans a receipt containing "COCA-COLA 8OZ 12 PCS 120.00".
    *   *Then* the system automatically maps the line item.
    *   *And* when confirmed, the inventory updates to 22 stock and the cost price updates to 10.00.
*   **Scenario 2: Low Confidence Match**
    *   *Given* the user has "Nescafe Original" in inventory.
    *   *When* the user scans a receipt containing "NSCF ORG".
    *   *Then* the system highlights the item in yellow for review.
    *   *And* the user can manually link it to "Nescafe Original", saving the alias for future scans.

## 20.5 Risk Analysis
| Risk | Probability | Impact | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **OCR Failure on bad receipts** | High | Medium | Implement robust manual-override workflows in the Review Screen. Do not force AI reliance. |
| **Database Corruption** | Low | Critical | Implement mandatory weekly local backups. Use SQLite WAL mode to prevent transaction tearing during crashes. |
| **User Abandonment (Too Complex)** | Medium | High | Enforce strict UI simplicity. Restrict advanced features (like taxes) to optional settings toggles. Keep onboarding under 4 screens. |
| **Device Storage Full** | Medium | Medium | Automatically compress images. Provide an option to delete original receipt photos after parsing. |

## 20.6 Testing Strategy
1.  **Unit Testing:** Focus heavily on the Business Logic layer, specifically the mathematical calculations of the `TransactionService` and the Regex parsing logic of the `ReceiptParserService`.
2.  **Integration Testing:** Test the interaction between the SQLite repository and the Flutter UI, ensuring Database Locks do not cause app crashes during background operations.
3.  **Real-World AI Testing (Crucial):** QA testers MUST procure actual, physical receipts from popular Philippine distributors (Puregold, Suy Sing, local wholesalers) in varying conditions (faded, crumpled, poorly lit) to benchmark the OCR and Fuzzy Matching accuracy thresholds before launch. Simulator testing is insufficient for the AI module.
