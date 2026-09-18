# TwtVisitorSDK for iOS

Native WKWebView visitor container. Minimum iOS 15 and Xcode 16+ are recommended. The host must provide an HTTPS visitor URL.

## Installation

SPM only: in Xcode choose File → Add Package Dependencies, add https://github.com/TWT-Chat/twt-visitor-ios.git, then select tag 0.0.1 and product TwtVisitorSDK. Deployment Target must be iOS 15 or later. CocoaPods is not published.

## Privacy and quick start

~~~xml
<key>NSMicrophoneUsageDescription</key><string>Used to send voice messages.</string>
<key>NSCameraUsageDescription</key><string>Used to capture and send photos or videos.</string>
<key>NSPhotoLibraryAddUsageDescription</key><string>Used to save chat images.</string>
<key>UIFileSharingEnabled</key><true/>
<key>LSSupportsOpeningDocumentsInPlace</key><true/>
~~~

Do not weaken ATS. Call public APIs on the main actor:

~~~swift
import TwtVisitorSDK

let config = VisitorConfiguration(
    url: URL(string: "https://visitor.example.com/direct/app")!,
    query: ["visitor_id": "user-123", "source": "ios"],
    title: "Online support", language: .en, theme: .system,
    directChatId: nil, newMessageSoundMode: .web, isApp: true
)
let handle = try TwtVisitorSDK.present(from: viewController, configuration: config)
~~~

present creates and presents VisitorViewController and returns VisitorHandle. The host keeps the presenter alive and dismisses the controller; the handle is invalid after dismissal.

## Configuration and public API

url must be HTTPS. query is UTF-8 percent-encoded by the SDK. isApp adds is_app=1. title sets the native title. language (en, zh-cn, zh-tw, ja, ko, de, fr, pt, ru, es, vi, th, id, ms, tl) becomes lang. theme (light/dark/system) becomes theme. directChatId becomes direct=1&chatid=.... newMessageSoundMode is native or web. Typed fields override duplicate query keys. Never put passwords, cookies or long-lived tokens in the URL.

- TwtVisitorSDK.present(from:configuration:animated:delegate:) validates the URL and presents a page.
- TwtVisitorSDK.makeEmbeddedController(configuration:delegate:) creates an unpresented controller for Flutter PlatformView; the host embeds and removes it.
- TwtVisitorSDK.register(controller:) registers the active embedded controller for unified setTheme and download status calls.
- TwtVisitorSDK.bridgeDelegate is a weak global delegate; a per-present delegate takes precedence.
- VisitorHandle.setTheme, reportDownloadStatus and close operate on the session.
- TwtVisitorSDK.clearSiteData(for:) async throws clears data for the target host after dismissal.

## Delegate events

VisitorBridgeDelegate is weak; releasing it stops callbacks. Callbacks run on the main actor:
- visitorDownloadRequested contains requestId/url/type/fileName/mimeType/callback. After downloading, report VisitorDownloadStatus(requestId:status:path:errorCode:message:) with started/completed/failed/cancelled.
- visitorNewMessage signals a new message and may repeat; deduplicate in the host.
- visitorBack returns true when the host consumed back; false allows dismissal.
- visitorPermissionResult contains requestId, granted, canAskAgain and resources.

## Navigation, permissions and data cleanup

Only same-origin HTTPS top-level pages stay in the container. Cross-origin HTTPS opens in the system browser; HTTP, file, javascript and custom schemes are rejected. Only same-origin HTTPS microphone requests enter the system permission flow; camera and combined audio/video requests are denied. File inputs are handled by WebKit; no AppBridge is injected. Cookies, Local Storage and IndexedDB persist by default.

Cleanup selects the longest matching WebKit record for the target host. Sibling subdomains in one record may be removed; global cleanup is never used. siteInUse means an active session still uses the host; websiteDataVerificationFailed means post-delete verification failed; invalidURL, invalidQueryKey and invalidDirectChatID indicate invalid input. Dismiss all sessions and wait for dismissal to finish before cleanup when switching accounts.

## Verification

~~~bash
swift package describe
xcodebuild -scheme TwtVisitorSDK -destination 'generic/platform=iOS' build
xcodebuild -project Sample/TwtVisitorSample.xcodeproj -scheme TwtVisitorSample -destination 'generic/platform=iOS' build
~~~

On a real device verify microphone, photo/video/file upload, WSS, background/lock-screen behavior, weak-network retry, back navigation and account switching.
