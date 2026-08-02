# CHAPTER 9: POINT OF SALE (POS)

The Point of Sale (POS) module is the most frequently used interface in SariSmart. It is designed for maximum speed, requiring the fewest possible taps to complete a transaction. Unlike traditional supermarket POS systems that rely heavily on barcode scanners, the SariSmart POS is optimized for visual navigation, recognizing that most sari-sari transactions are fast, high-volume, and involve small quantities of items.

## 9.1 The POS Interface Layout
*   **Architecture:** The screen is divided into two primary sections: The Product Grid (main area) and the Cart Drawer (bottom or side panel, depending on device orientation).
*   **Top Bar:**
    *   **Search Bar:** A highly prominent, sticky search bar. It supports fuzzy text search and includes a "Scan Item" icon (triggering the visual product recognition module).
    *   **Category Pills:** A horizontally scrolling list of category tags below the search bar (e.g., "All," "⭐ Favorites," "Drinks," "Canned Goods," "Snacks"). Tapping a category instantly filters the Product Grid below.
*   **Product Grid (Main View):**
    *   A grid of large, touch-friendly square tiles.
    *   *Content per Tile:* Product Image (fills the tile), Product Name (white text on a semi-transparent dark banner at the bottom of the tile), and Selling Price (badge in the top right corner).
    *   *Visual Cues:* If an item is out of stock, the tile is grayed out with a subtle "Out of Stock" overlay, though it can still be tapped (to allow negative inventory if enabled in settings).

## 9.2 Adding Items to the Cart
*   **Single Tap:** Tapping a product tile adds a quantity of '1' to the cart. The tile flashes briefly to provide visual feedback. A small floating "+1" animation floats up from the tile.
*   **Multiple Quantities (Rapid Tapping):** Tapping the same tile three times rapidly adds '3' to the cart. 
*   **Custom Quantity / Notes (Long Press):** Long-pressing a product tile opens a quick-action modal.
    *   *Modal Elements:* A numeric keypad to input a large quantity (e.g., "24" for a whole case), an input field for item-specific discounts (e.g., "₱2.00 off"), and a "Notes" field (e.g., "Customer will return the glass bottle").

## 9.3 Managing the Cart
*   **The Cart Drawer:** On portrait devices, this sits at the bottom of the screen, showing the current Subtotal and an "Expand" indicator. 
*   **Expanded View:** Swiping up or tapping the drawer expands it to show line items.
*   **Line Item Actions:**
    *   *Swipe Left to Delete:* Standard mobile interaction to remove an item completely.
    *   *+/- Steppers:* Adjust the quantity of a specific line item.
    *   *Item Total:* Displays the calculated total for that line (Price x Qty - Discount).
*   **Global Cart Actions:**
    *   **Apply Global Discount:** A button to apply a percentage or fixed amount discount to the entire bill (useful for wholesale customers or family members).
    *   **Hold Order:** Allows the user to save the current cart to a temporary state. Useful if a customer realizes they forgot their wallet and holds up the line; the store owner can serve the next customer.
    *   **Cancel Order:** Clears the entire cart instantly. Prompts a confirmation dialog: "Are you sure you want to clear this transaction?"

## 9.4 Payment Workflow
*   **Trigger:** Tapping the large, prominent "Charge [Total Amount]" button at the bottom of the Cart Drawer.
*   **Screen: Payment Modal**
    *   **Total Due:** Displayed in massive typography at the top.
    *   **Quick Cash Buttons:** Smart buttons dynamically generated based on the total. If the bill is ₱46.00, the buttons might be: [Exact Amount], [₱50], [₱100], [₱500], [₱1000].
    *   **Custom Numpad:** A standard numeric keypad to enter exact cash tendered (e.g., if the customer hands over ₱106.00 to get a solid ₱60.00 change).
    *   **Action:** User taps a Quick Cash button or enters the amount and taps "Confirm Payment."
*   **Validation:** If the entered cash tendered is less than the total due, the "Confirm Payment" button remains disabled, and the missing balance is shown in red.

## 9.5 Transaction Completion
*   **Screen: Success & Change**
    *   **Visuals:** A bright green success screen.
    *   **Key Information:** "Change Due: ₱54.00" (in massive, undeniable text to prevent calculation errors).
    *   **Actions Available:**
        *   "New Sale" (Primary action, routes immediately back to the empty POS grid).
        *   "View Receipt" (Secondary action, opens a digital receipt).
*   **Database Operations (Offline Transaction):**
    1.  An SQLite transaction is initiated.
    2.  A new row is inserted into the `transactions` table (ID, timestamp, total_amount, cash_tendered, change, global_discount, status='COMPLETED').
    3.  Multiple rows are inserted into `transaction_line_items` (transaction_id, product_id, quantity, unit_price, item_discount).
    4.  The `inventory` table is updated; `current_stock` is decremented for each product sold.
    5.  The SQLite transaction commits. This entire process takes <10ms.

## 9.6 History, Returns, and Voids
*   **Transaction History:** Accessible via the Dashboard or the Reports tab. It lists all transactions chronologically.
*   **Voiding a Sale:** 
    *   If a mistake was made, the user can tap a recent transaction and select "Void."
    *   *Database Action:* The system does not delete the transaction (for audit purposes). It marks the `status` as 'VOIDED' and automatically increments the `current_stock` back to its previous state.
*   **Refunds / Returns:** 
    *   If a customer returns a single item (e.g., a defective lightbulb) from a multi-item transaction, the user opens the transaction, selects the specific line item, and taps "Refund Item."
    *   *Database Action:* A linked negative transaction is created, and the inventory for that specific item is restored.

## 9.7 Offline Transactions & Edge Cases
Because the system is fully offline, there is no "Offline Mode" toggle. All POS transactions are inherently offline. 
*   **Zero Inventory Edge Case:** If a user tries to sell an item that the database says has 0 stock, the system will allow the transaction to proceed but will display a warning dialog post-sale: "Warning: Your stock for [Product] is now negative. Please adjust your inventory later." This respects the reality that physical stock takes precedence over digital records.
