import Foundation
import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Tab Selection
enum DashboardTab: String, CaseIterable {
    case overview = "Overview"
    case certificates = "Certificates"
    case profiles = "Profiles"
}

// MARK: - Status Filter
enum StatusFilter: String, CaseIterable {
    case all = "All"
    case valid = "Valid"
    case expiring = "Expiring"
    case expired = "Expired"
}

// MARK: - Team summary (used for popover color assignment + grouped views)

struct TeamSummary: Identifiable, Hashable {
    let id: String           // teamId
    let name: String         // teamName
    let certCount: Int
    let profileCount: Int
    let colorIndex: Int

    var totalCount: Int { certCount + profileCount }
    var color: Color { TeamPalette.color(forIndex: colorIndex) }
}

// MARK: - Change Event
struct ChangeEvent: Identifiable, Codable {
    let id: UUID
    let date: Date
    let type: ChangeType
    let itemName: String
    let detail: String

    enum ChangeType: String, Codable {
        case added = "Added"
        case removed = "Removed"
        case renewed = "Renewed"
        case expired = "Expired"

        var icon: String {
            switch self {
            case .added: return "plus.circle.fill"
            case .removed: return "minus.circle.fill"
            case .renewed: return "arrow.triangle.2.circlepath"
            case .expired: return "xmark.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .added: return "green"
            case .removed: return "gray"
            case .renewed: return "blue"
            case .expired: return "red"
            }
        }
    }

    init(type: ChangeType, itemName: String, detail: String) {
        self.id = UUID()
        self.date = Date()
        self.type = type
        self.itemName = itemName
        self.detail = detail
    }
}

