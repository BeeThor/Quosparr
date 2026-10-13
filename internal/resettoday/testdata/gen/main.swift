// Generates internal/resettoday/testdata/swift_cases.json.gz: reset-today feeds
// (hand written and pseudo-random), each evaluated by the real QuosparrCore
// at many instants in several time zones. The Go tests replay every case and
// compare the verdict, schedule, transition, copy, alert and widget output.
// Run regenerate.sh next to this file; the fixture is committed.
import Foundation
@testable import QuosparrCore

let outputPath = CommandLine.arguments[1]

func ms(_ d: Date) -> Int64 { Int64((d.timeIntervalSince1970 * 1000).rounded()) }
func date(_ s: String) -> Date { try! Date(s, strategy: .iso8601) }
func calendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

struct Summary: Codable {
    var start: Int64, end: Int64, range: Bool, type: String, confidence: Double, basis: String?, postID: String
}
struct DayNext: Codable { var postID: String, start: Int64, end: Int64, range: Bool }
struct Latest: Codable { var at: Int64, type: String }
struct Hint: Codable { var type: String, text: String, ago: String? }
struct Detail: Codable {
    var type: String?
    var label: String
    var percent: String?
    var time: String?
    var plain: String
    var tokens: [String]
}
struct Probe: Codable {
    var at: Int64
    var state: String
    var reason: String
    var showsYes: Bool
    var isCompleted: Bool
    var isScheduled: Bool
    var resetType: String?
    var percent: Int?
    var band: String?
    var confidence: Double?
    var basis: String?
    var completedAt: Int64?
    var evidence: String?
    var winStart: Int64?
    var winEnd: Int64?
    var winRange: Bool?
    var summary: Summary?
    var dayNext: DayNext?
    var next: String?
    var transitions: [Int64]
    var evidenceEN: String?
    var evidenceURL: String?
    var display: String?
    var latest: Latest?
    var effectiveToday: Bool
    var uncertain: Bool
    var sameDay: Bool
    var unconfirmed: Hint?
    var alertsNil: [RunwayAlert]
    var alertsEmpty: [RunwayAlert]
    var alertsSelf: [RunwayAlert]
    // First probe of a case only (keeps the fixture small).
    var evidenceZH: String?
    var evidenceURLZH: String?
    var detailEN: Detail?
    var detailZH: Detail?
    var noneHintEN: Hint?
    var noneHintZH: Hint?
    var widget: RunwayWidgetResetTodaySnapshot?
}
struct Case: Codable {
    var name: String
    var feed: String
    var nowMs: Int64
    var zone: String
    var decodeError: Bool
    var state: String?
    var probes: [Probe]
}

func tokenNames(_ tokens: [RateLimitResetTodayDetailToken]) -> [String] {
    tokens.map { token in
        switch token {
        case .text(let t): return "text:" + t
        case .resetType: return "type"
        case .percent: return "percent"
        case .time: return "time"
        }
    }
}
func detail(_ d: RateLimitResetTodayDetailPresentation?) -> Detail? {
    d.map { Detail(type: $0.resetType?.rawValue, label: $0.typeLabel, percent: $0.percentText,
                   time: $0.timeText, plain: $0.plainText, tokens: tokenNames($0.tokens)) }
}

func feedText(_ f: ResetStatusFeedFixture) -> String {
    let lastSuccessValue = f.lastSuccessfulCheckAt.map { "\"\($0)\"" } ?? "null"
    let errorValue = f.errorCode.map { "\"\($0)\"" } ?? "null"
    let timelineField = f.resetTimelineJSON.map { ",\n  \"resetTimeline\": \($0)" } ?? ""
    let graceField = f.graceSchedulesJSON.map { ",\n  \"graceSchedules\": [\($0)]" } ?? ""
    return """
    {
      "schemaVersion": 1,
      "generatedAt": "\(f.generatedAt)",
      "lastSuccessfulCheckAt": \(lastSuccessValue),
      "monitor": {"status": "\(f.monitorStatus)", "errorCode": \(errorValue)},
      "events": [\(f.eventsJSON)]\(graceField)\(timelineField)
    }
    """
}

