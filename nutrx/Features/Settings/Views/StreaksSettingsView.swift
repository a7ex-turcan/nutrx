import SwiftUI
import SwiftData

/// Settings → Streaks: the on/off toggle.
struct StreaksSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]

    private var preferences: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { preferences.streaksEnabled },
                    set: { preferences.streaksEnabled = $0 }
                )) {
                    Text("Track streaks")
                }
            } footer: {
                Text("Show your daily completion streak on the Today and History screens.")
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
    }
}

#Preview {
    NavigationStack {
        StreaksSettingsView()
            .navigationTitle("Streaks")
    }
    .modelContainer(previewContainer)
}
