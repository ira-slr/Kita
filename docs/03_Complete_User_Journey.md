# CHAPTER 3: COMPLETE USER JOURNEY

This chapter details the absolute end-to-end journey of a user interacting with SariSmart, from the moment of installation through daily operations, ensuring every screen, state, and interaction is meticulously mapped.

## 3.1 Pre-Installation and Installation
*   **Context:** The store owner (User) hears about SariSmart through word-of-mouth or social media. They realize they need a better way to track their inventory without buying expensive equipment.
*   **Action:** The User opens the Google Play Store on their Android smartphone, searches for "SariSmart", and clicks "Install."
*   **System Response:** The application downloads. Because the architecture includes local ML models, the APK size is optimized (approximately 40-60MB) to ensure it can be downloaded even on slower cellular networks.

## 3.2 First Launch and Splash Screen
*   **Action:** The User taps the SariSmart icon on their home screen.
*   **Screen: Splash Screen**
    *   **Visuals:** A vibrant, welcoming screen displaying the SariSmart logo (a stylized storefront or a smart shopping basket).
    *   **Animation:** The logo subtly pulses or scales up. A minimal loading indicator spins at the bottom.
    *   **Background Process:** The application initializes the local SQLite database, decrypts the local storage using a device-specific keystore, and loads the TensorFlow Lite models into memory. 
    *   **Transition:** After 1.5 to 2.5 seconds, the system transitions to the Permission Request Flow.

## 3.3 Permission Requests
SariSmart requires specific permissions to function. These are requested transparently and sequentially.
*   **Screen: Camera Permission Justification**
    *   **Visuals:** An illustration of a receipt being scanned.
    *   **Text:** "SariSmart needs your camera to scan receipts and recognize products instantly."
    *   **Action:** User taps "Continue".
    *   **System Popup:** Standard Android OS prompt: "Allow SariSmart to take pictures and record video?" User selects "While using the app".
*   **Screen: Storage Permission Justification (If applicable for Android versions requiring it for backups)**
    *   **Visuals:** An illustration of a secure vault or a folder.
    *   **Text:** "We need storage access to save your inventory data and backups securely on your phone."
    *   **Action:** User taps "Continue" -> Accepts OS prompt.
*   **Screen: Notification Permission Justification (Android 13+)**
    *   **Visuals:** An illustration of a bell icon with an alert.
    *   **Text:** "Allow notifications so we can remind you when your best-selling items are running out of stock."
    *   **Action:** User taps "Continue" -> Accepts OS prompt.

## 3.4 First-Time Setup (Onboarding)
Once permissions are granted, the User must configure their store.
*   **Screen: Welcome & Store Profile**
    *   **Visuals:** A clean form.
    *   **Fields:** "Store Name" (Required text field), "Owner Name" (Optional text field).
    *   **Action:** User enters "Aling Nena's Sari-Sari" and taps "Next".
*   **Screen: Currency & Region**
    *   **Visuals:** Dropdown menus.
    *   **Fields:** "Currency" (Defaults to PHP - Philippine Peso based on device locale).
    *   **Action:** User confirms PHP and taps "Next".
*   **Screen: Security Setup (Optional but Recommended)**
    *   **Visuals:** A numpad for PIN entry.
    *   **Text:** "Protect your sales data with a 4-digit PIN."
    *   **Action:** User enters '1234', confirms '1234'. If the device has biometric sensors, a prompt asks, "Enable Fingerprint Login?" User taps "Yes".
*   **Screen: Setup Complete**
    *   **Visuals:** A celebratory animation (confetti or a checkmark).
    *   **Action:** User taps "Go to Dashboard".

## 3.5 The Dashboard Experience
*   **Context:** The User is now on the main hub of the application.
*   **Screen: Dashboard (Empty State)**
    *   **Visuals:** Because the store is new, the "Daily Sales" shows ₱0.00. The "Low Stock" widget shows an illustration of empty shelves with the text, "Your inventory is empty. Let's add some products!"
    *   **Action:** The User taps the prominent floating action button (FAB) or the "Add Inventory" card.

