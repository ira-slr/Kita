# CHAPTER 18: SECURITY

While sari-sari stores operate on a micro scale, the financial data stored within SariSmart is highly sensitive to the owner. Since the device may also be a personal phone shared with family members or occasionally handled by customers, the application must employ rigorous, offline-first security measures.

## 18.1 Data Encryption (Data at Rest)
*   **Implementation:** The entire SQLite database is encrypted using **SQLCipher** (an open-source extension to SQLite that provides 256-bit AES encryption).
*   **Key Management:** The encryption key is dynamically generated upon first launch and stored securely in the device's hardware-backed **Android Keystore** system. This ensures that even if a malicious actor extracts the `.db` file via physical access or a rooted device, the data remains unreadable without the specific hardware key.

## 18.2 Application Authentication
To prevent unauthorized access to sales data or inventory manipulation when the phone is unlocked and unattended, SariSmart employs application-level locking.
*   **PIN Security:** Users can set a 4 to 6-digit PIN. 
    *   *Brute Force Protection:* After 5 incorrect attempts, the app locks for 30 seconds, doubling the timeout on subsequent failures.
*   **Biometric Login:** Integration with the `androidx.biometric` library allows users to bypass the PIN using Fingerprint or Face Unlock, providing enterprise-grade security without compromising speed.
*   **Timeout Logic:** The app can be configured to require re-authentication immediately upon being backgrounded, or after a custom timeout (e.g., 5 minutes of inactivity).

## 18.3 Permissions and Privacy
SariSmart strictly adheres to the principle of least privilege.
*   **Camera:** Used explicitly for OCR and Product Recognition. Video/photos are never streamed to a server.
*   **Storage:** In modern Android versions (Scoped Storage), the app only requests permission to write to its designated app-specific directory. Exported CSVs or PDFs are saved to public directories (like Downloads) using the native Storage Access Framework, which requires explicit user consent per file.
*   **No Internet Requirement:** Because the core app functions 100% offline, users have the absolute guarantee that their sales data, supplier pricing, and profit margins are not being silently harvested for third-party analytics. 

## 18.4 Cloud Security (Opt-In Features)
If the user explicitly opts into Cloud Backup or Cloud Analytics:
*   **Authentication:** Requires a verified OAuth login (e.g., Google or Apple Sign-In).
*   **Encryption in Transit:** All synchronization payloads are transmitted over TLS 1.3 (HTTPS).
*   **Database Encryption (Backup):** The SQLite `.db` file uploaded to the cloud remains encrypted by SQLCipher. The cloud provider only stores the encrypted blob. Restoring the data requires the user to authenticate on the new device to negotiate the decryption key.

## 18.5 Employee/Multi-User Security (Preparation)
While the initial release targets single-owner operations, the database schema (`users`, `roles`, `permissions`) and UI architecture are designed to support role-based access control (RBAC) in future updates. 
*   *Future State:* An owner can create a "Cashier" PIN that allows access to the POS module but hides the Reports tab and the "Cost Price" fields in the Inventory module.
