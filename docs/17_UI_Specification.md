# CHAPTER 17: USER INTERFACE SPECIFICATION

This chapter dictates the micro-interactions, states, and feedback mechanisms that define the "feel" of SariSmart. The UI must be unapologetically simple, relying on color psychology and iconography rather than dense text to guide the user.

## 17.1 Global UI Standards
*   **Typography:** A highly legible, sans-serif font (e.g., Inter or Roboto). 
    *   Headers (H1): 24sp, Bold.
    *   Body: 14sp or 16sp, Regular.
    *   Numbers (Prices/Quantities): Must use a monospace or tabular-lining font setting so decimals align vertically in lists.
*   **Primary Action Buttons:** Always solid color, full-width (or max 400dp on tablets), rounded corners (8dp), placed at the bottom of the screen.
*   **Destructive Actions:** (e.g., "Delete", "Void"). Always colored red, often requiring a secondary confirmation dialog.

## 17.2 State Management & Feedback
*   **Loading Screens:** 
    *   *Rule:* Avoid blocking full-screen spinners whenever possible.
    *   *Implementation:* Use "Shimmer" effects (skeleton screens) over the specific widget that is loading data from the database. 
    *   *Exception:* Heavy ML tasks (OCR scanning) use a modal overlay with a contextual Lottie animation (e.g., a scanning laser) so the user understands the device is "thinking."
*   **Empty States:**
    *   *Rule:* A blank screen is a failure of UX. 
    *   *Implementation:* If the Inventory is empty, display a friendly illustration of a cardboard box and a button: "Add Your First Product." If the daily sales are zero, display: "Waiting for your first customer today!"
*   **Success Messages:**
    *   *Implementation:* Unobtrusive "Snackbars" at the bottom of the screen that auto-dismiss after 3 seconds. e.g., "Inventory updated." (Green background).
*   **Warning/Error Screens:**
    *   *Implementation:* Modal Dialogs that require user acknowledgement (an "OK" button). e.g., "Camera permission denied. Please enable it in settings."

## 17.3 Specific Screen Specifications (Deep Dives)

### The Confirmation Dialog (Universal Component)
*   **Visuals:** A standard modal card dimming the background (barrier color: black 50% opacity).
*   **Title:** Bold, e.g., "Void Transaction?"
*   **Body:** "Are you sure you want to void this sale? This will return the items to your inventory. This action cannot be undone."
*   **Buttons:** 
    *   Right side (Primary): "Yes, Void" (Red text).
    *   Left side (Secondary): "Cancel" (Grey text).

### The POS Product Tile (Micro-UI)
*   **Size:** Minimum 100x100 dp to ensure it can be easily tapped by thumbs.
*   **Interaction States:**
    *   *Default:* Flat, subtle drop shadow.
    *   *Pressed:* The tile shrinks by 5% and the drop shadow disappears (simulating physical depth).
    *   *Out of Stock:* The image becomes grayscale, opacity drops to 50%, and a small red badge "0 left" appears.
    *   *Active (in Cart):* A blue border highlights the tile, and a badge in the top right shows the quantity currently in the cart (e.g., "x3").

### The Quick Cash Numpad (POS Modal)
*   **Design:** Inspired by traditional calculators but optimized for touch.
*   **Buttons:** Massive, borderless numbers (0-9, 00).
*   **Dynamic Buttons:** Above the numpad, 3-4 pills display calculated convenient amounts. If total is ₱135: 
    *   Pill 1: "Exact (₱135)"
    *   Pill 2: "₱150"
    *   Pill 3: "₱200"
    *   Pill 4: "₱500"
*   **Animation:** When the exact or greater amount is entered, a "Calculate Change" button slides up smoothly from the bottom, turning bright green to signal readiness.
