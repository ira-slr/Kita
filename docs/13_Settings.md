# CHAPTER 13: SETTINGS

The Settings module allows the store owner to mold SariSmart to their specific operational environment. It is divided into logical sections accessible via a clean, list-based UI from the main navigation menu or dashboard profile icon.

## 13.1 Store Profile
This section defines the identity of the business.
*   **Store Logo:** An image picker allowing the user to upload a photo of their storefront or a custom logo. This logo appears on the Dashboard and on any generated PDF reports/receipts.
*   **Store Name & Owner Name:** Editable text fields.
*   **Contact Information:** Optional fields for phone number or address (used primarily if the user intends to print receipts for customers).

## 13.2 Regional & Financial Settings
*   **Currency:** Dropdown to select the primary currency symbol (₱, $, €, etc.). Changes are reflected globally across all UI elements immediately.
*   **Language:** Allows hot-swapping the application language (English, Tagalog, Bisaya). The app utilizes local string resource files (`.arb` or `.json`) to update the UI without requiring a restart.
*   **Taxes (Optional):** While most sari-sari stores operate in an informal economy without VAT tracking, advanced users can toggle "Enable Tax Tracking." This adds a global tax percentage to all POS transactions, which is broken out separately in the Reports module.

## 13.3 Theme & Appearance
*   **Dark Mode Toggle:** Options for "Light," "Dark," or "System Default." Dark mode is highly requested for battery saving on AMOLED screens and reducing eye strain during night shifts.
*   **Color Theme:** The user can select from 4-5 pre-defined accessible color palettes (e.g., "SariSmart Blue", "Palengke Green", "Sunset Orange") to personalize the app's accent colors.

## 13.4 Security & Privacy
Because the app contains sensitive financial data, security controls are prominent.
*   **App Lock:** Toggle to require authentication every time the app is opened or brought back from the background.
*   **Authentication Methods:**
    *   *PIN:* A 4-digit or 6-digit passcode.
    *   *Biometrics:* A toggle to enable Fingerprint or Face Unlock, utilizing the native Android BiometricPrompt API.
*   **Hide Balances:** A "Privacy Mode" toggle. When enabled, the large Dashboard sales figures are blurred or replaced with asterisks (***) until the user explicitly taps an "eye" icon to reveal them. Useful when customers are peering over the counter.

## 13.5 Data Management (Backup, Restore, Import, Export)
This is the most critical section for an offline-first application.
*   **Local Export (.csv):** Buttons to "Export Inventory" and "Export Transactions". These generate raw CSV files saved to the phone's Documents folder.
*   **Local Backup (.db):** Generates an encrypted copy of the entire SQLite database file and saves it locally.
*   **Cloud Sync (Opt-In):**
    *   *Authentication:* Requires the user to sign in (e.g., via Google Sign-In).
    *   *Toggle:* "Enable Automatic Cloud Backup" (Only on Wi-Fi, or Wi-Fi + Cellular).
    *   *Manual Sync Button:* Shows the timestamp of the "Last Successful Sync" and provides a "Sync Now" button.
*   **Restore:** Allows the user to select a local `.db` file or pull their latest cloud backup to completely overwrite the current state (used when migrating to a new phone).

## 13.6 Feature Toggles (AI & Hardware)
*   **AI Settings:** Toggles to enable/disable specific intelligent features if the user finds them distracting or if they are causing performance issues on very old devices:
    *   "Suggest Products from Photos"
    *   "Smart Restock Predictions"
*   **OCR Settings:**
    *   "Save Original Receipt Photos" (Toggle off to save storage space; the app will extract data and immediately delete the photo).
*   **Accessibility:**
    *   "Large Text Mode": Overrides the system default to force larger typography within the app for visually impaired users.
    *   "Haptic Feedback": Toggle vibrations on POS button taps.
