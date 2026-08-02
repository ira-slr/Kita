# CHAPTER 15: DATABASE DESIGN

Because SariSmart is an offline-first application, the local SQLite database is the most critical technical component. It must be highly normalized to prevent data anomalies, yet optimized with indexes to ensure complex analytical queries (like the Monthly Report) execute in milliseconds without blocking the UI thread.

## 15.1 Entity Relationship (ER) Overview
The database revolves around two core hubs: `inventory` (the master list of products) and `transactions` (the record of sales).

## 15.2 Core Tables and Data Dictionary

### Table: `settings`
Stores singleton configuration data.
*   `id` (INTEGER, PRIMARY KEY) - Always 1.
*   `store_name` (TEXT)
*   `owner_name` (TEXT, NULLABLE)
*   `currency_code` (TEXT) - e.g., 'PHP'
*   `language_code` (TEXT) - e.g., 'en' or 'tl'
*   `is_dark_mode` (BOOLEAN)
*   `last_backup_timestamp` (DATETIME, NULLABLE)

### Table: `categories`
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `name` (TEXT, UNIQUE) - e.g., 'Beverages', 'Canned Goods'
*   `color_hex` (TEXT, NULLABLE) - For UI styling.

### Table: `suppliers`
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `name` (TEXT, UNIQUE) - e.g., 'Puregold', 'Coca-Cola Distributor'
*   `contact_info` (TEXT, NULLABLE)

### Table: `inventory` (The Master Product Catalog)
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `sku` (TEXT, UNIQUE, NULLABLE) - For optional barcode support.
*   `product_name` (TEXT, UNIQUE) - e.g., 'Nescafe 3-in-1 Original'
*   `category_id` (INTEGER, FOREIGN KEY references `categories(id)`)
*   `supplier_id` (INTEGER, FOREIGN KEY references `suppliers(id)`)
*   `cost_price` (REAL) - The current average or latest purchase price.
*   `selling_price` (REAL) - The current retail price.
*   `current_stock` (REAL) - Real to allow fractional quantities (e.g., 1.5 kg of rice).
*   `minimum_threshold` (REAL) - Trigger for low stock alerts (Default: 5).
*   `is_archived` (BOOLEAN) - Soft delete flag (Default: 0).
*   `created_at` (DATETIME, DEFAULT CURRENT_TIMESTAMP)
*   `updated_at` (DATETIME, DEFAULT CURRENT_TIMESTAMP)
*   *Indexes:* `idx_inventory_product_name`, `idx_inventory_category_id`.

### Table: `product_images`
Allows multiple images per product.
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `product_id` (INTEGER, FOREIGN KEY references `inventory(id)`)
*   `file_path` (TEXT) - Relative path to local storage (e.g., '/images/prod_123.webp').
*   `is_primary` (BOOLEAN) - Defines the main image for the POS.
*   `embedding` (BLOB, NULLABLE) - Serialized 256-float array for visual recognition.

### Table: `product_aliases` (The ML Translation Dictionary)
Stores how suppliers refer to products vs. the actual product name.
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `product_id` (INTEGER, FOREIGN KEY references `inventory(id)`)
*   `supplier_id` (INTEGER, FOREIGN KEY references `suppliers(id)`, NULLABLE)
*   `alias_text` (TEXT) - e.g., 'NSCFE ORIG 3N1'
*   *Indexes:* `idx_alias_text` (For rapid exact matching before falling back to fuzzy matching).

### Table: `purchases` (Supplier Receipts / Restocks)
Records bulk additions to inventory, acting as the primary expense ledger.
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `supplier_id` (INTEGER, FOREIGN KEY references `suppliers(id)`, NULLABLE)
*   `receipt_image_path` (TEXT, NULLABLE) - Path to the original scanned receipt photo.
*   `total_amount` (REAL)
*   `purchase_date` (DATETIME, DEFAULT CURRENT_TIMESTAMP)

### Table: `purchase_line_items`
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `purchase_id` (INTEGER, FOREIGN KEY references `purchases(id)`)
*   `product_id` (INTEGER, FOREIGN KEY references `inventory(id)`)
*   `quantity_added` (REAL)
*   `unit_cost` (REAL) - The price paid at this specific time.

### Table: `transactions` (POS Sales)
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `total_amount` (REAL) - The final gross revenue for the receipt.
*   `cash_tendered` (REAL)
*   `change_given` (REAL)
*   `global_discount` (REAL)
*   `status` (TEXT) - 'COMPLETED', 'VOIDED', 'HELD'.
*   `created_at` (DATETIME, DEFAULT CURRENT_TIMESTAMP)
*   *Indexes:* `idx_transactions_created_at`, `idx_transactions_status`. (Critical for fast daily/monthly reports).

### Table: `transaction_line_items`
Records the snapshot of the sale. Crucially, it records the `historical_cost_price` to ensure profit reports remain accurate even if the product's cost price changes months later.
*   `id` (INTEGER, PRIMARY KEY AUTOINCREMENT)
*   `transaction_id` (INTEGER, FOREIGN KEY references `transactions(id)`)
*   `product_id` (INTEGER, FOREIGN KEY references `inventory(id)`)
*   `quantity` (REAL)
*   `unit_selling_price` (REAL) - The price it was sold for.
*   `historical_cost_price` (REAL) - The cost price at the exact moment of sale.
*   `item_discount` (REAL)
*   *Indexes:* `idx_tli_transaction_id`, `idx_tli_product_id`.

## 15.3 Database Normalization and Optimization
*   **Normalization:** The database adheres strictly to 3rd Normal Form (3NF). There is no redundant data (e.g., product names are not duplicated in the line item tables, only the `product_id`).
*   **Write-Ahead Logging (WAL):** SQLite is configured to use WAL mode (`PRAGMA journal_mode=WAL;`). This allows concurrent reads and writes, meaning a background ML process updating embeddings will never block the user from rapidly tapping items in the POS.
*   **Foreign Key Constraints:** Enforced strictly (`PRAGMA foreign_keys = ON;`). Attempting to delete an `inventory` item that is referenced in `transaction_line_items` will throw an SQL constraint error, forcing the application logic to use the `is_archived` soft-delete flag instead, preserving historical accounting integrity.
