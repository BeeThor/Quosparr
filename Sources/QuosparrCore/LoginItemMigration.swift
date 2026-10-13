import Foundation

public struct PreviousLoginItemState: Sendable {
    public var exists: Bool
    public var enabled: Bool
    public init(exists: Bool, enabled: Bool) { self.exists = exists; self.enabled = enabled }
}

public protocol PreviousLoginItems {
    func state() throws -> PreviousLoginItemState
    func remove() throws
}

/// A working replacement is required before retiring enabled previous entries.
/// System-disabled entries are cleaned up without enabling the new application.
public final class MigratingLoginItemBackend: LoginItemBackend {
    private let current: any LoginItemBackend
    private let previous: any PreviousLoginItems
    private let lock = NSRecursiveLock()
    private var attempted = false
    private var migrationError: (any Error)?

    public init(current: any LoginItemBackend, previous: any PreviousLoginItems) {
        self.current = current
        self.previous = previous
    }

    public func status() throws -> LoginItemStatus {
        lock.lock()
        defer { lock.unlock() }
        if !attempted {
            attempted = true
            do { try migrate() } catch { migrationError = error }
        }
        if let migrationError { throw migrationError }
        return try current.status()
    }

    public func register() throws { _ = try status(); try current.register() }
    public func unregister() throws { _ = try status(); try current.unregister() }

    private func migrate() throws {
        let old = try previous.state()
        guard old.exists else { return }
        if old.enabled {
            if try current.status() == .notRegistered { try current.register() }
            let status = try current.status()
            if status == .requiresApproval { return }
            guard status == .enabled else { throw LoginItemError.registerFailed }
        }
        try previous.remove()
        guard try !previous.state().exists else { throw LoginItemError.unregisterFailed }
    }
}
