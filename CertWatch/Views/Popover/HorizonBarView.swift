import SwiftUI

struct HorizonBarView: View {
    let certificates: [Certificate]
    let profiles: [ProvisioningProfile]

    private struct WeekBucket {
        var count: Int = 0
        var critical: Int = 0
    }

    private var buckets: [WeekBucket] {
        var result = Array(repeating: WeekBucket(), count: 13)
        let now = Date()
        let cal = Calendar.current

        for date in certificates.map(\.expirationDate) + profiles.map(\.expirationDate) {
            guard let days = cal.dateComponents([.day], from: now, to: date).day, days >= 0, days < 91 else { continue }
            let week = min(12, days / 7)
            result[week].count += 1
            if days < 30 { result[week].critical += 1 }
        }
        return result
    }

    var body: some View {
        let all = buckets
        let maxCount = max(1, all.map(\.count).max() ?? 1)

        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<all.count, id: \.self) { i in
                    let b = all[i]
                    let frac = max(0.15, Double(b.count) / Double(maxCount))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(b.critical > 0 ? Theme.crit : Theme.accent)
                        .opacity(b.count == 0 ? 0.22 : 1)
                        .frame(height: max(4, CGFloat(frac) * 28))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 28)

            HStack {
                Text("Today")
                Spacer()
                Text("30d")
                Spacer()
                Text("60d")
                Spacer()
                Text("90d")
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.textTert)
        }
    }
}
