---
name: App Store Rejection Fix
overview: "Resolve two App Store rejection issues: (1) Add account deletion functionality to the Profile sheet, and (2) Implement a silent guest account mode that allows users to try the app without providing personal info."
todos:
  - id: delete-auth-service
    content: Add deleteAccount() method to AuthService.swift
    status: pending
  - id: delete-viewmodel
    content: Add deleteAccount() function to AuthViewModel.swift
    status: pending
  - id: delete-profile-ui
    content: Add Delete Account button and confirmation dialog to ProfileSheetView in HomeView.swift
    status: pending
  - id: guest-auth-service
    content: Add createGuestAccount() and isGuestAccount property to AuthService.swift
    status: pending
  - id: guest-viewmodel
    content: Add guest account state (isGuest, guestUploadCount) and tryAsGuest() to AuthViewModel.swift
    status: pending
  - id: guest-signin-button
    content: Add 'Try the App' button to SignInView.swift that triggers silent guest account creation
    status: pending
  - id: guest-upload-limit
    content: Add upload limit check (max 3) for guest accounts in ImageGridViewModel or ImageUploadView
    status: pending
  - id: guest-upgrade-flow
    content: Add upgrade prompt and flow to convert guest account to full account
    status: pending
isProject: false
---

# App Store Rejection Resolution Plan

## Issue 1: Account Deletion (Guideline 5.1.1(v))

**Current State:** Profile sheet ([HomeView.swift](Guidepost/Views/HomeView.swift) lines 350-522) has sign out but no account deletion.

**Solution:**

Add "Delete Account" button to `ProfileSheetView` with:

- Confirmation alert explaining data will be permanently deleted
- Call new `deleteAccount()` method in `AuthService`
- Clear local tokens and navigate back to sign-in after deletion

**Files to modify:**

- [AuthService.swift](Guidepost/Services/AuthService.swift) - Add `deleteAccount()` API method
- [AuthViewModel.swift](Guidepost/ViewModels/AuthViewModel.swift) - Add `deleteAccount()` function
- [HomeView.swift](Guidepost/Views/HomeView.swift) - Add delete button in `ProfileSheetView` Account section

**Backend Note:** Verify your backend has a `DELETE /api/auth/me` endpoint (or similar). If not, you'll need to add one that:

- Deletes user's Cognito account
- Deletes all user data (images, analysis results)

---

## Issue 2: Guest Mode (Guideline 5.1.1)

**Problem:** App requires sign-in before accessing any features. Apple requires non-account-based features be accessible without registration.

### Recommended Approach: Silent Guest Account

Create an anonymous/silent guest account behind the scenes when user taps "Try the App". This is a common pattern used by games, productivity apps, and many others.

**How it works:**

1. User taps "Try the App" on sign-in screen
2. App silently creates a guest account (random email like `guest_<UUID>@guidepost.guest`, random password)
3. Auto sign-in, tokens stored in keychain
4. User can upload up to 3 images to try the app
5. After 3 uploads, prompt to upgrade to full account
6. Guest can "upgrade" by providing real email/password

**Why this approach:**

- User doesn't provide personal info upfront (satisfies Apple's 5.1.1)
- Reuses 90% of existing auth and upload code
- Data persists between sessions on same device
- Natural conversion funnel to full account
- Industry-standard pattern (Firebase, Cognito both support this natively)

### Implementation Details

**UI Flow:**

```
SignInView
   |
   +-- "Try the App" button
          |
          v
   [Silent account creation]
   [Auto sign-in]
   [isGuest = true stored locally]
          |
          v
   HomeView (existing)
       - All existing functionality works
       - Upload limited to 3 images
       - Profile shows "Upgrade Account" instead of email
       - Subtle upgrade prompts after uploads
```

**Files to modify:**

- [AuthService.swift](Guidepost/Services/AuthService.swift):
  - Add `createGuestAccount()` - generates random credentials, calls signup + signin
  - Add `isGuestAccount` property (stored in keychain)
  - Add `upgradeGuestAccount(email:password:)` for converting to full account

- [AuthViewModel.swift](Guidepost/ViewModels/AuthViewModel.swift):
  - Add `isGuest` observable property
  - Add `guestUploadCount` property (stored in UserDefaults)
  - Add `tryAsGuest()` async function
  - Add `upgradeAccount()` function

- [SignInView.swift](Guidepost/Views/Auth/SignInView.swift):
  - Add "Try the App" button below sign-in form

- [ImageUploadView.swift](Guidepost/Views/ImageUploadView.swift) or [ImageGridViewModel.swift](Guidepost/ViewModels/ImageGridViewModel.swift):
  - Check guest upload limit before allowing upload
  - Show upgrade prompt when limit reached

- [HomeView.swift](Guidepost/Views/HomeView.swift) - ProfileSheetView:
  - Show "Upgrade Account" section for guest users instead of email
  - Hide "Delete Account" for guests (or delete guest account directly)

**New View (optional but recommended):**

- `Views/Auth/UpgradeAccountView.swift` - Form to enter email/password to claim guest account

**Backend Requirements:**

Option A (Recommended - No backend changes):
- Use existing `/api/auth/signup` with generated guest credentials
- Guest accounts are regular accounts, just with fake emails
- Add periodic cleanup job to delete old guest accounts (optional)

Option B (If you want backend awareness of guests):
- Add `isGuest` field to user metadata in Cognito
- Add `PATCH /api/auth/upgrade` endpoint to update email/password and clear guest flag

---

## Summary of Changes

### Client-Side (This Codebase)

1. **Account Deletion:**
   - Add `deleteAccount()` API call to AuthService
   - Add delete button in ProfileSheetView with confirmation dialog

2. **Guest Mode:**
   - Add `createGuestAccount()` to AuthService (generates random creds, auto sign-in)
   - Add "Try the App" button to SignInView
   - Track guest status and upload count locally
   - Limit guest uploads to 3, show upgrade prompts
   - Add upgrade flow to convert guest → full account

### Backend Requirements

1. `DELETE /api/auth/me` - Delete authenticated user's account and all data
2. (Optional) `PATCH /api/auth/upgrade` - Convert guest account to full account with real email/password
3. (Optional) Scheduled job to clean up old unused guest accounts
