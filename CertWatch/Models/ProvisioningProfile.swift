import Foundation

// MARK: - Profile Type
enum ProfileType: String, Codable, CaseIterable {
    case development = "Development"
    case appStore = "App Store"
    case adHoc = "Ad Hoc"
    case enterprise = "Enterprise"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .development: return "hammer.fill"
        case .appStore: return "bag.fill"
        case .adHoc: return "person.2.fill"
        case .enterprise: return "building.2.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Profile Status
enum ProfileStatus: String, Codable {
    case active = "Active"
    case expiringSoon = "Expiring Soon"
    case critical = "Critical"
    case expired = "Expired"

    var color: String {
        switch self {
        case .active: return "green"
        case .expiringSoon: return "orange"
        case .critical: return "red"
        case .expired: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .expired: return "xmark.circle.fill"
        }
    }
}

// MARK: - Provisioning Profile Model
struct ProvisioningProfile: Identifiable, Codable {
    let id: UUID
    let name: String
    let uuid: String
    let appIdName: String
    let bundleIdentifier: String
    let teamId: String
    let teamName: String
    let type: ProfileType
    let creationDate: Date
    let expirationDate: Date
    let entitlements: [String: String]
    let certificateNames: [String]
    let certificateSHA1s: [String]
    let provisionedDevices: [String]?
    let filePath: String

    var status: ProfileStatus {
        let now = Date()
        guard expirationDate > now else { return .expired }

        let daysRemaining = Calendar.current.dateComponents([.day], from: now, to: expirationDate).day ?? 0

        if daysRemaining <= 7 {
            return .critical
        } else if daysRemaining <= 30 {
            return .expiringSoon
        } else {
            return .active
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

    var deviceCount: Int {
        return provisionedDevices?.count ?? 0
    }

    init(
        id: UUID = UUID(),
        name: String,
        uuid: String,
        appIdName: String,
        bundleIdentifier: String,
        teamId: String,
        teamName: String,
        type: ProfileType,
        creationDate: Date,
        expirationDate: Date,
        entitlements: [String: String] = [:],
        certificateNames: [String] = [],
        certificateSHA1s: [String] = [],
        provisionedDevices: [String]? = nil,
        filePath: String
    ) {
        self.id = id
        self.name = name
        self.uuid = uuid
        self.appIdName = appIdName
        self.bundleIdentifier = bundleIdentifier
        self.teamId = teamId
        self.teamName = teamName
        self.type = type
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.entitlements = entitlements
        self.certificateNames = certificateNames
        self.certificateSHA1s = certificateSHA1s
        self.provisionedDevices = provisionedDevices
        self.filePath = filePath
    }
}
