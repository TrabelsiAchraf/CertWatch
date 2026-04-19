import Foundation
import Security
import CryptoKit

// MARK: - Keychain Service
/// Reads Apple Developer certificates from the macOS Keychain
class KeychainService {

    static let shared = KeychainService()

    private init() {}

    /// Fetches all Apple Developer certificates from the Keychain
    func fetchCertificates() -> [Certificate] {
        print("🔑 [KeychainService] Starting certificate fetch...")

        // Approach 1: SecItemCopyMatching on default keychain
        let certs = fetchViaSecItem()
        if !certs.isEmpty {
            print("🔑 [KeychainService] SecItemCopyMatching returned \(certs.count) Apple Dev certificates")
            return certs
        }

        // Approach 2: Fallback to security CLI
        print("🔑 [KeychainService] SecItemCopyMatching returned 0 results, trying CLI fallback...")
        let cliFallback = fetchViaCLI()
        print("🔑 [KeychainService] CLI fallback returned \(cliFallback.count) Apple Dev certificates")
        return cliFallback
    }

    // MARK: - Approach 1: SecItemCopyMatching

    private func fetchViaSecItem() -> [Certificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            print("🔑 [KeychainService] SecItemCopyMatching failed with OSStatus: \(status)")
            if status == errSecItemNotFound {
                print("🔑 [KeychainService] → errSecItemNotFound: No certificates in keychain")
            } else if status == errSecAuthFailed {
                print("🔑 [KeychainService] → errSecAuthFailed: Keychain access denied (sandbox?)")
            }
            return []
        }

        guard let certificates = result as? [SecCertificate] else {
            print("🔑 [KeychainService] Result is not [SecCertificate], got: \(type(of: result))")
            return []
        }

        print("🔑 [KeychainService] Found \(certificates.count) total certificates in keychain")

