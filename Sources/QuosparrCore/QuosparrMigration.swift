import Foundation

/// One-time brand migration; original data remains available for recovery.
public enum QuosparrMigration {
    private static let oldDirectory = ".codex-runway"
    private static let oldLock = "codex-runway.lock"

    public static func acquireLegacyLock(home: URL) throws -> SingleInstanceGuard? {
        let root = home.appendingPathComponent(oldDirectory, isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        guard let lock = try SingleInstanceGuard.acquire(lockURL: root.appendingPathComponent(oldLock)) else {
            throw POSIXError(.EWOULDBLOCK)
        }
        return lock
    }

    /// Call while holding the previous app's lock and before opening any stores.
    public static func migrateData(home: URL) throws -> Bool {
        try QuosparrDataMigration(home: home).run()
    }

    public static func migratePreferences(current: UserDefaults, previous: [UserDefaults], legacy: UserDefaults) throws {
        for key in ["runway.preferences", "runway.networkProxy"] where current.object(forKey: key) == nil {
            let value = previous.lazy.compactMap { $0.object(forKey: key) }.first
                ?? (key == "runway.preferences" ? legacy.object(forKey: key) : nil)
            guard let value else { continue }
            guard let data = value as? Data else { throw CocoaError(.propertyListReadCorrupt) }
            if key == "runway.preferences" {
                _ = try JSONDecoder().decode(RunwayPreferences.self, from: data)
            } else {
                let proxy = try JSONDecoder().decode(NetworkProxyConfiguration.self, from: data).validated()
                if proxy.usesAuthentication && proxy.credentialID == nil {
                    throw NetworkProxyError.credentialsUnavailable
                }
            }
            current.set(data, forKey: key)
            guard current.data(forKey: key) == data else { throw CocoaError(.fileWriteUnknown) }
            NSLog("Migrated %@ settings to Quosparr", key)
        }
    }
}
