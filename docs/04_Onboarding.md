# CHAPTER 4: ONBOARDING

This chapter provides a meticulous UI/UX breakdown of the First-Time User Experience (FTUE) and Onboarding flow. The primary goal of this onboarding is to establish trust, demonstrate the core value proposition (AI receipt scanning), and configure the application with minimal friction. 

## 4.1 Design Philosophy for Onboarding
The target demographic (sari-sari store owners) may not be highly tech-savvy. Therefore, the onboarding flow adheres to the following principles:
*   **One Concept Per Screen:** Avoid cognitive overload by asking for only one piece of information or granting one permission per screen.
*   **Visual Storytelling:** Use culturally relevant, localized illustrations (e.g., a hand holding a phone over a typical Philippine grocery receipt) rather than abstract corporate graphics.
*   **Generous Hit Targets:** Buttons must be large (minimum 48x48 dp), high-contrast, and placed at the bottom of the screen for easy one-handed reachability.

## 4.2 Screen 1: The Value Proposition Carousel
*   **Trigger:** Immediate upon opening the app for the very first time after installation.
*   **Visual Elements:**
    *   **Carousel Indicator:** A row of three small dots at the bottom of the screen indicating pagination.
    *   **Animation:** A smooth, 300ms ease-in-out slide transition between pages. Lottie animations are used for the main graphics to keep the app size small while providing delightful motion.
    *   **Skip Button:** A "Skip" text button in the top right corner. Tapping this jumps the user directly to the Permission Request Flow (Screen 2).
*   **Slide 1: No More Notebooks**
    *   *Illustration:* An animated notebook with crossed-out lines transforming into a neat, digital list on a smartphone.
    *   *Heading (H1):* "Ditch the Notebook"
    *   *Subtext (Body):* "Manage your sari-sari store inventory instantly without writing a single line."
    *   *Button:* "Next" (Primary color, bottom right).
*   **Slide 2: Scan to Restock**
    *   *Illustration:* An animation showing a camera lens focusing on a crumpled receipt, with products popping out of the receipt into virtual boxes.
    *   *Heading (H1):* "Just Scan Your Receipt"
    *   *Subtext (Body):* "Our smart AI reads your supplier receipts and updates your stock automatically."
    *   *Button:* "Next" (Primary color, bottom right).
*   **Slide 3: Works Without Internet**
    *   *Illustration:* A Wi-Fi symbol with a slash through it, alongside a thriving digital storefront.
    *   *Heading (H1):* "100% Offline First"
    *   *Subtext (Body):* "No load? No problem. SariSmart works flawlessly even without an internet connection."
    *   *Button:* "Get Started" (Full-width, primary color, bottom center).

## 4.3 Screen 2: Mandatory Permissions Request
*   **Trigger:** Tapping "Get Started" on the carousel, or "Skip".
*   **Visual Elements:**
    *   *Illustration:* A friendly robot character or mascot holding a camera.
    *   *Heading (H1):* "We need your permission"
    *   *Subtext (Body):* "To scan receipts, SariSmart needs access to your camera. We process everything on your phone—your data stays private."
    *   *Button:* "Allow Camera Access" (Full-width, primary color).
*   **Interaction:**
    *   User taps the button.
    *   The native Android permission dialog appears over the app UI: "Allow SariSmart to take pictures and record video?"
    *   *Validation/Edge Case:* If the user selects "Deny," the app remains on this screen but changes the subtext to: "Camera access is required for our core features. You can grant it later in your phone settings, but you won't be able to scan receipts." The button changes to "Continue without Camera" (Secondary style).

## 4.4 Screen 3: Store Configuration
*   **Trigger:** Completing the permission step.
*   **Visual Elements:**
    *   *Header:* "Set up your store"
    *   *Input Field 1:* "Store Name" (Placeholder: e.g., "Aling Nena's Sari-Sari"). This is a mandatory text field. Max length: 50 characters. Keyboard type: Default text with auto-capitalization of words.
    *   *Input Field 2:* "Your Name (Optional)" (Placeholder: e.g., "Nena").
    *   *Button:* "Next" (Disabled state until 'Store Name' has at least 3 characters. Once valid, it transitions to active primary color).
*   **Validation:** 
    *   If the user tries to proceed with an empty Store Name, the field border turns red and inline error text appears: "Store Name is required."

## 4.5 Screen 4: Localization & Currency
*   **Trigger:** Tapping "Next" on the Store Configuration screen.
*   **Visual Elements:**
    *   *Header:* "Regional Settings"
    *   *Dropdown 1:* "Language" (Options: English, Tagalog, Bisaya). Defaults to English.
    *   *Dropdown 2:* "Currency" (Options: PHP (₱), USD ($)). Defaults to PHP based on device locale detection.
    *   *Button:* "Finish Setup" (Full-width, primary color).
*   **Database Update:** Upon tapping "Finish Setup", the application writes the `store_name`, `owner_name`, `language_code`, and `currency_code` to the local SQLite `settings` table. 

## 4.6 Screen 5: Success & Handoff
*   **Trigger:** Successful database write from Screen 4.
*   **Visual Elements:**
    *   *Animation:* A brief (1.5s) Lottie animation of a storefront opening its doors or a celebratory checkmark.
    *   *Header:* "You're all set!"
    *   *Subtext:* "Welcome to SariSmart, [Owner Name]. Let's make managing your store easier."
    *   *Transition:* Automatically fades out after 2 seconds and routes the user to the Main Dashboard (Empty State).

## 4.7 Edge Cases & Offline Behavior
*   **Offline Behavior:** The entire onboarding flow is entirely hardcoded and local. No network requests are made. The user can install the app from an APK sent via Bluetooth and onboard completely offline.
*   **App Termination During Onboarding:** If the user kills the app during onboarding, the application stores a `has_completed_onboarding = false` flag in SharedPreferences. Upon relaunch, the app will return the user to the exact onboarding screen they left off on, preserving any entered data (e.g., Store Name) in local state.
