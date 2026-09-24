# TruDataa iOS Implementation & App Store Deployment Guide

This guide provides an end-to-end technical roadmap and ready-to-use specifications for permissions, background location tracking, notifications, media handling, and App Store compliance in the TruDataa iOS project.

---

## 1. Xcode Project Capabilities Setup

Open your iOS project in Xcode (`Truedata.xcworkspace`), select the **Truedata** target under **Signing & Capabilities**, and confirm:

### A. Background Modes
Click **+ Capability** → Select **Background Modes** → Check:
- [x] **Location updates** (Required for shift tracking)
- [x] **Remote notifications** (Required for Firebase / APNs push alerts)
- [x] **Background fetch** (Optional for data sync)

### B. Push Notifications
Click **+ Capability** → Select **Push Notifications**.

---

## 2. `Info.plist` Permissions Configuration

The project build settings (`INFOPLIST_KEY_*`) are configured with compliant purpose strings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Location — While Using the App only (App Store 2.5.4: no background location) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>TruDataa needs your location while using the app to record attendance punch and verify client shop visits.</string>

    <!-- Camera Permission (Shop visits & Payment receipts) -->
    <key>NSCameraUsageDescription</key>
    <string>TruDataa requires camera access to capture shop visit verification photos and scan payment cheques/receipts.</string>

    <!-- Microphone & Speech Recognition (Voice search & Order notes) -->
    <key>NSMicrophoneUsageDescription</key>
    <string>TruDataa requires microphone access to record voice notes and search products by voice.</string>

    <key>NSSpeechRecognitionUsageDescription</key>
    <string>TruDataa requires speech recognition to transcribe voice input for quick product search and order remarks.</string>

    <!-- Photo Library (Receipt / Document upload) -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>TruDataa requires access to your photo library to select and upload payment receipts and business documents.</string>

    <!-- Background Modes — no `location` on App Store build -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>processing</string>
        <string>remote-notification</string>
    </array>
</dict>
</plist>
```

---

## 3. Location usage (`LocationManager.swift`)

App Store build uses **When In Use / one-shot** location only (attendance, shop visits, order actions). Continuous shift tracking and `allowsBackgroundLocationUpdates` are disabled in [`LocationManager.swift`](Truedata/Core/LocationManager.swift). Company-only Custom App builds can re-enable background tracking later if needed.

---

## 4. App Store Review Checklist (Zero Rejection Guidelines)

Before submitting your app to App Store Connect, ensure these 5 requirements are met:

### 1. Location (Guideline 2.5.4 + 5.1.1)
> **App Store build**: Background location mode is **disabled**. Location is requested **While Using the App** only for attendance punch and shop-visit verification (foreground / one-shot). Continuous shift route tracking is not used on the public App Store build.
>
> Pre-permission CTA uses **Continue** (never “Grant permission” / “Not Now”); denied state offers **Open Settings**.

### 2. Account Deletion (Guideline 5.1.1(v))
> **Not applicable for self-serve delete**: TruDataa is an employer-provisioned admin / workforce app. Staff accounts are created by the company — end users cannot self-register in the app. In-app **Delete Account** is intentionally omitted. Document account-removal requests via Privacy Policy / support (employer or `spicemonktech@gmail.com`). Mention this in App Review Notes.

### 3. App Review Information (Demo Credentials)
In App Store Connect under **App Review Information**:
- Provide valid **Username** and **Password** for a test employee account.
- In the **Notes** section, write:
  > *"TruDataa is a workforce management and field sales application. Location is used only while the app is open to record attendance punch and verify client shop visits — not for continuous background employee tracking. Accounts are provisioned by the employer; end users cannot self-register, so in-app account deletion is not offered."*

### 4. App Privacy Details (Nutrition Labels)
Under App Store Connect -> **App Privacy**:
- **Location** (Precise, while using the app) -> Used for *App Functionality* & linked to user. Do **not** claim continuous background location collection.
- **Photos/Audio/Camera** -> Used for *App Functionality*.
- **Contact Info** (Phone/Name) -> Used for *Account Management*.
