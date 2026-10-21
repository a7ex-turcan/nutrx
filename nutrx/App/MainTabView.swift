import SwiftUI
import SwiftData

struct MainTabView: View {
    enum TabID: Hashable { case today, nutrients, stacks, history }

    @State private var selection: TabID = .today
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Environment(\.widthClass) private var widthClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Covers the brief visit to the split-view tabs at launch (`prepareSplitViewTabs`).
    @State private var preparingSplitViews = false
    @State private var preparedSplitViews = false

    var body: some View {
        TabView(selection: $selection) {
            // Icons and labels from the design (Main.dc.html): rings for Today, a leaf for Nutrients, a calendar
            // for History. The Nutrients screen keeps its "My Nutrients" title.
            Tab("Today", systemImage: "circle.circle", value: TabID.today) {
                NavigationStack {
                    TodayView()
                        .navigationTitle("Today")
                        .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .navigationBarTitleDisplayMode(.large)
                        .withProfileMenu()
                }
            }

            Tab("Nutrients", systemImage: "leaf", value: TabID.nutrients) {
                NutrientsListView()
            }

            // Stacks have their own tab: something you build, like nutrients, and used daily from Today.
            Tab("Stacks", systemImage: "square.stack.3d.up", value: TabID.stacks) {
                NavigationStack {
                    // The profile menu is added inside, so + sits before the avatar.
                    StacksView()
                }
            }

            Tab("History", systemImage: "calendar", value: TabID.history) {
                // Its own navigation: a stack on iPhone, a split view (calendar and day) on large screens (#154).
                HistoryListView()
            }

        }
        .overlay {
            if preparingSplitViews {
                Theme.surfaceGround.ignoresSafeArea()
            }
        }
        // Keyed on the width class: it's compact until the window has been measured.
        .task(id: widthClass) { await prepareSplitViewTabs() }
        // A refill reminder opens that nutrient's analytics (My Nutrients pushes it).
        .onChange(of: router?.supplyNutrientID) { _, id in
            if id != nil { selection = .nutrients }
        }
        // Today's Apple Health card opens a nutrient's analytics at its Health card.
        .onChange(of: router?.healthNutrientID) { _, id in
            if id != nil { selection = .nutrients }
        }
        // Today's stacks row "Edit" opens the Stacks tab.
        .onChange(of: router?.showsStacks) { _, shows in
            if shows == true {
                selection = .stacks
                router?.showsStacks = false
            }
        }
        // A recap notification opens the recap (History pushes it).
        .onChange(of: router?.showsRecap) { _, shows in
            if shows == true { selection = .history }
        }
    }

    /// iPad only: shows My Nutrients and History once, under a cover, then goes back to where the app opened. The
    /// first time a tab holding a `NavigationSplitView` came up, iPadOS laid it out 64 pt too low, under an opaque
    /// band with a small title (and History's recap push added 44 pt); a split view shown before is laid out
    /// right, even a bare one with a plain list (#196). A frame per tab is enough; the cover stays up as long as
    /// building them takes (about a second on an iPad in a Debug build).
    private func prepareSplitViewTabs() async {
        guard !preparedSplitViews, widthClass != .compact, horizontalSizeClass == .regular else { return }
        preparedSplitViews = true
        preparingSplitViews = true
        let start = selection
        for tab in [TabID.nutrients, .history] where tab != start {
            selection = tab
            try? await Task.sleep(for: .milliseconds(16))
        }
        selection = start
        try? await Task.sleep(for: .milliseconds(16))
        preparingSplitViews = false
    }
}

#Preview {
    MainTabView()
        .modelContainer(previewContainer)
}
