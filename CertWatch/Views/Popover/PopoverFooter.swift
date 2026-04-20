import SwiftUI

struct PopoverFooter: View {
    @ObservedObject var viewModel: CertWatchViewModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.ok)
                .frame(width: 6, height: 6)
            if let last = viewModel.lastRefresh {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text("Updated \(Self.relativeLabel(last, now: context.date))")
                }
            } else {
                Text("Not yet refreshed")
            }

            Spacer()

            Button {
                viewModel.openDeveloperPortal()
            } label: {
                HStack(spacing: 3) {
                    Text("Developer Portal")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.lineStrong).frame(width: 1, height: 12)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSec)
            }
            .buttonStyle(.plain)
            .help("Quit CertWatch")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.textTert)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
    }

    private static func relativeLabel(_ date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
