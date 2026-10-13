package app

import _ "embed"

const trayIconWidth, trayIconHeight = 140, 44

//go:embed assets/tray-placeholder.png
var trayIconPNG []byte

// trayIcon returns the tray glyph as a PNG: black on transparent, which
// macOS tints as a template image. It is Swift's empty meters placeholder:
// centered "--", 8.5pt semibold, in 70x22 points at 2x. Live tray content
// replaces this startup placeholder after the first snapshot.
func trayIcon() (png []byte, template bool) {
	return trayIconPNG, true
}
