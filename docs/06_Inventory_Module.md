# CHAPTER 6: INVENTORY MODULE

The Inventory Module is the backbone of SariSmart. It manages all product master data, stock levels, and historical purchasing records. While the primary data entry method is the AI Receipt Scanner, this module provides the granular control necessary for manual overrides, categorization, and detailed adjustments.

## 6.1 The Inventory List View
*   **Visual Elements:** 
    *   **Search Bar:** Pinned to the top. Implements a debounced (300ms) full-text search against the `product_name` and `category` fields.
    *   **Filter/Sort Chips:** Located below the search bar (e.g., "All," "Low Stock," "Out of Stock," "By Category," "Sort: A-Z," "Sort: Quantity").
    *   **Product List (RecyclerView):** 
        *   *Left:* Product Thumbnail (defaults to an AI-generated category icon if no photo exists).
        *   *Center:* Product Name (H3, bold), Category (Subtitle, grey).
        *   *Right:* Stock Quantity (Large number). If quantity is below the threshold, text is red. Below quantity: Selling Price (e.g., "₱15.00").
*   **Interaction:** Tapping a row opens the Product Details Screen. Long-pressing enables multi-select mode for Bulk Updates.

## 6.2 Adding Products Manually
While AI scanning is preferred, users can add items manually (e.g., for items bought without a receipt, like loose vegetables).
*   **Action:** User taps the "Add Product" FAB (Floating Action Button) or menu item.
*   **Screen: Manual Entry Form**
    *   **Image Section:** A large placeholder to "Add Photo." Tapping it opens a bottom sheet: "Take Photo" or "Choose from Gallery."
    *   **Fields (Mandatory marked with *):**
        *   `Product Name*` (Text Input)
        *   `Selling Price*` (Numeric Input, formatted as currency)
        *   `Cost Price` (Numeric Input, used to calculate profit. If left blank, profit calculations for this item are disabled).
        *   `Initial Stock Quantity*` (Numeric Input, integer).
    *   **Fields (Optional/Advanced - hidden behind an "Advanced Settings" accordion):**
        *   `Category` (Dropdown with "Add New Category" option)
        *   `Variants` (e.g., Size, Flavor. Selecting this dynamically generates sub-rows).
        *   `Expiration Date` (Date Picker. Crucial for perishables).
        *   `Supplier` (Dropdown mapped to the suppliers table).
        *   `Minimum Stock Alert` (Integer. Defaults to 5).
    *   **Validation:** 
        *   Product Name must be unique. If a duplicate is detected, a warning dialog appears: "It looks like [Name] already exists. Do you want to update the stock instead?"
        *   Selling Price must not be lower than Cost Price (triggers a warning, not a hard block: "Warning: You are selling this at a loss.").

## 6.3 Product Details and Editing
*   **Action:** Tapping an existing item in the inventory list.
*   **Screen: Product Dashboard**
    *   **Visuals:** A detailed view showing the image, current stock, and a large "Adjust Stock" button.
    *   **Profit Margins:** A visual progress bar showing the markup percentage (e.g., "Cost: ₱10 | Sell: ₱15 | Profit: ₱5 (50%)").
    *   **Purchase History:** A localized list displaying previous supplier purchases for this specific item, tracking price fluctuations over time.
*   **Editing:** Tapping the "Edit" pencil icon re-opens the form populated with the current data.
*   **Deleting / Archiving:** 
    *   *Rule:* If a product has associated transaction history, it cannot be hard-deleted from the SQLite database to preserve historical reporting integrity.
    *   *Action:* Tapping "Delete" flags the item as `is_archived = true`. It is hidden from the active POS and Inventory lists but remains in the database. 
    *   *Restore:* Archived items can be viewed via a filter and restored by toggling the flag.

## 6.4 Image Management
*   **Multiple Images:** Sari-sari products often look different from the front vs. top (e.g., sachets). The system allows up to 3 images per product.
*   **Image Cropping:** When a photo is taken, a native cropping tool appears, locking to a 1:1 square aspect ratio to ensure uniform UI presentation in the POS.
*   **Automatic Image Suggestion (Offline):** If the user types "Nescafe 3-in-1", a local asset dictionary may suggest a pre-bundled generic icon for coffee to save time and storage space.
*   **Storage:** Images are compressed (WebP format, max 500x500px, quality 70%) and stored in the app's local file directory. The SQLite database stores the relative file path.

## 6.5 Bulk Updates & Stock Adjustments
*   **Stock Adjustment (Single):** When receiving new stock without a receipt, the user taps "Adjust Stock" on the product detail page. They can choose "Add", "Subtract" (for damages/spoilage), or "Set to exactly".
*   **Bulk Update:** By long-pressing items in the list, the user enters multi-select mode. They can select multiple items and apply a bulk action: e.g., "Increase Selling Price by ₱1.00" or "Change Category to 'Snacks'".

## 6.6 Import and Export
*   **Export:** The user can export their entire inventory to a standard `.csv` file. The app utilizes native Android sharing intents to send this file to Email, WhatsApp, or save to local storage.
*   **Import:** To facilitate migration from other systems, users can import a `.csv` file. The app provides a column-mapping UI (e.g., "Which column is the Product Name?").

## 6.7 Categories and Variants
*   **Categories:** Simple text tags (e.g., "Beverages," "Canned Goods," "Hygiene"). Products can only belong to one primary category to keep the POS UI simple.
*   **Variants:** Handled as parent-child relationships. A parent product "Fita Crackers" can have variants "Small (₱7)" and "Large (₱40)". In the database, variants are distinct rows linked by a `parent_id`.

## 6.8 Edge Cases & Error Handling
*   **Database Lock:** If a background sync is running simultaneously with a manual edit, SQLite handles the lock. The UI should display a brief "Saving..." overlay to prevent double-tapping.
*   **Storage Full:** Before taking a product photo or running an export, the system checks available device storage. If below 50MB, a dialog appears: "Your phone storage is almost full. Please free up space to save new product images."
*   **Duplicate Detection (Fuzzy):** If a user tries to manually add "Marlboro Red" and "Marlboro Reds" already exists, the local fuzzy matcher triggers a warning before saving, preventing accidental database bloat.
