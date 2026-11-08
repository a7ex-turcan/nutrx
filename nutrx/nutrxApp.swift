import AppIntents
import SwiftUI
import UserNotifications
import SwiftData

@main
struct nutrxApp: App {
    let modelContainer = ModelContainerFactory.create()
    /// nutrx Pro, from StoreKit. Created at launch so it hears `Transaction.updates` from the start.
    @State private var proAccess = ProAccess()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Siri and Shortcuts intents run in this process and use the app's store, not a second container.
        let container = modelContainer
        AppDependencyManager.shared.add(dependency: container)
        // Here too, not only on .active: Siri can launch the app in the background to log a stack.
        if StackLogging.repairDuplicateIDs(context: container.mainContext) {
            NutrxShortcuts.updateAppShortcutParameters()  // phrases registered with the old shared id
        }
        // Two devices that turned on the same How you feel preset before syncing (#133).
        FeelingQuestions.mergeDuplicatePresets(in: container.mainContext)
        // Refill reminder actions (Refilled, Remind me tomorrow) and taps; actions can arrive with the app in the
        // background.
        NotificationHandler.shared.container = container
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        NotificationHandler.registerCategories()
        // A control's tap that opens the app (#138) lands here, as a link would.
        OpenNutrxIntent.openLink = { NotificationRouter.shared.open($0) }
        #if DEBUG
        if ScreenshotDemoData.isRequested {
            ScreenshotDemoData.replaceStore(in: modelContainer.mainContext)
        }
        ScheduleDebug.apply(to: modelContainer.mainContext)  // until the Schedule sheet exists (#132)
        DosePlanDebug.apply(to: modelContainer.mainContext)  // a plan by name, without the sheet (#135)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The window's width class for large-screen layouts (#151); sheets inherit it.
                .measuresWidthClass()
                .environment(proAccess)
                .environment(NotificationRouter.shared)
                // Widget and control taps (docs/pro/WIDGETS.md §5); a link the app doesn't know opens Today.
                .onOpenURL { url in NotificationRouter.shared.open(AppLink(url) ?? .today) }
                .task {
                    await proAccess.refreshEntitlement()
                    syncWithPro()
                }
                .onChange(of: proAccess.isPro) {
                    // Becoming Pro (or lapsing) adds or removes refill reminders, resumes or holds dose plans, and
                    // puts back the default app icon.
                    NotificationService.refreshAllNutrientReminders(context: modelContainer.mainContext)
                    syncWithPro()
                }
        }
        .modelContainer(modelContainer)
        // Rolls the per-date dose-reminder window forward without the app being opened (#4).
        .backgroundTask(.appRefresh(NotificationService.reminderRefreshTaskID)) { [modelContainer, proAccess] in
            // Pro decides whether refill reminders stay, so check it before syncing.
            await proAccess.refreshEntitlement()
            await NotificationService.refreshRemindersInBackground(container: modelContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // A subscription that lapses sends no `Transaction.updates`, so look again whenever the app comes back.
                Task {
                    await proAccess.refreshEntitlement()
                    syncWithPro()
                }
                StackLogging.repairDuplicateIDs(context: modelContainer.mainContext)
                FeelingQuestions.mergeDuplicatePresets(in: modelContainer.mainContext)
                WidgetReload.all()
                // Siri's "Log my <nutrient>" phrases use the current nutrient names.
                NutrxShortcuts.updateAppShortcutParameters()
            } else if newPhase == .background {
                // Renames and other edits made in the app reach the widgets and controls.
                WidgetReload.all()
            }
        }
    }

    /// What follows Pro, only after a check that knows whether it's active:
    /// - Dose plans hold without Pro and resume with it (#135, `DosePlanHold`). A stopping plan's hold or resume moves
    ///   its course end, the reminders' last day, so they're rebuilt then.
    /// - An alternate app icon goes back to the default without Pro (#139); iOS says so in its own alert.
    private func syncWithPro() {
        guard ProAccess.isStoreVisible, proAccess.hasCheckedEntitlements else { return }
        if DosePlanHold.sync(isPro: proAccess.isPro, context: modelContainer.mainContext) {
            NotificationService.refreshAllNutrientReminders(context: modelContainer.mainContext)
        }
        // Once: a lapse found on becoming active runs this from the check and from `onChange(of: isPro)`.
        if !Self.resettingAppIcon,
           AppIconChoice.shouldReset(alternateIconName: UIApplication.shared.alternateIconName, isPro: proAccess.isPro) {
            Self.resettingAppIcon = true
            Task {
                try? await UIApplication.shared.setAlternateIconName(nil)
                Self.resettingAppIcon = false
            }
        }
    }

    /// An app icon reset in flight (#139).
    private static var resettingAppIcon = false
}