## 3.6 Adding Initial Inventory via Receipt Scanner
The User decides to test the core AI feature.
*   **Context:** The User has a physical receipt from a local wholesaler (e.g., Puregold or a local distributor).
*   **Action:** User selects "Scan Receipt" from the action menu.
*   **Screen: Camera Viewfinder**
    *   **Visuals:** A live camera feed with an overlay box guiding the user to align the receipt. A flashlight toggle is available in the corner.
    *   **Action:** User aligns the receipt and taps the shutter button.
*   **Screen: Image Processing (Loading state)**
    *   **Visuals:** A scanning animation moves over the captured image.
    *   **Background Process:** The local OCR model extracts text. The fuzzy matching engine attempts to parse lines into [Product Name] - [Quantity] - [Price].
*   **Screen: Receipt Review**
    *   **Visuals:** A list of extracted items. E.g., "NESCAFE ORIGINAL 30S" | Qty: 2 | Total: ₱150.00.
    *   **Action:** The User reviews the list. The system highlights an item in yellow indicating low confidence: "CK MSMO 290". The User taps it and manually types "Coke Mismo 290ml". The AI learns this alias.
    *   **Action:** User taps "Confirm & Update Inventory".
    *   **Database Update:** The SQLite database adds the products, calculates the per-unit cost, and updates stock levels.

## 3.7 Setting Selling Prices
*   **Context:** The products are in the system with their Cost Price. The User must set the Selling Price before opening the store.
*   **Screen: Pricing Action Required**
    *   **Visuals:** A modal appears after receipt scanning: "You have 5 new items. Set their selling prices now."
    *   **Action:** User taps "Set Prices".
    *   **Screen: Bulk Pricing List**
    *   **Visuals:** A list of the newly added items. It shows Cost: ₱5.00/sachet. An empty text field for Selling Price. The app might suggest a standard 20% markup (Selling Price: ₱6.00).
    *   **Action:** User accepts the suggestions or types their own prices. Taps "Save".

## 3.8 Conducting a POS Transaction
*   **Context:** A customer arrives and wants to buy 1 Nescafe and 2 Coke Mismos.
*   **Action:** The User taps the "POS" tab on the bottom navigation bar.
*   **Screen: Point of Sale**
    *   **Visuals:** A grid of product images (or colored tiles with product names).
    *   **Action:** User taps the "Nescafe" tile once (adds 1 to cart). User taps the "Coke Mismo" tile twice (adds 2 to cart).
    *   **Visuals:** A side or bottom panel shows the Cart Summary: Total ₱46.00.
    *   **Action:** User taps "Charge ₱46.00".
*   **Screen: Payment Modal**
    *   **Visuals:** Quick cash buttons (₱50, ₱100, ₱500, Exact Amount) and a custom numpad.
    *   **Action:** The customer hands over a ₱100 bill. The User taps the "₱100" button.
*   **Screen: Transaction Complete**
    *   **Visuals:** Large text displays "Change: ₱54.00".
    *   **Database Update:** The inventory for Nescafe is reduced by 1. Coke Mismo is reduced by 2. A transaction record is created for ₱46.00 revenue and the corresponding profit is calculated.
    *   **Action:** User taps "New Sale" to return to the POS screen.

## 3.9 End of Day & Reporting
*   **Context:** It's 9:00 PM and the User is closing the store. They want to see how much they made.
*   **Action:** User taps the "Reports" tab.
*   **Screen: Daily Report**
    *   **Visuals:** A clean dashboard showing Total Sales, Gross Profit, and Total Transactions for the day. A bar chart shows sales by hour, indicating a peak at 4:00 PM.
    *   **Action:** User feels satisfied with the visual confirmation of their hard work.

## 3.10 Low Stock Notification (The next day)
*   **Context:** The User is outside the app, perhaps browsing Facebook.
*   **Action:** A local push notification arrives: "⚠️ Low Stock Alert: Coke Mismo 290ml is down to 2 pieces."
*   **Action:** User taps the notification, which opens SariSmart directly to the Inventory screen for that product, prompting them to add it to their next shopping list.

## 3.11 Cloud Backup (Weekly)
*   **Context:** The User connects to their home Wi-Fi on Sunday.
*   **Action:** The application detects the unmetered Wi-Fi connection. In the background, it silently encrypts the SQLite database and uploads a secure backup to the cloud. A small, unobtrusive toast message appears: "Data backed up successfully."

This complete user journey illustrates a seamless, offline-first workflow that eliminates manual typing, ensures continuous operation, and provides actionable insights without requiring technical expertise.
