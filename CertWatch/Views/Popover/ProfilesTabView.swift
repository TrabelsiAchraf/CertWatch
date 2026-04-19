import SwiftUI

struct ProfilesTabView: View {
    @ObservedObject var viewModel: CertWatchViewModel

    var body: some View {
        VStack(spacing: 0) {
            PopoverSearchBar(text: $viewModel.searchText, placeholder: "Search profiles")
                .padding(.vertical, 8)

            if viewModel.filteredProfiles.isEmpty {
                EmptyTabState(icon: "doc.badge.clock", text: "No provisioning profiles found")
            } else {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.profilesByTeam, id: \.team) { group in
                        teamBlock(group: group)
                    }
                }
            }
        }
    }

    private func teamBlock(group: (team: String, profiles: [ProvisioningProfile])) -> some View {
        let summary = viewModel.teamSummary(for: group.team)
        let color = summary?.color ?? Theme.neu
        let teamId = summary?.id ?? group.team
        return VStack(spacing: 6) {
            TeamHeader(
                teamName: group.team,
                teamId: teamId == group.team ? "" : teamId,
                teamColor: color,
                count: group.profiles.count
            )
            ForEach(group.profiles) { profile in
                PopoverProfileRow(profile: profile, viewModel: viewModel)
            }
        }
        .padding(.top, 4)
    }
}