        return certificates.compactMap { secCert in
            let summary = SecCertificateCopySubjectSummary(secCert) as String? ?? "Unknown"

            guard isAppleDeveloperCertificate(summary) else {
                return nil
            }

            print("🔑 [KeychainService] Parsing Apple Dev cert: \(summary)")
            return parseCertificate(secCert, summary: summary)
        }
    }

    // MARK: - Approach 2: CLI Fallback

    private func fetchViaCLI() -> [Certificate] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-certificate", "-a", "-p"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("🔑 [KeychainService] CLI failed: \(error)")
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let pemBlocks = output.components(separatedBy: "-----BEGIN CERTIFICATE-----")
            .dropFirst()
            .compactMap { block -> Data? in
                guard let endRange = block.range(of: "-----END CERTIFICATE-----") else { return nil }
                let base64 = block[block.startIndex..<endRange.lowerBound]
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                return Data(base64Encoded: base64)
            }

        print("🔑 [KeychainService] CLI found \(pemBlocks.count) PEM certificates")

        return pemBlocks.compactMap { derData -> Certificate? in
            guard let secCert = SecCertificateCreateWithData(nil, derData as CFData) else { return nil }
            let summary = SecCertificateCopySubjectSummary(secCert) as String? ?? "Unknown"
            guard isAppleDeveloperCertificate(summary) else { return nil }
            print("🔑 [KeychainService] CLI parsing: \(summary)")
            return parseCertificate(secCert, summary: summary)
        }
    }

    // MARK: - Certificate Parsing

    private func parseCertificate(_ secCertificate: SecCertificate, summary: String) -> Certificate? {
        let type = detectCertificateType(from: summary)
        let (teamId, teamName) = extractTeamInfo(from: summary)
        let sha1 = extractSHA1Fingerprint(secCertificate)

        // Extract dates using multiple strategies
        let (issueDate, expirationDate) = extractDates(from: secCertificate)

        guard let expDate = expirationDate else {
            print("🔑 [KeychainService] ⚠️ Could not extract expiration date for: \(summary)")
            return nil
        }

        let serialNumber = extractSerialNumber(from: secCertificate)

        print("🔑 [KeychainService] ✅ Parsed: \(summary) | expires: \(expDate) | team: \(teamName)")

        return Certificate(
            name: summary,
            type: type,
            serialNumber: serialNumber,
            teamId: teamId,
            teamName: teamName,
            issueDate: issueDate ?? Date(),
            expirationDate: expDate,
            sha1Fingerprint: sha1
        )
    }

    // MARK: - Date Extraction

    private func extractDates(from certificate: SecCertificate) -> (issue: Date?, expiration: Date?) {
        // Strategy 1: Use SecCertificateCopyValues with known OID keys
        if let dates = extractDatesFromValues(certificate) {
            return dates
        }

        // Strategy 2: Parse the DER data directly using security CLI for this specific cert
        print("🔑 [KeychainService] SecCertificateCopyValues date extraction failed, trying OID iteration...")
        if let dates = extractDatesViaOIDIteration(certificate) {
            return dates
        }

        print("🔑 [KeychainService] ⚠️ All date extraction strategies failed")
        return (nil, nil)
    }

    private func extractDatesFromValues(_ certificate: SecCertificate) -> (issue: Date?, expiration: Date?)? {
        var error: Unmanaged<CFError>?
        guard let valuesDict = SecCertificateCopyValues(certificate, nil, &error) as? [String: Any] else {
            if let err = error?.takeRetainedValue() {
                print("🔑 [KeychainService] SecCertificateCopyValues error: \(err)")
            }
            return nil
        }

        var issueDate: Date?
        var expirationDate: Date?

        // Iterate all entries to find date fields by label (more robust than hardcoded OIDs)
        for (oid, rawValue) in valuesDict {
            guard let entry = rawValue as? [String: Any] else { continue }
            let label = entry["label"] as? String ?? ""

            if label.contains("Not Valid Before") || label == "Not Before" {
                issueDate = extractDateValue(from: entry, oid: oid)
            } else if label.contains("Not Valid After") || label == "Not After" {
                expirationDate = extractDateValue(from: entry, oid: oid)
            }
        }

        if expirationDate != nil {
            return (issueDate, expirationDate)
        }

        return nil
    }

    private func extractDatesViaOIDIteration(_ certificate: SecCertificate) -> (issue: Date?, expiration: Date?)? {
        // Try well-known OIDs for X.509 validity
        let possibleNotBeforeOIDs = [
            "2.16.840.1.113741.2.1.1.1.6",  // Apple-specific
            "2.16.840.1.113741.2.1.1.1.7",
            "2.5.4.24"                         // Standard X.509
        ]
        let possibleNotAfterOIDs = [
            "2.16.840.1.113741.2.1.1.1.7",
            "2.16.840.1.113741.2.1.1.1.8",
            "2.5.4.25"
        ]

        var error: Unmanaged<CFError>?

        // Try requesting specific OIDs
        let allOIDs = (possibleNotBeforeOIDs + possibleNotAfterOIDs).map { $0 as CFString } as CFArray
        guard let valuesDict = SecCertificateCopyValues(certificate, allOIDs, &error) as? [String: Any] else {
            return nil
        }

        var issueDate: Date?
        var expirationDate: Date?

        for oid in possibleNotBeforeOIDs {
            if let entry = valuesDict[oid] as? [String: Any] {
                issueDate = extractDateValue(from: entry, oid: oid)
                if issueDate != nil { break }
            }
        }

        for oid in possibleNotAfterOIDs {
            if let entry = valuesDict[oid] as? [String: Any] {
                let date = extractDateValue(from: entry, oid: oid)
                // Pick the one that's in the future or most recent (not-before date)
                if let d = date, d != issueDate {
                    expirationDate = d
                    break
                }
            }
        }

        if expirationDate != nil {
            return (issueDate, expirationDate)
        }
        return nil
    }

    /// Extracts a Date from a SecCertificateCopyValues entry, handling multiple value types
    private func extractDateValue(from entry: [String: Any], oid: String) -> Date? {
        let value = entry["value"]

        // Direct Date
        if let date = value as? Date {
            return date
        }

        // CFNumber (absolute time / seconds since reference date 2001-01-01)
        if let number = value as? NSNumber {
            let absTime = number.doubleValue
            // CFAbsoluteTime reference is 2001-01-01
            let date = Date(timeIntervalSinceReferenceDate: absTime)
            // Sanity check: should be between 2000 and 2050
            let year = Calendar.current.component(.year, from: date)
            if year >= 2000 && year <= 2050 {
                return date
            }
            // Maybe it's Unix timestamp
            let unixDate = Date(timeIntervalSince1970: absTime)
            let unixYear = Calendar.current.component(.year, from: unixDate)
            if unixYear >= 2000 && unixYear <= 2050 {
                return unixDate
            }
        }

        // String date
        if let string = value as? String {
            let formatters: [DateFormatter] = {
                let iso = DateFormatter()
                iso.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

                let iso2 = DateFormatter()
                iso2.dateFormat = "MMM d, yyyy"

                return [iso, iso2]
            }()

            for formatter in formatters {
                if let date = formatter.date(from: string) {
                    return date
                }
            }
        }

        print("🔑 [KeychainService] Could not parse date from OID \(oid), value type: \(type(of: value)), value: \(String(describing: value))")
        return nil
    }

    // MARK: - Serial Number

    private func extractSerialNumber(from certificate: SecCertificate) -> String {
        var error: Unmanaged<CFError>?
        guard let valuesDict = SecCertificateCopyValues(certificate, nil, &error) as? [String: Any] else {
            return "N/A"
        }

        for (_, rawValue) in valuesDict {
            guard let entry = rawValue as? [String: Any] else { continue }
            let label = entry["label"] as? String ?? ""

            if label.contains("Serial Number") {
                if let value = entry["value"] as? String {
                    return value
                }
                if let value = entry["value"] as? Data {
                    return value.map { String(format: "%02X", $0) }.joined(separator: ":")
                }
            }
        }

        return "N/A"
    }

    // MARK: - Helper Methods

    private func isAppleDeveloperCertificate(_ name: String) -> Bool {
        let developerKeywords = [
            "Apple Development",
            "Apple Distribution",
            "iPhone Distribution",
            "iPhone Developer",
            "Mac Developer",
            "3rd Party Mac Developer",
            "Apple Push Services",
            "Apple Push Notification"
        ]
        return developerKeywords.contains { name.contains($0) }
    }

    private func detectCertificateType(from name: String) -> CertificateType {
        if name.contains("Development") || name.contains("Developer") {
            return .development
        } else if name.contains("Distribution") {
            return .distribution
        } else if name.contains("Push") {
            return .pushNotification
        }
        return .unknown
    }

    private func extractTeamInfo(from name: String) -> (teamId: String, teamName: String) {
        let components = name.components(separatedBy: ": ")
        if components.count > 1 {
            let teamPart = components[1]
            if let range = teamPart.range(of: "\\(([A-Z0-9]+)\\)", options: .regularExpression) {
                let teamId = String(teamPart[range]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                let teamName = teamPart.replacingOccurrences(of: "\\s*\\([A-Z0-9]+\\)", with: "", options: .regularExpression)
                return (teamId, teamName.trimmingCharacters(in: .whitespaces))
            }
            return ("N/A", teamPart)
        }
        return ("N/A", "Unknown Team")
    }

    private func extractSHA1Fingerprint(_ certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
