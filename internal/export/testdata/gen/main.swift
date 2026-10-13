// Generates the Swift-encoded fixtures that the Go tests of internal/sessions,
// internal/alerts, internal/estimate and internal/export compare against byte
// for byte. It links the real QuosparrCore, so the bytes are exactly what the
// Swift app wrote. Run regenerate.sh next to this file; the fixtures are
// committed, so the Go tests do not need Swift.
import Foundation
@testable import QuosparrCore

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func out(_ package: String, _ name: String, _ data: Data) throws {
    let dir = root.appendingPathComponent("internal/\(package)/testdata", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try data.write(to: dir.appendingPathComponent(name))
}
func out(_ package: String, _ name: String, _ text: String) throws { try out(package, name, Data(text.utf8)) }
func date(_ s: String) -> Date { try! Date(s, strategy: .iso8601) }
func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
func compactEncoder(sorted: Bool = true, pretty: Bool = false) -> JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    var f: JSONEncoder.OutputFormatting = []
    if sorted { f.insert(.sortedKeys) }
    if pretty { f.insert(.prettyPrinted) }
    e.outputFormatting = f
    return e
}

// MARK: scalar encoding (swiftjson)
struct Scalars: Codable {
    var doubles: [Double]
    var strings: [String]
    var decimals: [Decimal]
    var date: Date
}
let doubles: [Double] = [
    0, -0.0, 1, 12, 0.04, 0.5, 100, 1234.5678, 33.333333333333336, 0.1 + 0.2, 3379.6, 112662.5,
    1e15, 9007199254740992, 9007199254740994, 1e16, 1e20, 1e21, 1.2345678901234568e17,
    0.0001, 0.00012345, 0.00001, 1e-7, 1.5e-10, 5e-324, 1.7976931348623157e308, -2.5, -1e-5, -123456.789,
    Double(Int.max), 4503599627370496.5, 0.30000000000000004, 2.2250738585072014e-308, 123456789.123456789,
]
let strings = [
    "", "plain", "a/b", "a\\b", "quote\"inside", "<tag>&amp;", "tab\tnew\nline\rret", "\u{08}\u{0c}\u{00}\u{01}\u{1f}",
    "del\u{7f}end", "caf\u{e9}", "\u{2028}\u{2029}", "emoji \u{1F600} \u{1F468}\u{200D}\u{1F469}", "中文/路径\\x", "https://x.com/a/b?c=d&e=f",
]
let decimalTexts = [
    "0", "1", "12.5", "0.00132", "0.132", "0.0264", "123456789012345678901234567890", "1000", "0.216048", "4.25", "100.10", "-3.75",
    "0.1", "99999999.99999999",
]
let scalars = Scalars(
    doubles: doubles, strings: strings,
    decimals: decimalTexts.map { Decimal(string: $0)! },
    date: Date(timeIntervalSince1970: 1_800_000_000.987))
try out("export", "swift_scalars.json", try compactEncoder().encode(scalars))
try out("export", "swift_scalars_pretty.json", try compactEncoder(pretty: true).encode(scalars))

struct Empties: Codable { var a: [Int]; var b: [String: Int]; var c: String?; var d: [[Int]]; var e: Int }
try out("export", "swift_empties_pretty.json", try compactEncoder(pretty: true).encode(Empties(a: [], b: [:], c: nil, d: [[], [1]], e: 1)))
try out("export", "swift_empties.json", try compactEncoder().encode(Empties(a: [], b: [:], c: nil, d: [[], [1]], e: 1)))

// MARK: estimate history
do {
    let url = tempDir().appendingPathComponent("quota-estimate-history.json")
    let store = QuotaEstimateHistoryStore(fileURL: url)
    let base = date("2026-06-29T12:00:00Z")
    for index in 0..<14 {
        _ = store.upsert(accountKey: "oauth:user:abc|account:acct", sample: QuotaEstimateHistorySample(
            cycleStartDate: String(format: "2026-05-%02d", index + 1),
            estimatedCredits: Double(100 + index) + 0.5,
            usedPercent: 40 + Double(index) / 3,
            usedCredits: 40.25 * Double(index + 1),
            recordedAt: base.addingTimeInterval(Double(index) * 60 + 0.75)))
    }
    _ = store.upsert(accountKey: "oauth:user:abc|account:acct", sample: QuotaEstimateHistorySample(
        cycleStartDate: "2026-05-14", estimatedCredits: 50, usedPercent: 20, usedCredits: 10, recordedAt: base.addingTimeInterval(1_000)))
    _ = store.upsert(accountKey: "unknown", sample: QuotaEstimateHistorySample(
        cycleStartDate: "2026-06-22", estimatedCredits: 112662.5, usedPercent: 3, usedCredits: 3379.6, recordedAt: base))
    _ = store.upsert(accountKey: "id:api-é/中", sample: QuotaEstimateHistorySample(
        cycleStartDate: "2026-06-22", estimatedCredits: 1e20, usedPercent: 0.00001, usedCredits: 0, recordedAt: base))
    try out("estimate", "swift_history.json", try Data(contentsOf: url))
}