// MARK: - ViewModel
@MainActor
class CertWatchViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var certificates: [Certificate] = []
    @Published var profiles: [ProvisioningProfile] = []
    @Published var selectedTab: DashboardTab = .overview
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .all
    @Published var selectedTeam: String? = nil
    @Published var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var recentChanges: [ChangeEvent] = []
    @Published var copyFeedback: String? = nil

    /// Set to push the certificate detail view over the popover's tab content.
    @Published var selectedCertificate: Certificate? = nil

    // MARK: - Services
    private let keychainService = KeychainService.shared
    private let profileService = ProvisioningProfileService.shared
    private let notificationService = NotificationService.shared

    private var refreshTimer: Timer?

    // MARK: - Init

    init() {
        loadRecentChanges()
        startBackgroundRefresh()
    }

    // MARK: - Team Grouping

    var allTeams: [String] {
        var teams = Set<String>()
        certificates.forEach { teams.insert($0.teamName) }
        profiles.forEach { teams.insert($0.teamName) }
        return teams.sorted()
    }

    /// One entry per distinct team (keyed by teamId when available, else teamName).
    /// Stable sort by team name so the color index assignment is predictable.
    var distinctTeams: [TeamSummary] {
        // Group by teamId, preferring a teamId as stable key; fall back to teamName when missing.
        var byKey: [String: (name: String, id: String, certs: Int, profs: Int)] = [:]
        for c in certificates {
            let key = c.teamId.isEmpty || c.teamId == "N/A" ? c.teamName : c.teamId
            var cur = byKey[key] ?? (c.teamName, c.teamId, 0, 0)
            cur.certs += 1
            byKey[key] = cur
        }
        for p in profiles {
            let key = p.teamId.isEmpty ? p.teamName : p.teamId
            var cur = byKey[key] ?? (p.teamName, p.teamId, 0, 0)
            cur.profs += 1
            byKey[key] = cur
        }
        let sorted = byKey.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return sorted.enumerated().map { idx, v in
            TeamSummary(id: v.id.isEmpty ? v.name : v.id, name: v.name, certCount: v.certs, profileCount: v.profs, colorIndex: idx)
        }
    }

    /// Look up team color by either teamId or teamName.
    func teamColor(for key: String) -> Color {
        let teams = distinctTeams
        if let match = teams.first(where: { $0.id == key || $0.name == key }) {
            return match.color
        }
        return Theme.neu
    }

    func teamSummary(for key: String) -> TeamSummary? {
        distinctTeams.first(where: { $0.id == key || $0.name == key })
    }

    // MARK: - Filtered & Grouped Data

    var filteredCertificates: [Certificate] {
        certificates.filter { cert in
            // Search
            let matchesSearch = searchText.isEmpty ||
                cert.name.localizedCaseInsensitiveContains(searchText) ||
                cert.teamName.localizedCaseInsensitiveContains(searchText)
            // Team
            let matchesTeam = selectedTeam == nil || cert.teamName == selectedTeam
            // Status
            let matchesStatus: Bool
            switch statusFilter {
            case .all: matchesStatus = true
            case .valid: matchesStatus = cert.status == .valid
            case .expiring: matchesStatus = cert.status == .expiringSoon || cert.status == .critical
            case .expired: matchesStatus = cert.status == .expired
            }
            return matchesSearch && matchesTeam && matchesStatus
        }
    }

    var filteredProfiles: [ProvisioningProfile] {
        profiles.filter { profile in
            let matchesSearch = searchText.isEmpty ||
                profile.name.localizedCaseInsensitiveContains(searchText) ||
                profile.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
                profile.teamName.localizedCaseInsensitiveContains(searchText)
            let matchesTeam = selectedTeam == nil || profile.teamName == selectedTeam
            let matchesStatus: Bool
            switch statusFilter {
            case .all: matchesStatus = true
            case .valid: matchesStatus = profile.status == .active
            case .expiring: matchesStatus = profile.status == .expiringSoon || profile.status == .critical
            case .expired: matchesStatus = profile.status == .expired
            }
            return matchesSearch && matchesTeam && matchesStatus
        }
    }

    /// Group certificates by team name
    var certificatesByTeam: [(team: String, certs: [Certificate])] {
        Dictionary(grouping: filteredCertificates, by: { $0.teamName })
            .sorted { $0.key < $1.key }
            .map { (team: $0.key, certs: $0.value) }
    }

    /// Group profiles by team name
    var profilesByTeam: [(team: String, profiles: [ProvisioningProfile])] {
        Dictionary(grouping: filteredProfiles, by: { $0.teamName })
            .sorted { $0.key < $1.key }
            .map { (team: $0.key, profiles: $0.value) }
    }

    var expiredCertificates: [Certificate] {
        certificates.filter { $0.status == .expired }
    }

    var expiringSoonCertificates: [Certificate] {
        certificates.filter { $0.status == .expiringSoon || $0.status == .critical }
    }

    var validCertificates: [Certificate] {
        certificates.filter { $0.status == .valid }
    }

    var expiredProfiles: [ProvisioningProfile] {
        profiles.filter { $0.status == .expired }
    }

    var expiringSoonProfiles: [ProvisioningProfile] {
        profiles.filter { $0.status == .expiringSoon || $0.status == .critical }
    }

    var activeProfiles: [ProvisioningProfile] {
        profiles.filter { $0.status == .active }
    }

    var brokenProfiles: [ProvisioningProfile] {
        let expiredCertNames = Set(expiredCertificates.map { $0.name })
        let expiredCertFingerprints = Set(expiredCertificates.map { $0.sha1Fingerprint })
        return profiles.filter { profile in
            guard profile.status != .expired else { return false }
            return profile.certificateNames.contains { expiredCertNames.contains($0) }
                || profile.certificateSHA1s.contains { expiredCertFingerprints.contains($0) }
        }
    }

    /// All provisioning profiles that reference the given certificate by SHA-1 or name.
    func profiles(using cert: Certificate) -> [ProvisioningProfile] {
        profiles.filter {
            $0.certificateSHA1s.contains(cert.sha1Fingerprint)
                || $0.certificateNames.contains(cert.name)
        }
    }

    var alertCount: Int {
        expiringSoonCertificates.count + expiringSoonProfiles.count + brokenProfiles.count
    }

    var overallStatus: CertificateStatus {
        if !brokenProfiles.isEmpty { return .critical }
        let allCertStatuses = certificates.map { $0.status }
        let allProfileStatuses = profiles.map { $0.status }
        if allCertStatuses.contains(.critical) || allProfileStatuses.contains(.critical) { return .critical }
        if allCertStatuses.contains(.expiringSoon) || allProfileStatuses.contains(.expiringSoon) { return .expiringSoon }
        if allCertStatuses.contains(.expired) || allProfileStatuses.contains(.expired) { return .expired }
        return .valid
    }

    // MARK: - Background Refresh

    private func startBackgroundRefresh() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Actions

    func refresh() {
        isLoading = true
        let previousCerts = certificates
        let previousProfiles = profiles

        Task.detached(priority: .userInitiated) { [keychainService, profileService] in
            let certs = keychainService.fetchCertificates()
            let profs = profileService.fetchProfiles()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.certificates = certs.sorted { $0.expirationDate < $1.expirationDate }
                self.profiles = profs.sorted { $0.expirationDate < $1.expirationDate }
                self.lastRefresh = Date()
                self.isLoading = false

                if let selected = self.selectedCertificate,
                   !certs.contains(where: { $0.sha1Fingerprint == selected.sha1Fingerprint }) {
                    self.selectedCertificate = nil
                }

                // Detect changes
                if !previousCerts.isEmpty || !previousProfiles.isEmpty {
                    self.detectChanges(oldCerts: previousCerts, newCerts: certs, oldProfiles: previousProfiles, newProfiles: profs)
                }

                if self.notificationsEnabled {
                    self.scheduleNotifications()
                }

                print("🔄 [ViewModel] Refresh complete: \(certs.count) certs, \(profs.count) profiles")
            }
        }
    }

    // MARK: - Change Detection

    private func detectChanges(oldCerts: [Certificate], newCerts: [Certificate], oldProfiles: [ProvisioningProfile], newProfiles: [ProvisioningProfile]) {
        let oldCertSHAs = Set(oldCerts.map { $0.sha1Fingerprint })
        let newCertSHAs = Set(newCerts.map { $0.sha1Fingerprint })

        // New certificates
        for cert in newCerts where !oldCertSHAs.contains(cert.sha1Fingerprint) {
            let event = ChangeEvent(type: .added, itemName: cert.name, detail: "Certificate added")
            recentChanges.insert(event, at: 0)
        }
        // Removed certificates
        for cert in oldCerts where !newCertSHAs.contains(cert.sha1Fingerprint) {
            let event = ChangeEvent(type: .removed, itemName: cert.name, detail: "Certificate removed")
            recentChanges.insert(event, at: 0)
        }

        let oldProfileUUIDs = Set(oldProfiles.map { $0.uuid })
        let newProfileUUIDs = Set(newProfiles.map { $0.uuid })

        for profile in newProfiles where !oldProfileUUIDs.contains(profile.uuid) {
            let event = ChangeEvent(type: .added, itemName: profile.name, detail: "Profile added")
            recentChanges.insert(event, at: 0)
        }
        for profile in oldProfiles where !newProfileUUIDs.contains(profile.uuid) {
            let event = ChangeEvent(type: .removed, itemName: profile.name, detail: "Profile removed")
            recentChanges.insert(event, at: 0)
        }

        // Renewed: same name but different SHA (cert was recreated)
        let oldCertsByName = Dictionary(grouping: oldCerts, by: { $0.name })
        for cert in newCerts {
            if let oldGroup = oldCertsByName[cert.name],
               !oldGroup.contains(where: { $0.sha1Fingerprint == cert.sha1Fingerprint }),
               oldGroup.contains(where: { $0.expirationDate < cert.expirationDate }) {
                let event = ChangeEvent(type: .renewed, itemName: cert.name, detail: "Certificate renewed (new expiry: \(cert.formattedExpirationDate))")
                recentChanges.insert(event, at: 0)
            }
        }

        // Keep only last 50 changes
        if recentChanges.count > 50 { recentChanges = Array(recentChanges.prefix(50)) }
        saveRecentChanges()
    }

    private func loadRecentChanges() {
        guard let data = UserDefaults.standard.data(forKey: "recentChanges"),
              let decoded = try? JSONDecoder().decode([ChangeEvent].self, from: data) else { return }
        recentChanges = decoded
    }

    private func saveRecentChanges() {
        if let data = try? JSONEncoder().encode(recentChanges) {
            UserDefaults.standard.set(data, forKey: "recentChanges")
        }
    }

    // MARK: - Copy to Clipboard

    func copyToClipboard(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyFeedback = "\(label) copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyFeedback = nil
        }
    }

    // MARK: - Export Report

    func exportReport() {
        let report = generateReport()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "CertWatch-Report-\(formattedDateForFile()).json"
        panel.allowedContentTypes = [.json]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            try? report.write(to: url, atomically: true, encoding: .utf8)
            self?.copyFeedback = "Report exported!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.copyFeedback = nil }
        }
    }

    private func generateReport() -> String {
        var report: [String: Any] = [:]
        report["generatedAt"] = ISO8601DateFormatter().string(from: Date())
        report["summary"] = [
            "totalCertificates": certificates.count,
            "validCertificates": validCertificates.count,
            "expiringSoonCertificates": expiringSoonCertificates.count,
            "expiredCertificates": expiredCertificates.count,
            "totalProfiles": profiles.count,
            "activeProfiles": activeProfiles.count,
            "expiringSoonProfiles": expiringSoonProfiles.count,
            "expiredProfiles": expiredProfiles.count,
            "brokenProfiles": brokenProfiles.count
        ]
        report["certificates"] = certificates.map { cert in
            [
                "name": cert.name,
                "type": cert.type.rawValue,
                "team": "\(cert.teamName) (\(cert.teamId))",
                "status": cert.status.rawValue,
                "daysRemaining": cert.daysRemaining,
                "expirationDate": ISO8601DateFormatter().string(from: cert.expirationDate),
                "sha1": cert.sha1Fingerprint,
                "serialNumber": cert.serialNumber
            ] as [String: Any]
        }
        report["profiles"] = profiles.map { profile in
            [
                "name": profile.name,
                "uuid": profile.uuid,
                "bundleId": profile.bundleIdentifier,
                "type": profile.type.rawValue,
                "team": "\(profile.teamName) (\(profile.teamId))",
                "status": profile.status.rawValue,
                "daysRemaining": profile.daysRemaining,
                "expirationDate": ISO8601DateFormatter().string(from: profile.expirationDate),
                "deviceCount": profile.deviceCount
            ] as [String: Any]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) else { return "{}" }
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    private func formattedDateForFile() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Notifications

    func setupNotifications() {
        notificationService.requestAuthorization { [weak self] granted in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
                UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                if granted { self?.scheduleNotifications() }
            }
        }
    }

    func toggleNotifications(_ enabled: Bool) {
        if enabled {
            setupNotifications()
        } else {
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: "notificationsEnabled")
            notificationService.removeAllNotifications()
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = enabled
        } catch {
            print("⚠️ Launch at login toggle failed: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func scheduleNotifications() {
        notificationService.scheduleExpirationAlerts(
            certificates: certificates,
            profiles: profiles,
            brokenProfiles: brokenProfiles
        )
    }

    func sendTestNotification() { notificationService.sendTestNotification() }

    func openDeveloperPortal() {
        if let url = URL(string: "https://developer.apple.com/account/resources/certificates/list") {
            NSWorkspace.shared.open(url)
        }
    }

    func revealInFinder(profile: ProvisioningProfile) {
        NSWorkspace.shared.selectFile(profile.filePath, inFileViewerRootedAtPath: "")
    }
}
