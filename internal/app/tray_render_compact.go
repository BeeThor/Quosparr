package app

import (
	"math"
	"strconv"

	"github.com/egoist/mygo/ui"
	"github.com/licoy/quosparr/internal/store"
)

// Desktop trays reserve a square icon; the full captions stay in the tooltip
func drawCompactTray(p *ui.Painter, r TrayRender, paint trayPaint) {
	ink := paint.ink
	items := r.Items[:min(2, len(r.Items))]
	if len(items) == 0 {
		items = []TrayItem{{Caption: "--"}}
	}
	switch r.Style {
	case store.StatusBarStyleText:
		lines := r.Lines[:min(2, len(r.Lines))]
		if len(lines) == 0 {
			lines = []string{"--"}
		}
		height := float32(22) / float32(len(lines))
		for i, text := range lines {
			drawTrayText(p, text, ui.Rect{X: 1, Y: float32(i) * height, W: 20, H: height}, 8, ink, true)
		}
	case store.StatusBarStyleCountdown:
		p.StrokePath((&ui.Path{}).Circle(11, 11, 8.5), 1.5, ink)
		level := min(1, max(0, items[0].Remaining))
		a := -math.Pi/2 + level*2*math.Pi
		path := (&ui.Path{}).MoveTo(11, 5).LineTo(11, 11).LineTo(11+float32(6*math.Cos(a)), 11+float32(6*math.Sin(a)))
		p.StrokePath(path, 1.5, ink)
	case store.StatusBarStyleMeters:
		for i, item := range items {
			bar := ui.Rect{X: 2, Y: float32(6 + i*8), W: 18, H: 4}
			if ink.A > 0 {
				p.Fill(bar, ink.Alpha(0.25), 2)
			}
			bar.W *= float32(min(1, max(0, item.Remaining)))
			if bar.W > 0 {
				p.Fill(bar, trayLevelColor(item.Health, true).Alpha(paint.colorOpacity), 2)
			}
		}
	case store.StatusBarStyleBattery:
		for i, item := range items {
			box := ui.Rect{X: 0, Y: float32(i*10 + 1), W: 22, H: 10}
			item.Caption = ""
			drawTrayBattery(p, item, box, 7, ink, trayLevelColor(item.Health, true).Alpha(paint.colorOpacity))
		}
	case store.StatusBarStyleRings:
		item := items[0]
		item.Caption = "--"
		if len(r.Items) > 0 {
			item.Caption = strconv.Itoa(int(math.Round(item.Remaining * 100)))
		}
		drawTrayItem(p, item, store.StatusBarStyleRings, ui.Rect{W: 22, H: 22}, 6, paint)
	}
}
