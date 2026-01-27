# Guidepost iOS Extensions & Widgets Plan

This document outlines recommended iOS extensions and mechanisms to enhance the Guidepost app beyond the main application experience.

---

## App Functionality Summary

**Guidepost** is an AI-powered photo management app with these core features:

| Feature | Description |
|---------|-------------|
| **Image Upload** | Upload photos with EXIF metadata (location, date) to AWS backend |
| **AI Analysis** | Automatic extraction of keywords, descriptions, and text (OCR) |
| **Smart Search** | Search images by AI-generated keywords, descriptions, or detected text |
| **Location Mapping** | Display photo locations on maps with reverse geocoding |
| **Share Extension** | Upload from any app via share sheet (already implemented) |

---

## Recommended iOS Extensions & Mechanisms

### 1. Home Screen Widgets (WidgetKit) — High Priority

| Widget Type | Description |
|-------------|-------------|
| **Photo Memories** (Small/Medium/Large) | Display a random analyzed photo with its description. Include "On This Day" memories from previous years. Tap to open detail view. |
| **Quick Upload** (Small) | One-tap camera/photo library access. Shows last uploaded thumbnail. |
| **Recent Keywords** (Medium) | Display trending/recent keywords as tappable tags for quick search |
| **Photo Stats** (Small) | Show total photos, photos this week, pending analysis count |

**Why**: Widgets keep your app top-of-mind and provide value without opening the app. iOS 17+ interactive widgets can even trigger searches directly.

#### Implementation Notes
- Use `WidgetKit` framework
- Create `GuidepostWidgets` target
- Share data via App Groups
- Timeline provider fetches recent/random images
- Support Small, Medium, and Large widget families

---

### 2. Spotlight Search (Core Spotlight) — High Priority

Index all analyzed images so users can search from anywhere:
- Keywords, descriptions, and detected text become system-searchable
- User searches "receipt" in Spotlight → your app's receipt photos appear
- Deep-link directly to `ImageDetailView`

**Why**: Your app already has rich searchable metadata (keywords, descriptions, OCR text). Surfacing this in Spotlight dramatically increases utility.

#### Implementation Notes
- Use `CoreSpotlight` framework
- Create `CSSearchableItem` for each analyzed image
- Index: keywords, description, detected text, filename
- Update index when analysis completes
- Handle `NSUserActivity` for deep linking
- Delete from index when image is deleted

```swift
// Example indexing structure
let attributeSet = CSSearchableItemAttributeSet(contentType: .image)
attributeSet.title = image.filename
attributeSet.contentDescription = analysisResult.description
attributeSet.keywords = analysisResult.keywords
attributeSet.thumbnailData = thumbnailData
```

---

### 3. Lock Screen Widgets (iOS 16+) — Medium Priority

| Widget | Function |
|--------|----------|
| **Circular** | Photo count or quick upload icon |
| **Rectangular** | Last uploaded image thumbnail or "X photos this week" |

**Why**: Provides glanceable info without unlocking, encourages daily engagement.

#### Implementation Notes
- Add `.accessoryCircular` and `.accessoryRectangular` to widget families
- Keep data minimal (counts, thumbnails)
- Use `AccessoryWidgetBackground()` for proper styling

---

### 4. Live Activities & Dynamic Island — Medium Priority

Show real-time progress for:
- Image uploads (especially batch uploads from share extension)
- AI analysis processing status
- Completion notification with preview

**Why**: Users uploading multiple photos (share extension supports this) benefit from seeing progress without keeping the app open.

#### Implementation Notes
- Use `ActivityKit` framework
- Define `ActivityAttributes` for upload progress
- Start activity when upload begins
- Update with progress percentage
- End with success/failure state
- Show in Dynamic Island on supported devices

```swift
struct UploadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var uploadedCount: Int
        var totalCount: Int
        var currentImageName: String
    }
    var startTime: Date
}
```

---

### 5. Siri Shortcuts & App Intents — Medium Priority

Expose these intents:
- `"Show photos from Paris"` → Search by location keyword
- `"Upload last photo to Guidepost"` → Quick upload
- `"Search Guidepost for receipts"` → Keyword search
- `"Show recent Guidepost photos"` → Open app to home

**Why**: Voice and Shortcuts app integration enables hands-free use and automation workflows.

