import SwiftUI

// MARK: - Glass card modifier — translucent material with soft border + subtle top highlight

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var material: Material = .regularMaterial
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.02))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12, material: Material = .regularMaterial) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, material: material))
    }
}

// MARK: - Team glyph (rounded tile with initials, team-colored)

struct TeamGlyph: View {
    let teamName: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 0.5)
            Text(teamInitials(teamName))
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
                .tracking(-0.2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Health pill (colored chip for expiration)

struct HealthPill: View {
    let expirationDate: Date
    var compact: Bool = false

    private var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }

    private var bucket: HealthBucket {
        if expirationDate <= Date() { return .expired }
        if daysLeft < 30 { return .critical }
        if daysLeft < 90 { return .warning }
        return .healthy
    }

    private var label: String {
        switch bucket {
        case .expired:  return "Expired"
        default:        return compact ? "\(daysLeft)d" : "\(daysLeft)d left"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(bucket.color)
                .frame(width: 6, height: 6)
            Text(label)
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(-0.1)
        .foregroundStyle(bucket.color)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(bucket.bgColor)
        )
    }
}

enum HealthBucket {
    case expired, critical, warning, healthy

    var color: Color {
        switch self {
        case .expired, .critical: return Theme.crit
        case .warning:            return Theme.warn
        case .healthy:            return Theme.ok
        }
    }

    var bgColor: Color {
        switch self {
        case .expired, .critical: return Theme.critBg
        case .warning:            return Theme.warnBg
        case .healthy:            return Theme.okBg
        }
    }

    static func of(_ expirationDate: Date) -> HealthBucket {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        if expirationDate <= Date() { return .expired }
        if days < 30 { return .critical }
        if days < 90 { return .warning }
        return .healthy
    }
}

// MARK: - Health bar (thin strip showing remaining life on a 365-day scale)

struct HealthBar: View {
    let expirationDate: Date

    private var bucket: HealthBucket { .of(expirationDate) }

    private var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }

    private var progress: Double {
        if daysLeft < 0 { return 1.0 }
        let max = 365.0
        return min(1.0, Swift.max(0.04, Double(daysLeft) / max))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(bucket == .expired
                          ? Theme.crit.opacity(0.25)
                          : Theme.line)
                Capsule()
                    .fill(bucket.color)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Type badge

struct TypeBadge: View {
    let type: String

    private var color: Color {
        switch type {
        case "Development": return Theme.accent
        case "App Store":   return Theme.neu
        case "Ad Hoc":      return Theme.warn
        case "Enterprise":  return Theme.crit
        case "APNs", "Apple Push Services", "Apple Push Notification": return Theme.warn
        case "Distribution", "Apple Distribution": return Theme.neu
        case "Apple Development": return Theme.accent
        default: return Theme.neu
        }
    }

    private var bgColor: Color {
        switch type {
        case "Development", "Apple Development": return Theme.accentBg
        case "App Store", "Distribution", "Apple Distribution": return Theme.neuBg
        case "Ad Hoc", "APNs", "Apple Push Services", "Apple Push Notification": return Theme.warnBg
        case "Enterprise": return Theme.critBg
        default: return Theme.neuBg
        }
    }

    var body: some View {
        Text(type)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(bgColor)
            )
    }
}

// MARK: - Stat chip (used on the overview's 2x2 grid)

struct StatChip: View {
    let icon: String
    let color: Color
    let bgColor: Color
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(bgColor)
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 18, height: 18)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSec)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12, material: .thinMaterial)
    }
}

// MARK: - Section head (uppercase label with colored icon chip + count)

struct SectionHead: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    let bgColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(bgColor)
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 16, height: 16)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSec)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTert)
            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Team header (used above team-grouped lists)

struct TeamHeader: View {
    let teamName: String
    let teamId: String
    let teamColor: Color
    let count: Int
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            TeamGlyph(teamName: teamName, color: teamColor, size: size)
            VStack(alignment: .leading, spacing: 1) {
                Text(teamName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                if !teamId.isEmpty {
                    Text(teamId)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textTert)
                }
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTert)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
    }
}

// MARK: - Copy feedback toast

struct CopyFeedbackToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(radius: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Change event row (used in overview's Recent changes section)

struct ChangeEventRow: View {
    let event: ChangeEvent

    private var color: Color {
        switch event.type {
        case .added:   return Theme.ok
        case .removed: return Theme.neu
        case .renewed: return Theme.accent
        case .expired: return Theme.crit
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: event.type.icon)
                .font(.system(size: 11))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.itemName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(event.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTert)
                    .lineLimit(1)
            }

            Spacer()

            Text(event.date, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTert)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Chip (small colored label for inline use)

struct Chip: View {
    let label: String
    let icon: String?
    let color: Color
    let bgColor: Color

    init(label: String, icon: String? = nil, color: Color, bgColor: Color) {
        self.label = label
        self.icon = icon
        self.color = color
        self.bgColor = bgColor
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(bgColor)
        )
    }
}
