import SwiftUI

private struct OnboardingPage {
    let icon: String
    let tint: Color
    let title: String
    let description: String
}

/// A one-time, skippable guided intro shown on first launch — see
/// `HomeView`'s `hasCompletedOnboarding` wiring for how it takes priority
/// over both `SmileReceivedView` and check-in auto-launch (mirrors the same
/// "gate the lower-priority presentation, retry it once this one is
/// dismissed" pattern already used between those two). Deliberately a fixed,
/// short set of pages rather than anything configurable — reuses the exact
/// icons/tints Home's own cards use (`Period.symbolName`/`.tint`,
/// `Theme.reflect`/`Theme.smile`) so the intro visually maps to what you see
/// moments later, rather than inventing new iconography.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "hands.sparkles.fill",
            tint: Theme.positive,
            title: "Welcome to Gratitude",
            description: "A calm moment, twice a day — right after waking, and right before bed."
        ),
        OnboardingPage(
            icon: Period.morning.symbolName,
            tint: Theme.morning,
            title: "Morning",
            description: "Set an intention for the day in a couple of quick questions. Opens during a window you can adjust in Settings — 4am–11am by default."
        ),
        OnboardingPage(
            icon: Period.evening.symbolName,
            tint: Theme.evening,
            title: "Evening",
            description: "Look back before bed — how the day went, and one good thing about it. Opens 8pm–2am by default."
        ),
        OnboardingPage(
            icon: "clock.arrow.circlepath",
            tint: Theme.reflect,
            title: "Reflect",
            description: "Open any time to revisit a specific past day — morning and evening together, with any photo you attached."
        ),
        OnboardingPage(
            icon: "face.smiling",
            tint: Theme.smile,
            title: "Smiles",
            description: "Tag someone during an evening check-in to send them a quick thank-you, or send one anytime from the Smiles log."
        ),
    ]

    private var isLastPage: Bool { pageIndex == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
                    .accessibilityHidden(isLastPage)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(height: 44)

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(isLastPage ? "Get Started" : "Next") {
                Haptic.selection()
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { pageIndex += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(pages[pageIndex].tint)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(page.tint)
            }
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.weight(.bold))
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