let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys]
    return e
}()
let en = L10n(language: .english)
let zh = L10n(language: .simplifiedChinese)

func probeOffsets(base: Date, transitions: [Date]) -> [Date] {
    var set = Set<Int64>()
    var list: [Date] = []
    func add(_ d: Date) {
        if set.insert(ms(d)).inserted { list.append(d) }
    }
    for minutes in [0, 20, 90, 240, 540, 840, 1_200, 1_980] {
        add(base.addingTimeInterval(Double(minutes) * 60))
    }
    for t in transitions.prefix(5) {
        add(t.addingTimeInterval(-1))
        add(t)
    }
    return list.sorted().prefix(16).map { $0 }
}

func run(name: String, feed: String, now: Date, zone: String) -> Case {
    let cal = calendar(zone)
    let data = Data(feed.utf8)
    guard let snapshot = try? RateLimitResetTodaySnapshot.decode(from: data, now: now, calendar: cal) else {
        return Case(name: name, feed: feed, nowMs: ms(now), zone: zone, decodeError: true, state: nil, probes: [])
    }
    let emptyFeed = feedText(ResetStatusFeedFixture(eventsJSON: "", now: now).using(cal))
    let empty = try! RateLimitResetTodaySnapshot.decode(from: Data(emptyFeed.utf8), now: now, calendar: cal)
    let transitions0 = snapshot.nextVerdictTransitionDates(now: now, calendar: cal)
    var probes: [Probe] = []
    for (index, at) in probeOffsets(base: now, transitions: transitions0).enumerated() {
        let v = snapshot.verdictPresentation(now: at, calendar: cal)
        let summary = snapshot.nextScheduledResetSummary(now: at).map {
            Summary(start: ms($0.window.startAt), end: ms($0.window.endAt), range: $0.window.isRange,
                    type: $0.resetType.rawValue, confidence: $0.confidence, basis: $0.scheduleBasis?.rawValue,
                    postID: $0.event.source.postID)
        }
        let dayNext = snapshot.nextScheduledReset(onLocalDayOf: at, calendar: cal).map {
            DayNext(postID: $0.event.source.postID, start: ms($0.effectiveAt), end: ms($0.effectiveUntil), range: $0.isRange)
        }
        var probe = Probe(
            at: ms(at),
            state: snapshot.resolvedState(now: at, calendar: cal).rawValue,
            reason: v.reason.rawValue,
            showsYes: v.showsYes, isCompleted: v.isCompleted, isScheduled: v.isScheduled,
            resetType: v.resetType?.rawValue, percent: v.percent, band: v.band?.rawValue,
            confidence: v.confidence, basis: v.scheduleBasis?.rawValue,
            completedAt: v.completedAt.map(ms), evidence: v.evidenceEvent?.source.postID,
            winStart: v.scheduleWindow.map { ms($0.startAt) }, winEnd: v.scheduleWindow.map { ms($0.endAt) },
            winRange: v.scheduleWindow?.isRange,
            summary: summary, dayNext: dayNext,
            next: snapshot.nextScheduledReset(now: at)?.event.source.postID,
            transitions: snapshot.nextVerdictTransitionDates(now: at, calendar: cal).map(ms),
            evidenceEN: snapshot.evidenceLine(l10n: en, now: at, calendar: cal),
            evidenceURL: snapshot.evidenceURL(now: at, calendar: cal)?.absoluteString,
            display: snapshot.displayResetType(now: at, calendar: cal)?.rawValue,
            latest: snapshot.latestReset(now: at).map { Latest(at: ms($0.at), type: $0.resetType.rawValue) },
            effectiveToday: snapshot.hasAlreadyEffectiveResetToday(now: at, calendar: cal),
            uncertain: snapshot.hasUncertainNoSignalToday(now: at, calendar: cal),
            sameDay: snapshot.prefersSameDayScheduleExplanation(now: at, calendar: cal),
            unconfirmed: snapshot.unconfirmedScheduleHint(l10n: en, now: at, calendar: cal).map {
                Hint(type: $0.resetType.rawValue, text: $0.text, ago: nil)
            },
            alertsNil: RunwayAlertDecider.rateLimitResetTodayAlerts(previous: nil, current: snapshot, now: at, calendar: cal),
            alertsEmpty: RunwayAlertDecider.rateLimitResetTodayAlerts(previous: empty, current: snapshot, now: at, calendar: cal),
            alertsSelf: RunwayAlertDecider.rateLimitResetTodayAlerts(previous: snapshot, current: snapshot, now: at, calendar: cal))
        if index == 0 {
            probe.evidenceZH = snapshot.evidenceLine(l10n: zh, now: at, calendar: cal)
            probe.evidenceURLZH = snapshot.evidenceURL(now: at, calendar: cal, language: .simplifiedChinese)?.absoluteString
            probe.detailEN = detail(snapshot.verdictDetail(l10n: en, now: at, calendar: cal))
            probe.detailZH = detail(snapshot.verdictDetail(l10n: zh, now: at, calendar: cal))
            probe.noneHintEN = snapshot.noneHintLastReset(l10n: en, now: at).map { Hint(type: $0.resetType.rawValue, text: $0.text, ago: $0.ago) }
            probe.noneHintZH = snapshot.noneHintLastReset(l10n: zh, now: at).map { Hint(type: $0.resetType.rawValue, text: $0.text, ago: $0.ago) }
            probe.widget = snapshot.makeWidgetResetTodaySnapshot(now: at, calendar: cal)
        }
        probes.append(probe)
    }
    return Case(name: name, feed: feed, nowMs: ms(now), zone: zone, decodeError: false,
                state: snapshot.state.rawValue, probes: probes)
}