#### Implementation Notes
- Use `AppIntents` framework (iOS 16+)
- Define `AppIntent` structs for each action
- Provide `AppShortcutsProvider` for Siri suggestions
- Handle parameters (search terms, locations)

```swift
struct SearchPhotosIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Guidepost Photos"
    
    @Parameter(title: "Search Term")
    var searchTerm: String
    
    func perform() async throws -> some IntentResult {
        // Open app with search
    }
}
```

---

### 6. Notification Service/Content Extension — Medium Priority

When image analysis completes:
- Rich notification showing the analyzed image thumbnail
- Display 2-3 extracted keywords inline
- Tap to view full details

**Why**: Analysis status tracking exists. Surfacing results as rich notifications closes the feedback loop.

#### Implementation Notes
- Create `NotificationContentExtension` target
- Design custom notification UI
- Show image thumbnail and keywords
- Handle notification tap to deep-link

---

### 7. Apple Watch App — Lower Priority (Differentiating)

| Feature | Description |
|---------|-------------|
| **Recent Photos** | Thumbnail grid of recent uploads |
| **Keywords Browse** | Scroll through keywords, tap to see matching photos |
| **Quick Capture** | Upload photos from Watch camera to Guidepost |
| **Complications** | Photo count, recent upload indicator |

**Why**: Differentiates your app, useful for quick glances at photo library on-the-go.

#### Implementation Notes
- Create WatchOS target
- Use `WatchConnectivity` for data sync
- Implement complications for watch faces
- Consider offline caching for thumbnails

---

### 8. Photo Editing Extension — Lower Priority

Allow users in the Photos app to:
- Send any photo to Guidepost for analysis
- View existing Guidepost keywords/tags overlaid on photos

**Why**: Meets users where they already are (Photos app).

#### Implementation Notes
- Create Photo Editing Extension target
- Implement `PHContentEditingController`
- Non-destructive editing approach

---

## Implementation Priority Matrix

| Priority | Extension | Effort | Impact | Dependencies |
|----------|-----------|--------|--------|--------------|
| 1 | **Spotlight Integration** | Low | High | CoreSpotlight |
| 2 | **Photo Memories Widget** | Medium | High | WidgetKit, App Groups |
| 3 | **Live Activities** (upload progress) | Medium | Medium | ActivityKit |
| 4 | **Siri Shortcuts** | Medium | Medium | AppIntents |
| 5 | **Lock Screen Widgets** | Low | Medium | WidgetKit |
| 6 | **Rich Notifications** | Low | Medium | UserNotifications |
| 7 | **Apple Watch App** | High | Medium | WatchKit, WatchConnectivity |

---

## Technical Prerequisites

### App Groups (Required for Widgets & Extensions)

Add to both main app and extensions:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.gambrell.Guidepost</string>
</array>
```

### Shared Data Layer

Create shared code for:
- Authentication token access (Keychain with shared access group)
- Image cache (shared container)
- API service (shared framework or SPM package)

### Frameworks Required

| Extension | Frameworks |
|-----------|------------|
| Widgets | WidgetKit, SwiftUI |
| Spotlight | CoreSpotlight |
| Live Activities | ActivityKit |
| Siri Shortcuts | AppIntents |
| Watch App | WatchKit, WatchConnectivity |
| Notifications | UserNotifications, UserNotificationsUI |

---

## Deep Linking Strategy

Define URL scheme for navigation:

```
guidepost://                     → Open app
guidepost://image/{id}           → Open image detail
guidepost://search?q={query}     → Search with query
guidepost://upload               → Open upload sheet
```

Already have `guidepost://` scheme registered (used in share extension).

---

## Estimated Timeline

| Phase | Components | Duration |
|-------|------------|----------|
| **Phase 1** | Spotlight indexing, App Groups setup | 1-2 days |
| **Phase 2** | Photo Memories Widget (all sizes) | 2-3 days |
| **Phase 3** | Lock Screen Widgets | 1 day |
| **Phase 4** | Live Activities for uploads | 2 days |
| **Phase 5** | Siri Shortcuts | 2 days |
| **Phase 6** | Rich Notifications | 1 day |
| **Phase 7** | Apple Watch App | 1 week |

---

## References

- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [Core Spotlight Documentation](https://developer.apple.com/documentation/corespotlight)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [WWDC23: Bring widgets to new places](https://developer.apple.com/videos/play/wwdc2023/10027/)
- [WWDC22: Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2022/10102/)

---

*Document created: January 27, 2026*
