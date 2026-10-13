import Foundation
import Testing
@testable import QuosparrCore

struct QuosparrMigrationTests {
    @Test func dataCopyPreservesOriginalAndNewData() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("quosparr-migration-test-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let source = home.appendingPathComponent(".codex-runway/accounts/sample")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        let original = source.appendingPathComponent("auth.json")
        try Data("synthetic fixture".utf8).write(to: original)
        let lock = try QuosparrMigration.acquireLegacyLock(home: home)
        try withExtendedLifetime(lock) {
            #expect(try QuosparrMigration.migrateData(home: home))
            let target = home.appendingPathComponent(".quosparr/accounts/sample/auth.json")
            #expect(try Data(contentsOf: target) == Data(contentsOf: original))
            #expect((try fm.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
            try Data("changed original".utf8).write(to: original)
            #expect(try !QuosparrMigration.migrateData(home: home))
            #expect(try Data(contentsOf: target) == Data("synthetic fixture".utf8))
        }
    }

    @Test func preferencesCopyAndInvalidProxyAreExplicit() throws {
        let names = (0..<3).map { "quosparr-migration-test.\(UUID().uuidString).\($0)" }
        let stores = try names.map { try #require(UserDefaults(suiteName: $0)) }
        defer { for (name, store) in zip(names, stores) { store.removePersistentDomain(forName: name) } }
        var preferences = RunwayPreferences()
        preferences.language = .french
        let data = try JSONEncoder().encode(preferences)
        stores[1].set(data, forKey: "runway.preferences")
        try QuosparrMigration.migratePreferences(current: stores[0], previous: [stores[1]], legacy: stores[2])
        #expect(stores[0].data(forKey: "runway.preferences") == data)
        #expect(stores[1].data(forKey: "runway.preferences") == data)
        stores[1].set(Data("invalid".utf8), forKey: "runway.networkProxy")
        #expect(throws: (any Error).self) {
            try QuosparrMigration.migratePreferences(current: stores[0], previous: [stores[1]], legacy: stores[2])
        }
        #expect(stores[0].object(forKey: "runway.networkProxy") == nil)
    }

    @Test func oldAccountPackCanBeImportedAndReexported() throws {
        let data = Data(#"{"format":"codex-runway-accounts","version":1,"provider":"codex","accounts":[]}"#.utf8)
        let pack = try AccountTransferCodec.decode(data)
        #expect(pack.format == AccountTransferFormat.magic)
        #expect(AccountTransferCodec.decodeIfPack(data) != nil)
        _ = try AccountTransferCodec.encode(pack)
    }

    @Test func latestPreviewPreferencesTakePriority() throws {
        let names = (0..<4).map { "quosparr-migration-test.\(UUID().uuidString).\($0)" }
        let stores = try names.map { try #require(UserDefaults(suiteName: $0)) }
        defer { for (name, store) in zip(names, stores) { store.removePersistentDomain(forName: name) } }
        var preferences = RunwayPreferences()
        preferences.language = .french
        let latest = try JSONEncoder().encode(preferences)
        stores[1].set(latest, forKey: "runway.preferences")
        stores[2].set(try JSONEncoder().encode(RunwayPreferences()), forKey: "runway.preferences")
        try QuosparrMigration.migratePreferences(current: stores[0], previous: [stores[1], stores[2]], legacy: stores[3])
        #expect(stores[0].data(forKey: "runway.preferences") == latest)
    }
}