// MARK: hand written feeds
struct Scenario { var name: String; var feed: String; var now: Date; var zones: [String] }
let allZones = ["UTC", "America/Los_Angeles", "Asia/Singapore", "Pacific/Auckland", "America/Havana"]
var scenarios: [Scenario] = []
func add(_ name: String, _ feed: ResetStatusFeedFixture, zones: [String] = allZones) {
    scenarios.append(Scenario(name: name, feed: feedText(feed), now: feed.now, zones: zones))
}
func fixtureFeed(_ now: String, _ events: [ResetStatusEventFixture], _ configure: (ResetStatusFeedFixture) -> ResetStatusFeedFixture = { $0 }) -> ResetStatusFeedFixture {
    let n = date(now)
    return configure(ResetStatusFeedFixture(eventsJSON: events.map { $0.json }.joined(separator: ",\n"), now: n))
}
func manualJSON(_ id: String, _ completed: String, _ visibleUntil: String, _ rep: String, _ schedules: [ResetStatusEventFixture]) -> String {
    """
    {
      "id": "\(id)", "completedAt": "\(completed)", "visibleUntil": "\(visibleUntil)",
      "representativePostId": "\(rep)", "schedulePostIds": [\(schedules.map { "\"\($0.postID)\"" }.joined(separator: ","))],
      "schedules": [\(schedules.map { $0.json }.joined(separator: ","))], "fulfillmentOrigin": "manual"
    }
    """
}
func sched(_ announced: String, _ eff: String, _ id: String, type: String? = nil, precision: String? = nil,
           basis: String? = nil, hours: String? = nil) -> ResetStatusEventFixture {
    ResetStatusEventFixture(kind: "reset_scheduled", resetType: type, announcedAt: announced, effectiveAt: eff,
                            schedulePrecision: precision, scheduleBasis: basis, scheduleGraceHoursJSON: hours, postID: id)
}
func done(_ announced: String, _ id: String, type: String? = nil, eff: String? = nil) -> ResetStatusEventFixture {
    ResetStatusEventFixture(kind: "reset_completed", resetType: type, announcedAt: announced, effectiveAt: eff, postID: id)
}
func op(kind: String, _ announced: String, _ id: String, eff: String? = nil, precision: String? = nil, type: String? = "global") -> ResetStatusEventFixture {
    ResetStatusEventFixture(kind: kind, resetType: type, announcedAt: announced, effectiveAt: eff, schedulePrecision: precision,
                            scheduleBasis: kind == "reset_scheduled" ? "explicit" : nil, postID: id, origin: "operator", handle: nil, includeURL: false)
}

