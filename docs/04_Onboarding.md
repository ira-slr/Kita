# CHAPTER 4: ONBOARDING

This chapter provides a meticulous UI/UX breakdown of the First-Time User Experience (FTUE) and Onboarding flow. The primary goal of this onboarding is to establish trust, demonstrate the core value proposition (AI receipt scanning), and configure the application with minimal friction. 

## 4.1 Design Philosophy for Onboarding
The target demographic (sari-sari store owners) may not be highly tech-savvy. Therefore, the onboarding flow adheres to the following principles:
*   **One Concept Per Screen:** Avoid cognitive overload by asking for only one piece of information or granting one permission per screen.
*   **Visual Storytelling:** Use culturally relevant, localized illustrations (e.g., a hand holding a phone over a typical Philippine grocery receipt) rather than abstract corporate graphics.
*   **Generous Hit Targets:** Buttons must be large (minimum 48x48 dp), high-contrast, and placed at the bottom of the screen for easy one-handed reachability.

## 4.2 First-Open Narrative & Brand Story
When **Nanay** (the store owner) opens **Kita** for the very first time on her phone, she is greeted by a warm, friendly, and non-intimidating welcome experience. Instead of complex technical jargon or accounting terms, **Kita** immediately communicates its core purpose: **bringing clarity to her hard work**.

```
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │                     Welcome to KITA 🛒                       │
  │             "Kita ang Benta, Kita ang Kita"                 │
  │                                                             │
  │    [Slide 1]            [Slide 2]            [Slide 3]      │
  │   Ditch Blind          Real Profit         100% Free &      │
  │    Listing             Visibility           Offline         │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘
```

## 4.3 Screen 1: The Value Proposition Carousel
*   **Trigger:** Immediate upon opening the app for the very first time after installation.
*   **Slide 1: Huwag nang Manghula sa Notebook (Ditch Blind Listing)**
    *   *Illustration:* A worn-out paper ledger transforming into a clean, digital product list on a mobile screen.
    *   *Heading (H1):* "Huwag nang manghula sa notebook"
    *   *Subtext (Body):* "Wala nang nawawalang listahan. I-manage ang paninda at panukli nang mabilis at sigurado."
    *   *Button:* "Next" (Primary color).
*   **Slide 2: Kitang-Kita ang Benta at Kita (Real Profit Visibility)**
    *   *Illustration:* A glowing chart showing daily sales and green profit cards.
    *   *Heading (H1):* "Kitang-kita ang totoong kita"
    *   *Subtext (Body):* "Alamin agad ang benta at tubo araw-araw nang walang kumplikadong accounting."
    *   *Button:* "Next" (Primary color).
*   **Slide 3: Libre at Gana Kahit Walang Load (100% Free & Offline)**
    *   *Illustration:* A Wi-Fi icon with a checkmark and a ₱0 free badge.
    *   *Heading (H1):* "100% Libre at Offline First"
    *   *Subtext (Body):* "Walang monthly fee at gagana kahit walang internet data. Data mo ay ligtas sa iyong telepono."
    *   *Button:* "Magsimula Na!" (Get Started - Primary full-width button).

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
