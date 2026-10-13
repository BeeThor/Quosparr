import Testing
@testable import QuosparrCore

struct LoginItemMigrationTests {
    final class Current: LoginItemBackend {
        var value: LoginItemStatus = .notRegistered
        var afterRegistration: LoginItemStatus = .enabled
        var writes = 0
        func status() throws -> LoginItemStatus { value }
        func register() throws { writes += 1; value = afterRegistration }
        func unregister() throws { writes += 1; value = .notRegistered }
    }
    final class Previous: PreviousLoginItems {
        var value = PreviousLoginItemState(exists: true, enabled: true)
        var removals = 0
        var removalFails = false
        func state() throws -> PreviousLoginItemState { value }
        func remove() throws {
            removals += 1
            if removalFails { throw LoginItemError.unregisterFailed }
            value.exists = false
            value.enabled = false
        }
    }

    @Test func enabledEntryMovesOnlyAfterReplacementWorks() throws {
        let current = Current(), previous = Previous()
        let backend = MigratingLoginItemBackend(current: current, previous: previous)
        #expect(try backend.status() == .enabled)
        #expect(current.writes == 1 && previous.removals == 1)
        _ = try backend.status()
        #expect(current.writes == 1 && previous.removals == 1)
    }
    @Test func systemDisabledChoiceIsPreserved() throws {
        let current = Current(), previous = Previous()
        previous.value.enabled = false
        let backend = MigratingLoginItemBackend(current: current, previous: previous)
        #expect(try backend.status() == .notRegistered)
        #expect(current.writes == 0 && previous.removals == 1)
    }
    @Test func pendingApprovalRetainsWorkingOldEntry() throws {
        let current = Current(), previous = Previous()
        current.afterRegistration = .requiresApproval
        let backend = MigratingLoginItemBackend(current: current, previous: previous)
        #expect(try backend.status() == .requiresApproval)
        #expect(previous.value.exists && previous.removals == 0)
    }
    @Test func failuresAreVisibleAndOldRegistrationRemains() throws {
        let current = Current(), previous = Previous()
        current.afterRegistration = .notRegistered
        let backend = MigratingLoginItemBackend(current: current, previous: previous)
        #expect(throws: LoginItemError.registerFailed) { try backend.status() }
        #expect(throws: LoginItemError.registerFailed) { try backend.status() }
        #expect(current.writes == 1 && previous.removals == 0 && previous.value.exists)
        let other = MigratingLoginItemBackend(current: Current(), previous: previous)
        previous.removalFails = true
        #expect(throws: LoginItemError.unregisterFailed) { try other.status() }
        #expect(previous.value.exists)
    }
    @Test func developmentHostDoesNotReadOrChangeLoginItems() throws {
        let current = Current(), previous = Previous()
        let item = LoginItemApplier(backend: MigratingLoginItemBackend(current: current, previous: previous), canMutateSystem: false)
        #expect(try item.status() == .unavailable)
        #expect(current.writes == 0 && previous.removals == 0)
    }
}
