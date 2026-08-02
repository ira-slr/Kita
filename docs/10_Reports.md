# CHAPTER 10: REPORTS AND ANALYTICS

The Reports module transforms raw transaction and inventory data into actionable business intelligence. For a sari-sari store owner, understanding actual profit versus gross revenue is often the most transformative benefit of adopting a digital system. All reports in SariSmart are generated locally on the device using efficient SQL queries, requiring no cloud processing.

## 10.1 Reporting Architecture and UI
*   **Navigation:** The Reports tab is accessed via the bottom navigation bar.
*   **Time Filters (Global):** At the very top of the screen, a prominent toggle or dropdown allows the user to filter all displayed data by: 
    *   Today
    *   Yesterday
    *   This Week
    *   This Month
    *   This Year
    *   Custom Date Range (opens a native date picker).
*   **Visual Presentation:** Data is presented using native Flutter charting libraries (e.g., `fl_chart`), utilizing smooth animations when data updates. Complex accounting jargon is avoided; labels are plain and understandable (e.g., "Money In" instead of "Gross Revenue", "Actual Earnings" instead of "Net Profit").

## 10.2 Core Financial Metrics (The Headline Numbers)
Located directly below the time filter, three large summary cards display the vital health of the business for the selected period:
1.  **Total Sales (Gross Revenue):** The sum of all completed transactions.
    *   *SQL Logic:* `SUM(total_amount)` from `transactions` where status='COMPLETED'.
2.  **Total Expenses (Cost of Goods Sold - COGS):** The total cost of the items that were sold.
    *   *SQL Logic:* `SUM(quantity * historical_cost_price)` from `transaction_line_items`. (Note: The system must snapshot the cost price at the time of sale, rather than referencing the current cost price, to maintain historical accuracy).
3.  **Net Profit:** The actual money earned.
    *   *Calculation:* Total Sales - Total Expenses.
    *   *Visuals:* Highlighted in green if positive. A small trend indicator shows the percentage increase/decrease compared to the previous equivalent period.

## 10.3 Sales Trends (Line/Bar Charts)
*   **Visuals:** A dynamic chart showing sales over time.
*   **Logic based on Time Filter:**
    *   *If 'Today':* Shows a bar chart broken down by Hour (revealing peak hours).
    *   *If 'This Week':* Shows a line chart broken down by Day of the Week.
    *   *If 'This Month':* Shows a line chart broken down by Week or Day.
*   **Interaction:** The user can tap and hold on a specific data point (e.g., Tuesday) to see a tooltip with the exact sales figure for that specific increment.

## 10.4 Product Performance Analytics
*   **Best Sellers (By Volume):** A ranked list (top 5 or 10) of items that sold the highest quantity. Useful for knowing what to always keep in stock.
*   **Top Earners (By Profit):** A ranked list of items that generated the highest total net profit. (e.g., Candy might sell high volume, but a bottle of cooking oil might generate more actual profit).
*   **Worst Sellers (Dead Stock):** Items that have not sold a single unit in the longest amount of time (e.g., > 30 days). 
    *   *Actionable Insight:* The UI suggests: "Consider lowering the price of these items to clear shelf space."

## 10.5 Inventory Value Report
This report provides a snapshot of the assets currently sitting on the store's shelves.
*   **Total Inventory Value (At Cost):** The total amount of money the store owner has tied up in physical goods. 
    *   *SQL Logic:* `SUM(current_stock * cost_price)` across all active inventory.
*   **Potential Retail Value:** The total amount of money those goods would generate if all were sold at their current selling prices.
*   **Projected Profit:** The difference between Retail Value and Cost Value.

## 10.6 Category Breakdown
*   **Visuals:** A Donut Chart or Pie Chart.
*   **Content:** Visualizes sales distribution across different categories (e.g., 40% Drinks, 30% Snacks, 20% Canned Goods, 10% Others).
*   **Interaction:** Tapping a slice of the pie filters the "Best Sellers" list below it to only show items within that category.

## 10.7 Export and Sharing
Recognizing that store owners may need to share reports with partners, spouses, or micro-finance institutions, SariSmart provides robust export capabilities.
*   **Trigger:** An "Export" icon (typically a share symbol or a download arrow) located in the top App Bar of the Reports screen.
*   **Export Formats:**
    1.  **Export to PDF:** Generates a clean, branded PDF document containing the summary numbers, charts, and top-selling tables. It uses a local PDF generation library (e.g., `pdf` package in Flutter).
    2.  **Export to Excel (CSV):** Generates raw data files for advanced users. It allows exporting the raw transaction logs or the aggregated daily summaries.
*   **Sharing:** Once the file is generated locally, the native Android Share Sheet is invoked, allowing the user to instantly send the PDF via Messenger, Viber, WhatsApp, Email, or Print via a Bluetooth/Wi-Fi printer.

## 10.8 Performance Considerations for Reporting
*   **Aggregated Tables:** For stores that have been operating for years and have hundreds of thousands of transactions, running complex `JOIN` and `SUM` queries on the fly can cause UI stuttering.
*   **Optimization Strategy:** SariSmart implements an internal "Rollup" architecture. Every night (e.g., at 2:00 AM) or upon the first launch of a new day, the system runs a background worker that aggregates the previous day's granular transactions into a single row in a `daily_summary_analytics` table. Monthly and Annual reports query this summary table rather than scanning millions of individual line items, guaranteeing instant report generation regardless of the database size.
