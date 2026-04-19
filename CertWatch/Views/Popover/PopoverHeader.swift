import SwiftUI

struct PopoverHeader: View {
    @ObservedObject var viewModel: CertWatchViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // App glyph
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.accent, Theme.teamPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)

                Text("CertWatch")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(Theme.text)

                Spacer()

                PopoverIconButton(
                    systemName: viewModel.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                    help: "Refresh",
                    action: { viewModel.refresh() }
                )
                PopoverIconButton(systemName: "gearshape", help: "Settings") {
                    openSettings()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            // Segmented tabs
            HStack {
                SegmentedTabs(selection: $viewModel.selectedTab)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }
}

struct PopoverIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSec)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovering ? Theme.bgHover : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct SegmentedTabs: View {
    @Binding var selection: DashboardTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(2)
        .glassCard(cornerRadius: 10, material: .ultraThinMaterial)
    }

    @ViewBuilder
    private func tabButton(_ tab: DashboardTab) -> some View {
        let isSelected = selection == tab
        Button {
            selection = tab
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.text : Theme.textSec)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.thinMaterial)
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
