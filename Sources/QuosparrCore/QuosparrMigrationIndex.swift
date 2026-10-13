import Foundation

/// Merge raw objects after validating the existing schema, retaining unknown
/// fields and the new library's current selection and duplicate-ID metadata.
enum QuosparrMigrationIndex {
    static func validate(_ data: Data, name: String) throws {
        do {
            let decoder = JSONDecoder()
            let version: Int
            if name == "grok-index.json" {
                decoder.dateDecodingStrategy = .grokAccountStoreDates
                version = try decoder.decode(GrokAccountIndex.self, from: data).version
            } else {
                decoder.dateDecodingStrategy = .accountStoreDates
                version = try decoder.decode(AccountIndex.self, from: data).version
            }
            guard version == 1,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rows = root["accounts"] as? [[String: Any]] else { throw CocoaError(.fileReadCorruptFile) }
            var ids = Set<String>()
            for row in rows {
                let (id, _) = try identity(row)
                guard ids.insert(id).inserted else { throw CocoaError(.fileReadCorruptFile) }
            }
        } catch { throw CocoaError(.fileReadCorruptFile) } // Never expose credential-like decoder contents.
    }

    static func merge(_ old: Data, current: Data, name: String) throws -> Data {
        try validate(current, name: name)
        guard let previous = try JSONSerialization.jsonObject(with: old) as? [String: Any],
              var next = try JSONSerialization.jsonObject(with: current) as? [String: Any],
              let previousRows = previous["accounts"] as? [[String: Any]],
              var rows = next["accounts"] as? [[String: Any]] else { throw CocoaError(.fileReadCorruptFile) }
        var ids = Set<String>(), oldIDs = Set<String>(), order = -1
        for row in rows {
            let (id, index) = try identity(row)
            guard ids.insert(id).inserted else { throw CocoaError(.fileReadCorruptFile) }
            order = max(order, index)
        }
        for var row in previousRows {
            let (id, _) = try identity(row)
            guard oldIDs.insert(id).inserted else { throw CocoaError(.fileReadCorruptFile) }
            if ids.contains(id) { continue }
            guard order < Int.max else { throw CocoaError(.fileReadCorruptFile) }
            order += 1
            row["sortIndex"] = order
            rows.append(row)
        }
        if rows.count == ids.count { return current }
        next["accounts"] = rows
        return try JSONSerialization.data(withJSONObject: next, options: [.prettyPrinted, .sortedKeys])
    }

    private static func identity(_ row: [String: Any]) throws -> (String, Int) {
        guard let id = row["id"] as? String, !id.isEmpty, ![".", ".."].contains(id),
              !id.contains("/"), !id.contains("\\"), let order = row["sortIndex"] as? Int else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (id, order)
    }
}
