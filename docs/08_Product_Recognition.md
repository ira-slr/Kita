# CHAPTER 8: PRODUCT RECOGNITION

While the Receipt Scanner handles bulk data entry from suppliers, SariSmart also incorporates visual Product Recognition. This feature allows users to scan the physical products themselves—useful when adding single items bought without a receipt, or when performing rapid price checks or POS actions.

## 8.1 The Core Concept
Instead of typing a product name to search the inventory, or using a hardware barcode scanner (which requires the product to have a pristine barcode), the user points their smartphone camera at the packaging of the item. The application visually recognizes the product and brings up its digital record.

## 8.2 The Capture Workflow
*   **Trigger:** Tapping a designated "Scan Item" icon located on the Dashboard Quick Actions grid or within the POS search bar.
*   **Screen: Visual Search Viewfinder**
    *   **Visuals:** A full-screen camera feed. Unlike the receipt scanner, the guiding overlay is a dynamic, pulsating square centered on the screen.
    *   **Text:** "Point camera at product packaging."
    *   **Action:** The user aims the camera. A shutter button is available, but the system also runs in a continuous scanning mode (evaluating frames every 500ms).

## 8.3 Offline Image Matching
Because SariSmart is offline-first, it does not rely on massive cloud-based image recognition APIs (like Google Lens). Instead, it uses a localized, lightweight approach.
*   **Feature Extraction:** The app uses a highly optimized MobileNet (or similar lightweight CNN) TFLite model. When a frame is captured, the model extracts an "image embedding"—a compact mathematical representation (e.g., an array of 256 floats) of the visual features of the product (colors, logos, text layout).
*   **Database Search:** This embedding is compared against the embeddings stored in the local SQLite database for existing inventory items. The system calculates the Euclidean distance or Cosine similarity to find the closest match.
*   **Speed:** Because it only compares against the store's local database (usually 200-1000 items), the matching process is incredibly fast, often resolving in under 200 milliseconds on modern mid-range Android devices.

## 8.4 User Confirmation and Interaction
*   **Result Presentation:** Once a match crosses the confidence threshold (e.g., >80% similarity).
*   **Visuals:** A bottom sheet slides up quickly over the camera feed.
    *   **Content:** The matched product's image, name, current stock, and selling price.
    *   **Actions Available:**
        1.  **Add to Cart (POS mode):** Instantly adds 1 unit to the current transaction.
        2.  **Edit Product (Inventory mode):** Opens the product details for quick price adjustments.
*   **No Match Found:** If no existing inventory item matches the visual signature, the bottom sheet displays: "Unknown Product."
    *   **Action:** "Add to Inventory." The app automatically passes the captured photo to the manual "Add Product" form, saving the user from having to take the picture again.

## 8.5 Active Learning and Photo Management
The accuracy of the offline product recognition is directly tied to the quality of the reference photos in the user's database.
*   **Initial Training:** When a user first adds a product manually and takes a photo, that photo becomes the primary reference embedding.
*   **Multiple Perspectives:** Sari-sari products can be viewed from different angles (e.g., a bag of chips lying flat vs. standing up). The product details screen allows adding up to 3 photos. Each photo generates a separate embedding, dramatically increasing recognition robustness.
*   **Packaging Updates:** FMCG (Fast-Moving Consumer Goods) brands frequently update their packaging. 
    *   If a user scans a "new look" item and it fails to recognize, they will manually search for it and tap "Update Photo."
    *   The system replaces the old embedding with the new one, immediately adapting to the packaging change without requiring an app update.

## 8.6 Limitations and Edge Cases
*   **Highly Similar Packaging:** Different flavors of the same brand (e.g., Piattos Cheese vs. Piattos Sour Cream) have very similar visual signatures, differing only in color. The local ML model is tuned to heavily weight color histograms to differentiate these variants.
*   **Lighting and Glare:** Shiny plastic packaging (sachets) can reflect flash or sunlight, obliterating visual features. The continuous scanning mode helps mitigate this by analyzing multiple frames at different slight angles as the user naturally moves their hand.
*   **Database Size Constraints:** To keep the app lightweight, image embeddings are stored as BLOBs or serialized strings in SQLite. For a store with 1,000 items (3 embeddings each), this adds a negligible amount of storage (a few megabytes), ensuring the offline architecture remains highly performant.