// MARK: alerts store
do {
    let url = tempDir().appendingPathComponent("alerts.json")
    let store = RunwayAlertStore(stateURL: url)
    let small = (0..<5).map { RunwayAlert(id: "quota:5-hour:\(80 + $0):17830\($0)", kind: .quota, name: "5-hour", threshold: 80, date: nil) }
    _ = try store.unseen(small + [RunwayAlert(id: "reset-credit:a/b:é:1", kind: .resetCredit, name: "a/b", threshold: nil, date: nil)])
    try out("alerts", "swift_alert_state_small.json", try Data(contentsOf: url))
    let big = (0..<250).map { RunwayAlert(id: "quota:Weekly:100:\(1_780_000_000 + $0 * 7)", kind: .quota, name: "Weekly", threshold: 100, date: nil) }
    let unseen = try store.unseen(big)
    precondition(unseen.count == 250)
    try out("alerts", "swift_alert_state_capped.json", try Data(contentsOf: url))
    // After the cap the oldest-sorted IDs are forgotten and alert again.
    let again = try store.unseen(big)
    try out("alerts", "swift_alert_cap_reappear.json", try compactEncoder().encode(again.map(\.id)))
}

// MARK: alert decisions
let utc: Calendar = resetStatusUTCCalendar
func rl(_ w: RateWindow) -> RateWindow { w }
do {
    let now = date("2026-08-23T12:00:00Z")
    var decisions: [String: [RunwayAlert]] = [:]

    let reset = date("2026-08-23T18:00:00Z")
    let quota = QuotaSnapshot(
        plan: "pro",
        primary: RateWindow(usedPercent: 82, windowMinutes: 300, resetsAt: reset),
        secondary: RateWindow(usedPercent: 100, windowMinutes: 10_080, resetsAt: reset.addingTimeInterval(86_400)),
        additionalWindows: [
            NamedRateWindow(name: "GPT-5.3-Codex-Spark", window: RateWindow(usedPercent: 96, windowMinutes: 300, resetsAt: nil)),
            NamedRateWindow(name: "Other", window: RateWindow(usedPercent: 79, windowMinutes: 300, resetsAt: reset)),
        ],
        creditsBalance: nil, updatedAt: now)
    decisions["quota"] = RunwayAlertDecider.quotaAlerts(quota)

    let credits = ResetCreditsSnapshot(availableCount: 4, credits: [
        ResetCredit(id: "c1", status: "available", createdAt: nil, expiresAt: now.addingTimeInterval(3 * 86_400), remainingSeconds: 3 * 86_400),
        ResetCredit(id: nil, status: "available", createdAt: nil, expiresAt: now.addingTimeInterval(86_400), remainingSeconds: 86_400),
        ResetCredit(id: "c3", status: "available", createdAt: nil, expiresAt: now.addingTimeInterval(8 * 86_400), remainingSeconds: 8 * 86_400),
        ResetCredit(id: "c4", status: "available", createdAt: nil, expiresAt: nil, remainingSeconds: 0),
        ResetCredit(id: "c5", status: "used", createdAt: nil, expiresAt: now.addingTimeInterval(86_400), remainingSeconds: 86_400),
        ResetCredit(id: "c6", status: "available", createdAt: nil, expiresAt: now.addingTimeInterval(7 * 86_400), remainingSeconds: 7 * 86_400),
    ], updatedAt: now)
    decisions["resetCredit"] = RunwayAlertDecider.resetCreditAlerts(credits)

    func decide(_ previous: RateLimitResetTodaySnapshot?, _ current: RateLimitResetTodaySnapshot) -> [RunwayAlert] {
        RunwayAlertDecider.rateLimitResetTodayAlerts(previous: previous, current: current, now: now, calendar: utc)
    }
    let existing = alertEvent(postID: "050", resetType: .global, announcedAt: date("2026-08-23T01:00:00Z"))
    decisions["firstLoad"] = decide(nil, alertSnapshot(now: now, events: [alertEvent(postID: "100", resetType: .banked, announcedAt: date("2026-08-23T10:00:00Z"))]))
    decisions["newOccurrences"] = decide(
        alertSnapshot(now: now, events: [existing]),
        alertSnapshot(now: now, events: [
            alertEvent(postID: "300", resetType: .banked, announcedAt: date("2026-08-23T04:00:00Z")),
            existing,
            alertEvent(postID: "200", resetType: .global, announcedAt: date("2026-08-23T04:00:00Z")),
            alertEvent(postID: "100", resetType: .global, announcedAt: date("2026-08-23T03:00:00Z")),
            alertEvent(postID: "tomorrow", resetType: .global, announcedAt: date("2026-08-24T03:00:00Z")),
        ]))
    let banked = alertEvent(postID: "900", kind: .resetScheduled, resetType: .banked, announcedAt: date("2026-08-23T01:00:00Z"), effectiveAt: date("2026-08-23T03:00:00Z"))
    let global = alertEvent(postID: "901", kind: .resetScheduled, resetType: .global, announcedAt: date("2026-08-23T01:05:00Z"), effectiveAt: date("2026-08-23T03:00:00Z"))
    let completion = RateLimitResetManualCompletion(
        id: "manual:mixed-1", completedAt: date("2026-08-23T04:00:00Z"), visibleUntil: date("2026-08-24T04:00:00Z"),
        representativePostID: "900", schedulePostIDs: ["900", "901"], schedules: [banked, global])
    decisions["manualMixed"] = decide(
        alertSnapshot(now: now, timeline: RateLimitResetTimeline()),
        alertSnapshot(now: now, timeline: RateLimitResetTimeline(manualCompletions: [completion])))
    decisions["completedThenManual"] = decide(
        alertSnapshot(now: now, events: [alertEvent(postID: "900", resetType: .global, announcedAt: date("2026-08-23T04:00:00Z"), effectiveAt: date("2026-08-23T04:00:00Z"))]),
        alertSnapshot(now: now, timeline: RateLimitResetTimeline(manualCompletions: [RateLimitResetManualCompletion(
            id: "manual:cl_later", completedAt: date("2026-08-23T04:00:00Z"), visibleUntil: date("2026-09-02T04:00:00Z"),
            representativePostID: "900", schedulePostIDs: ["900"],
            schedules: [alertSchedule(postID: "900", announcedAt: date("2026-08-23T01:00:00Z"))])])))
    let effectiveAt = date("2026-08-23T12:25:00Z")
    let g = alertEvent(postID: "500", kind: .resetScheduled, resetType: .global, announcedAt: now, effectiveAt: effectiveAt, scheduleBasis: .explicit, confidence: 0.91)
    let b = alertEvent(postID: "501", kind: .resetScheduled, resetType: .banked, announcedAt: now, effectiveAt: effectiveAt, scheduleBasis: .contextualInference, confidence: 0.72)
    let merged = alertSnapshot(now: now, events: [g, b])
    decisions["upcomingMerged"] = decide(merged, merged)
    let inferred = alertSnapshot(now: now, events: [alertEvent(
        postID: "preview", kind: .resetScheduled, resetType: .global, announcedAt: date("2026-08-23T10:00:00Z"),
        effectiveAt: effectiveAt, scheduleBasis: .contextualInference, confidence: 0.876)])
    decisions["upcomingInferred"] = decide(inferred, inferred)
    let sixty = alertSnapshot(now: now, events: [alertEvent(
        postID: "600", kind: .resetScheduled, resetType: .banked, announcedAt: date("2026-08-23T10:00:00Z"),
        effectiveAt: date("2026-08-23T12:45:30Z"), scheduleBasis: .explicit, confidence: 0.5)])
    decisions["upcomingSixty"] = decide(sixty, sixty)
    let far = alertSnapshot(now: now, events: [alertEvent(
        postID: "700", kind: .resetScheduled, resetType: .global, announcedAt: date("2026-08-23T10:00:00Z"),
        effectiveAt: date("2026-08-23T14:00:00Z"))])
    decisions["upcomingFar"] = decide(far, far)
    let expired = alertSnapshot(now: now, events: [alertEvent(
        postID: "800", kind: .resetScheduled, resetType: .global, announcedAt: date("2026-08-23T10:00:00Z"),
        effectiveAt: date("2026-08-23T11:00:00Z"))])
    decisions["upcomingExpired"] = decide(expired, expired)
    try out("alerts", "swift_decisions.json", try compactEncoder().encode(decisions))
}

