# CHAPTER 11: AI FEATURES

SariSmart leverages Artificial Intelligence not as a gimmick, but as a practical, invisible assistant that eliminates friction for non-technical users. Crucially, all core AI features operate completely offline, relying on on-device processing to ensure privacy, speed, and reliability. 

## 11.1 The Offline AI Architecture
To achieve offline intelligence, SariSmart bundles pre-trained, lightweight Machine Learning models directly into the application (using TensorFlow Lite). 
*   **The Models:** 
    *   *OCR Model:* Extracts raw text from images (ML Kit/TFLite).
    *   *Vision Embedding Model:* A MobileNet variant that converts images into 256-dimensional numerical vectors (embeddings) for visual product recognition.
    *   *Time-Series Prediction (Optional/Heuristic):* A lightweight statistical model (e.g., ARIMA or simple moving average) used for sales forecasting, often replaced by fast SQLite aggregations for extreme efficiency.

## 11.2 Fuzzy Matching & Alias Learning (The Translation Engine)
Supplier receipts are notoriously cryptic. The AI's job is to translate supplier jargon into the store owner's catalog.
*   **Fuzzy Matching Process:** When OCR extracts "CK MSMO 290", the AI calculates the Levenshtein distance (edit distance) against all items in the `inventory` table. If "Coca-Cola Mismo 290ml" yields the highest score (but below 100%), it suggests this match to the user.
*   **Alias Learning (Active Learning):**
    *   If the user confirms that "CK MSMO 290" is indeed "Coca-Cola Mismo 290ml," the system records this exact mapping in the `product_aliases` database table.
    *   *Result:* The AI "learns." The next time a receipt from that same supplier is scanned, the match is instantaneous and 100% confident, requiring no user intervention.

## 11.3 Duplicate Detection (Data Integrity)
When a user manually adds a product, they might type "Marlboro Red" when "Marlboro Reds" already exists.
*   **Process:** Before the database `INSERT` commits, the system runs a fuzzy text comparison and a visual embedding comparison (if a photo is provided).
*   **Action:** If a high-confidence duplicate is found, the UI intercepts the save action: "It looks like you already have this item in your inventory. Did you want to update the stock instead?"

## 11.4 Restock & Sales Prediction (Inventory Intelligence)
Instead of forcing the user to analyze complex charts to figure out what to buy, the AI pushes actionable insights to the Dashboard.
*   **Sales Velocity Calculation:** The system constantly runs background SQLite queries to determine the "Burn Rate" of products (e.g., selling 5 units per day).
*   **Restock Prediction:** By dividing the `current_stock` by the `burn_rate`, the AI predicts the exact date an item will run out.
    *   *Insight Generated:* "💡 At your current sales rate, you will run out of Piattos Cheese by Thursday. Consider adding it to your shopping list."
*   **Seasonal Demand (Heuristics):** The system correlates sales spikes with the calendar.
    *   *Insight Generated:* "🌧️ It's June (Rainy Season). Last year, your sales of Instant Noodles increased by 40%. Consider stocking up early."

## 11.5 Recommendations and Supplier Suggestions
*   **Pricing Recommendations:** The AI analyzes the `cost_price` fluctuations. If the supplier increases the cost of Coffee from ₱5.00 to ₱6.00, but the user's `selling_price` is still ₱6.00 (0 profit), the AI triggers an immediate alert:
    *   *Insight Generated:* "⚠️ Your cost for Nescafe increased. To maintain your usual 20% profit, you should increase your selling price to ₱7.50."
*   **Supplier Optimization (If multiple suppliers are used):** If the user buys the exact same item from two different distributors (tracked via the `purchases` table), the AI identifies the cheapest source.
    *   *Insight Generated:* "💡 You usually buy Sugar from Supplier A for ₱50/kilo, but Supplier B recently sold it to you for ₱45/kilo."

## 11.6 Optional Cloud Insights
While the app is strictly offline-first, users who opt-in to cloud backups can receive "Macro Insights" processed on secure servers.
*   **Anonymized Regional Trends:** If many opted-in SariSmart users in a specific province are suddenly selling high volumes of a new energy drink, the cloud AI can push a suggestion to other local stores:
    *   *Cloud Insight:* "📈 'Sting Energy' is trending in your area. Consider adding it to your inventory." (Note: This is strictly opt-in and relies on heavily anonymized, aggregated data).