let t0 = "2026-07-28T12:00:00Z"
add("empty", fixtureFeed(t0, []))
add("completed", fixtureFeed(t0, [done("2026-07-28T04:09:02Z", "1", eff: "2026-07-28T04:09:02Z")]))
add("completed_yesterday", fixtureFeed(t0, [done("2026-07-27T04:09:02Z", "1")]))
add("completed_late_utc", fixtureFeed("2026-07-28T00:30:00Z", [done("2026-07-27T23:30:00Z", "1")]))
add("scheduled_datetime", fixtureFeed(t0, [sched("2026-07-28T11:00:00Z", "2026-07-28T13:00:00Z", "1", precision: "datetime", basis: "explicit")]))
add("scheduled_legacy", fixtureFeed(t0, [sched("2026-07-28T09:00:00Z", "2026-07-28T13:00:00Z", "1")]))
add("scheduled_elapsed", fixtureFeed(t0, [sched("2026-07-27T22:00:00Z", "2026-07-28T11:00:00Z", "1")]))
add("scheduled_date_precision", fixtureFeed("2026-08-09T14:17:20Z", [sched("2026-08-08T20:34:50Z", "2026-08-10T07:00:00Z", "1", precision: "date")]))
add("scheduled_date_noon", fixtureFeed("2026-08-10T12:00:00Z", [sched("2026-08-09T12:00:00Z", "2026-08-10T15:00:00Z", "1", precision: "date")]))
add("scheduled_contextual", fixtureFeed("2026-08-10T20:00:00Z", [sched("2026-08-09T12:00:00Z", "2026-08-10T07:00:00Z", "1", precision: "date", basis: "contextual_inference")]))
add("scheduled_future_day", fixtureFeed(t0, [sched("2026-07-28T09:00:00Z", "2026-07-31T12:00:00Z", "1")]))
add("completed_and_scheduled", fixtureFeed(t0, [done("2026-07-28T08:00:00Z", "100"), sched("2026-07-28T09:00:00Z", "2026-07-28T20:00:00Z", "200")]))
add("two_schedules", fixtureFeed("2026-08-01T12:00:00Z", [
    sched("2026-08-01T10:00:00Z", "2026-08-01T20:00:00Z", "100"), sched("2026-08-01T11:00:00Z", "2026-08-01T15:00:00Z", "200")]))
add("merge_global_banked", fixtureFeed(t0, [
    sched("2026-07-28T10:00:00Z", "2026-07-28T16:00:00Z", "100", type: "global", basis: "explicit"),
    sched("2026-07-28T11:00:00Z", "2026-07-28T16:00:00Z", "200", type: "banked", basis: "contextual_inference")]))
add("banked_only_schedule", fixtureFeed(t0, [sched("2026-07-28T11:00:00Z", "2026-07-28T14:00:00Z", "200", type: "banked")]))
add("mixed_type_schedule", fixtureFeed(t0, [
    sched("2026-07-28T10:00:00Z", "2026-07-28T16:00:00Z", "100", type: "global"),
    sched("2026-07-28T11:00:00Z", "2026-07-28T14:00:00Z", "200", type: "global_and_banked")]))
