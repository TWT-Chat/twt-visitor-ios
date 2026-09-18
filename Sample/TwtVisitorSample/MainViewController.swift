import TwtVisitorSDK
import UIKit

final class MainViewController: UIViewController {
    private let resultLabel = UILabel()
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

    @objc private func openDefault() { present(configuration: .init()) }
    @objc private func openCustom() {
        let form = CustomVisitorConfigurationViewController { [weak self] configuration in
            guard let self else { return }
            self.dismiss(animated: true) { self.present(configuration: configuration) }
        }
        present(UINavigationController(rootViewController: form), animated: true)
    }
    private func present(configuration: VisitorConfiguration) {
        do { try TwtVisitorSDK.present(from: self, configuration: configuration) }
        catch { resultLabel.text = "Invalid configuration. Check the HTTPS URL and parameters." }
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
