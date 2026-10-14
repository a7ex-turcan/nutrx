import SwiftUI

/// The small "PRO" chip (docs/pro/design/2-paywall). `.inline` sits next to a Pro feature's name for a free user
/// (chip grey, never a lock); `.onForest` goes with the "nutrx" wordmark on forest cards.
struct ProBadge: View {
    enum Style {
        case inline
        case onForest
    }

    var style: Style = .inline

    var body: some View {
        Text("PRO")
            .font(.system(style == .onForest ? .subheadline : .caption2, design: .rounded, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(style == .onForest ? Theme.forest : Theme.textPrimary)
            .padding(.horizontal, style == .onForest ? 9 : 7)
            .padding(.vertical, style == .onForest ? 4 : 3)
            .background(style == .onForest ? Theme.greenSoft : Theme.surfaceChip,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.tag, style: .continuous))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityLabel("Pro")
    }
}

/// "nutrx" in rounded heavy with the PRO chip, on forest.
struct ProWordmark: View {
    var size: CGFloat = 30

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("nutrx")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.onForestPrimary)
            ProBadge(style: .onForest)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("nutrx Pro")
        .accessibilityAddTraits(.isHeader)
    }
}

/// The ring motif: two concentric tracks, centred near a forest card's top-right corner, with a green arc along
/// the bottom of the outer one, below the card's text (paywall header, Pro screen). Settings' card has no arc.
struct ProRingMotif: View {
    var lineWidth: CGFloat = 30
    var showsArc = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(Theme.onForestTrack, lineWidth: lineWidth)
                Circle()
                    .stroke(Theme.onForestTrack, lineWidth: lineWidth)
                    .frame(width: side * 0.62, height: side * 0.62)
                if showsArc {
                    // From about 4 to 7 o'clock: the bottom of the ring, clear of the text on the left.
                    Circle()
                        .trim(from: 0.1, to: 0.26)
                        .stroke(Theme.green.opacity(0.55), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
            .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}

/// The 44pt Pro tile: a ring arc in soft green on a translucent tile (Settings' nutrx Pro card).
struct ProRingTile: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.08, to: 0.86)
                .stroke(Theme.greenSoft, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .frame(width: size * 0.5, height: size * 0.5)
                .rotationEffect(.degrees(-60))
            Circle()
                .trim(from: 0.15, to: 0.7)
                .stroke(Theme.greenSoft, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.22)
                .rotationEffect(.degrees(-60))
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.iconTile, style: .continuous))
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack { Text("Scan a label").font(.headline); ProBadge() }
        ProWordmark()
            .padding()
            .background(Theme.forest)
        ProRingTile()
            .padding()
            .background(Theme.forest)
    }
    .padding()
}
