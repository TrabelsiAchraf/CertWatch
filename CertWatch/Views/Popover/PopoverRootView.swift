import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: CertWatchViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                PopoverHeader(viewModel: viewModel)
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)

                ScrollView {
                    Group {
                        switch viewModel.selectedTab {
                        case .overview:     OverviewTabView(viewModel: viewModel)
                        case .certificates: CertificatesTabView(viewModel: viewModel)
                        case .profiles:     ProfilesTabView(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .padding(.top, 4)
                }

                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
                PopoverFooter(viewModel: viewModel)
            }

            if let message = viewModel.copyFeedback {
                CopyFeedbackToast(message: message)
                    .padding(.bottom, 44)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.copyFeedback)
            }
        }
        .frame(width: 380, height: 620)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        Theme.accent.opacity(0.08),
                        Color.clear,
                        Theme.teamPurple.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .onAppear {
            if viewModel.lastRefresh == nil {
                viewModel.refresh()
            }
        }
    }
}
