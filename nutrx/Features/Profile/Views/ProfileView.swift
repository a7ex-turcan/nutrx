import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ProfileViewModel()
    @State private var showSavedConfirmation = false
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, weight, height
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileIcon
                fields
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    focusedField = nil
                    viewModel.save()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.hasChanges || !viewModel.isValid)
            }
        }
        .overlay {
            if showSavedConfirmation {
                savedToast
            }
        }
        .onAppear {
            viewModel.load(context: modelContext)
        }
    }

    // MARK: - Profile Icon

    private var profileIcon: some View {
        Button {
            showImageSourcePicker = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let data = viewModel.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, .blue)
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Profile Photo", isPresented: $showImageSourcePicker) {
            Button("Choose from Library") {
                showPhotoPicker = true
            }

            Button("Take Photo") {
                showCamera = true
            }

            if viewModel.profileImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    viewModel.profileImageData = nil
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if let compressed = compressImage(data, maxSize: 300) {
                        viewModel.profileImageData = compressed
                    }
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    if let compressed = compressImage(data, maxSize: 300) {
                        viewModel.profileImageData = compressed
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func compressImage(_ data: Data, maxSize: CGFloat) -> Data? {
        guard let uiImage = UIImage(data: data) else { return nil }

        let size = uiImage.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(spacing: 20) {
            FormField(label: "Name") {
                TextField("Your name", text: $viewModel.name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
            }

            FormField(label: "Birthday") {
                DatePicker(
                    "Birthday",
                    selection: $viewModel.birthdate,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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
    }

    // MARK: - Saved Toast

    private var savedToast: some View {
        VStack {
            Spacer()
            Text("Profile saved")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 24)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSavedConfirmation = false
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