// MARK: reaction visitor
do {
    let url = tempDir().appendingPathComponent("reaction-visitor.json")
    let store = RateLimitResetTodayReactionCookieStore(fileURL: url)
    store.saveVisitorID("  0123456789ABCDEF0123456789abcdef \n")
    var data = try Data(contentsOf: url)
    // updatedAt is the wall clock; pin it so the bytes can be compared.
    var text = String(decoding: data, as: UTF8.self)
    let range = text.range(of: #""updatedAt":"[^"]+""#, options: .regularExpression)!
    text.replaceSubrange(range, with: #""updatedAt":"2026-08-23T12:00:00Z""#)
    data = Data(text.utf8)
    try out("export", "swift_reaction_visitor.json", data)
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    try out("export", "swift_reaction_mode.txt", String(format: "%o", (attrs[.posixPermissions] as! NSNumber).intValue))
}

// MARK: deep links
do {
    var lines: [String] = []
    for provider in RunwayWidgetProviderScope.allCases {
        for section in RunwayWidgetSection.allCases {
            lines.append(RunwayWidgetDeepLink(provider: provider, section: section).url.absoluteString)
        }
    }
    try out("export", "swift_deeplinks.txt", lines.joined(separator: "\n") + "\n")
    let probes = [
        "quosparr://widget?provider=both&section=overview", "quosparr://widget/?provider=codex&section=quota",
        "quosparr://widget?provider=bad&section=quota", "https://widget?provider=codex&section=quota",
        "quosparr://widget?provider=codex&section=quota&extra=1", "quosparr://widget?provider=codex",
        "quosparr://widget?section=tokens&provider=grok", "quosparr://widget/x?provider=codex&section=quota",
        "quosparr://other?provider=codex&section=quota", "QUOSPARR://widget?provider=codex&section=quota",
        "quosparr://widget?provider=codex&provider=grok", "quosparr://widget?provider=%63odex&section=resetToday",
        "quosparr://widget?provider&section=quota", "quosparr://widget?provider=codex&section=quota#frag",
        "quosparr://widget", "quosparr:widget?provider=codex&section=quota",
    ]
    let results = probes.map { p -> String in
        guard let url = URL(string: p), let link = RunwayWidgetDeepLink(url: url) else { return "\(p)\t-" }
        return "\(p)\t\(link.provider.rawValue)/\(link.section.rawValue)"
    }
    try out("export", "swift_deeplink_parse.txt", results.joined(separator: "\n") + "\n")
}

// MARK: status export
do {
    let now = date("2026-06-30T10:00:00Z")
    let totals = ApiEquivalentTotals(totalTokens: 1_000, uncachedInputTokens: 700, cachedInputTokens: 200, outputTokens: 100, turns: 3, threads: 1)
    let quota = QuotaSnapshot(
        plan: "pro",
        primary: RateWindow(usedPercent: 25, windowMinutes: 300, resetsAt: now.addingTimeInterval(3_600)),
        secondary: RateWindow(usedPercent: 60, windowMinutes: 10_080, resetsAt: nil),
        additionalWindows: [NamedRateWindow(name: "GPT-5.3-Codex-Spark", window: RateWindow(usedPercent: 3, windowMinutes: 300, resetsAt: now))],
        creditsBalance: 12.5, updatedAt: now)
    let cost = ApiEquivalentSummary(
        source: .localSessions, confidence: .priced,
        window: DateInterval(start: now.addingTimeInterval(-3_600), end: now),
        estimatedUSD: Decimal(string: "1.25"), totals: totals,
        dailyRows: [
            ApiEquivalentDailyRow(date: "2026-06-29", totals: totals, estimatedUSD: Decimal(string: "0.216048"), rawCredits: 3379.6, creditsReported: true, totalsReported: true),
            ApiEquivalentDailyRow(date: "2026-06-30", totals: .zero, estimatedUSD: nil, rawCredits: 0),
        ],
        modelRows: [ApiEquivalentBreakdownRow(name: "gpt-5.5", totals: totals, estimatedUSD: Decimal(string: "1.25"), rawCredits: 0)],
        projectRows: [ApiEquivalentBreakdownRow(name: "quosparr", totals: totals, estimatedUSD: Decimal(string: "1.25"), rawCredits: 0)],
        clientRows: [], rawCredits: 3379.6, warnings: ["analytics-token-parts-missing"],
        pricingVersion: "test/1", calculatedAt: now)
    let sessions = SessionActivitySummary(items: [
        SessionActivityItem(id: "s1", title: "Fix \"status\" / <json>", projectName: "quosparr", cwd: "/Users/me/dev/quosparr",
                            updatedAt: now, state: .needsAttention, totals: totals, estimatedUSD: Decimal(string: "1.25")),
        SessionActivityItem(id: "s2", title: "Untitled", projectName: "Unknown project", cwd: nil,
                            updatedAt: now.addingTimeInterval(-60.5), state: .failed, totals: .zero, estimatedUSD: nil),
    ])
    let full = RunwayStatusSnapshot(generatedAt: now, quota: RunwayStatusQuota(snapshot: quota), cost: cost, sessions: sessions)
    let dir = tempDir()
    let exporter = RunwayStatusExporter(statusURL: dir.appendingPathComponent("status.json"))
    try exporter.save(full)
    try out("export", "swift_status_full.json", try Data(contentsOf: exporter.statusURL))
    try exporter.save(RunwayStatusSnapshot(generatedAt: now, quota: nil, cost: nil, sessions: nil))
    try out("export", "swift_status_empty.json", try Data(contentsOf: exporter.statusURL))
    try exporter.save(RunwayStatusSnapshot(generatedAt: now, quota: RunwayStatusQuota(snapshot: QuotaSnapshot(
        plan: nil, primary: RateWindow(usedPercent: 100, windowMinutes: nil, resetsAt: nil), secondary: nil, additionalWindows: [], creditsBalance: nil, updatedAt: now)),
        cost: nil, sessions: SessionActivitySummary(items: [])))
    try out("export", "swift_status_minimal.json", try Data(contentsOf: exporter.statusURL))
}

// MARK: widget snapshot
do {
    let date0 = Date(timeIntervalSince1970: 1_800_000_000)
    func quotaRow(_ title: String, minutes: Int?, source: RunwayWidgetQuotaSource = .standard, used: Int = 25, remaining: Int = 75, reset: Date? = nil) -> RunwayWidgetQuota {
        RunwayWidgetQuota(title: title, windowMinutes: minutes, source: source, usedPercent: used, remainingPercent: remaining, resetsAt: reset)
    }
    let snapshot = RunwayWidgetSnapshot(
        generatedAt: date0, language: .simplifiedChinese,
        providers: [
            RunwayWidgetProviderSnapshot(
                provider: .grok, availability: .notLoggedIn, plan: nil, updatedAt: nil, quota: [], balanceUSD: nil,
                apiEquivalentCostUSD: nil, tokenSource: .thisMac, dailyTokens: [], resetCredits: nil),
            RunwayWidgetProviderSnapshot(
                provider: .codex, availability: .available, plan: "Plus / Team", updatedAt: date0.addingTimeInterval(0.9),
                quota: [
                    quotaRow("Model", minutes: 60, source: .modelSpecific, used: 150, remaining: -5),
                    quotaRow("Weekly", minutes: 10_080, used: 40, remaining: 60, reset: date0.addingTimeInterval(86_400)),
                    quotaRow("Unknown", minutes: nil),
                    quotaRow("5 hours", minutes: 300, reset: date0.addingTimeInterval(3_600.4)),
                ],
                balanceUSD: Decimal(string: "12.5"), apiEquivalentCostUSD: Decimal(string: "4.25"),
                tokenSource: .allDevices,
                dailyTokens: [RunwayWidgetDailyTokens(date: "2026-08-06", tokens: 99), RunwayWidgetDailyTokens(date: "2026-08-05", tokens: -3)],
                resetCredits: RunwayWidgetResetCredits(availableCount: 2, expiringCount: -1)),
        ],
        resetToday: RunwayWidgetResetTodaySnapshot(
            state: .unknown, resetType: .globalAndBanked, nextScheduledAt: date0.addingTimeInterval(3_600),
            nextScheduledResetType: .banked, lastSuccessfulCheckAt: nil, fetchedAt: date0, confidencePercent: 92, confidenceBand: .ok,
            timeline: [
                RunwayWidgetResetTodayTimelineEntry(
                    effectiveAt: date0, reason: .upcoming, state: .yes, resetType: .banked, nextScheduledAt: date0.addingTimeInterval(3_600),
                    nextScheduledResetType: .banked, scheduleBasis: .explicit, confidencePercent: 92, confidenceBand: .ok),
                RunwayWidgetResetTodayTimelineEntry(
                    effectiveAt: date0.addingTimeInterval(3_600), reason: .grace, state: .yes, resetType: .banked, nextScheduledAt: nil,
                    nextScheduledResetType: nil, scheduleBasis: .explicit, confidencePercent: 92, confidenceBand: .ok),
            ]))
    // A directory that does not exist yet, so its mode is the one save() gives it.
    let dir = tempDir().appendingPathComponent("widget", isDirectory: true)
    let store = RunwayWidgetSnapshotStore(fileURL: dir.appendingPathComponent("widget-snapshot.json"))
    try store.save(snapshot)
    try out("export", "swift_widget_full.json", try Data(contentsOf: store.fileURL))
    let attrs = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
    try out("export", "swift_widget_mode.txt", String(format: "%o", (attrs[.posixPermissions] as! NSNumber).intValue))
    let dirAttrs = try FileManager.default.attributesOfItem(atPath: dir.path)
    try out("export", "swift_widget_dir_mode.txt", String(format: "%o", (dirAttrs[.posixPermissions] as! NSNumber).intValue))

    try store.save(RunwayWidgetSnapshot(generatedAt: date0, language: .english, providers: [], resetToday: nil))
    try out("export", "swift_widget_empty.json", try Data(contentsOf: store.fileURL))

    // The reset-today timeline assembled by the real verdict code.
    let nowR = try resetStatusDate("2026-07-28T12:00:00Z")
    var cases: [String: RunwayWidgetResetTodaySnapshot] = [:]
    let scheduled = ResetStatusEventFixture(
        kind: "reset_scheduled", announcedAt: "2026-07-28T11:00:00Z", effectiveAt: "2026-07-28T13:00:00Z",
        schedulePrecision: "datetime", scheduleBasis: "explicit")
    cases["upcoming"] = try ResetStatusFeedFixture(event: scheduled, now: nowR).decode()
        .makeWidgetResetTodaySnapshot(now: nowR, calendar: resetStatusUTCCalendar)
    let completed = ResetStatusEventFixture(kind: "reset_completed", announcedAt: "2026-07-28T11:00:00Z", effectiveAt: "2026-07-28T11:00:00Z", postID: "100")
    let future = ResetStatusEventFixture(
        kind: "reset_scheduled", announcedAt: "2026-07-28T11:30:00Z", effectiveAt: "2026-07-29T13:00:00.123Z",
        schedulePrecision: "datetime", postID: "200")
    cases["completedWithFuture"] = try ResetStatusFeedFixture(eventsJSON: completed.json + "," + future.json, now: nowR).decode()
        .makeWidgetResetTodaySnapshot(now: nowR, calendar: resetStatusUTCCalendar)
    cases["none"] = try ResetStatusFeedFixture(eventsJSON: "", now: nowR).decode()
        .makeWidgetResetTodaySnapshot(now: nowR, calendar: resetStatusUTCCalendar)
    let stale = try ResetStatusFeedFixture(eventsJSON: "", now: nowR).generated(at: "2026-07-26T12:00:00Z").checked(at: "2026-07-26T12:00:00Z").decode()
    cases["stale"] = stale.makeWidgetResetTodaySnapshot(now: nowR, calendar: resetStatusUTCCalendar)
    try out("export", "swift_widget_reset_cases.json", try compactEncoder().encode(cases))
}

// MARK: session activity and repair
do {
    let home = tempDir()
    func write(_ rel: String, _ text: String, mtime: String) throws {
        let url = home.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: date(mtime)], ofItemAtPath: url.path)
    }
    try write("session_index.jsonl", """
    {"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","thread_name":"Index title \\"quoted\\"/slash","updated_at":"2026-06-29T00:04:00Z"}
    {"id":"gone","thread_name":"Gone","updated_at":"2026-06-01T00:00:00Z"}
    """, mtime: "2026-06-29T00:04:00Z")
    try write("sessions/2026/06/29/rollout-2026-06-29T00-00-00-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jsonl", """
    {"timestamp":"2026-06-29T00:00:00.500Z","type":"session_meta","payload":{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","cwd":"/Users/me/dev/quosparr"}}
    {"timestamp":"2026-06-29T00:01:00Z","type":"event_msg","payload":{"type":"message","role":"user","content":"Fix the status bar"}}
    {"timestamp":"2026-06-29T00:02:00Z","type":"event_msg","payload":{"type":"approval_request"}}
    {"timestamp":"2026-06-29T00:03:00Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000000,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":10}}},"turn_context":{"model":"gpt-5.3-codex-spark"}}
    {"timestamp":"2026-06-29T00:04:00Z","type":"event_msg","payload":{"type":"task_complete"}}
    """, mtime: "2026-06-29T00:04:00Z")
    try write("sessions/2026/06/30/rollout-bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb.jsonl", """
    {"timestamp":"2026-06-30T00:00:00Z","type":"session_meta","payload":{"session_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}}
    {"timestamp":"2026-06-30T00:01:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"  second\\nmessage  "},{"type":"input_text","text":"parts"}]}}
    {"timestamp":"2026-06-30T00:02:00Z","type":"event_msg","payload":{"type":"error","status":"failed"}}
    {"timestamp":"2026-06-30T00:03:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":123456,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0}}},"turn_context":{"model":"gpt-5.3-codex-spark"}}
    {"timestamp":"2026-06-30T00:03:30Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":50,"cached_input_tokens":10,"output_tokens":5,"reasoning_output_tokens":1}}},"turn_context":{"model":"mystery-model"}}
    """, mtime: "2026-06-30T00:03:30Z")
    let summary = try SessionActivityScanner(codexHome: home).scan(limit: 5)
    try out("sessions", "swift_activity.json", try compactEncoder().encode(summary))
    let repair = SessionRepairService(codexHome: home)
    let dry = try repair.dryRun()
    try out("sessions", "swift_repair_dry.txt", """
    missing=\(dry.missingIndexIDs.joined(separator: ","))
    orphan=\(dry.orphanIndexIDs.joined(separator: ","))
    duplicate=\(dry.duplicateIndexIDs.joined(separator: ","))
    stale=\(dry.staleTitleIDs.joined(separator: ","))
    planned=\(dry.plannedEntries)

    """)
    _ = try repair.repair()
    try out("sessions", "swift_repaired_index.jsonl", try Data(contentsOf: home.appendingPathComponent("session_index.jsonl")))
}

