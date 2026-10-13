package app

import (
	"bytes"
	"image/color"
	"image/png"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"
	"github.com/licoy/quosparr/internal/l10n"
	"github.com/licoy/quosparr/internal/runway"
	"github.com/licoy/quosparr/internal/store"
)

func TestPanelIdentityWholeRowIsClickable(t *testing.T) {
	for _, provider := range store.Providers() {
		t.Run(string(provider), func(t *testing.T) {
			a, tt := newPanel(t, func(p *store.Preferences) { p.SelectedProvider = provider }, panelFixture(), PanelActions{})
			label := a.L().Text(l10n.KeyAccounts)
			if provider == store.ProviderGrok {
				label = a.L().Text(l10n.KeyGrokAccountsTitle)
			}
			row, ok := tt.Find(label)
			if !ok || row.X+row.W < 389 {
				t.Fatalf("account hit area does not fill row: %v", row)
			}
			tt.Move(380, row.Y+row.H/2)
			if tt.Cursor() != ui.CursorPointer {
				t.Fatal("empty end of row does not hover")
			}
			tt.ClickAt(380, row.Y+row.H/2)
			if a.panelState.detail != detailAccounts {
				t.Fatal("empty end of row did not open accounts")
			}
		})
	}
}

func TestTrayFullContentHasHorizontalPadding(t *testing.T) {
	for _, style := range []store.StatusBarStyle{store.StatusBarStyleMeters, store.StatusBarStyleBattery, store.StatusBarStyleRings, store.StatusBarStyleText, store.StatusBarStyleCountdown} {
		data, err := TrayImage(TrayFromStatus(trayTestStatus(style, nil)), true, false)
		if err != nil {
			t.Fatal(err)
		}
		img, err := png.Decode(bytes.NewReader(data))
		if err != nil {
			t.Fatal(err)
		}
		for y := 0; y < img.Bounds().Dy(); y++ {
			for x := 0; x < 8; x++ {
				for _, edge := range []int{x, img.Bounds().Dx() - 1 - x} {
					if _, _, _, a := img.At(edge, y).RGBA(); a != 0 {
						t.Fatalf("%s has content in 4pt edge padding at %d,%d", style, edge, y)
					}
				}
			}
		}
	}
}

func TestPanelReactionFloatIsSmallAndNeutral(t *testing.T) {
	for _, dark := range []bool{false, true} {
		rs := panelReactionState{delta: 1, deltaAt: time.Now()}
		tt := ui.NewTester(func(c *ui.Context) {
			applyTheme(c)
			ui.Column(c).Fill().Padding(30).Children(func() {
				button := ui.Box(c).Size(100, 20)
				reactionFloat(c, button, &rs)
			})
		}, 180, 100)
		tt.SetDark(dark)
		r, ok := tt.Find("+1")
		if !ok || r.H > 13 {
			t.Fatalf("floating text too large: %v", r)
		}
		img := tt.Image()
		for y := int(r.Y); y < int(r.Y+r.H); y++ {
			for x := int(r.X); x < int(r.X+r.W); x++ {
				p := color.NRGBAModel.Convert(img.At(x, y)).(color.NRGBA)
				// The gray glyph is translucent over a slightly tinted dark surface.
				if absChannel(p.R, p.G) > 2 || absChannel(p.G, p.B) > 2 {
					t.Fatalf("delta is not neutral gray in dark=%v: %v", dark, p)
				}
			}
		}
	}
}

func TestPanelQuotaCountdownFitsBesideProjection(t *testing.T) {
	l := l10n.New(l10n.SimplifiedChinese)
	now := time.Date(2026, 10, 13, 12, 0, 0, 0, time.UTC)
	m := runway.Meter{Title: "weekly", RemainingPercent: 53, ResetsAt: now.Add(5*24*time.Hour + 6*time.Hour), Projection: &runway.BurnProjection{ExhaustsAt: now.Add(46 * time.Hour)}}
	tt := ui.NewTester(func(c *ui.Context) {
		applyTheme(c)
		ui.Column(c).Fill().Padding(16).Children(func() { quotaRow(c, l, m, now, true) })
	}, 400, 150)
	r, ok := tt.Find(resetCountdown(l, m.ResetsAt, now))
	if !ok || r.X+r.W > 384 {
		t.Fatalf("countdown exceeds panel: %v", r)
	}
	if !tt.HasText(projectionText(l, m, now)) {
		t.Fatal("projection disappeared")
	}
}

func absChannel(a, b uint8) int {
	if a > b {
		return int(a - b)
	}
	return int(b - a)
}
