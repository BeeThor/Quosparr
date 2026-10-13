#!/usr/bin/env python3
"""Generate the outlined Quosparr horizontal lockup from the SVG master."""

from pathlib import Path
import re

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "Resources" / "Brand"
FONT = Path("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf")
WORD = "Quosparr"


def outlined_wordmark() -> tuple[str, float]:
    font = TTFont(FONT)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = 0.082
    cursor = 236.0
    paths: list[str] = []
    for character in WORD:
        glyph_name = cmap[ord(character)]
        pen = SVGPathPen(glyphs)
        transformed = TransformPen(pen, (scale, 0, 0, -scale, cursor, 172))
        glyphs[glyph_name].draw(transformed)
        paths.append(f'    <path d="{pen.getCommands()}"/>')
        cursor += (glyphs[glyph_name].width - 24) * scale
    return "\n".join(paths), cursor


def extract_symbol(master: str) -> str:
    start = master.index('  <g id="symbol">')
    depth = 0
    for match in re.finditer(r"<g\b|</g>", master[start:]):
        depth += 1 if match.group() == "<g" else -1
        if depth == 0:
            return master[start : start + match.end()]
    raise ValueError("unterminated symbol group")


def main() -> None:
    master = (BRAND / "quosparr-logo.svg").read_text(encoding="utf-8")
    defs = master[master.index("  <defs>") : master.index("  </defs>") + len("  </defs>")]
    symbol = extract_symbol(master)
    wordmark, end_x = outlined_wordmark()
    width = round(end_x + 34)
    horizontal = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} 256" width="{width}" height="256" role="img" aria-labelledby="title desc">
  <title id="title">Quosparr horizontal logo</title>
  <desc id="desc">Quosparr sparrow symbol with an outlined rounded wordmark.</desc>
{defs}
  <g transform="translate(20 32) scale(0.75)">
{symbol}
  </g>
  <g id="wordmark" fill="#B3582D">
{wordmark}
  </g>
</svg>
'''
    (BRAND / "quosparr-logo-horizontal.svg").write_text(horizontal, encoding="utf-8")
    print(f"wrote Resources/Brand/quosparr-logo-horizontal.svg ({width} x 256)")


if __name__ == "__main__":
    main()
