import SwiftUI
import SwiftData

/// Second onboarding screen (DESIGN.md §5.8): back, progress, Skip; "What do you want to track first?"; a grid of
/// starting points and "Something else". A starting point pre-fills editable goal / step fields above Start
/// tracking — nothing is created until that's tapped.
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                        .padding(.bottom, 24)

                    Text("What do you want to track first?")
                        .font(.system(.largeTitle, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a starting point or make your own. Everything stays editable.")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                    LazyVGrid(columns: columns, spacing: Theme.Spacing.cardGap) {
                        ForEach(StartingPoint.all) { point in
                            startingPointCard(point)
                        }
                    }

                    somethingElse
                        .padding(.top, Theme.Spacing.cardGap)
                }
                .padding(.horizontal, Theme.Spacing.screenMargin)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { bottomPanel }
            .background(Theme.surfaceGround)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                // At the root, not inside the scroll content — see NutrientFormField.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
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
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.cardGap), count: count)
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
            if viewModel.selectedStartingPoint != nil {
                goalFields
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                if let error = draft.rangeError {
                    Text(error)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textAmberInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }

            Button {
                focusedField = nil
                viewModel.startTracking(context: modelContext)
            } label: {
                Text("Start tracking")
                    .font(.headline)
                    .foregroundStyle(Theme.controlOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.controlPrimary,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStartTracking)
            .opacity(viewModel.canStartTracking ? 1 : 0.5)
        }
        .padding(.horizontal, Theme.Spacing.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        // Down to the screen edge: with the keyboard up, the floating Done bar below the panel is see-through
        // and the grid would show between the panel and the keys.
        .background { Theme.surfaceGround.ignoresSafeArea(edges: .bottom) }
        .animation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.2)), value: viewModel.selectedStartingPoint)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", text: text)
                    .font(Self.valueFont)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .fixedSize()
                    .accessibilityLabel(label)
                Text(draft.unit)
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
    }
}

private struct OnboardingFirstNutrientPreview: View {
    @State private var viewModel: OnboardingViewModel

    /// - Parameter selected: index into `StartingPoint.all` to pre-select (before the first render, so the
    ///   snapshot isn't caught mid-animation), or nil.
    init(selected: Int? = 0) {
        let viewModel = OnboardingViewModel()
        if let selected { viewModel.select(StartingPoint.all[selected]) }
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
