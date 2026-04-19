import SwiftUI

struct CertificatesTabView: View {
    @ObservedObject var viewModel: CertWatchViewModel

    var body: some View {
        VStack(spacing: 0) {
            PopoverSearchBar(text: $viewModel.searchText, placeholder: "Search certificates")
                .padding(.vertical, 8)

            if viewModel.filteredCertificates.isEmpty {
                EmptyTabState(icon: "shield.slash", text: "No certificates found")
            } else {
                LazyVStack(alignment: .leading, spacing: 6, pinnedViews: []) {
                    ForEach(viewModel.certificatesByTeam, id: \.team) { group in
                        teamBlock(group: group)
                    }
                }
            }
        }
    }

    private func teamBlock(group: (team: String, certs: [Certificate])) -> some View {
        let summary = viewModel.teamSummary(for: group.team)
        let color = summary?.color ?? Theme.neu
        let teamId = summary?.id ?? group.team
        return VStack(spacing: 6) {
            TeamHeader(
                teamName: group.team,
                teamId: teamId == group.team ? "" : teamId,
                teamColor: color,
                count: group.certs.count
            )
            ForEach(group.certs) { cert in
                PopoverCertRow(cert: cert, viewModel: viewModel)
            }
        }
        .padding(.top, 4)
    }
}

struct PopoverSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTert)
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text)
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTert)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .glassCard(cornerRadius: 9, material: .thinMaterial)
        }
    }
}

struct EmptyTabState: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Theme.textQuat)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTert)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
