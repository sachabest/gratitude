import SwiftUI

/// The "you got a smile" hero moment — shown full-screen the moment a
/// `Smile(direction: .received, hasBeenSeen: false)` lands, regardless of
/// whether it arrived via the native CloudKit share-invitation push or a
/// tapped `gratitude.sachabest.com` link (see `HomeView`'s `@Query` wiring and
/// `SmileService.acceptShareAndSaveSmile`) — both converge on the same
/// record, so this view doesn't need to know or care which path fired.
/// Deliberately single-smile, no carousel: if more than one is waiting,
/// `additionalUnseenCount` just says so in a small line rather than building
/// out a multi-step queue nobody asked for.
struct SmileReceivedView: View {
    let smile: Smile
    let additionalUnseenCount: Int
    let onDismiss: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "face.smiling.inverse")
                .font(.system(size: 96))
                .foregroundStyle(Theme.smile)
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)

            VStack(spacing: 8) {
                Text("\(smile.personName) sent you a smile")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(smile.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)

            if additionalUnseenCount > 0 {
                Text("+\(additionalUnseenCount) more waiting in your Smiles log")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(Theme.smile)
                .controlSize(.large)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .onAppear {
            Haptic.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

#Preview {
    SmileReceivedView(
        smile: Smile(direction: .received, personName: "Kate Bell", message: "Thanks for always checking in on me!"),
        additionalUnseenCount: 1,
        onDismiss: {}
    )
}
