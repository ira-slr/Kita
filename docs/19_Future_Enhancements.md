# CHAPTER 19: FUTURE ENHANCEMENTS

SariSmart is designed with a roadmap that scales alongside the growth of the micro-entrepreneur. While Version 1.0 focuses strictly on the offline, AI-assisted core, the architecture supports significant expansion into a comprehensive retail ecosystem.

## 19.1 Hardware Integration
*   **Thermal Receipt Printers:** Support for cheap, generic Bluetooth thermal printers (58mm/80mm). The app will utilize ESC/POS commands to print physical customer receipts and end-of-day summary reports.
*   **Hardware Barcode Scanners:** While the AI vision model replaces scanners for many users, larger stores that upgrade to USB/Bluetooth scanners will be supported via HID (Human Interface Device) keyboard emulation in the POS search bar.

## 19.2 Digital Payments & E-Wallets
Cash remains king in sari-sari stores, but digital payments are rising rapidly.
*   **GCash and Maya Integration:** 
    *   *Phase 1:* Adding "GCash" and "Maya" as Payment Types in the POS (purely for accounting purposes, requiring the owner to manually verify the SMS/App transfer).
    *   *Phase 2:* API Integration. Generating dynamic QR codes on the SariSmart screen that the customer scans, with the app automatically verifying the payment via webhooks.

## 19.3 Multi-User and Multi-Store (Cloud Scale)
*   **Employee Accounts (Role-Based Access Control):** Allowing the owner to hire a cashier. The cashier logs in with a limited PIN, allowing them to ring up sales (POS) but blocking them from seeing total profit, altering inventory, or deleting transactions.
*   **Multi-Store Syncing:** For owners who expand to a second location, a premium cloud subscription will allow real-time database synchronization via a backend like Firebase/Supabase, enabling the owner to monitor both stores' live sales from home.

## 19.4 Supplier & Supply Chain Integration
*   **Automated Purchase Orders:** When the AI detects low stock, it can automatically generate a PDF Purchase Order and open a WhatsApp intent to send it directly to the distributor.
*   **Digital Wholesale Marketplace:** Transforming the app into a B2B platform where FMCG brands (Nestle, Unilever, Coca-Cola) can push exclusive discounts or bulk deals directly to the SariSmart dashboard, bypassing traditional middlemen.

## 19.5 Advanced AI and Customer Loyalty
*   **Customer Debt Tracking (Digital "Lista"):** Digitizing the traditional notebook credit system. Owners can create customer profiles, attribute unpaid sales to them, set credit limits, and send automated SMS reminders for payment.
*   **Loyalty Programs:** Implementing a simple points system based on customer profiles (tracked via phone number) to encourage repeat business.
*   **Price Elasticity AI:** If the app notices that increasing the price of Ice from ₱3 to ₱5 did not decrease sales volume, it might suggest slight price increases on other highly inelastic goods.
