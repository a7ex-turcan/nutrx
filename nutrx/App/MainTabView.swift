import SwiftUI
import SwiftData

struct MainTabView: View {
    enum TabID: Hashable { case today, nutrients, stacks, history }

    @State private var selection: TabID = .today
    @Environment(NotificationRouter.self) private var router: NotificationRouter?
    @Environment(\.widthClass) private var widthClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Covers the brief visit to the split-view tabs at launch (`prepareSplitViewTabs`).
    @State private var preparingSplitViews = false
    @State private var preparedSplitViews = false
    /// A tab a notification or Today's links chose while the cover was up: where the visit ends instead of the start.
    @State private var routedTab: TabID?

    /// Whether My Nutrients and History show split views: the same rule as theirs (`usesSplitView`).
    private var showsSplitViews: Bool {
        guard widthClass != .compact, horizontalSizeClass == .regular else { return false }
        return !(dynamicTypeSize.isAccessibilitySize && widthClass == .regular)
    }

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
        // History leaves a recap notification's flag alone during the visit, so the route is seen here first.
        .environment(\.isPreparingSplitViews, preparingSplitViews)
        .overlay {
            if preparingSplitViews {
                Theme.surfaceGround.ignoresSafeArea()
            }
        }
        // Keyed on whether there are split views: false until the window has been measured (the width class starts
        // compact), and it can become true later (a larger window, a smaller text size).
        .task(id: showsSplitViews) { await prepareSplitViewTabs() }
        // A refill reminder opens that nutrient's analytics (My Nutrients pushes it).
        .onChange(of: router?.supplyNutrientID) { _, id in
            if id != nil { route(to: .nutrients) }
        }
        // Today's Apple Health card opens a nutrient's analytics at its Health card.
        .onChange(of: router?.healthNutrientID) { _, id in
            if id != nil { route(to: .nutrients) }
        }
        // Widget and control links (docs/pro/WIDGETS.md §5). Initial too: a tap can cold-launch the app with the link
        // already followed.
        .onChange(of: router?.linkedTab, initial: true) { _, tab in
            guard let tab else { return }
            route(to: tab == .today ? .today : .nutrients)
            router?.linkedTab = nil
        }
        .onChange(of: router?.nutrientID, initial: true) { _, id in
            if id != nil { route(to: .nutrients) }
        }
        .onChange(of: router?.showsPaywall, initial: true) { _, shows in
            if shows == true { route(to: .today) }
        }
        #if DEBUG
        // `-screenshotRoute` (#218): the tab here, the screen in it from there.
        .task {
            guard let screenshot = ScreenshotRoute.requested else { return }
            router?.screenshotRoute = screenshot
            switch screenshot {
            case .today, .paywall: route(to: .today)
            case .nutrients, .nutrient: route(to: .nutrients)
            case .stacks: route(to: .stacks)
            case .history, .historyDay: route(to: .history)
            }
        }
        #endif
        // Today's stacks row "Edit" opens the Stacks tab.
        .onChange(of: router?.showsStacks) { _, shows in
            if shows == true {
                route(to: .stacks)
                router?.showsStacks = false
            }
        }
        // A recap notification opens the recap (History pushes it).
        .onChange(of: router?.showsRecap) { _, shows in
            if shows == true { route(to: .history) }
        }
    }

    /// iPad only: shows My Nutrients and History once, under a cover, then goes back to where the app opened. The
    /// first time a tab holding a `NavigationSplitView` came up, iPadOS laid it out 64 pt too low, under an opaque
    /// band with a small title (and History's recap push added 44 pt); a split view shown before is laid out
    /// right, even a bare one with a plain list (#196). A frame per tab is enough; the cover stays up as long as
    /// building them takes (about a second on an iPad in a Debug build).
    private func prepareSplitViewTabs() async {
        guard !preparedSplitViews, showsSplitViews else { return }
        preparingSplitViews = true
        defer { preparingSplitViews = false }
        let start = selection
        // Read before the visit: showing My Nutrients can open a refill reminder's analytics and clear its flag.
        let routeBefore = routeSetBeforeAppearing
        routedTab = nil
        for tab in [TabID.nutrients, .history] where tab != start {
            selection = tab
            try? await Task.sleep(for: .milliseconds(16))
            // Cancelled when the window settles into another class mid-visit: back to where it was, and the next
            // run does the visit again.
            if Task.isCancelled {
                selection = routedTab ?? routeBefore ?? start
                return
            }
        }
        // A notification routed during the cover (a recap, a refill reminder) wins over where the app opened; a flag
        // set before this view appeared never fired `onChange`, so they're checked too.
        let target = routedTab ?? routeBefore ?? routeSetBeforeAppearing ?? start
        // A launch routed to a split-view tab (a recap notification opens History, a refill reminder My Nutrients)
        // came up with that tab's sidebar title collapsed and its content 52 pt down when the visit was left on it
        // (#201). Stepping off to Today for a frame first lays it out as when tapped. What matters is that it's shown
        // again, not the time: one frame did it on every launch on the 13-inch iPad simulator, as did 300 ms.
        if target == .nutrients || target == .history {
            selection = .today
            try? await Task.sleep(for: .milliseconds(16))
            if Task.isCancelled {
                selection = routedTab ?? target
                return
            }
        }
        // A route that came in meanwhile wins, as during the visit.
        selection = routedTab ?? target
        try? await Task.sleep(for: .milliseconds(16))
        if Task.isCancelled {
            if let routedTab { selection = routedTab }
            return
        }
        preparedSplitViews = true
        // One that came in during that last frame: `route(to:)` only records it while the cover is up.
        if let routedTab, routedTab != selection { selection = routedTab }
    }

    /// The tab a notification's flag asks for when it was set before this view appeared: a recap opens History; a
    /// refill reminder or Today's Health card opens My Nutrients.
    private var routeSetBeforeAppearing: TabID? {
        if router?.showsRecap == true { return .history }
        if router?.supplyNutrientID != nil || router?.healthNutrientID != nil || router?.nutrientID != nil {
            return .nutrients
        }
        if router?.showsPaywall == true { return .today }
        return nil
    }

    /// Switches tab for a notification or one of Today's links. While the launch cover is up it's only recorded, and
    /// the visit ends there: switching at once would show a split-view tab straight after the visit (#201).
    private func route(to tab: TabID) {
        if preparingSplitViews {
            routedTab = tab
        } else {
            selection = tab
        }
    }
}

extension EnvironmentValues {
    /// True while `MainTabView` briefly shows the split-view tabs at launch (#196): screens hold off on consuming a
    /// notification's route until it's done.
    @Entry var isPreparingSplitViews = false
}

#Preview {
    MainTabView()
        .modelContainer(previewContainer)
}
