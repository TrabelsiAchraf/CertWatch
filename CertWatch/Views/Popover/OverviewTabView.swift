import SwiftUI

struct OverviewTabView: View {
    @ObservedObject var viewModel: CertWatchViewModel

    private var expiringIn30Days: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let now = Date()
        let certs = viewModel.certificates.filter { $0.expirationDate > now && $0.expirationDate <= cutoff }.count
        let profs = viewModel.profiles.filter { $0.expirationDate > now && $0.expirationDate <= cutoff }.count
        return certs + profs
    }

    private var criticalCount: Int {
        viewModel.certificates.filter { $0.status == .critical }.count
            + viewModel.profiles.filter { $0.status == .critical }.count
    }

    var body: some View {
        VStack(spacing: 10) {
            heroCard
            statGrid

            if !viewModel.expiringSoonCertificates.isEmpty || !viewModel.expiringSoonProfiles.isEmpty {
                attentionSection
            }

            if !viewModel.brokenProfiles.isEmpty {
                brokenSection
            }

            if viewModel.alertCount == 0 && !viewModel.certificates.isEmpty {
                allGoodState
            }

            if viewModel.certificates.isEmpty && viewModel.profiles.isEmpty && !viewModel.isLoading {
                emptyState
            }

            if !viewModel.recentChanges.isEmpty {
                recentChangesSection
            }
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXT 90 DAYS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Theme.textTert)
                Spacer()
                if criticalCount > 0 {
                    Chip(label: "\(criticalCount) critical", color: Theme.crit, bgColor: Theme.critBg)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(expiringIn30Days)")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(Theme.text)
                Text("items expire in 30 days")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSec)
                    .padding(.bottom, 4)
            }
            .padding(.top, 8)

            HorizonBarView(certificates: viewModel.certificates, profiles: viewModel.profiles)
                .padding(.top, 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14, material: .regularMaterial)
    }

    // MARK: Stats

    private var statGrid: some View {
        let brokenCount = viewModel.brokenProfiles.count
        let expiredCount = viewModel.expiredCertificates.count + viewModel.expiredProfiles.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            StatChip(icon: "checkmark", color: Theme.ok, bgColor: Theme.okBg,
                     value: viewModel.validCertificates.count, label: "Valid certs")
            StatChip(icon: "exclamationmark.triangle.fill", color: Theme.warn, bgColor: Theme.warnBg,
                     value: viewModel.expiringSoonCertificates.count + viewModel.expiringSoonProfiles.count,
                     label: "Expiring")
            StatChip(icon: "doc.fill", color: Theme.accent, bgColor: Theme.accentBg,
                     value: viewModel.activeProfiles.count, label: "Active profiles")
            if brokenCount > 0 {
                StatChip(icon: "link.badge.plus", color: Theme.crit, bgColor: Theme.critBg,
                         value: brokenCount, label: "Broken")
            } else {
                StatChip(icon: "xmark", color: Theme.crit, bgColor: Theme.critBg,
                         value: expiredCount, label: "Expired")
            }
        }
    }

    // MARK: Sections

    private var attentionSection: some View {
        VStack(spacing: 6) {
            SectionHead(icon: "exclamationmark.triangle.fill", title: "Needs attention",
                        count: viewModel.expiringSoonCertificates.count + viewModel.expiringSoonProfiles.count,
                        color: Theme.crit, bgColor: Theme.critBg)

            ForEach(urgentProfiles().prefix(3)) { profile in
                PopoverProfileRow(profile: profile, viewModel: viewModel, broken: false)
            }
            ForEach(urgentCertificates().prefix(3)) { cert in
                PopoverCertRow(cert: cert, viewModel: viewModel)
            }
        }
        .padding(.top, 4)
    }

    private var brokenSection: some View {
        VStack(spacing: 6) {
            SectionHead(icon: "link.badge.plus", title: "Broken profiles",
                        count: viewModel.brokenProfiles.count, color: Theme.crit, bgColor: Theme.critBg)
            ForEach(viewModel.brokenProfiles) { profile in
                PopoverProfileRow(profile: profile, viewModel: viewModel, broken: true)
            }
        }
        .padding(.top, 4)
    }

    private var recentChangesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHead(icon: "clock.arrow.circlepath", title: "Recent changes",
                        count: viewModel.recentChanges.count,
                        color: Theme.textSec, bgColor: Theme.neuBg)
            ForEach(viewModel.recentChanges.prefix(5)) { event in
                ChangeEventRow(event: event)
            }
        }
        .padding(.top, 4)
    }

    private var allGoodState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.okBg)
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.ok)
            }
            Text("All certificates and profiles are valid")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSec)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Theme.textQuat)
            Text("No certificates or profiles found")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTert)
        }
        .padding(.vertical, 28)
    }

    // MARK: - helpers

    private func urgentProfiles() -> [ProvisioningProfile] {
        viewModel.expiringSoonProfiles.sorted(by: { $0.daysRemaining < $1.daysRemaining })
    }

    private func urgentCertificates() -> [Certificate] {
        viewModel.expiringSoonCertificates.sorted(by: { $0.daysRemaining < $1.daysRemaining })
    }
}
