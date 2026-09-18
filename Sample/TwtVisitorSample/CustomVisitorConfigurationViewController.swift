import TwtVisitorSDK
import UIKit

/// Custom configuration form of the sample; it collects input and hands a validated configuration back to the host.
final class CustomVisitorConfigurationViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    let urlField = UITextField()
    let queryField = UITextField()
    let languageField = UITextField()
    let themeControl = UISegmentedControl(items: VisitorTheme.allCases.map(\.rawValue))
    let directChatIDField = UITextField()
    let errorLabel = UILabel()

    private let languagePicker = UIPickerView()
    private let onSubmit: (VisitorConfiguration) -> Void
    private var didSubmit = false

    init(onSubmit: @escaping (VisitorConfiguration) -> Void = { _ in }) {
        self.onSubmit = onSubmit
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Custom Configuration"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Open", style: .done, target: self, action: #selector(submit))
        configureFields()
        configureLayout()
    }

    private func configureFields() {
        configureTextField(urlField, placeholder: "https://host/direct/APP_ID", identifier: "custom-url")
        urlField.text = VisitorConfiguration.defaultVisitorURL.absoluteString
        urlField.keyboardType = .URL
        urlField.textContentType = .URL
        urlField.autocapitalizationType = .none

        configureTextField(queryField, placeholder: "key=value&key2=value2 (optional)", identifier: "custom-query")
        queryField.autocapitalizationType = .none

        configureTextField(languageField, placeholder: nil, identifier: "custom-language")
        languageField.text = VisitorLanguage.zhCn.rawValue
        languagePicker.dataSource = self
        languagePicker.delegate = self
        languagePicker.selectRow(VisitorLanguage.allCases.firstIndex(of: .zhCn) ?? 0, inComponent: 0, animated: false)
        languageField.inputView = languagePicker
        languageField.tintColor = .clear

        themeControl.selectedSegmentIndex = VisitorTheme.allCases.firstIndex(of: .system) ?? 0
        themeControl.accessibilityIdentifier = "custom-theme"

        configureTextField(directChatIDField, placeholder: "Chat ID (optional)", identifier: "custom-direct-chat-id")
        directChatIDField.autocapitalizationType = .none

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.accessibilityIdentifier = "custom-error"
    }

    private func configureTextField(_ field: UITextField, placeholder: String?, identifier: String) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.accessibilityIdentifier = identifier
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
    }

    private func configureLayout() {
        let stack = UIStackView(arrangedSubviews: [
            makeField(title: "Full HTTPS URL", control: urlField),
            makeField(title: "Query parameters", control: queryField),
            makeField(title: "Language", control: languageField),
            makeField(title: "Theme", control: themeControl),
            makeField(title: "Direct chat ID", control: directChatIDField),
            errorLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    private func makeField(title: String, control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline)
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    @objc func submit() {
        guard !didSubmit else { return }
        view.endEditing(true)
        do {
            let configuration = try CustomVisitorConfigurationBuilder.makeConfiguration(
                from: CustomVisitorConfigurationInput(
                    urlText: urlField.text ?? "",
                    queryText: queryField.text ?? "",
                    language: selectedLanguage,
                    theme: selectedTheme,
                    directChatIdText: directChatIDField.text ?? ""
                )
            )
            errorLabel.text = nil
            didSubmit = true
            navigationItem.rightBarButtonItem?.isEnabled = false
            onSubmit(configuration)
        } catch let error as CustomVisitorConfigurationError {
            errorLabel.text = error.errorDescription
        } catch {
            errorLabel.text = "Invalid configuration. Check your input and try again."
        }
    }

    @objc private func cancel() { dismiss(animated: true) }

    private var selectedLanguage: VisitorLanguage {
        VisitorLanguage.allCases[languagePicker.selectedRow(inComponent: 0)]
    }

    private var selectedTheme: VisitorTheme {
        let index = max(themeControl.selectedSegmentIndex, 0)
        return VisitorTheme.allCases[index]
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { VisitorLanguage.allCases.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        VisitorLanguage.allCases[row].rawValue
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        languageField.text = VisitorLanguage.allCases[row].rawValue
    }
}