// MARK: helpers copied from the alert tests
func alertSchedule(postID: String, announcedAt: Date, resetType: RateLimitResetType = .global) -> RateLimitResetTodayEvent {
    alertEvent(postID: postID, kind: .resetScheduled, resetType: resetType, announcedAt: announcedAt, effectiveAt: announcedAt)
}
func alertEvent(
    postID: String, kind: RateLimitResetTodayEventKind = .resetCompleted, resetType: RateLimitResetType,
    announcedAt: Date, effectiveAt: Date? = nil, scheduleBasis: RateLimitResetScheduleBasis? = nil, confidence: Double = 1)
    -> RateLimitResetTodayEvent
{
    RateLimitResetTodayEvent(
        kind: kind, resetType: resetType, announcedAt: announcedAt, effectiveAt: effectiveAt,
        schedulePrecision: kind == .resetScheduled ? .datetime : nil, scheduleBasis: scheduleBasis,
        scope: RateLimitResetTodayScope(plans: ["all"], windows: ["weekly"]),
        source: RateLimitResetTodaySource(handle: "thsottiaux", postID: postID, url: URL(string: "https://x.com/thsottiaux/status/\(postID)")!),
        confidence: confidence, rationale: "alert fixture", text: "alert fixture")
}
func alertSnapshot(
    now: Date, monitorStatus: RateLimitResetTodayMonitorStatus = .ok, events: [RateLimitResetTodayEvent] = [],
    graceSchedules: [RateLimitResetTodayEvent] = [], timeline: RateLimitResetTimeline? = nil) -> RateLimitResetTodaySnapshot
{
    RateLimitResetTodaySnapshot(
        response: RateLimitResetTodayResponse(
            schemaVersion: 1, generatedAt: now, lastSuccessfulCheckAt: now, monitor: RateLimitResetTodayMonitor(status: monitorStatus),
            events: events, graceSchedules: graceSchedules, resetTimeline: timeline),
        now: now, calendar: resetStatusUTCCalendar)
}
print("fixtures written")
