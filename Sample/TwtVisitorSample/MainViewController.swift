import TwtVisitorSDK
import UIKit

final class MainViewController: UIViewController {
    private let resultLabel = UILabel()
    private weak var visitorController: VisitorViewController?
    private let clearButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Twt Visitor SDK"
        view.backgroundColor = .systemBackground
        let defaultButton = makeButton(title: "Open Default", action: #selector(openDefault))
        let customButton = makeButton(title: "Open Custom", action: #selector(openCustom))
        clearButton.setTitle("Clear Site Data", for: .normal)
        clearButton.addTarget(self, action: #selector(clearSiteData), for: .touchUpInside)
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [defaultButton, customButton, clearButton, resultLabel])
        stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24), stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system); button.setTitle(title, for: .normal); button.addTarget(self, action: action, for: .touchUpInside); return button
    }

    /// Sample default configuration: swap in the console URL; the visitor page parses the query values itself.
    private static let defaultConfiguration = VisitorConfiguration(
        url: URL(string: "")!,
        query: [:]
    )

    @objc private func openDefault() { present(configuration: Self.defaultConfiguration) }
    @objc private func openCustom() {
        let form = CustomVisitorConfigurationViewController { [weak self] configuration in
            guard let self else { return }
            self.dismiss(animated: true) { self.present(configuration: configuration) }
        }
        present(UINavigationController(rootViewController: form), animated: true)
    }
    private func present(configuration: VisitorConfiguration) {
        do {
            // The SDK only provides a bare WebView: the sample draws the back button and title in its own navigation bar.
            let visitor = try TwtVisitorSDK.makeEmbeddedController(configuration: configuration, delegate: self)
            visitor.navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.backward"),
                style: .plain,
                target: self,
                action: #selector(closeVisitor)
            )
            visitor.navigationItem.title = "Online support"
            visitorController = visitor
            let container = UINavigationController(rootViewController: visitor)
            // Use an opaque appearance so the bar background and title colour stay fixed; the iOS 26 glass bar samples what sits behind it and can swallow the title.
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            container.navigationBar.standardAppearance = appearance
            container.navigationBar.scrollEdgeAppearance = appearance
            container.modalPresentationStyle = .fullScreen
            present(container, animated: true)
        } catch {
            resultLabel.text = "Invalid configuration. Check the HTTPS URL and parameters."
        }
    }

    @objc private func closeVisitor() {
        dismiss(animated: true)
        visitorController = nil
    }

    @objc private func clearSiteData() {
        clearButton.isEnabled = false; resultLabel.text = "Clearing…"
        Task { @MainActor in
            defer { clearButton.isEnabled = true }
            do { try await TwtVisitorSDK.clearSiteData(); resultLabel.text = "Cleared" }
            catch VisitorSDKError.siteInUse { resultLabel.text = "Close the chat page first, then try again." }
            catch { resultLabel.text = "Cleanup failed. Try again later." }
        }
    }
}

extension MainViewController: @preconcurrency VisitorBridgeDelegate {
    func visitorDownloadRequested(requestId: String, url: URL, type: String, fileName: String?, mimeType: String?, callback: String?) {
        resultLabel.text = "Download requested: \(url.lastPathComponent)"
    }

    func visitorNewMessage() {}

    func visitorBack() -> Bool { false }

    /// The host owns the title bar: forward the web page title to the sample's navigation bar.
    func visitorTitleChanged(_ title: String) {
        visitorController?.navigationItem.title = title
    }
}
