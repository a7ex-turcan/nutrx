import AppIntents
import SwiftData
import SwiftUI

/// Settings → Siri & Shortcuts (#127): what to say to Siri for each nutrient on Today and each stack, ready as they
/// are with no setup, and a link to nutrx's actions in the Shortcuts app. Before this, the stack detail's Siri tip was
/// the only place a phrase showed.
struct SiriSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogStack.sortOrder) private var stacks: [LogStack]
    /// Today's nutrients in Today's order, as Siri suggests them (`NutrientEntityQuery`).
    @State private var nutrients: [Nutrient] = []

    /// Stacks with something to log: the ones Siri suggests.
    private var loggableStacks: [LogStack] {
        stacks.filter { !StackLogging.activeEntries(of: $0).isEmpty }
    }

    var body: some View {
        List {
            Section {
                Text("Ask Siri to log without opening nutrx. These work as they are, with no setup.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Color.clear)
                    // Lined up with the section headers and footers below.
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
            }

            if !nutrients.isEmpty {
                Section {
                    ForEach(nutrients, id: \.persistentModelID) { nutrient in
                        phraseRow(NutrientShortcutLogging.siriPhrase(for: nutrient.name)) {
                            NutrientIconTile(nutrient: nutrient, size: 32)
                        }
                    }
                } header: {
                    Text("Nutrients")
                } footer: {
                    Text("Siri logs one step. In the Shortcuts app, Log Nutrient can log an amount too.")
                }
                .listRowBackground(Theme.surfaceCard)
            }

            if !loggableStacks.isEmpty {
                Section("Stacks") {
                    ForEach(loggableStacks, id: \.persistentModelID) { stack in
                        phraseRow(StackShortcutLogging.siriPhrase(for: stack.name)) {
                            NutrientIconTile(glyph: Theme.onForestPrimary, background: Theme.forest,
                                             symbolName: "square.stack.3d.up", size: 32)
                        }
                    }
                }
                .listRowBackground(Theme.surfaceCard)
            }

            Section {
                ShortcutsLink()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Add nutrx's actions to an automation, a Home Screen shortcut or the Action button.")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .onAppear { nutrients = NutrientEntityQuery.activeNutrients(in: modelContext) }
    }

    /// A phrase in quotes beside its tile. A long press copies the whole phrase (selectable text picked a single word).
    private func phraseRow(_ phrase: String, @ViewBuilder tile: () -> some View) -> some View {
        HStack(spacing: 12) {
            tile()
            Text("“\(phrase)”")
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = phrase }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Copy") { UIPasteboard.general.string = phrase }
    }
}

#Preview {
    NavigationStack {
        SiriSettingsView()
            .navigationTitle("Siri & Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(previewContainer)
}
