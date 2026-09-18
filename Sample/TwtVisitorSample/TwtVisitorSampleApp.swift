import SwiftUI

@main
struct TwtVisitorSampleApp: App {
    var body: some Scene {
        WindowGroup { SampleRootViewControllerRepresentable().ignoresSafeArea() }
    }
}

private struct SampleRootViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { MainViewController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
