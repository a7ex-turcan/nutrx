import SwiftUI

/// The user's photo, else their name's initial, else a person symbol (DESIGN.md §3) — in the toolbar, on the
/// Settings profile card and at the top of Profile.
struct ProfileAvatar: View {
    enum Style {
        /// Pale green fill, forest ink — the 44pt toolbar avatar.
        case toolbar
        /// Forest fill, soft-green ink — the Settings profile card and Profile.
        case forest
    }

    let image: UIImage?
    let name: String
    var size: CGFloat = 44
    var style: Style = .toolbar

    private var initial: String? {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() }
    }

    private var fill: Color { style == .forest ? Theme.forest : Theme.avatarFill }
    private var ink: Color { style == .forest ? Theme.greenSoft : Theme.avatarInk }

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initial {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    HStack(spacing: 16) {
        ProfileAvatar(image: nil, name: "Alex")
        ProfileAvatar(image: nil, name: "")
        ProfileAvatar(image: nil, name: "Alex", size: 56, style: .forest)
        ProfileAvatar(image: nil, name: "", size: 56, style: .forest)
        ProfileAvatar(image: nil, name: "sam", size: 100, style: .forest)
    }
    .padding()
    .frame(maxHeight: .infinity)
    .background(Theme.surfaceGround)
}

#Preview("Dark") {
    HStack(spacing: 16) {
        ProfileAvatar(image: nil, name: "Alex")
        ProfileAvatar(image: nil, name: "", size: 56, style: .forest)
    }
    .padding()
    .frame(maxHeight: .infinity)
    .background(Theme.surfaceGround)
    .preferredColorScheme(.dark)
}
