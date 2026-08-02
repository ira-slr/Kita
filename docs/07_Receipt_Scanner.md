# CHAPTER 7: RECEIPT SCANNER (AI OCR)

The Receipt Scanner is the primary differentiator of SariSmart. It replaces tedious manual data entry with an intelligent, offline optical character recognition (OCR) workflow. This chapter details the entire lifecycle of a scanned receipt, from pixel to database row.

## 7.1 The Capture Workflow
*   **Trigger:** Tapping the FAB Camera icon.
*   **Screen: Custom Camera Viewfinder**
    *   **Visuals:** A full-screen camera feed. A semi-transparent overlay draws a bounding rectangle, guiding the user to align the physical receipt vertically.
    *   **UI Elements:** Flashlight toggle (top left), Gallery import icon (bottom left), large Shutter button (bottom center).
    *   **Edge Case - Poor Lighting:** The app monitors the ambient light sensor. If lux levels are extremely low, a non-intrusive toast suggests: "It's a bit dark. Try turning on the flashlight."
*   **Action:** The user aligns the receipt from their supplier (e.g., a long thermal printout or a handwritten invoice) and taps the shutter.

## 7.2 Image Enhancement (Pre-Processing)
Raw photos of receipts are often skewed, shadowed, or crumpled. Before running OCR, the image undergoes local pre-processing using an embedded C++ or OpenCV lite library.
1.  **Grayscale Conversion:** Color is stripped to increase text contrast.
2.  **Adaptive Thresholding (Binarization):** The image is converted to pure black and white, eliminating background shadows and highlighting ink.
3.  **Perspective Correction:** If the receipt was photographed at an angle, the system detects the rectangular edges and warps the image to be flat. (If edge detection fails, it proceeds with the unwarped image).
4.  **Noise Reduction:** A slight Gaussian blur is applied to remove digital camera noise, preventing the OCR from reading artifacts as punctuation.

## 7.3 OCR and Text Detection
*   **Engine:** The pre-processed image is passed to the local ML Kit Text Recognition V2 model (or equivalent TFLite model).
*   **Execution:** The engine runs entirely on the device CPU/GPU. Note: This process blocks for 0.5 to 2.0 seconds depending on device hardware. A playful Lottie animation (e.g., a laser scanning paper) is displayed to mask this latency.
*   **Output:** The OCR engine returns a list of "TextBlocks," containing the raw string, bounding box coordinates (X, Y), and a confidence score.

## 7.4 Information Extraction & Parsing
Supplier receipts are highly unstructured and vary wildly between different distributors. SariSmart uses spatial analysis to extract semantic meaning.
*   **Line Grouping:** The algorithm sorts TextBlocks by their Y-coordinates to establish horizontal "lines" of text.
*   **Pattern Matching (Regex):** 
    *   It scans the lines for common price patterns: `\b\d+\.\d{2}\b` (e.g., "150.00").
    *   It scans for quantity patterns: `\b(\d+)\s*(pcs|bx|cs|x)\b` (e.g., "12 pcs", "5x").
*   **Spatial Association:** If a line reads `NESCAFE BLK  12  60.00`, the parser identifies "NESCAFE BLK" as the Product Description, "12" as the Quantity, and "60.00" as the Total Cost. It calculates the Unit Cost automatically (`60.00 / 12 = 5.00`).

## 7.5 Fuzzy Matching and Learned Aliases
This is the core intelligence of the module. Supplier receipts use terrible abbreviations (e.g., "COKE REG 8Z", "NESC 3IN1 ORIG").
1.  **Fuzzy Search:** The extracted product description is compared against the user's existing `inventory` table using a localized Levenshtein Distance or Trigram matching algorithm.
2.  **Scoring:** 
    *   *High Confidence (>85% match):* "Coke Regular 8oz" matches existing "Coca-Cola Regular 8oz". The system maps it automatically.
    *   *Low Confidence (50-84% match):* The system maps it but flags it for user review (highlighted in yellow).
    *   *No Match (<50% match):* Flagged as a "New Product" (highlighted in blue).
3.  **Alias Dictionary:** If the user manually corrects "CK REG 8Z" to "Coca-Cola 8oz", the system saves "CK REG 8Z" to the `product_aliases` table. The next time the user scans a receipt from that supplier, the match will be 100% confident.

## 7.6 Review and Correction Screen
The AI is a tool, not an autonomous agent. The user MUST review and confirm the parsed data.
*   **Visuals:** A split-screen or scrollable list.
    *   *Top:* A croppable thumbnail of the original receipt photo for reference.
    *   *Bottom:* A list of parsed items. 
*   **Item States:**
    *   *Green Check:* High confidence match. (e.g., "Nescafe - Qty: 12 - Cost: ₱5.00").
    *   *Yellow Warning:* Low confidence. User taps to open a dropdown of existing inventory items to link it to, or create new.
    *   *Blue "New":* New item detected. User must provide a Selling Price before confirming.
*   **Action:** The user can edit quantities, fix typo'd prices, or delete rows that are just receipt header text (e.g., "THANK YOU FOR SHOPPING").

## 7.7 Confirmation and Inventory Update
*   **Action:** User taps "Confirm & Update Inventory" (Primary button, sticky at the bottom).
*   **Database Transaction:**
    1.  The system begins an SQLite Transaction to ensure data integrity.
    2.  For matched items, it increments the `current_stock` by the parsed quantity.
    3.  It updates the `cost_price` to reflect the latest receipt (implementing a moving average or latest-cost approach).
    4.  It inserts "New" items into the `inventory` table.
    5.  It saves the receipt photo path and the total amount to the `purchases` table for expense tracking.
    6.  The SQLite Transaction commits.
*   **Feedback:** A success dialog appears: "Inventory Updated Successfully! Added 35 items."

## 7.8 Error Handling and Edge Cases
*   **Blurred Photos:** If the OCR engine returns very few characters or incredibly low confidence scores across the board, the app intercepts the flow before parsing. 
    *   *Dialog:* "The image looks a bit blurry, making it hard to read. Do you want to retake the photo?"
*   **Damaged/Faded Receipts:** If a receipt is torn or the thermal ink has faded, the system will parse what it can. The user will have to manually add the missing rows on the Review Screen by tapping "+ Add Missing Item".
*   **Different Receipt Layouts:** The algorithm is robust enough to handle "Description | Qty | Price" and "Description | Price | Qty" by prioritizing regex pattern matching over strict column positioning.
