import SwiftUI

struct OnboardingPersonalInfoView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onContinue: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, weight, height
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                VStack(spacing: 20) {
                    nameField
                    birthdayField
                    weightField
                    heightField
                }

                continueButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("About You")
                .font(.largeTitle.bold())

            Text("Tell us a bit about yourself to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Your name", text: $viewModel.name)
                .textContentType(.name)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .name)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var birthdayField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Birthday")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            DatePicker(
                "Birthday",
                selection: $viewModel.birthdate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var weightField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weight")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("0", text: $viewModel.weight)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Picker("Unit", selection: $viewModel.weightUnit) {
                    Text("kg").tag("kg")
                    Text("lbs").tag("lbs")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    private var heightField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Height")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("0", text: $viewModel.height)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .height)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Picker("Unit", selection: $viewModel.heightUnit) {
                    Text("cm").tag("cm")
                    Text("ft").tag("ft")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button {
            focusedField = nil
            onContinue()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isPersonalInfoValid)
        .padding(.top, 8)
    }
}

#Preview {
    OnboardingPersonalInfoView(viewModel: OnboardingViewModel()) {}
}
