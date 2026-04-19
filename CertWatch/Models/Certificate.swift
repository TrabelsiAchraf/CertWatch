import Foundation

// MARK: - Certificate Status
enum CertificateStatus: String, Codable {
    case valid = "Valid"
    case expiringSoon = "Expiring Soon"  // < 30 days
    case critical = "Critical"            // < 7 days
    case expired = "Expired"

    var color: String {
        switch self {
        case .valid: return "green"
        case .expiringSoon: return "orange"
        case .critical: return "red"
        case .expired: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .valid: return "checkmark.shield.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.shield.fill"
        case .expired: return "xmark.circle.fill"
        }
    }

    var menuBarIcon: String {
        switch self {
        case .valid: return "shield.checkered"
        case .expiringSoon: return "exclamationmark.shield.fill"
        case .critical: return "xmark.shield.fill"
        case .expired: return "shield.slash"
        }
    }
}

// MARK: - Certificate Type
enum CertificateType: String, Codable, CaseIterable {
    case development = "Apple Development"
    case distribution = "Apple Distribution"
    case pushNotification = "Apple Push Services"
    case unknown = "Unknown"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .development: return "hammer.fill"
        case .distribution: return "shippingbox.fill"
        case .pushNotification: return "bell.badge.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Certificate Model
struct Certificate: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: CertificateType
    let serialNumber: String
    let teamId: String
    let teamName: String
    let issueDate: Date
    let expirationDate: Date
    let sha1Fingerprint: String

    var status: CertificateStatus {
        let now = Date()
        guard expirationDate > now else { return .expired }

        let daysRemaining = Calendar.current.dateComponents([.day], from: now, to: expirationDate).day ?? 0

        if daysRemaining <= 7 {
            return .critical
        } else if daysRemaining <= 30 {
            return .expiringSoon
        } else {
            return .valid
        }
    }

    var daysRemaining: Int {
        let now = Date()
        return max(0, Calendar.current.dateComponents([.day], from: now, to: expirationDate).day ?? 0)
    }

    var formattedExpirationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expirationDate)
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: CertificateType,
        serialNumber: String,
        teamId: String,
        teamName: String,
        issueDate: Date,
        expirationDate: Date,
        sha1Fingerprint: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.serialNumber = serialNumber
        self.teamId = teamId
        self.teamName = teamName
        self.issueDate = issueDate
        self.expirationDate = expirationDate
        self.sha1Fingerprint = sha1Fingerprint
    }
}
