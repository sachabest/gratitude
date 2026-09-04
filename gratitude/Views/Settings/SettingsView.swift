import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.morningReminderEnabled) private var morningReminderEnabled = false
    @AppStorage(SettingsKeys.eveningReminderEnabled) private var eveningReminderEnabled = false
    @AppStorage(SettingsKeys.morningReminderTime) private var morningReminderSeconds: Double = 8 * 3600
    @AppStorage(SettingsKeys.eveningReminderTime) private var eveningReminderSeconds: Double = 21 * 3600
    @AppStorage(SettingsKeys.cloudBackupEnabled) private var cloudBackupEnabled = false
    @AppStorage(SettingsKeys.userDisplayName) private var userDisplayName = ""

    @State private var iCloudStatusText = "Checking…"
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var showNotificationDeniedAlert = false
    @State private var exportURL: URL?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $userDisplayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Smiles")
                } footer: {
                    Text("Shown to whoever you send a smile to. Defaults to this device's name if left blank.")
                }

                Section("Reminders") {
                    Toggle(isOn: $morningReminderEnabled) {
                        Label("Morning reminder", systemImage: Period.morning.symbolName)
                    }
                    .tint(Theme.morning)
                    .onChange(of: morningReminderEnabled) { _, enabled in
                        updateReminder(enabled: enabled, period: .morning)
                    }

                    if morningReminderEnabled {
                        DatePicker("Time", selection: morningTimeBinding, displayedComponents: .hourAndMinute)
                            .onChange(of: morningReminderSeconds) { _, _ in
                                updateReminder(enabled: true, period: .morning)
                            }
                    }

                    Toggle(isOn: $eveningReminderEnabled) {
                        Label("Evening reminder", systemImage: Period.evening.symbolName)
                    }
                    .tint(Theme.evening)
                    .onChange(of: eveningReminderEnabled) { _, enabled in
                        updateReminder(enabled: enabled, period: .evening)
                    }

                    if eveningReminderEnabled {
                        DatePicker("Time", selection: eveningTimeBinding, displayedComponents: .hourAndMinute)
                            .onChange(of: eveningReminderSeconds) { _, _ in
                                updateReminder(enabled: true, period: .evening)
                            }
                    }
                }

                Section {
                    Toggle(isOn: $cloudBackupEnabled) {
                        Label("Encrypted iCloud Backup", systemImage: "icloud")
                    }
                    .tint(Theme.reflect)
                    .onChange(of: cloudBackupEnabled) { _, enabled in
                        handleBackupToggle(enabled)
                    }

                    HStack {
                        Text("iCloud status")
                        Spacer()
                        Text(iCloudStatusText)
                            .foregroundStyle(.secondary)
                    }

                    if cloudBackupEnabled {
                        Button {
                            syncNow()
                        } label: {
                            if isSyncing {
                                ProgressView()
                            } else {
                                Text("Sync Now")
                            }
                        }
                        .disabled(isSyncing)

                        Button("Restore from iCloud") {
                            restoreNow()
                        }
                        .disabled(isSyncing)

                        if let syncMessage {
                            Text(syncMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Your entries are encrypted on this device before they're backed up. Apple and iCloud only ever see unreadable ciphertext — the key stays in your device's Keychain and syncs privately via iCloud Keychain.")
                }

                Section("History") {
                    NavigationLink("Browse all entries") {
                        HistoryListView()
                    }
                }

                Section("Data & Privacy") {
                    if let exportURL {
                        ShareLink("Export my data", item: exportURL)
                    } else {
                        Text("Preparing export…")
                            .foregroundStyle(.secondary)
                    }

                    Button("Delete all data", role: .destructive) {
                        showDeleteConfirmation = true
                    }

                    Text("Everything you enter stays on this device unless you turn on encrypted backup above. Nothing is ever sent anywhere unencrypted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await refreshICloudStatus()
                exportURL = makeExportFile()
            }
            .alert("Notifications not allowed", isPresented: $showNotificationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable notifications for Gratitude in Settings to get reminders.")
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every check-in on this device. This can't be undone.")
            }
        }
    }

    private var morningTimeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromSecondsSinceMidnight: morningReminderSeconds) },
            set: { morningReminderSeconds = Self.secondsSinceMidnight(from: $0) }
        )
    }

    private var eveningTimeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromSecondsSinceMidnight: eveningReminderSeconds) },
            set: { eveningReminderSeconds = Self.secondsSinceMidnight(from: $0) }
        )
    }

    private static func date(fromSecondsSinceMidnight seconds: Double) -> Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(seconds)
    }

    private static func secondsSinceMidnight(from date: Date) -> Double {
        date.timeIntervalSince(Calendar.current.startOfDay(for: date))
    }

    private func updateReminder(enabled: Bool, period: Period) {
        if enabled {
            Task {
                let granted = await NotificationScheduler.requestAuthorizationIfNeeded()
                guard granted else {
                    if period == .morning { morningReminderEnabled = false } else { eveningReminderEnabled = false }
                    showNotificationDeniedAlert = true
                    return
                }
                let seconds = period == .morning ? morningReminderSeconds : eveningReminderSeconds
                let components = Calendar.current.dateComponents([.hour, .minute], from: Self.date(fromSecondsSinceMidnight: seconds))
                if period == .morning {
                    NotificationScheduler.scheduleMorningReminder(at: components)
                } else {
                    NotificationScheduler.scheduleEveningReminder(at: components)
                }
            }
        } else {
            if period == .morning {
                NotificationScheduler.cancelMorningReminder()
            } else {
                NotificationScheduler.cancelEveningReminder()
            }
        }
    }

    private func refreshICloudStatus() async {
        let status = await CloudBackupService.shared.accountStatus()
        iCloudStatusText = switch status {
        case .available: "Signed in"
        case .noAccount: "Not signed in"
        case .restricted: "Restricted"
        case .temporarilyUnavailable: "Temporarily unavailable"
        case .couldNotDetermine: "Unknown"
        @unknown default: "Unknown"
        }
    }

    private func handleBackupToggle(_ enabled: Bool) {
        guard enabled else { return }
        Task {
            await refreshICloudStatus()
            let status = await CloudBackupService.shared.accountStatus()
            guard status == .available else {
                cloudBackupEnabled = false
                syncMessage = "Sign in to iCloud to enable backup."
                return
            }
            syncNow()
        }
    }

    private func syncNow() {
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                let count = try await CloudBackupService.shared.backupAll(context: modelContext)
                syncMessage = "Backed up \(count) entries just now."
            } catch {
                syncMessage = error.localizedDescription
            }
        }
    }

    private func restoreNow() {
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                let count = try await CloudBackupService.shared.restoreAll(context: modelContext)
                syncMessage = count > 0 ? "Restored \(count) entries." : "You're already up to date."
                exportURL = makeExportFile()
            } catch {
                syncMessage = error.localizedDescription
            }
        }
    }

    private func makeExportFile() -> URL? {
        struct Export: Codable {
            var checkIns: [CheckInDTO]
            var smiles: [SmileDTO]
        }
        guard let checkIns = try? modelContext.fetch(FetchDescriptor<CheckIn>()) else { return nil }
        let smiles = (try? modelContext.fetch(FetchDescriptor<Smile>())) ?? []
        let export = Export(
            checkIns: checkIns.map { CheckInDTO(from: $0) },
            smiles: smiles.map { SmileDTO(from: $0) }
        )
        guard let data = try? JSONEncoder().encode(export) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gratitude-export.json")
        try? data.write(to: url, options: .atomic)
        return url
    }

    private func deleteAllData() {
        if let checkIns = try? modelContext.fetch(FetchDescriptor<CheckIn>()) {
            for checkIn in checkIns { modelContext.delete(checkIn) }
        }
        if let smiles = try? modelContext.fetch(FetchDescriptor<Smile>()) {
            for smile in smiles { modelContext.delete(smile) }
        }
        try? modelContext.save()
        exportURL = makeExportFile()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [CheckIn.self, QuestionResponse.self, Smile.self], inMemory: true)
}
