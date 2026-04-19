import SwiftUI

struct PopoverProfileRow: View {
    let profile: ProvisioningProfile
    @ObservedObject var viewModel: CertWatchViewModel
    var broken: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TeamGlyph(teamName: profile.teamName,
                      color: viewModel.teamColor(for: profile.teamId.isEmpty ? profile.teamName : profile.teamId),
                      size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if broken {
                        Chip(label: "Broken", color: Theme.crit, bgColor: Theme.critBg)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    TypeBadge(type: profile.type.rawValue)
                    Text(profile.bundleIdentifier)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textTert)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HealthBar(expirationDate: profile.expirationDate)
                    .padding(.top, 2)
            }

            VStack(alignment: .trailing, spacing: 2) {
                HealthPill(expirationDate: profile.expirationDate, compact: true)
                Text("Exp \(Self.dateFormatter.string(from: profile.expirationDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTert)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .glassCard(cornerRadius: 12, material: .thinMaterial)
    }
}

struct PopoverCertRow: View {
    let cert: Certificate
    @ObservedObject var viewModel: CertWatchViewModel

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f
    }()

    private var iconBgColor: Color {
        switch cert.type {
        case .distribution:     return Theme.accentBg
        case .pushNotification: return Theme.warnBg
        default:                return Theme.okBg
        }
    }

    private var iconColor: Color {
        switch cert.type {
        case .distribution:     return Theme.accent
        case .pushNotification: return Theme.warn
        default:                return Theme.ok
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconBgColor)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(cert.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    TypeBadge(type: cert.type.rawValue)
                    Text(cert.teamName)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTert)
                        .lineLimit(1)
                }

                HealthBar(expirationDate: cert.expirationDate)
                    .padding(.top, 2)
            }

            VStack(alignment: .trailing, spacing: 2) {
                HealthPill(expirationDate: cert.expirationDate, compact: true)
                Text("Exp \(Self.dateFormatter.string(from: cert.expirationDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTert)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .glassCard(cornerRadius: 12, material: .thinMaterial)
    }
}
