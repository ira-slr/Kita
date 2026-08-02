# CHAPTER 12: NOTIFICATIONS

Notifications in SariSmart are designed to be helpful, strictly relevant, and never spammy. Because the app operates offline, the vast majority of these notifications are generated locally by the device's operating system based on triggers evaluated by a background worker (e.g., Android WorkManager).

## 12.1 Local Notification Architecture
*   **Background Worker:** A lightweight background task runs periodically (e.g., every 4 hours, or immediately after the app is closed) to evaluate the state of the local SQLite database against predefined thresholds.
*   **Delivery:** If a threshold is met, the app uses the native OS notification system to deliver the alert.
*   **Deep Linking:** Tapping a notification opens the SariSmart app and routes the user directly to the relevant screen (e.g., tapping a low stock alert opens that specific product's details page).

## 12.2 Critical Alerts
These are high-priority notifications that directly impact the store's ability to operate or make money.
*   **Low Stock Alert:** 
    *   *Trigger:* `current_stock` falls below the `minimum_threshold` for an item.
    *   *Message:* "⚠️ Low Stock: You only have 2 [Product Name] left. Tap to add to your shopping list."
*   **Expiring Items (Perishables):**
    *   *Trigger:* The `expiration_date` of an item is approaching (default: 7 days prior).
    *   *Message:* "⏰ Expiration Warning: Your [Product Name] will expire on [Date]. Consider putting it on sale."
*   **Negative Profit Warning:**
    *   *Trigger:* A receipt scan updates a cost price to be higher than the current selling price.
    *   *Message:* "🚨 Action Required: You are selling [Product Name] at a loss based on your recent receipt. Tap to adjust prices."

## 12.3 Operational Reminders
These notifications help the user maintain good data hygiene and operational rhythm.
*   **Backup Reminder:**
    *   *Trigger:* The local database has grown significantly, and no cloud backup or local export has occurred in the last 7 days.
    *   *Message:* "💾 Secure your data: It's been a week since your last backup. Tap here to save a copy of your inventory and sales."
*   **Restock Reminder (AI Generated):**
    *   *Trigger:* The AI predicts an item will run out in 48 hours based on sales velocity.
    *   *Message:* "💡 Prediction: You might run out of [Product Name] by tomorrow. Check your stock."

## 12.4 Milestones and Motivation
Sari-sari store owners work long, grueling hours. Positive reinforcement helps drive user retention.
*   **Sales Milestone:**
    *   *Trigger:* The daily sales total crosses a user-defined threshold or breaks a historical record.
    *   *Message:* "🎉 Congratulations! You just broke your daily sales record (₱[Amount]). Great job today!"
*   **Anniversary:**
    *   *Trigger:* 1 year since the app was installed.
    *   *Message:* "🎂 Happy Anniversary! You've successfully managed your store with SariSmart for a whole year."

## 12.5 Notification Settings & Control
Store owners must have absolute control over what interrupts their day.
*   **Granular Toggles:** In the Settings module, users can independently toggle on/off:
    *   Low Stock Alerts
    *   Expiration Warnings
    *   AI Predictions
    *   Milestone Celebrations
*   **Quiet Hours (Do Not Disturb):** Users can define a window (e.g., 10:00 PM to 6:00 AM) where the app is forbidden from triggering local push notifications, ensuring they are not woken up by a background inventory calculation.
