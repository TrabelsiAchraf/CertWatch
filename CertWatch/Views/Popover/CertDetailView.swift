import SwiftUI

struct CertDetailView: View {
    let cert: Certificate
    @ObservedObject var viewModel: CertWatchViewModel

    private static let issuedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var linkedProfiles: [ProvisioningProfile] {
        viewModel.profiles(using: cert)
    }

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
        VStack(spacing: 0) {
            backBar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    identitySection
                    usedBySection
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: Back bar

    private var backBar: some View {
        HStack(spacing: 6) {
            PopoverIconButton(systemName: "chevron.left", help: "Back to certificates") {
                viewModel.selectedCertificate = nil
            }
            Text("Certificates")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSec)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconBgColor)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(cert.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(cert.teamName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTert)
                HStack(spacing: 6) {
                    TypeBadge(type: cert.type.rawValue)
                    HealthPill(expirationDate: cert.expirationDate)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("IDENTITY")
            VStack(alignment: .leading, spacing: 6) {
                copyableRow(label: "Serial", value: cert.serialNumber)
                copyableRow(label: "SHA-1", value: cert.sha1Fingerprint)
                infoRow(label: "Issued", value: Self.issuedFormatter.string(from: cert.issueDate))
                infoRow(label: "Expires",
                        value: "\(Self.issuedFormatter.string(from: cert.expirationDate))  ·  \(cert.daysRemaining)d")
                HealthBar(expirationDate: cert.expirationDate)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 12, material: .thinMaterial)
        }
    }

    private func copyableRow(label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTert)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button {
                viewModel.copyToClipboard(value, label: label)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTert)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Copy \(label)")
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTert)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
    }

    // MARK: Used-by

    private var usedBySection: some View {
        let profiles = linkedProfiles
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("USED BY \(profiles.count) PROFILE\(profiles.count == 1 ? "" : "S")")
            if profiles.isEmpty {
                Text("No provisioning profile references this certificate.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTert)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 12, material: .thinMaterial)
            } else {
                VStack(spacing: 6) {
                    ForEach(profiles) { profile in
                        ProfileMiniRow(profile: profile)
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(Theme.textTert)
            .padding(.horizontal, 2)
    }
}

// MARK: - ProfileMiniRow

struct ProfileMiniRow: View {
    let profile: ProvisioningProfile

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accentBg)
                Image(systemName: profile.type.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    TypeBadge(type: profile.type.rawValue)
                    Text(profile.bundleIdentifier)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.textTert)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                HealthPill(expirationDate: profile.expirationDate, compact: true)
                Text("Exp \(Self.dateFormatter.string(from: profile.expirationDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTert)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 10, material: .thinMaterial)
    }
}