add("completed_global_banked", fixtureFeed(t0, [done("2026-07-28T10:00:00Z", "100", type: "global"), done("2026-07-28T11:00:00Z", "200", type: "banked")]))
add("completed_same_instant", fixtureFeed(t0, [done("2026-07-28T11:00:00Z", "100", type: "global"), done("2026-07-28T11:00:00Z", "200", type: "banked")]))
add("uncertain_only", fixtureFeed(t0, [ResetStatusEventFixture(kind: "uncertain", announcedAt: "2026-07-28T11:00:00Z")]))
add("banked_reset_kind", fixtureFeed(t0, [ResetStatusEventFixture(kind: "banked_reset", resetType: "banked", announcedAt: "2026-07-28T11:00:00Z")]))
add("limit_increase_kind", fixtureFeed(t0, [ResetStatusEventFixture(kind: "limit_increase", announcedAt: "2026-07-28T11:00:00Z")]))
add("degraded", fixtureFeed(t0, [done("2026-07-28T11:00:00Z", "1")]) { $0.monitor(status: "degraded", errorCode: "request_failed") })
add("stale", fixtureFeed(t0, [done("2026-07-28T11:00:00Z", "1")]) { $0.generated(at: "2026-07-27T05:59:59Z").checked(at: "2026-07-27T05:59:59Z") })
add("stale_boundary", fixtureFeed(t0, [done("2026-07-28T11:00:00Z", "1")]) { $0.generated(at: "2026-07-27T06:00:00Z").checked(at: "2026-07-27T06:00:00Z") })
add("no_last_success", fixtureFeed(t0, [done("2026-07-28T11:00:00Z", "1")]) { $0.checked(at: nil) })
add("operator_completed", fixtureFeed("2026-08-25T16:00:00Z", [op(kind: "reset_completed", "2026-08-25T14:30:00Z", "op_4c549b7d3147b644968bb73a", eff: "2026-08-25T14:30:00Z")]))
add("operator_scheduled", fixtureFeed("2026-09-01T08:00:00Z", [op(kind: "reset_scheduled", "2026-09-01T00:12:30Z", "op_4c549b7d3147b644968bb73a", eff: "2026-09-01T18:00:00Z", precision: "datetime")]) {
    var f = $0
    f.resetTimelineJSON = resetStatusEmptyTimelineJSON(
        nextScheduleJSON: op(kind: "reset_scheduled", "2026-09-01T00:12:30Z", "op_4c549b7d3147b644968bb73a", eff: "2026-09-01T18:00:00Z", precision: "datetime").json,
        recentNonCompletedPostId: "op_4c549b7d3147b644968bb73a")
    return f
})
add("operator_expired_unconfirmed", fixtureFeed("2026-09-02T13:48:03Z", [
    op(kind: "reset_scheduled", "2026-09-01T00:12:30Z", "op_77973cda8bc5d0be9afde39e", eff: "2026-09-01T14:00:00Z", precision: "date"),
    done("2026-08-31T02:34:27Z", "2094252447271366730")]) {
    var f = $0
    f.resetTimelineJSON = resetStatusEmptyTimelineJSON(recentNonCompletedPostId: "op_77973cda8bc5d0be9afde39e")
    return f
})
let manualSched = sched("2026-08-13T01:01:37Z", "2026-08-13T02:01:37Z", "2087706104814023111", precision: "datetime", basis: "explicit")
add("manual_completion", fixtureFeed("2026-08-13T10:29:13Z", [done("2026-08-11T00:27:44Z", "123")]) {
    var f = $0
    f.resetTimelineJSON = resetStatusEmptyTimelineJSON(
        manualJSON: manualJSON("manual:cl_abd", "2026-08-13T04:35:00.000Z", "2026-08-23T04:35:00.000Z", "2087706104814023111", [manualSched]),
        suppressedJSON: "\"2087706104814023111\"")
    return f
})
add("manual_completion_past", fixtureFeed("2026-08-18T03:15:00Z", [done("2026-08-11T00:27:44Z", "2086972802457063486")]) {
    var f = $0.checked(at: "2026-08-18T01:00:02Z")
    f.resetTimelineJSON = resetStatusEmptyTimelineJSON(
        manualJSON: manualJSON("manual:cl_stale", "2026-08-13T04:35:00.000Z", "2026-08-23T04:35:00.000Z", "2087706104814023111", [manualSched]))
    return f
})
let g24 = sched("2026-09-24T12:00:00Z", "2026-09-25T07:00:00Z", "11", precision: "date", basis: "explicit", hours: "24")
add("grace_24", fixtureFeed("2026-09-26T04:00:00Z", [g24]) { $0.withGraceSchedules(g24.json) })
add("grace_zero", fixtureFeed("2026-09-25T20:00:00Z", [sched("2026-09-24T12:00:00Z", "2026-09-25T07:00:00Z", "12", precision: "datetime", basis: "explicit", hours: "0")]))
add("grace_decimal", fixtureFeed("2026-09-25T09:00:00Z", [sched("2026-09-25T00:00:00Z", "2026-09-25T07:00:00Z", "13", precision: "datetime", basis: "explicit", hours: "1.5")]))
add("grace_with_completion", fixtureFeed("2026-11-02T09:00:00Z", [
    sched("2026-11-01T06:00:00Z", "2026-11-01T15:00:00Z", "21", precision: "date", basis: "explicit", hours: "24"),
    done("2026-11-01T20:00:00Z", "22")]) { $0.withGraceSchedules(sched("2026-11-01T06:00:00Z", "2026-11-01T15:00:00Z", "21", precision: "date", basis: "explicit", hours: "24").json) })
