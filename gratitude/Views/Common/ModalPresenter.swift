import UIKit

/// Presents a UIKit view controller directly via the key window, bypassing
/// SwiftUI's `.sheet`. This is needed for system controllers that dismiss
/// *themselves* (`CNContactPickerViewController`, `MFMessageComposeViewController`)
/// — wrapping those as the content of a SwiftUI `.sheet`, especially one
/// nested inside another sheet (our check-in flow is already a sheet), causes
/// a desync: the picker's self-dismissal and SwiftUI's binding-driven
/// dismissal fight each other, and it was observed to cascade into dismissing
/// the *parent* sheet too, silently discarding an in-progress check-in.
enum ModalPresenter {
    @MainActor
    static func present(_ viewController: UIViewController) {
        topViewController()?.present(viewController, animated: true)
    }

    @MainActor
    static func dismiss() {
        topViewController()?.dismiss(animated: true)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
