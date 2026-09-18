#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit
import AVFoundation

/// Internal chat container for the SDK: a persistent WKWebView, basic title and close chrome, retry on error, and safe-area layout.
@MainActor
public final class VisitorViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    public let configuration: VisitorConfiguration
    private let showsChrome: Bool
    private(set) var webView: WKWebView!
    private let titleLabel = UILabel()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var activityToken: VisitorActivityRegistry.Token?
    private let resolvedURL: URL
    private var hasLoadedSuccessfully = false
    public let sessionId = UUID().uuidString
    public weak var bridgeDelegate: VisitorBridgeDelegate?
    private var downloadCallbacks: [String: String] = [:]

    public init(configuration: VisitorConfiguration, showsChrome: Bool = true) throws {
        self.configuration = configuration
        self.showsChrome = showsChrome
        self.resolvedURL = try VisitorURLPolicy.makeURL(from: configuration)
        super.init(nibName: nil, bundle: nil)
        self.activityToken = VisitorActivityRegistry.shared.acquire(host: resolvedURL.host ?? "")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureWebView()
        if showsChrome { configureChrome() } else { configureErrorUI() }
        webView.load(URLRequest(url: resolvedURL))
    }

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(self, name: "AppBridgeChannel")
        let script = "(function(){window.__TWT_VISITOR_BRIDGE_CONFIG__={sessionId:'\(sessionId)',newMessageSoundMode:'\(self.configuration.newMessageSoundMode.rawValue)'};window.AppBridge=window.AppBridge||{_callbacks:{},call:function(m,p,cb){var id=cb?'cb_'+Date.now()+'_'+Math.random().toString(16).slice(2):null;if(cb)this._callbacks[id]=cb;p=Object.assign({sessionId:'\(sessionId)'},p||{});window.webkit.messageHandlers.AppBridgeChannel.postMessage(JSON.stringify({method:m,params:p,callback:id}));return Promise.resolve({status:'sent',callbackId:id});},invokeCallback:function(id,r){var cb=this._callbacks[id];if(cb){cb(r);var data=r&&r.data&&typeof r.data==='object'?r.data:r;var status=data&&data.status;if(status==='completed'||status==='failed'||status==='cancelled')delete this._callbacks[id];}},emitEvent:function(t,p){window.dispatchEvent(new CustomEvent('twt:visitor-event',{detail:{type:t,payload:p}}));}};})();"
        configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // Enable the edge-swipe back gesture so in-page history navigation matches the system back gesture.
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        let topAnchor = showsChrome ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        let bottomAnchor = showsChrome ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
        let leadingAnchor = showsChrome ? view.safeAreaLayoutGuide.leadingAnchor : view.leadingAnchor
        let trailingAnchor = showsChrome ? view.safeAreaLayoutGuide.trailingAnchor : view.trailingAnchor
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor, constant: showsChrome ? 44 : 0),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "AppBridgeChannel", let body = message.body as? String, let data = body.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let method = object["method"] as? String else { return }
        let params = object["params"] as? [String: Any] ?? [:]
        if method == "new_message" { bridgeDelegate?.visitorNewMessage() }
        if method == "download", let raw = params["url"] as? String, let url = URL(string: raw) { let id = params["requestId"] as? String ?? UUID().uuidString; let callback = object["callback"] as? String; if let callback { downloadCallbacks[id] = callback }; bridgeDelegate?.visitorDownloadRequested(requestId: id, url: url, type: params["type"] as? String ?? "file", fileName: params["fileName"] as? String, mimeType: params["mimeType"] as? String, callback: callback) }
    }

    private func configureChrome() {
        let bar = UIView(); bar.translatesAutoresizingMaskIntoConstraints = false; bar.backgroundColor = .systemBackground
        view.addSubview(bar)
        titleLabel.text = configuration.title ?? "Online support"; titleLabel.font = .preferredFont(forTextStyle: .headline); titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let close = UIButton(type: .system); close.setTitle("Close", for: .normal); close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside); close.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(titleLabel); bar.addSubview(close)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor), bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), bar.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor), titleLabel.centerXAnchor.constraint(equalTo: bar.centerXAnchor), close.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16), close.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
        errorLabel.isHidden = true; errorLabel.numberOfLines = 0; errorLabel.textAlignment = .center; errorLabel.translatesAutoresizingMaskIntoConstraints = false
        retryButton.isHidden = true; retryButton.setTitle("Retry", for: .normal); retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside); retryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel); view.addSubview(retryButton)
        NSLayoutConstraint.activate([
            errorLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -20),
            retryButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            retryButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
        ])
    }

    private func configureErrorUI() {
        errorLabel.isHidden = true
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        retryButton.isHidden = true
        retryButton.setTitle("Retry", for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)
        view.addSubview(retryButton)
        NSLayoutConstraint.activate([
            errorLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -20),
            retryButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
        ])
    }

    @objc private func closeTapped() { dismiss(animated: true) { [weak self] in self?.releaseActivity() } }
    @objc private func retryTapped() { retry() }

    /// Clears the error message and reloads the initial visitor URL.
    func retry() { errorLabel.isHidden = true; retryButton.isHidden = true; webView.load(URLRequest(url: resolvedURL)) }

    public func setTheme(_ theme: VisitorTheme) {
        let value = theme.rawValue
        webView.evaluateJavaScript("document.documentElement.setAttribute('data-theme','\(value)');window.AppBridge&&window.AppBridge.emitEvent('themeChanged',{theme:'\(value)'})", completionHandler: nil)
    }

    public func reportDownloadStatus(_ status: VisitorDownloadStatus) {
        guard let callback = downloadCallbacks[status.requestId] else { return }
        var data: [String: Any] = ["requestId": status.requestId, "status": status.status]
        if let path = status.path { data["path"] = path }; if let errorCode = status.errorCode { data["errorCode"] = errorCode }; if let message = status.message { data["message"] = message }
        guard let json = try? JSONSerialization.data(withJSONObject: data), let text = String(data: json, encoding: .utf8) else { return }
        let code = status.status == "failed" ? 0 : 1
        webView.evaluateJavaScript("window.AppBridge&&window.AppBridge.invokeCallback('\(callback)',{code:\(code),data:\(text)})", completionHandler: nil)
        if status.status == "completed" || status.status == "failed" || status.status == "cancelled" { downloadCallbacks.removeValue(forKey: status.requestId) }
    }

    /// Reduces the navigation delegate's WebKit parameters to a directly verifiable decision, so tests never need to build WebKit objects that cannot be publicly initialized.
    func navigationDecision(candidate: URL?, isMainFrame: Bool, isNewWindow: Bool) -> VisitorNavigationDecision {
        guard let candidate else { return .blocked }
        return VisitorNavigationPolicy.decide(base: resolvedURL, candidate: candidate, isMainFrame: isMainFrame, isNewWindow: isNewWindow)
    }

    /// Media permission is granted only to same-origin HTTPS microphone, camera, and combined capture requests.
    func mediaPermissionDecision(scheme: String, host: String, port: Int, type: WKMediaCaptureType) -> WKPermissionDecision {
        guard isMediaOriginAllowed(scheme: scheme, host: host, port: port) else { return .deny }
        return .grant
    }

    var isErrorVisible: Bool { !errorLabel.isHidden }
    var isRetryVisible: Bool { !retryButton.isHidden }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { hasLoadedSuccessfully = true }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if !hasLoadedSuccessfully { showError(error) } }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if !hasLoadedSuccessfully { showError(error) } }
    func showError(_ error: Error) { errorLabel.text = "Failed to load the page. Check your network and try again."; errorLabel.isHidden = false; retryButton.isHidden = false }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        let candidate = navigationAction.request.url
        let decision = navigationDecision(candidate: candidate, isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true, isNewWindow: navigationAction.targetFrame == nil)
        switch decision {
        case .internalWebView: decisionHandler(.allow)
        case .blocked: decisionHandler(.cancel)
        case .externalBrowser:
            decisionHandler(.cancel)
            if let candidate { UIApplication.shared.open(candidate) }
        }
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let candidate = navigationAction.request.url
        switch navigationDecision(candidate: candidate, isMainFrame: true, isNewWindow: true) {
        case .internalWebView:
            if let candidate { webView.load(URLRequest(url: candidate)) }
        case .externalBrowser:
            if let candidate { UIApplication.shared.open(candidate) }
        case .blocked: break
        }
        return nil
    }

    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        guard isMediaOriginAllowed(scheme: origin.protocol, host: origin.host, port: origin.port) else { decisionHandler(.deny); return }
        let needsMicrophone = type == .microphone || type == .cameraAndMicrophone
        let needsCamera = type == .camera || type == .cameraAndMicrophone
        let requestId = UUID().uuidString
        let resources = (needsMicrophone ? ["microphone"] : []) + (needsCamera ? ["camera"] : [])
        let requestCamera: (@escaping (Bool) -> Void) -> Void = { completion in
            guard needsCamera else { completion(true); return }
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        }
        let finish: (Bool, Bool) -> Void = { [weak self] microphoneGranted, cameraGranted in
            let grantedResources = (needsMicrophone && microphoneGranted ? ["microphone"] : []) + (needsCamera && cameraGranted ? ["camera"] : [])
            let granted = grantedResources.count == resources.count
            self?.bridgeDelegate?.visitorPermissionResult(requestId: requestId, granted: granted, canAskAgain: false, resources: grantedResources)
            decisionHandler(granted ? .grant : .deny)
        }
        let requestMicrophone: (@escaping (Bool) -> Void) -> Void = { completion in
            guard needsMicrophone else { completion(true); return }
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        }
        requestMicrophone { microphoneGranted in
            guard microphoneGranted || !needsMicrophone else { finish(false, false); return }
            requestCamera { cameraGranted in finish(microphoneGranted, cameraGranted) }
        }
    }

    func isMediaOriginAllowed(scheme: String, host: String, port: Int) -> Bool {
        guard scheme.lowercased() == "https", host.caseInsensitiveCompare(resolvedURL.host ?? "") == .orderedSame else { return false }
        return (port == 0 ? 443 : port) == (resolvedURL.port ?? 443)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { releaseActivity() }
    }

    private func releaseActivity() { activityToken?.release(); activityToken = nil }
    deinit { activityToken?.release() }
}
#endif
