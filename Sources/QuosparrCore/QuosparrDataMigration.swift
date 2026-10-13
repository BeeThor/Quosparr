import Darwin
import Foundation

/// Matches the Go v2 journal and completion record, so either implementation
/// can recover an interrupted upgrade. The caller holds the stable legacy lock.
struct QuosparrDataMigration {
    static let marker = ".brand-migration-v2"
    static let signature = Data("quosparr-data-migration-v2\n".utf8)
    let home: URL
    private let fm = FileManager.default
    private var target: URL { home.appendingPathComponent(".quosparr") }
    private var work: URL { home.appendingPathComponent(".quosparr-migration-v2") }

    func run() throws -> Bool {
        try checkCurrentLock()
        try recover()
        if try completed(target) { return false }
        let source = home.appendingPathComponent(".codex-runway")
        guard try directoryExists(source) else { return false }
        let hadTarget = try directoryExists(target)
        try privateDirectory(work)
        try Self.signature.write(to: work.appendingPathComponent("owner"), options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: work.appendingPathComponent("owner").path)
        let stage = work.appendingPathComponent("new")
        do {
            try privateDirectory(stage)
            if hadTarget { try copyTree(target, to: stage, merge: false) }
            try copyTree(source, to: stage, merge: true)
            try Self.signature.write(to: stage.appendingPathComponent(Self.marker), options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stage.appendingPathComponent(Self.marker).path)
        } catch {
            do { try fm.removeItem(at: work) }
            catch { NSLog("Unable to remove incomplete migration staging directory") }
            throw error
        }
        if hadTarget { try fm.moveItem(at: target, to: work.appendingPathComponent("previous")) }
        do { try fm.moveItem(at: stage, to: target) }
        catch {
            do { try recover() }
            catch { NSLog("Migration recovery failed; retained all remaining data") }
            throw error
        }
        try fm.removeItem(at: work)
        return true
    }

    private func checkCurrentLock() throws {
        let path = target.appendingPathComponent(SingleInstanceGuard.lockFileName).path
        let fd = open(path, O_RDWR | O_NOFOLLOW)
        if fd < 0 {
            if errno == ENOENT { return }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw POSIXError(.EWOULDBLOCK) }
        guard flock(fd, LOCK_UN) == 0 else { throw POSIXError(.EIO) }
    }

    func recover() throws {
        guard try directoryExists(work) else { return }
        let contents = try fm.contentsOfDirectory(atPath: work.path)
        if contents.isEmpty { try fm.removeItem(at: work); return }
        let owner = work.appendingPathComponent("owner")
        try requireRegular(owner)
        guard try Data(contentsOf: owner) == Self.signature,
              contents.allSatisfy({ ["owner", "new", "previous"].contains($0) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let previous = work.appendingPathComponent("previous")
        if try directoryExists(previous) {
            if try !directoryExists(target) { try fm.moveItem(at: previous, to: target) }
            else if try !completed(target) { throw CocoaError(.fileWriteFileExists) }
        }
        try fm.removeItem(at: work)
    }

    private func completed(_ path: URL) throws -> Bool {
        guard try directoryExists(path) else { return false }
        let record = path.appendingPathComponent(Self.marker)
        guard let values = try fileValues(record) else { return false }
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              try Data(contentsOf: record) == Self.signature else { throw CocoaError(.fileReadCorruptFile) }
        return true
    }

    private func copyTree(_ source: URL, to destination: URL, merge: Bool) throws {
        let existing = try fm.contentsOfDirectory(atPath: destination.path)
        let databases = Set(existing.compactMap(Self.databaseFamily))
        for name in try fm.contentsOfDirectory(atPath: source.path) {
            if ["codex-runway.lock", "quosparr.lock", Self.marker].contains(name) { continue }
            let from = source.appendingPathComponent(name), to = destination.appendingPathComponent(name)
            guard let values = try fileValues(from), values.isSymbolicLink != true,
                  values.isDirectory == true || values.isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
            if merge, let family = Self.databaseFamily(name), databases.contains(family) { continue }
            let current = try fileValues(to)
            if let current {
                guard current.isSymbolicLink != true, current.isDirectory == values.isDirectory,
                      current.isDirectory == true || current.isRegularFile == true else { throw CocoaError(.fileWriteFileExists) }
            }
            if values.isDirectory == true {
                try privateDirectory(to)
                try copyTree(from, to: to, merge: merge)
            } else if name == "index.json" || name == "grok-index.json" {
                let old = try Data(contentsOf: from)
                try QuosparrMigrationIndex.validate(old, name: name)
                let output = try current == nil ? old : QuosparrMigrationIndex.merge(old, current: Data(contentsOf: to), name: name)
                try output.write(to: to, options: .atomic)
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: to.path)
            } else if current == nil {
                try fm.copyItem(at: from, to: to)
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: to.path)
            }
        }
    }

    private static func databaseFamily(_ name: String) -> String? {
        var base = name
        for suffix in ["-wal", "-shm", "-journal"] where base.hasSuffix(suffix) { base.removeLast(suffix.count) }
        return ["sqlite", "sqlite3", "db"].contains((base as NSString).pathExtension) ? base : nil
    }

    private func privateDirectory(_ path: URL) throws {
        try fm.createDirectory(at: path, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
    }

    private func directoryExists(_ path: URL) throws -> Bool {
        guard let values = try fileValues(path) else { return false }
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
        return true
    }

    private func requireRegular(_ path: URL) throws {
        let values = try fileValues(path)
        guard values?.isRegularFile == true, values?.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
    }

    private func fileValues(_ path: URL) throws -> URLResourceValues? {
        // attributesOfItem does not follow symbolic links, including dangling ones.
        do { _ = try fm.attributesOfItem(atPath: path.path) }
        catch CocoaError.fileReadNoSuchFile { return nil }
        return try path.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
    }
}
