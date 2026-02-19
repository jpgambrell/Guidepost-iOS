# Share Extension Setup Guide

This guide walks you through the final manual steps to configure the Guidepost Share Extension in Xcode.

## Overview

The Share Extension allows users to share images from the Photos app (or any other app) directly to Guidepost for upload and analysis. All code files have been created - you just need to configure the Xcode project.

## Manual Xcode Configuration Steps

### 1. Add Share Extension Target to Xcode Project

1. Open `Guidepost.xcodeproj` in Xcode
2. Click **File > New > Target...**
3. Select **Share Extension** from the iOS Application Extension templates
4. Configure the target:
   - **Product Name:** `GuidepostShare`
   - **Bundle Identifier:** `com.gambrell.Guidepost2026.GuidepostShare`
   - **Language:** Swift
   - Click **Finish**
   - When prompted to activate the scheme, click **Activate**

### 2. Replace Generated Files

The Share Extension target creation wizard generates some default files. Replace them with the ones already created:

1. **Delete** the auto-generated files from the `GuidepostShare` folder in Xcode:
   - `ShareViewController.swift` (if different from our version)
   - `MainInterface.storyboard` (not needed)
   
2. **Add** the pre-created files to the `GuidepostShare` target:
   - Right-click on `GuidepostShare` folder in Xcode
   - Select **Add Files to "Guidepost"...**
   - Navigate to the `GuidepostShare` folder and select:
     - `ShareViewController.swift`
     - `ShareExtensionView.swift`
     - `Info.plist`
     - `GuidepostShare.entitlements`

3. Ensure these files are in the `GuidepostShare` target (check File Inspector)

### 3. Add Existing Source Files to Share Extension Target

The Share Extension needs access to shared code. Add target membership for these files:

1. Select each file in the Project Navigator
2. In the **File Inspector** (right panel), check the **Target Membership** box for `GuidepostShare`

**Files to add:**
- `Guidepost/Services/AuthService.swift`
- `Guidepost/Services/ImageAPIService.swift`
- `Guidepost/Models/ImageModels.swift`
- `Guidepost/Models/AuthModels.swift`

### 4. Configure Entitlements for Both Targets

#### Main App (Guidepost):
1. Select the **Guidepost** target in Project Settings
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click the **+** button and add: `group.com.gambrell.guidepost2026.shared`
6. Add **Keychain Sharing** capability
7. Add keychain group: `group.com.gambrell.guidepost2026.shared`
8. In **Build Settings**, set `CODE_SIGN_ENTITLEMENTS` to `Guidepost/Guidepost.entitlements`

#### Share Extension (GuidepostShare):
1. Select the **GuidepostShare** target in Project Settings
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click the **+** button and add: `group.com.gambrell.guidepost2026.shared`
6. Add **Keychain Sharing** capability
7. Add keychain group: `group.com.gambrell.guidepost2026.shared`
8. In **Build Settings**, set `CODE_SIGN_ENTITLEMENTS` to `GuidepostShare/GuidepostShare.entitlements`

### 5. Configure URL Scheme for Main App

1. Select the **Guidepost** target in Project Settings
2. Go to the **Info** tab
3. Expand **URL Types**
4. Click **+** to add a new URL Type
5. Configure:
   - **Identifier:** `com.gambrell.Guidepost2026`
   - **URL Schemes:** `guidepost`
   - **Role:** Editor

### 6. Configure Share Extension Info.plist

1. Select the `GuidepostShare/Info.plist` file
2. Verify the `NSExtension` configuration is correct (should already be set from the created file)
3. Ensure these keys exist:
   - `NSExtensionActivationSupportsImageWithMaxCount` = 10
   - `NSExtensionPointIdentifier` = com.apple.share-services

### 7. Configure Build Settings

For both targets, ensure these settings:

**GuidepostShare Target:**
- **iOS Deployment Target:** Same as main app (iOS 17.0 or later recommended)
- **Swift Language Version:** Swift 5
- **Embed in Application:** Guidepost.app

### 8. Update Project Dependencies

If your project uses any frameworks or dependencies (like Alamofire, etc.), add them to the GuidepostShare target as well.

## Testing the Share Extension

1. **Build and run** the main **Guidepost** app on a device or simulator
2. **Sign in** to your Guidepost account
3. Open the **Photos** app
4. Select one or more images
5. Tap the **Share** button
6. Scroll and tap **Guidepost** in the share sheet
7. The Share Extension should appear showing your selected images
8. Tap **Upload & Analyze** to upload the images

## Troubleshooting

### Share Extension doesn't appear in share sheet
- Make sure you built and ran the app after adding the extension
- Check that the extension target is embedded in the main app
- Verify the `Info.plist` activation rules are correct

### "Sign In Required" message appears
- Make sure you're signed in to the main Guidepost app first
- Check that both targets have the same App Group configured
- Verify keychain access group is set correctly in both entitlements files

### Images fail to upload
- Check that the Share Extension has the same API service code
- Verify network permissions in the extension
- Check the Xcode console for error messages

### Cannot find type 'ImageMetadata' or similar errors
- Verify that all required files are added to the GuidepostShare target membership
- Clean build folder (Cmd+Shift+K) and rebuild

## Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                    Photos App                        │
│                        │                             │
│                    Share Button                      │
└────────────────────────┼───────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│              Share Extension (GuidepostShare)        │
│  ┌────────────────────────────────────────────────┐ │
│  │  ShareViewController                           │ │
│  │    └─> ShareExtensionView (SwiftUI)           │ │
│  │           └─> ShareExtensionViewModel         │ │
│  └────────────────────────────────────────────────┘ │
│                         │                            │
│              Uses Shared Services:                   │
│         • AuthService (Shared Keychain)             │
│         • ImageAPIService (Upload)                  │
│         • Models (ImageModels, AuthModels)          │
└─────────────────────────┼───────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│            Shared Keychain (App Group)              │
│         group.com.gambrell.guidepost2026.shared         │
└─────────────────────────┼───────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                  Backend API                         │
│            AWS Lambda (Upload Service)               │
└─────────────────────────────────────────────────────┘
```

## Key Features Implemented

✅ **Shared Keychain Access** - Tokens accessible from both main app and extension
✅ **Token Migration** - Existing users' tokens automatically migrated to shared keychain
✅ **URL Scheme Handling** - Deep link to main app when user needs to sign in
✅ **Batch Upload Support** - Upload up to 10 images at once
✅ **Metadata Preservation** - Location and creation date preserved when available
✅ **Progress Tracking** - Real-time upload progress display
✅ **Error Handling** - Graceful error messages and retry logic
✅ **Modern SwiftUI UI** - Clean, consistent design matching main app

## Next Steps

After completing the Xcode configuration:

1. Test the share extension thoroughly
2. Test with various image sources (Photos, Files, Safari, etc.)
3. Test the authentication flow (signed out → share → redirected to app)
4. Test on both device and simulator
5. Test with single and multiple images
6. Verify metadata (location, date) is preserved

## Support

If you encounter issues:
1. Check the console logs in Xcode for detailed error messages
2. Verify all entitlements are correctly configured
3. Ensure app groups match exactly between targets
4. Clean build folder and rebuild both targets
