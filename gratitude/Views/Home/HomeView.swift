import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]

    @AppStorage(SettingsKeys.morningWindowStart) private var morningWindowStart = CheckInWindowDefaults.morningStart
    @AppStorage(SettingsKeys.morningWindowEnd) private var morningWindowEnd = CheckInWindowDefaults.morningEnd
    @AppStorage(SettingsKeys.eveningWindowStart) private var eveningWindowStart = CheckInWindowDefaults.eveningStart
    @AppStorage(SettingsKeys.eveningWindowEnd) private var eveningWindowEnd = CheckInWindowDefaults.eveningEnd

    @State private var path = NavigationPath()
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var activeFlow: Period?
    @State private var showReflect = false
    @State private var showSettings = false
    @State private var showSmiles = false
    @State private var showCalendar = false
    @State private var hasAutoLaunched = false
    /// Bookkeeping only, to detect a day rollover while the app sits open or
    /// backgrounded — see `refreshForNewDayIfNeeded()`. Everything else that
    /// needs "today" uses the live `today` computed property below.
    @State private var lastKnownToday = Calendar.current.startOfDay(for: .now)

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var isViewingToday: Bool { selectedDate == today }

    private var streak: Int {
        StreakEngine.currentStreak(checkIns: checkIns)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(spacing: 16) {
                        dateNav

                        dayCard(for: .morning)
                        dayCard(for: .evening)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Anytime")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        StatusCardView(
                            icon: "clock.arrow.circlepath",
                            tint: Theme.reflect,
                            title: "Reflect",
                            subtitle: "Revisit a day from your past — morning and evening, together",
                            isComplete: false
                        ) { showReflect = true }

                        StatusCardView(
                            icon: "face.smiling",
                            tint: Theme.smile,
                            title: "Smiles",
                            subtitle: "See who you've smiled at, and who's smiled at you",
                            isComplete: false
                        ) { showSmiles = true }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Gratitude")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(streak)")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .fixedSize()
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(streak) day streak")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: CheckIn.self) { checkIn in
                CheckInDetailView(checkIn: checkIn)
            }
            .sheet(item: $activeFlow) { period in
                CheckInFlowView(period: period)
            }
            .sheet(isPresented: $showReflect) {
                ReflectView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showSmiles) {
                SmilesView()
            }
            .sheet(isPresented: $showCalendar) {
                CalendarPickerView(selectedDate: $selectedDate, checkIns: checkIns)
            }
            .task {
                autoLaunchIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { refreshForNewDayIfNeeded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                refreshForNewDayIfNeeded()
            }
        }
    }

    /// Called on returning to the foreground and on the system's own
    /// day-changed notification (covers both "backgrounded overnight" and
    /// the rarer "left open straight through midnight" case). Without this,
    /// `selectedDate`/`hasAutoLaunched` stay frozen on the day the view was
    /// first created, so a long-lived session would show stale "Today"
    /// labels and incorrectly lock today's actual Morning/Evening cards.
    private func refreshForNewDayIfNeeded() {
        let currentToday = today
        guard currentToday != lastKnownToday else { return }

        if selectedDate == lastKnownToday {
            selectedDate = currentToday
        }
        lastKnownToday = currentToday
        hasAutoLaunched = false
        autoLaunchIfNeeded()
    }

    private var dateNav: some View {
        HStack {
            Button {
                Haptic.selection()
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")

            Spacer()

            Button {
                Haptic.selection()
                showCalendar = true
            } label: {
                Text(dateLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open calendar")

            Spacer()

            Button {
                guard !isViewingToday else { return }
                Haptic.selection()
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(isViewingToday ? Color(.tertiaryLabel) : Color.primary)
            }
            .buttonStyle(.plain)
            .disabled(isViewingToday)
            .accessibilityLabel("Next day")
        }
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        if isViewingToday { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), selectedDate == yesterday {
            return "Yesterday"
        }
        let sameYear = calendar.component(.year, from: selectedDate) == calendar.component(.year, from: today)
        return selectedDate.formatted(
            .dateTime.weekday(.wide).month(.wide).day()
                .year(sameYear ? .omitted : .defaultDigits)
        )
    }

    private func windowState(for period: Period) -> CheckInWindowState {
        switch period {
        case .morning: CheckInWindow.state(start: morningWindowStart, end: morningWindowEnd)
        case .evening: CheckInWindow.state(start: eveningWindowStart, end: eveningWindowEnd)
        }
    }

    @ViewBuilder
    private func dayCard(for period: Period) -> some View {
        let checkIn = checkIns.first { $0.period == period && $0.date == selectedDate }
        let state = windowState(for: period)
        let canStart = isViewingToday && state == .open

        StatusCardView(
            icon: period.symbolName,
            tint: period.tint,
            title: period.title,
            subtitle: subtitle(for: period, checkIn: checkIn, windowState: state),
            isComplete: checkIn != nil,
            isDisabled: checkIn == nil && !canStart
        ) {
            if let checkIn {
                path.append(checkIn)
            } else if canStart {
                activeFlow = period
            }
        }
    }

    private func subtitle(for period: Period, checkIn: CheckIn?, windowState: CheckInWindowState) -> String {
        if let checkIn {
            return checkIn.sortedResponses.first { $0.answerKindTag != .scale }?.displaySummary ?? "Completed"
        }
        guard isViewingToday else { return "Not completed" }

        switch windowState {
        case .tooLate:
            return period == .morning ? "Missed this morning — see you tomorrow" : "Missed this evening — see you tomorrow"
        case .tooEarly:
            let opensAt = period == .morning ? morningWindowStart : eveningWindowStart
            return "Opens at \(Self.timeLabel(secondsSinceMidnight: opensAt))"
        case .open:
            return period == .morning ? "Set your intention for today" : "Reflect before you sleep"
        }
    }

    private static func timeLabel(secondsSinceMidnight: TimeInterval) -> String {
        let date = Calendar.current.startOfDay(for: .now).addingTimeInterval(secondsSinceMidnight)
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func autoLaunchIfNeeded() {
        guard !hasAutoLaunched else { return }
        hasAutoLaunched = true

        let period: Period?
        if windowState(for: .morning) == .open {
            period = .morning
        } else if windowState(for: .evening) == .open {
            period = .evening
        } else {
            period = nil
        }

        guard let period else { return }
        let alreadyDone = checkIns.contains { $0.period == period && $0.date == today }
        if !alreadyDone {
            activeFlow = period
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [CheckIn.self, QuestionResponse.self, Smile.self], inMemory: true)
}
