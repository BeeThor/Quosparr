import QuosparrCore
@preconcurrency import CoreServices
import Foundation
import ServiceManagement

struct PreviousSystemLoginItems: PreviousLoginItems {
    static let identifiers = ["com.github.quosparr", "com.github.codex-runway", "dev.licoy.codex-runway"]
    var home: URL = FileManager.default.homeDirectoryForCurrentUser

    func state() throws -> PreviousLoginItemState {
        let session = try visitSession(remove: false)
        let agents = try launchAgents()
        return PreviousLoginItemState(exists: session || !agents.isEmpty, enabled: session || agents.contains(where: \.enabled))
    }

    func remove() throws {
        let agents = try launchAgents()
        _ = try visitSession(remove: true)
        for agent in agents { try FileManager.default.removeItem(at: agent.url) }
    }

    static func isPreviousBundle(_ url: URL) -> Bool {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        // Unknown/unresolvable entries are left alone; names alone prove nothing.
        guard let data = try? Data(contentsOf: plist),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let id = values["CFBundleIdentifier"] as? String else { return false }
        return identifiers.contains(id)
    }

    private func visitSession(remove: Bool) throws -> Bool {
        try SessionLoginItems.withList(or: .statusUnavailable) { list in
            guard let snapshot = LSSharedFileListCopySnapshot(list, nil)?.takeRetainedValue() else {
                throw LoginItemError.statusUnavailable
            }
            var found = false
            for index in 0..<CFArrayGetCount(snapshot) {
                let item = unsafeBitCast(CFArrayGetValueAtIndex(snapshot, index), to: LSSharedFileListItem.self)
                guard let resolved = LSSharedFileListItemCopyResolvedURL(item,
                    LSSharedFileListResolutionFlags(kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes), nil)?.takeRetainedValue() else { continue }
                guard Self.isPreviousBundle((resolved as URL).resolvingSymlinksInPath()) else { continue }
                found = true
                if remove, LSSharedFileListItemRemove(list, item) != noErr { throw LoginItemError.unregisterFailed }
            }
            return found
        }
    }

    struct Agent { let url: URL; let enabled: Bool }

    func launchAgents() throws -> [Agent] {
        var result: [Agent] = []
        let fm = FileManager.default
        for id in Self.identifiers {
            let url = home.appendingPathComponent("Library/LaunchAgents/\(id).plist")
            let attributes: [FileAttributeKey: Any]
            do { attributes = try fm.attributesOfItem(atPath: url.path) }
            catch CocoaError.fileReadNoSuchFile { continue }
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any],
                  values["Label"] as? String == id,
                  let args = values["ProgramArguments"] as? [String], args.count == 5,
                  args[0] == "/usr/bin/open", args[1] == "-a", args[3] == "--args", args[4] == "--mygo-login",
                  Self.isPreviousBundle(URL(fileURLWithPath: args[2])) else { throw LoginItemError.statusUnavailable }
            var enabled = values["RunAtLoad"] as? Bool == true && values["Disabled"] as? Bool != true
            if #available(macOS 13.0, *), home == fm.homeDirectoryForCurrentUser,
               SMAppService.statusForLegacyPlist(at: url) == .requiresApproval { enabled = false }
            result.append(Agent(url: url, enabled: enabled))
        }
        return result
    }
}
