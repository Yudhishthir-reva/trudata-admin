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
    <!-- 1. Location Permissions (Mandatory for Attendance & Shift Tracking) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>TruDataa requires your location while using the app to record attendance, verify client shop visits, and plot field sales routes.</string>

    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>TruDataa requires continuous location access in the background during active work shifts to track field attendance and calculate travel allowance.</string>

    <key>NSLocationAlwaysUsageDescription</key>
    <string>TruDataa requires background location access during your work hours to track sales routes and shop visits accurately.</string>

    <!-- 2. Camera Permission (Shop visits & Payment receipts) -->
    <key>NSCameraUsageDescription</key>
    <string>TruDataa requires camera access to capture shop visit verification photos and scan payment cheques/receipts.</string>

    <!-- 3. Microphone & Speech Recognition (Voice search & Order notes) -->
    <key>NSMicrophoneUsageDescription</key>
    <string>TruDataa requires microphone access to record voice notes and search products by voice.</string>

    <key>NSSpeechRecognitionUsageDescription</key>
    <string>TruDataa requires speech recognition to transcribe voice input for quick product search and order remarks.</string>

    <!-- 4. Photo Library (Receipt / Document upload) -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>TruDataa requires access to your photo library to select and upload payment receipts and business documents.</string>

    <!-- 5. Background Modes Array -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>location</string>
        <string>remote-notification</string>
    </array>
</dict>
</plist>
```

---

## 3. Background Location Tracking Architecture (`LocationManager.swift`)

Background tracking is implemented in [`LocationManager.swift`](file:///Users/reva/Documents/GitHub/trudata-admin/Truedata/Core/LocationManager.swift).

- **Accuracy**: `kCLLocationAccuracyHundredMeters` (Optimized for battery & sales tracking)
- **Distance Filter**: `30` meters
- **Activity Type**: `.automotiveNavigation`
- **Background Mode**: `allowsBackgroundLocationUpdates = true`, `showsBackgroundLocationIndicator = true`
- **Stale Point Filter**: Coordinates older than 15s are automatically discarded
- **Shift Lifecycle**: Automatically activated when user Punches In, and automatically stopped when user Punches Out or Logs Out.

---

## 4. App Store Review Checklist (Zero Rejection Guidelines)

Before submitting your app to App Store Connect, ensure these 5 requirements are met:

### 1. Mandatory Shift End Logic (Guideline 2.5.4)
> **Compliance Confirmed**: GPS background tracking stops immediately upon:
> - User punching out in `MarkAttendanceViewModel`
> - User logging out in `MyProfileViewModel`

### 2. Account Deletion (Guideline 5.1.1(v))
> **Not applicable for self-serve delete**: TruDataa is an employer-provisioned admin / workforce app. Staff accounts are created by the company — end users cannot self-register in the app. In-app **Delete Account** is intentionally omitted. Document account-removal requests via Privacy Policy / support (employer or `spicemonktech@gmail.com`). Mention this in App Review Notes.

### 3. App Store Metadata Battery Disclaimer
Copy and paste this sentence at the bottom of your **App Description** in App Store Connect:
> *"Continued use of GPS running in the background can dramatically decrease battery life."*

### 4. App Review Information (Demo Credentials)
In App Store Connect under **App Review Information**:
- Provide valid **Username** and **Password** for a test employee account.
- In the **Notes** section, write:
  > *"TruDataa is a workforce management and field sales tracking application. Location tracking in the background is only activated after the employee logs in and marks attendance (Shift Start) to calculate travel reimbursement and verify client visits. Tracking stops immediately upon Punch-out. Accounts are provisioned by the employer; end users cannot self-register, so in-app account deletion is not offered."*

### 5. App Privacy Details (Nutrition Labels)
Under App Store Connect -> **App Privacy**:
- **Location** (Coarse & Precise) -> Used for *App Functionality* & linked to user.
- **Photos/Audio/Camera** -> Used for *App Functionality*.
- **Contact Info** (Phone/Name) -> Used for *Account Management*.
