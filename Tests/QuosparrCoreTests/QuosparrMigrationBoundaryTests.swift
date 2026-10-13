import Foundation
import Testing
@testable import QuosparrCore

struct QuosparrMigrationBoundaryTests {
    private func withHome(_ body: (URL) throws -> Void) throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("migration-boundary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try body(home)
    }
    private func put(_ home: URL, _ path: String, _ value: String) throws {
        let file = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: file)
    }
    private func get(_ home: URL, _ path: String) throws -> String {
        String(decoding: try Data(contentsOf: home.appendingPathComponent(path)), as: UTF8.self)
    }
    private func index(_ grok: Bool, active: String, ids: [String]) throws -> String {
        let rows: [[String: Any]] = ids.enumerated().map { order, id in
            var row: [String: Any] = ["id": id, "sortIndex": order, "createdAt": "2026-10-12T00:00:00Z", "requiresReauth": false]
            if grok { row["identity"] = ["kind": "oauth", "scope": "test", "hasAccessToken": true, "hasRefreshToken": true] }
            else { row["authMode"] = "oauth"; row["displayName"] = id }
            return row
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: ["version": 1, "accounts": rows, grok ? "currentAccountID" : "activeAccountId": active]), as: UTF8.self)
    }

    @Test(arguments: [false, true]) func mergesLibrariesPreservingNewData(grok: Bool) throws {
        try withHome { home in
            let name = grok ? "grok-index.json" : "index.json"
            try put(home, ".codex-runway/accounts/\(name)", index(grok, active: "old", ids: ["same", "old"]))
            try put(home, ".quosparr/accounts/\(name)", index(grok, active: "new", ids: ["new", "same"]))
            try put(home, ".codex-runway/accounts/same/auth.json", "old credential fixture")
            try put(home, ".codex-runway/accounts/old/auth.json", "older fixture")
            try put(home, ".quosparr/accounts/same/auth.json", "new credential fixture")
            #expect(try QuosparrMigration.migrateData(home: home))
            let root = try #require(JSONSerialization.jsonObject(with: Data(get(home, ".quosparr/accounts/\(name)").utf8)) as? [String: Any])
            let rows = try #require(root["accounts"] as? [[String: Any]])
            #expect(rows.count == 3 && rows[2]["id"] as? String == "old" && rows[2]["sortIndex"] as? Int == 2)
            #expect(root[grok ? "currentAccountID" : "activeAccountId"] as? String == "new")
            #expect(try get(home, ".quosparr/accounts/same/auth.json") == "new credential fixture")
            #expect(try get(home, ".quosparr/accounts/old/auth.json") == "older fixture")
            try FileManager.default.removeItem(at: home.appendingPathComponent(".quosparr/accounts/old"))
            #expect(try !QuosparrMigration.migrateData(home: home))
            #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".quosparr/accounts/old").path))
        }
    }

    @Test func databaseFamiliesStayTogether() throws {
        try withHome { home in
            try put(home, ".codex-runway/usage.sqlite", "old database")
            try put(home, ".codex-runway/usage.sqlite-wal", "old WAL")
            try put(home, ".quosparr/usage.sqlite", "new database")
            try put(home, ".codex-runway/other.sqlite", "other database")
            try put(home, ".codex-runway/other.sqlite-wal", "other WAL")
            _ = try QuosparrMigration.migrateData(home: home)
            #expect(try get(home, ".quosparr/usage.sqlite") == "new database")
            #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".quosparr/usage.sqlite-wal").path))
            #expect(try get(home, ".quosparr/other.sqlite-wal") == "other WAL")
        }
    }

    @Test(arguments: ["preparing", "old renamed", "committed"]) func interruptedMigrationRecovers(phase: String) throws {
        try withHome { home in
            try put(home, ".codex-runway/missing", "old")
            try put(home, ".quosparr/keep", "new")
            try put(home, ".quosparr-migration-v2/owner", "quosparr-data-migration-v2\n")
            try put(home, ".quosparr-migration-v2/new/partial", "partial")
            if phase != "preparing" {
                try FileManager.default.moveItem(at: home.appendingPathComponent(".quosparr"), to: home.appendingPathComponent(".quosparr-migration-v2/previous"))
            }
            if phase == "committed" {
                try put(home, ".quosparr/keep", "committed")
                try put(home, ".quosparr/.brand-migration-v2", "quosparr-data-migration-v2\n")
            }
            _ = try QuosparrMigration.migrateData(home: home)
            #expect(try get(home, ".quosparr/keep") == (phase == "committed" ? "committed" : "new"))
            #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".quosparr-migration-v2").path))
        }
    }

    @Test(arguments: ["conflict", "invalid index", "symlink"]) func invalidInputsNeverPartiallyInstall(kind: String) throws {
        try withHome { home in
            try put(home, ".quosparr/keep", "new")
            try put(home, ".codex-runway/first", "old")
            if kind == "conflict" {
                try put(home, ".quosparr/accounts", "file")
                try put(home, ".codex-runway/accounts/sample/auth.json", "fixture")
            } else if kind == "invalid index" { try put(home, ".codex-runway/accounts/index.json", "bad JSON") }
            else { try FileManager.default.createSymbolicLink(at: home.appendingPathComponent(".codex-runway/link"), withDestinationURL: home) }
            #expect(throws: (any Error).self) { try QuosparrMigration.migrateData(home: home) }
            #expect(try get(home, ".quosparr/keep") == "new")
            #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".quosparr/first").path))
        }
    }

    @Test func refusesActiveCurrentInstance() throws {
        try withHome { home in
            try put(home, ".codex-runway/keep", "old")
            let lock = try #require(try SingleInstanceGuard.acquire(lockURL: SingleInstanceGuard.defaultLockURL(homeDirectory: home)))
            _ = withExtendedLifetime(lock) {
                #expect(throws: (any Error).self) { try QuosparrMigration.migrateData(home: home) }
            }
        }
    }
}
