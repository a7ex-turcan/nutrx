import SwiftUI
import SwiftData

/// Settings → How you feel (#133, docs/pro/HOW-YOU-FEEL.md §2): the switch, when Today asks, and the questions —
/// the card's in order (drag to reorder, swipe to remove, tap one of your own to edit it), then the presets left and
/// a question of your own.
struct HowYouFeelSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The symbols' column, so every title starts at the same place.
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28
    @Query private var allPreferences: [UserPreferences]
    @Query(sort: [SortDescriptor(\FeelingQuestion.sortOrder), SortDescriptor(\FeelingQuestion.createdAt)])
    private var questions: [FeelingQuestion]
    @State private var sheet: QuestionSheet?
    @State private var showDeniedAlert = false

    /// The question sheet: a new one of your own, or one to edit.
    private enum QuestionSheet: Identifiable {
        case new
        case edit(FeelingQuestion)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let question): "\(question.persistentModelID.hashValue)"
            }
        }
    }

    private var preferences: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    private var active: [FeelingQuestion] { questions.filter { !$0.isRemoved } }

    var body: some View {
        List {
            Section {
                Toggle("How you feel", isOn: Binding(
                    get: { preferences.feelingsEnabled },
                    set: { turnOn in
                        preferences.feelingsEnabled = turnOn
                        if turnOn { FeelingQuestions.setUpIfNeeded(in: modelContext) }
                        try? modelContext.save()
                        NotificationService.refreshFeelingsReminder(context: modelContext)
                    }
                ))
            } footer: {
                Text(FeelingText.intro)
            }
            .listRowBackground(Theme.surfaceCard)

            if preferences.feelingsEnabled {
                Section {
                    DatePicker("Ask from", selection: askTime, displayedComponents: .hourAndMinute)
                    Toggle("Remind me", isOn: Binding(
                        get: { preferences.feelingsReminderEnabled },
                        set: { $0 ? turnOnReminder() : setReminder(false) }
                    ))
                } footer: {
                    Text(FeelingText.askFromFooter)
                }
                .listRowBackground(Theme.surfaceCard)

                questionsSection
                addSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .tint(Theme.controlPrimary)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .new: FeelingQuestionSheet(question: nil)
            case .edit(let question): FeelingQuestionSheet(question: question)
            }
        }
        // The questions name themselves in the reminder.
        .onDisappear { NotificationService.refreshFeelingsReminder(context: modelContext) }
        .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've previously denied notification permissions for nutrx. To be reminded, please turn on "
                 + "notifications in your device settings.")
        }
    }

    /// Asks for notifications the first time, as the other reminders do.
    private func turnOnReminder() {
        Task {
            switch await NotificationService.permissionStatus() {
            case .notDetermined:
                if await NotificationService.requestPermission() { setReminder(true) }
            case .granted:
                setReminder(true)
            case .denied:
                showDeniedAlert = true
            }
        }
    }

    private func setReminder(_ on: Bool) {
        preferences.feelingsReminderEnabled = on
        try? modelContext.save()
        NotificationService.refreshFeelingsReminder(context: modelContext)
    }

    private var questionsSection: some View {
        Section {
            ForEach(active, id: \.persistentModelID) { question in
                questionRow(question)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.unlessReduceMotion(reduceMotion)) {
                                FeelingQuestions.remove(question, in: modelContext)
                            }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .tint(.red)  // the list's tint would make it green
                    }
            }
            .onMove { source, destination in
                FeelingQuestions.move(fromOffsets: source, toOffset: destination, in: modelContext)
            }
        } header: {
            Text("Questions")
        } footer: {
            Text(active.isEmpty ? "No questions yet. Add one below." : FeelingText.questionsFooter)
        }
        .listRowBackground(Theme.surfaceCard)
    }

    /// A preset reads as it is; your own opens its sheet.
    @ViewBuilder
    private func questionRow(_ question: FeelingQuestion) -> some View {
        let label = rowLabel(title: question.displayTitle, symbol: question.symbolName,
                             caption: FeelingText.caption(question))
        if question.preset == nil {
            Button { sheet = .edit(question) } label: {
                HStack {
                    label
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edits the question")
        } else {
            label
        }
    }

    private var addSection: some View {
        let ownCount = FeelingQuestions.ownCount(of: active)
        return Section {
            ForEach(FeelingQuestions.presetsToAdd(besides: active), id: \.self) { preset in
                Button {
                    withAnimation(.unlessReduceMotion(reduceMotion)) {
                        FeelingQuestions.add(preset, in: modelContext)
                    }
                } label: {
                    HStack {
                        rowLabel(title: preset.title, symbol: preset.symbolName,
                                 caption: FeelingText.caption(kind: preset.kind, ends: preset.ends))
                        Spacer()
                        addSymbol
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(preset.title)")
            }
            Button { sheet = .new } label: {
                HStack {
                    rowLabel(title: "Your own question", symbol: "text.bubble", caption: FeelingText.ownCaption)
                    Spacer()
                    addSymbol
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(ownCount >= FeelingQuestions.ownLimit)
            .accessibilityLabel("Add your own question")
        } header: {
            Text("Add a question")
        } footer: {
            Text(FeelingText.addFooter(ownCount: ownCount))
        }
        .listRowBackground(Theme.surfaceCard)
    }

    /// At accessibility sizes the symbol goes, as in My Nutrients, so the words keep the row's width.
    private func rowLabel(title: String, symbol: String, caption: String) -> some View {
        HStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(Theme.SettingsTile.pink)
                    .frame(width: symbolWidth)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var addSymbol: some View {
        Image(systemName: "plus.circle.fill")
            .font(.title3)
            .foregroundStyle(Theme.controlPrimary)
            .accessibilityHidden(true)
    }

    /// The time Today starts asking, as a picker's date today.
    private var askTime: Binding<Date> {
        Binding(get: {
            let minutes = preferences.feelingsAskMinutes
            return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            preferences.feelingsAskMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            try? modelContext.save()
            NotificationService.refreshFeelingsReminder(context: modelContext)
        })
    }
}

#Preview {
    NavigationStack {
        HowYouFeelSettingsView()
            .navigationTitle("How you feel")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(previewContainer)
}
