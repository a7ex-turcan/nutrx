import SwiftUI
import SwiftData

/// Second onboarding screen (DESIGN.md §5.8): back, progress, Skip; "What do you want to track first?"; a grid of
/// starting points and "Something else". A starting point fills in the name, unit and look and shows empty goal / step
/// fields above Start tracking for the user's own amounts (none are suggested) — at accessibility sizes, below the picked
/// card instead. Nothing is created until Start tracking is tapped.
struct OnboardingFirstNutrientView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: OnboardingViewModel
    let onBack: () -> Void

    @State private var showCustomForm = false
    /// One draft for the screen's lifetime — reset, never replaced, so the form and its save action always share it.
    @State private var customDraft = NutrientDraft()
    @FocusState private var focusedField: GoalField?

    private enum GoalField: Hashable {
        case target, upperBound, step
    }

    private var draft: NutrientDraft { viewModel.draft }
    private static let valueFont = Font.system(.title3, design: .rounded, weight: .bold)
    /// One id per starting point: with a single shared id, a newly picked card showed the previous card's fields
    /// (their labels and unit) under it.
    private static func goalSectionID(_ point: StartingPoint) -> String { "goalSection-\(point.id)" }

    /// At accessibility sizes the goal fields stack, and stacked they don't fit in the pinned panel above the keyboard:
    /// with a range it reached over the top bar, and past the top of the screen at the largest sizes (#40). There they
    /// scroll with the content, right below the picked starting point, and the panel keeps Done and Start tracking.
    private var fieldsInContent: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                        .padding(.bottom, 24)

                    Text("What do you want to track first?")
                        .font(.system(.largeTitle, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a starting point or make your own. You set the amounts.")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    // One column at accessibility sizes, in a plain stack: in a lazy grid, picking another card
                    // after scrolling made the list jump back to where the last pick had left it before scrolling
                    // to the new fields.
                    if fieldsInContent {
                        VStack(spacing: Theme.Spacing.cardGap) { startingPoints }
                    } else {
                        LazyVGrid(columns: Self.columns, spacing: Theme.Spacing.cardGap) { startingPoints }
                    }

                    somethingElse
                        .padding(.top, Theme.Spacing.cardGap)
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { bottomPanel }
            // Fields in the content: line the picked starting point's fields up with the bottom of the visible area,
            // so the card stays in view above them. Once the keyboard has risen, put the focused field near the top of
            // what's left so the next one shows under it (as in NutrientFormView); tapping beside a field focuses it
            // without the system scrolling it into view.
            .task(id: viewModel.selectedStartingPoint?.id) {
                guard fieldsInContent, let point = viewModel.selectedStartingPoint else { return }
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                    proxy.scrollTo(Self.goalSectionID(point), anchor: .bottom)
                }
            }
            .task(id: focusedField) {
                guard fieldsInContent, let field = focusedField else { return }
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                    proxy.scrollTo(field, anchor: UnitPoint(x: 0.5, y: 0.3))
                }
            }
        }
        .background(Theme.surfaceGround)
        .sheet(isPresented: $showCustomForm, onDismiss: {
            viewModel.finishAfterCustomForm(context: modelContext)
        }) {
            // Save from the same instance the form edits, not whatever the state holds when Add is tapped.
            let draft = customDraft
            NutrientFormView(draft: draft, title: "New Nutrient", buttonLabel: "Add") {
                viewModel.createCustomNutrient(from: draft, context: modelContext)
            }
        }
    }

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.cardGap), count: 2)

    /// The starting-point cards; at accessibility sizes the picked one is followed by its goal fields.
    private var startingPoints: some View {
        ForEach(StartingPoint.all) { point in
            startingPointCard(point)
            if fieldsInContent, viewModel.selectedStartingPoint == point {
                goalSection
                    .id(Self.goalSectionID(point))
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // the 44pt circle doesn't grow with text
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
                    .background(Theme.surfaceCard, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule().fill(Theme.green).frame(height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step 2 of 2")

            Button("Skip") {
                viewModel.complete(context: modelContext)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .accessibilityHint("Finishes setup without adding a nutrient")
        }
        .padding(.top, 8)
    }

    // MARK: - Starting points

    private func startingPointCard(_ point: StartingPoint) -> some View {
        let isSelected = viewModel.selectedStartingPoint == point

        return Button {
            focusedField = nil
            withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2))) { viewModel.select(point) }
        } label: {
            HStack(spacing: 10) {
                NutrientIconTile(tint: point.tint, symbolName: point.symbolName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    // One line in the two-column grid ("Magnesium" would hyphenate); the single column has room.
                    Text(point.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.85)
                    Text(point.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .cardStyle()
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.controlPrimary, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(point.name)
        .accessibilityValue(point.subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var somethingElse: some View {
        Button {
            focusedField = nil
            customDraft.reset()
            showCustomForm = true
        } label: {
            Label("Something else", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(Theme.controlPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.controlGhostBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens a blank nutrient form")
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            // Done lives in the panel, not in a keyboard toolbar: with the fields inside this bottom inset, a
            // keyboard toolbar made SwiftUI log attribute-graph cycles on the first keyboard open (#19), and from the
            // third open on the panel no longer cleared its floating Done bar, which covered Start tracking.
            if focusedField != nil {
                Button {
                    focusedField = nil
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.controlPrimary)
                        .frame(minWidth: Theme.minTouchTarget, minHeight: Theme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHint("Hides the keyboard")
            }
            if !fieldsInContent, viewModel.selectedStartingPoint != nil {
                goalSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                focusedField = nil
                viewModel.startTracking(context: modelContext)
            } label: {
                // Disabled until the amounts are entered, which is most of the time: a chip-grey fill with
                // secondary text stays legible in both appearances (dimming the green didn't).
                Text("Start tracking")
                    .font(.headline)
                    .foregroundStyle(viewModel.canStartTracking ? Theme.controlOnPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(viewModel.canStartTracking ? Theme.controlPrimary : Theme.surfaceChip,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStartTracking)
        }
        .padding(.horizontal, Theme.Spacing.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        // Down to the screen edge, so the grid doesn't show below the panel: behind the home indicator, or the
        // keyboard's rounded top corners.
        .background { Theme.surfaceGround.ignoresSafeArea(edges: .bottom) }
        .animation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2)), value: viewModel.selectedStartingPoint)
    }

    /// The goal fields and, for a range whose maximum isn't above the minimum, the error below them.
    private var goalSection: some View {
        VStack(spacing: 10) {
            goalFields
            if let error = draft.rangeError {
                Text(error)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textAmberInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    /// "Daily goal" + "Each tap adds" — or Minimum / Maximum / Each tap adds for a range.
    private var goalFields: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))

        return layout {
            if draft.goalType == .range {
                goalField("Minimum", text: Bindable(draft).dailyTarget, field: .target)
                fieldDivider
                goalField("Maximum", text: Bindable(draft).upperBound, field: .upperBound)
            } else {
                goalField(draft.goalType == .maximum ? "Daily limit" : "Daily goal",
                          text: Bindable(draft).dailyTarget, field: .target)
            }
            fieldDivider
            goalField("Each tap adds", text: Bindable(draft).step, field: .step)
        }
        .cardStyle()
    }

    private var fieldDivider: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Divider()
            } else {
                Divider().frame(maxHeight: 44)
            }
        }
        .overlay(Theme.lineHairline)
    }

    private func goalField(_ label: String, text: Binding<String>, field: GoalField) -> some View {
        let unit = draft.unit.trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)  // the field's own label
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", text: text)
                    .font(Self.valueFont)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .fixedSize()
                    .accessibilityLabel(unit.isEmpty ? label : "\(label), \(unit)")
                Text(unit)
                    .font(Self.valueFont)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
        .id(field)
    }
}

private struct OnboardingFirstNutrientPreview: View {
    @State private var viewModel: OnboardingViewModel

    /// - Parameters:
    ///   - selected: index into `StartingPoint.all` to pre-select (before the first render, so the snapshot isn't
    ///     caught mid-animation), or nil.
    ///   - amounts: goal and step to type in after picking, so Start tracking is enabled. Starting points leave
    ///     them empty.
    init(selected: Int? = 0, amounts: (goal: String, step: String)? = nil) {
        let viewModel = OnboardingViewModel()
        if let selected { viewModel.select(StartingPoint.all[selected]) }
        if let amounts {
            viewModel.draft.dailyTarget = amounts.goal
            viewModel.draft.step = amounts.step
        }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        OnboardingFirstNutrientView(viewModel: viewModel, onBack: {})
    }
}

#Preview("Light") {
    OnboardingFirstNutrientPreview()
        .modelContainer(for: [Nutrient.self, NutrientGroup.self, UserProfile.self], inMemory: true)
}

#Preview("Amounts entered") {
    OnboardingFirstNutrientPreview(amounts: ("2000", "1000"))
        .modelContainer(for: [Nutrient.self, NutrientGroup.self, UserProfile.self], inMemory: true)
}

#Preview("Dark, amounts entered") {
    OnboardingFirstNutrientPreview(selected: 3, amounts: ("2.5", "0.25"))
        .modelContainer(for: [Nutrient.self, NutrientGroup.self, UserProfile.self], inMemory: true)
        .preferredColorScheme(.dark)
}

#Preview("Dark, nothing picked") {
    OnboardingFirstNutrientPreview(selected: nil)
        .modelContainer(for: [Nutrient.self, NutrientGroup.self, UserProfile.self], inMemory: true)
        .preferredColorScheme(.dark)
}

#Preview("Range (Protein)") {
    OnboardingFirstNutrientPreview(selected: 4)
        .modelContainer(for: [Nutrient.self, NutrientGroup.self, UserProfile.self], inMemory: true)
}

#Preview("Accessibility size") {
    OnboardingFirstNutrientPreview()
        .modelContainer(for: [Nutrient.self, NutrientGroup.self, UserProfile.self], inMemory: true)
        .dynamicTypeSize(.accessibility3)
}