add("dst_la_date_schedule", fixtureFeed("2026-03-08T09:00:00Z", [sched("2026-03-07T12:00:00Z", "2026-03-08T08:00:00Z", "31", precision: "date")]))
add("dst_la_fall_back", fixtureFeed("2026-11-01T08:30:00Z", [sched("2026-10-31T12:00:00Z", "2026-11-01T07:00:00Z", "32", precision: "date")]))
add("dst_auckland_completed", fixtureFeed("2026-04-05T12:00:00Z", [done("2026-04-05T01:30:00Z", "33")]))
add("invalid_rationale", ResetStatusFeedFixture(eventsJSON: """
{"kind":"reset_completed","announcedAt":"2026-07-28T11:00:00Z","effectiveAt":null,"scope":{"plans":["all"],"windows":["weekly"]},
 "source":{"handle":"thsottiaux","postId":"123","url":"https://x.com/thsottiaux/status/123"},"confidence":0.98,
 "rationale":"Copied post text.","text":"x"}
""", now: date(t0)), zones: ["UTC"])
add("scheduled_without_effective", fixtureFeed(t0, [ResetStatusEventFixture(kind: "reset_scheduled", announcedAt: "2026-07-28T11:00:00Z")]), zones: ["UTC"])

// MARK: pseudo-random feeds
var seed: UInt64 = 0x9E3779B97F4A7C15
func rnd(_ n: Int) -> Int {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Int((seed >> 33) % UInt64(n))
}
func iso(_ d: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.string(from: d)
}
let bases = ["2026-07-28T12:00:00Z", "2026-03-08T09:00:00Z", "2026-11-01T08:30:00Z", "2026-04-05T12:00:00Z"]
let scopes = [(["all"], ["weekly"]), (["plus"], ["weekly"]), (["all"], ["five_hour"]), (["unknown"], ["unknown"]), (["all"], ["unknown"])]
var nextID = 1_000
for base in bases {
    let now = date(base)
    for index in 0..<22 {
        var events: [ResetStatusEventFixture] = []
        var graceItems: [String] = []
        let count = 1 + rnd(4)
        for _ in 0..<count {
            nextID += 1
            let announced = now.addingTimeInterval(Double(rnd(66 * 60) - 60 * 60) * 60)
            let roll = rnd(100)
            let types = ["global", "global", "global", "banked", "global_and_banked"]
            let type: String? = rnd(5) == 0 ? nil : types[rnd(types.count)]
            var e: ResetStatusEventFixture
            if roll < 35 {
                e = ResetStatusEventFixture(kind: "reset_completed", resetType: type, announcedAt: iso(announced),
                                            effectiveAt: rnd(2) == 0 ? iso(announced) : nil, postID: String(nextID))
            } else if roll < 90 {
                let eff = announced.addingTimeInterval(Double(rnd(90 * 60) - 30 * 60) * 60)
                let precisions: [String?] = [nil, "date", "datetime", "datetime"]
                let bases: [String?] = [nil, "explicit", "contextual_inference"]
                var hours: String? = nil
                if rnd(4) == 0 { hours = ["0", "1.5", "4", "24", "72"][rnd(5)] }
                e = ResetStatusEventFixture(kind: "reset_scheduled", resetType: type, announcedAt: iso(announced), effectiveAt: iso(eff),
                                            schedulePrecision: precisions[rnd(precisions.count)], scheduleBasis: bases[rnd(bases.count)],
                                            scheduleGraceHoursJSON: hours, postID: String(nextID))
                if hours != nil, rnd(10) < 7 { graceItems.append(e.json) }
            } else {
                let kinds = ["uncertain", "limit_increase", "banked_reset"]
                let kind = kinds[rnd(kinds.count)]
                e = ResetStatusEventFixture(kind: kind, resetType: kind == "banked_reset" ? "banked" : nil,
                                            announcedAt: iso(announced), postID: String(nextID))
            }
            events.append(e)
        }
        var json = events.map { $0.json }.joined(separator: ",\n")
        let scope = scopes[rnd(scopes.count)]
        if scope.0 != ["all"] || scope.1 != ["weekly"] {
            let from = "\"scope\": {\"plans\": [\"all\"], \"windows\": [\"weekly\"]}"
            let to = "\"scope\": {\"plans\": [\(scope.0.map { "\"\($0)\"" }.joined(separator: ","))], \"windows\": [\(scope.1.map { "\"\($0)\"" }.joined(separator: ","))]}"
            // Only the first event changes scope, so mixed scopes are exercised.
            if let range = json.range(of: from) { json.replaceSubrange(range, with: to) }
        }
        var feed = ResetStatusFeedFixture(eventsJSON: json, now: now)
        let age = Double(rnd(22 * 60)) * 60
        feed = feed.generated(at: iso(now.addingTimeInterval(-age)))
        feed = feed.checked(at: rnd(5) == 0 ? nil : iso(now.addingTimeInterval(-age)))
        if rnd(12) == 0 { feed = feed.monitor(status: "degraded", errorCode: "request_failed") }
        if !graceItems.isEmpty {
            // The grace projection must repeat the event JSON of its schedules.
            let rewritten = graceItems.map { $0.replacingOccurrences(of: "\n", with: "\n") }
            feed = feed.withGraceSchedules(rewritten.joined(separator: ",\n"))
        }
        if rnd(4) == 0, let first = events.first(where: { $0.kind == "reset_scheduled" && ($0.resetType ?? "global") == "global" }) {
            let suppressed = rnd(3) == 0 ? "\"\(first.postID)\"" : ""
            feed = feed.withTimeline(resetStatusEmptyTimelineJSON(
                nextScheduleJSON: rnd(2) == 0 ? first.json : nil,
                recentNonCompletedPostId: first.postID, suppressedJSON: suppressed))
        }
        let zones = (0..<3).map { _ in allZones[rnd(allZones.count)] }
        scenarios.append(Scenario(name: "random_\(base)_\(index)", feed: feedText(feed), now: now, zones: Array(Set(zones)).sorted()))
    }
}

var cases: [Case] = []
for scenario in scenarios {
    for zone in scenario.zones {
        cases.append(run(name: scenario.name, feed: scenario.feed, now: scenario.now, zone: zone))
    }
}
let data = try encoder.encode(cases)
try data.write(to: URL(fileURLWithPath: outputPath))
print("cases: \(cases.count), decode errors: \(cases.filter { $0.decodeError }.count), bytes: \(data.count)")
