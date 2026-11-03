"""Gera os SF Symbols próprios do LogiBattery (#65): o símbolo do aparelho com o selo de conexão recortado no canto
de baixo à direita, como os `.badge` da Apple.

Saídas: `LogiBattery/Symbols.xcassets/lb.*.symbolset` (template estático só com o Regular-M; o app usa só o peso regular) e
`design/prototypes/custom-symbols.js` (prévia do protótipo).

Uso, na raiz do repo, com o app SF Symbols instalado:
    python3 -m venv /tmp/lb-venv && /tmp/lb-venv/bin/pip install skia-pathops fonttools
    /tmp/lb-venv/bin/python design/symbols/make.py
"""
import base64, json, re, subprocess, tempfile
from pathlib import Path as File

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from pathops import LineCap, LineJoin, Path, PathOp, op

SFSYMBOLS = '/Applications/SF Symbols.app/Contents/Executables/sfsymbols'
# Runa do Bluetooth, os mesmos pontos de `BluetoothRune` (BatteryCell.swift), em unidades do template (24 pt = 1/0,31).
RUNE = [(0.2, 0.7), (0.8, 0.3), (0.5, 0.05), (0.5, 0.95), (0.8, 0.7), (0.2, 0.3)]
STROKE, GAP = 5.5, 5
# Nome: (símbolo base, selo, centro do selo). O centro fica na quina de baixo à direita do desenho base.
SYMBOLS = {
    'lb.mouse.bluetooth': ('computermouse', 'bt', 63, -6),
    'lb.mouse.receiver': ('computermouse', 'rx', 63, -6),
    'lb.keyboard.bluetooth': ('keyboard', 'bt', 106, -8),
    'lb.keyboard.receiver': ('keyboard', 'rx', 106, -8),
    'lb.headphones.bluetooth': ('headphones', 'bt', 88, -6),
}
TEMPLATES = {}


def template(name):
    if name not in TEMPLATES:
        with tempfile.TemporaryDirectory() as tmp:
            out = f'{tmp}/{name}.svg'
            subprocess.run([SFSYMBOLS, 'export', name, '--output', out], check=True, capture_output=True)
            TEMPLATES[name] = File(out).read_text()
    return TEMPLATES[name]


def regular(name):
    """Caminho do Regular-S em coordenadas locais (origem na margem esquerda, y=0 na linha de base)."""
    group = re.search(r'<g id="Regular-S"[^>]*>(.*?)</g>', template(name), re.S).group(1)
    path = Path()
    for d in re.findall(r' d="([^"]+)"', group):
        parse_path(d, path.getPen())
    return op(path, path, PathOp.UNION)


def stroked(path, width):
    out = Path(path)
    out.stroke(width, LineCap.ROUND_CAP, LineJoin.ROUND_JOIN, 4)
    out.convertConicsToQuads(0.05)
    return out


def bluetooth(cx, cy, h=44):
    w = h * 8 / 11
    line = Path()
    for i, (x, y) in enumerate(RUNE):
        (line.lineTo if i else line.moveTo)(cx + (x - .5) * w, cy + (y - .5) * h)
    return stroked(line, STROKE), stroked(line, STROKE + 2 * GAP)


def receiver(cx, cy, h=46):
    plug = regular('cable.connector')
    x0, y0, x1, y1 = plug.bounds
    s = h / (y1 - y0)
    badge = Path()
    plug.draw(TransformPen(badge.getPen(), (s, 0, 0, s, cx - (x0 + x1) / 2 * s, cy - (y0 + y1) / 2 * s)))
    badge = op(badge, badge, PathOp.UNION)
    return badge, op(badge, stroked(badge, 2 * GAP), PathOp.UNION)


def compose(base, badge, cx, cy):
    glyph, clearance = (bluetooth if badge == 'bt' else receiver)(cx, cy)
    return op(op(regular(base), clearance, PathOp.DIFFERENCE), glyph, PathOp.UNION)


def svg_d(path):
    pen = SVGPathPen(None, ntos=lambda v: f'{v:.2f}'.rstrip('0').rstrip('.'))
    path.draw(pen)
    return pen.getCommands()


def symbol_svg(base, path):
    """Template do SF Symbols só com o Regular-S, com a margem direita afastada para caber o selo."""
    svg = template(base)
    left = float(re.search(r'id="left-margin-Regular-S"[^>]*x1="([\d.]+)"', svg).group(1))
    old_right = float(re.search(r'id="right-margin-Regular-S"[^>]*x1="([\d.]+)"', svg).group(1))
    bearing = old_right - left - regular(base).bounds[2]
    right = left + path.bounds[2] + bearing
    svg = re.sub(r'\s*<line id="(left|right)-margin-(Ultralight|Black)-S"[^>]*/>', '', svg)
    svg = re.sub(r'\s*<g id="(Ultralight|Black)-S".*?</g>', '', svg, flags=re.S)
    svg = re.sub(r'(id="right-margin-Regular-S"[^>]*x1=")[\d.]+(" x2=")[\d.]+', rf'\g<1>{right:.2f}\g<2>{right:.2f}', svg)
    svg = re.sub(r'(<g id="Regular-S"[^>]*>\s*<path [^>]*?d=")[^"]+(")', rf'\g<1>{svg_d(path)}\g<2>', svg, flags=re.S)
    # O actool exige o Regular-M; no template ele tem o mesmo tamanho do S, só desce para a linha de base do M.
    svg = svg.replace('<g id="Regular-S" transform="matrix(1 0 0 1 ', '<g id="Regular-M" transform="matrix(1 0 0 1 ')
    svg = re.sub(r'(<g id="Regular-M" transform="matrix\(1 0 0 1 [\d.]+) 696\)', r'\1 1126)', svg)
    return re.sub(r'id="(left|right)-margin-Regular-S"(.*?)y1="600.785" y2="720.121"',
                  r'id="\1-margin-Regular-M"\2y1="1030.79" y2="1150.12"', svg)


def main():
    assets = File('LogiBattery/Symbols.xcassets')
    preview = []
    for name, (base, *badge) in SYMBOLS.items():
        path = compose(base, *badge)
        folder = assets / f'{name}.symbolset'
        folder.mkdir(exist_ok=True)
        (folder / f'{name}.svg').write_text(symbol_svg(base, path))
        contents = {'info': {'author': 'xcode', 'version': 1}, 'symbols': [{'filename': f'{name}.svg', 'idiom': 'universal'}]}
        (folder / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n')
        x0, y0, x1, y1 = path.bounds
        x0, x1, y0, y1 = 0, x1 + 9.8, y0 - 4, y1 + 4
        box = f'{x0:.1f} {y0:.1f} {x1 - x0:.1f} {y1 - y0:.1f}'
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{box}"><path d="{svg_d(path)}"/></svg>'
        uri = 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode()
        preview.append(f" '{name}':{{w:{(x1 - x0) * .31:.2f},h:{(y1 - y0) * .31:.2f},d:'{uri}'}}")
    File('design/prototypes/custom-symbols.js').write_text(
        '// Gerado por design/symbols/make.py (#65): símbolos próprios com o selo dentro. Não editar à mão.\n'
        'Object.assign(SF,{\n' + ',\n'.join(preview) + '});\n')


if __name__ == '__main__':
    main()
