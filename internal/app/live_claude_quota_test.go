package app

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/licoy/quosparr/internal/claude"
	"github.com/licoy/quosparr/internal/l10n"
	"github.com/licoy/quosparr/internal/runway"
)

func TestClaudeKindPercentQuotaReachesMetersAccountsAndWidget(t *testing.T) {
	raw := json.RawMessage(`{
		"five_hour":{"utilization":3},
		"seven_day":{"utilization":72},
		"limits":[
			{"kind":"session","percent":3,"is_active":false,"resets_at":"2026-10-15T06:30:00Z"},
			{"kind":"weekly_all","percent":72,"is_active":true,"resets_at":"2026-10-17T19:00:00Z"}
		]
	}`)
	snap, err := claude.ParseUsageSnapshot(raw)
	if err != nil {
		t.Fatal(err)
	}
	l := l10n.New(l10n.English)
	at := time.Date(2026, 10, 15, 1, 42, 0, 0, time.UTC)
	meters := claudeMeters(l, snap, at)
	if len(meters) != 2 || meters[0].RemainingPercent != 97 || meters[1].RemainingPercent != 28 {
		t.Fatalf("main panel lost quota: %+v", meters)
	}
	if meters[0].WindowMinutes != runway.FiveHourMinutes || meters[1].WindowMinutes != runway.WeeklyMinutes {
		t.Fatalf("wrong quota windows: %+v", meters)
	}
	accounts := claudeAccountQuotas(l, []claude.ManagedAccount{{
		ID: "one", SubscriptionType: "pro", CachedQuota: raw, LastQuotaAt: &at,
	}})
	q, ok := accounts["one"]
	if !ok || q.Title == "" || q.UsedPercent != 3 || !q.UpdatedAt.Equal(at) || !q.ResetsAt.Equal(meters[0].ResetsAt) {
		t.Fatalf("account summary lost quota: %+v", accounts)
	}
	widget := claudeWidget(runway.ClaudeState{Meters: meters, UpdatedAt: at})
	if len(widget.Quota) != 2 || widget.Quota[0].RemainingPercent != 97 || widget.Quota[1].RemainingPercent != 28 {
		t.Fatalf("widget lost quota: %+v", widget.Quota)
	}
}
