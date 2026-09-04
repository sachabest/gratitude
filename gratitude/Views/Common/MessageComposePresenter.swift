import MessageUI

/// Presents `MFMessageComposeViewController` via `ModalPresenter` (see that
/// file for why not `.sheet`). Unlike the contact picker, Messages does
/// *not* dismiss itself — we're responsible for dismissing it from the
/// delegate callback.
final class MessageComposePresenter: NSObject, MFMessageComposeViewControllerDelegate {
    private let onFinish: (MessageComposeResult) -> Void

    init(onFinish: @escaping (MessageComposeResult) -> Void) {
        self.onFinish = onFinish
    }

    /// Returns `false` without presenting anything if this device can't send text messages.
    @discardableResult
    func present(recipients: [String], body: String) -> Bool {
        guard MFMessageComposeViewController.canSendText() else { return false }
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = self
        ModalPresenter.present(controller)
        return true
    }

    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        ModalPresenter.dismiss()
        onFinish(result)
    }
}
