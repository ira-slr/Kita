# CHAPTER 14: PERSONALIZATION

SariSmart is designed to adapt to the habits of the store owner, rather than forcing the owner to adapt to the software. The Personalization module ensures that the most frequently used features and products are always just one tap away.

## 14.1 Dashboard Customization
The Dashboard is not a static layout. Users can customize which widgets they see based on their business priorities.
*   **Widget Arrangement:** By long-pressing any widget on the Dashboard (e.g., "Low Stock Alerts" or "Recent Transactions"), the UI enters "Edit Mode."
*   **Drag and Drop:** Users can drag widgets up or down to reorder them. If a user doesn't care about the AI suggestions, they can drag that widget to the very bottom, bringing "Recent Transactions" up higher.
*   **Hiding Widgets:** In Edit Mode, each widget features an 'X' icon. Tapping it hides the widget entirely. A "Add Widget" button at the bottom allows restoring hidden components.

## 14.2 POS Optimization (Favorites & Recents)
Speed in the Point of Sale is dictated by how quickly a user can find an item.
*   **The "Favorites" Category (⭐):** 
    *   This is the default, first category shown when opening the POS.
    *   *Manual Assignment:* Users can manually "star" products in the Inventory module. These items are permanently pinned to the Favorites tab.
*   **The "Frequently Sold" Algorithm:**
    *   If the user has not manually favorited enough items to fill the screen, the system automatically populates the remaining slots with items that have the highest frequency of inclusion in the `transaction_line_items` table over the last 7 days.
    *   *Result:* The items the user sells the most are mathematically guaranteed to be immediately visible upon opening the POS, requiring zero searching.
*   **Quick Buttons Configuration:**
    *   For un-barcoded items sold by variable weight (e.g., loose rice, loose sugar), the user can create custom "Quick Buttons" in the POS.
    *   *Example:* A button labeled "Rice - ₱20" that instantly adds exactly ₱20 worth of rice to the cart, automatically calculating the fractional inventory decrement based on the per-kilo price.

## 14.3 Store Branding and Visuals
Personalization extends to making the app feel like it truly belongs to the store.
*   **Dynamic Theming (Material You / Monet):** If the device runs Android 12+, SariSmart can optionally inherit the system-level color palette derived from the user's wallpaper, making the app feel deeply integrated with their personal device.
*   **Custom Color Overrides:** If the user prefers brand consistency (e.g., their physical store is painted bright green), they can force the app's primary accent color to match, replacing the default SariSmart blue.

## 14.4 Accessibility as Personalization
Recognizing the diverse age range of sari-sari store owners (many of whom are elderly), accessibility features are treated as core personalization options.
*   **High Contrast Mode:** Increases the border thickness of POS tiles and maximizes the contrast ratio of text against backgrounds, bypassing the standard aesthetic themes for pure readability.
*   **Left-Handed Mode:** A simple toggle that mirrors the layout of the POS Cart Drawer (moving it from the right side of the screen to the left on tablets/landscape devices, or swapping the position of primary action buttons) to accommodate left-handed cashiers.
