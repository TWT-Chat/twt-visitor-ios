# TwtVisitorSDK

Embed a visitor chat page in your app with WKWebView.

**Version:** 0.0.1 · **iOS:** 15+ · **License:** Proprietary

Call all public APIs on the main actor.

## Installation

In Xcode: **File → Add Package Dependencies**

```
https://github.com/TWT-Chat/twt-visitor-ios.git
```

Select tag **0.0.1** and product **TwtVisitorSDK**. Set the deployment target to iOS 15 or later.

Add to `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used to send voice messages.</string>
<key>NSCameraUsageDescription</key>
<string>Used to capture and send photos or videos.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Used to save chat images.</string>
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

Do not weaken App Transport Security.

## Quick start

The visitor URL must be HTTPS. Put business parameters in `query` — do not build a query string yourself, and do not put secrets in the URL.

```swift
import TwtVisitorSDK

let config = VisitorConfiguration(
    url: URL(string: "URL from the console")!
)
let handle = try TwtVisitorSDK.present(from: self, configuration: config, delegate: self)
```

`present` shows `VisitorViewController` and returns `VisitorHandle`. Dismiss it yourself; the handle is invalid afterwards.

To embed in your own container instead of presenting:

```swift
let vc = try TwtVisitorSDK.makeEmbeddedController(configuration: config, delegate: self)
TwtVisitorSDK.register(controller: vc)
addChild(vc)
view.addSubview(vc.view)
vc.didMove(toParent: self)
```

## Configuration

| Field | Description |
| --- | --- |
| `url` | HTTPS URL from the console |
| `query` | Business parameters, UTF-8 encoded by the SDK |
| `isApp` | Adds `is_app=1` and shows a close button |
| `title` | Native title |
| `language` | `en`, `zh-cn`, `zh-tw`, `ja`, `ko`, `de`, `fr`, `pt`, `ru`, `es`, `vi`, `th`, `id`, `ms`, `tl` |
| `theme` | `light` / `dark` / `system`. Runtime `setTheme` accepts only `light` / `dark` |
| `directChatId` | Opens a conversation (`direct=1&chatid=`) |
| `newMessageSoundMode` | `web` or `native` |

Typed fields (`isApp`, `language`, `theme`, `directChatId`) override the same keys in `query`. Do not put `is_app` / `lang` / `theme` / `direct` / `chatid` in `query`.

## Query parameters

`query` is an opaque map: the SDK only encodes it. Anonymous visitors can omit it.

```swift
query: [
    "sbs": "user-123",
    "sbs_mm": signature,
    "ranstr": randomStr,
    "name": "Zhang San",
]
```

| Parameter | Required | Meaning |
| --- | --- | --- |
| `sbs` | When binding a user | Unique business-user id; the visitor page uses it to identify a logged-in customer |
| `sbs_mm` | If `sbs` is set | Signature of `sbs` |
| `ranstr` | If signing | Random string used in the signature |
| `name` | Optional | Visitor name shown in the agent console |
| `nickname` | Optional | Visitor nickname |
| `email` | Optional | Visitor email |
| `phone` | Optional | Visitor phone |
| `customer_remark` | Optional | Remark sent with login |
| `ext_fk_id` | Optional | Existing visitor id, to resume that visitor's history |
| `referer` | Optional | Source page URL (also accepts `referer_url`) |
| `source_title` | Optional | Source page title |

Do not send `visitor_id` or `source=ios`. Mark an in-app open with `isApp = true`.

## API

| Method | Description |
| --- | --- |
| `present(from:configuration:animated:delegate:)` | Present a session |
| `makeEmbeddedController(configuration:delegate:)` | Create an unpresented view controller |
| `register(controller:)` | Register an embedded controller for theme / download calls |
| `handle.setTheme` / `reportDownloadStatus` / `close` | Session controls |
| `clearSiteData(for:) async throws` | Clear WebKit data for the host |

Download status: `started` / `completed` / `failed` / `cancelled`. Photo library completions use `photos://localIdentifier`.

Errors: `invalidURL`, `invalidQueryKey`, `invalidDirectChatID`, `siteInUse`, `websiteDataVerificationFailed`.

## Delegate

`VisitorBridgeDelegate` is weak. Callbacks run on the main actor.

- `visitorDownloadRequested` — download, then report status
- `visitorNewMessage` — may repeat; deduplicate in the host
- `visitorBack() -> Bool` — return `true` if you handled it
- `visitorPermissionResult`

## Behavior

- Same-origin HTTPS stays in the web view; cross-origin HTTPS opens in the system browser; other schemes are blocked.
- Same-origin HTTPS microphone and camera capture can request system permission. Cross-origin requests are denied.
- File picking uses the system panel.
- Cookies, Local Storage, and IndexedDB persist.
- Cleanup matches the longest WebKit record for the host (sibling subdomains in that record may be removed). It never wipes all website data.
- Switch accounts: dismiss → wait until disappear finishes → `clearSiteData` → present again.

## Links

- [Android SDK](https://github.com/TWT-Chat/twt-visitor-android)
- [Flutter plugin](https://github.com/TWT-Chat/visitor_flutter)
