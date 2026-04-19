import Foundation
import CryptoKit
import Security

// MARK: - Provisioning Profile Service
/// Reads and parses provisioning profiles from ~/Library/MobileDevice/Provisioning Profiles/
class ProvisioningProfileService {

    static let shared = ProvisioningProfileService()

    /// Directories where macOS/Xcode store provisioning profiles
    private let profilesDirectories: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/MobileDevice/Provisioning Profiles",
            "\(home)/Library/Developer/Xcode/UserData/Provisioning Profiles"
        ]
    }()

    private init() {}

    /// Fetches all provisioning profiles from disk
    func fetchProfiles() -> [ProvisioningProfile] {
        let fileManager = FileManager.default
        var allParsed: [ProvisioningProfile] = []
        var seenUUIDs = Set<String>()

        for directory in profilesDirectories {
            print("📦 [ProfileService] Looking for profiles in: \(directory)")

            guard fileManager.fileExists(atPath: directory) else {
                print("📦 [ProfileService] ⚠️ Directory does NOT exist: \(directory)")
                continue
            }

            do {
                let files = try fileManager.contentsOfDirectory(atPath: directory)
                let provisionFiles = files.filter { $0.hasSuffix(".mobileprovision") || $0.hasSuffix(".provisionprofile") }

                print("📦 [ProfileService] Found \(files.count) total files, \(provisionFiles.count) provision files")

                for fileName in provisionFiles {
                    let filePath = "\(directory)/\(fileName)"
                    if let profile = parseProfile(at: filePath) {
                        // Deduplicate by UUID (same profile can exist in both directories)
                        guard !seenUUIDs.contains(profile.uuid) else {
                            print("📦 [ProfileService] ⏭️ Skipping duplicate: \(profile.name) (\(profile.uuid))")
                            continue
                        }
                        seenUUIDs.insert(profile.uuid)
                        print("📦 [ProfileService] ✅ Parsed: \(profile.name) (\(profile.type.rawValue)) expires \(profile.formattedExpirationDate)")
                        allParsed.append(profile)
                    } else {
                        print("📦 [ProfileService] ⚠️ Failed to parse: \(fileName)")
                    }
                }
            } catch {
                print("📦 [ProfileService] ⚠️ Failed to read directory: \(error)")
            }
        }

        print("📦 [ProfileService] Total: \(allParsed.count) unique profiles")
        return allParsed
    }

    /// Parses a single .mobileprovision file
    private func parseProfile(at path: String) -> ProvisioningProfile? {
        guard let data = FileManager.default.contents(atPath: path) else {
            print("📦 [ProfileService] Cannot read file data: \(path)")
            return nil
        }

        print("📦 [ProfileService] Read \(data.count) bytes from \((path as NSString).lastPathComponent)")

        // .mobileprovision files are CMS signed plists
        guard let plistData = extractPlistFromCMS(data: data) else {
            print("📦 [ProfileService] ⚠️ Could not extract plist from CMS envelope")
            return nil
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            print("📦 [ProfileService] ⚠️ Could not deserialize plist data")
            return nil
        }

        return buildProfile(from: plist, filePath: path)
    }

    /// Extracts the embedded plist from a CMS-signed .mobileprovision file
    private func extractPlistFromCMS(data: Data) -> Data? {
        guard let xmlStart = data.range(of: Data("<?xml".utf8)),
              let plistEnd = data.range(of: Data("</plist>".utf8)) else {
            print("📦 [ProfileService] ⚠️ No XML plist markers found in CMS data")
            return nil
        }

        let endIndex = plistEnd.upperBound
        return data.subdata(in: xmlStart.lowerBound..<endIndex)
    }

    /// Builds a ProvisioningProfile from parsed plist data
    private func buildProfile(from plist: [String: Any], filePath: String) -> ProvisioningProfile? {
        guard let name = plist["Name"] as? String else {
            print("📦 [ProfileService] ⚠️ Missing 'Name' in plist")
            return nil
        }
        guard let uuid = plist["UUID"] as? String else {
            print("📦 [ProfileService] ⚠️ Missing 'UUID' in plist for \(name)")
            return nil
        }
        guard let teamIds = plist["TeamIdentifier"] as? [String] else {
            print("📦 [ProfileService] ⚠️ Missing 'TeamIdentifier' in plist for \(name)")
            return nil
        }
        guard let creationDate = plist["CreationDate"] as? Date else {
            print("📦 [ProfileService] ⚠️ Missing/invalid 'CreationDate' in plist for \(name)")
            return nil
        }
        guard let expirationDate = plist["ExpirationDate"] as? Date else {
            print("📦 [ProfileService] ⚠️ Missing/invalid 'ExpirationDate' in plist for \(name)")
            return nil
        }

        let teamName = plist["TeamName"] as? String ?? "Unknown Team"
        let appIdName = plist["AppIDName"] as? String ?? "Unknown App"
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let devices = plist["ProvisionedDevices"] as? [String]

        let bundleId = entitlements["application-identifier"] as? String ?? "N/A"
        let certData = plist["DeveloperCertificates"] as? [Data] ?? []
        let certNames = extractCertificateNames(from: certData)
        let certSHA1s = extractCertificateSHA1s(from: certData)
        let type = detectProfileType(plist: plist, devices: devices)
        let simpleEntitlements = simplifyEntitlements(entitlements)

        return ProvisioningProfile(
            name: name,
            uuid: uuid,
            appIdName: appIdName,
            bundleIdentifier: bundleId,
            teamId: teamIds.first ?? "N/A",
            teamName: teamName,
            type: type,
            creationDate: creationDate,
            expirationDate: expirationDate,
            entitlements: simpleEntitlements,
            certificateNames: certNames,
            certificateSHA1s: certSHA1s,
            provisionedDevices: devices,
            filePath: filePath
        )
    }

    // MARK: - Helper Methods

    private func detectProfileType(plist: [String: Any], devices: [String]?) -> ProfileType {
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let getTaskAllow = entitlements["get-task-allow"] as? Bool ?? false
        let provisionAllDevices = plist["ProvisionsAllDevices"] as? Bool ?? false

        if provisionAllDevices {
            return .enterprise
        } else if getTaskAllow {
            return .development
        } else if devices != nil {
            return .adHoc
        } else {
            return .appStore
        }
    }

    private func extractCertificateNames(from certDataArray: [Data]) -> [String] {
        return certDataArray.compactMap { data in
            guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return nil }
            return SecCertificateCopySubjectSummary(certificate) as String?
        }
    }

    private func extractCertificateSHA1s(from certDataArray: [Data]) -> [String] {
        return certDataArray.map { data in
            let digest = Insecure.SHA1.hash(data: data)
            return digest.map { String(format: "%02X", $0) }.joined(separator: ":")
        }
    }

    private func simplifyEntitlements(_ entitlements: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        let importantKeys = [
            "application-identifier",
            "com.apple.developer.team-identifier",
            "aps-environment",
            "com.apple.developer.icloud-container-identifiers",
            "com.apple.developer.associated-domains",
            "com.apple.security.application-groups",
            "get-task-allow"
        ]

        for key in importantKeys {
            if let value = entitlements[key] {
                let shortKey = key.components(separatedBy: ".").last ?? key
                result[shortKey] = "\(value)"
            }
        }

        return result
    }
}
