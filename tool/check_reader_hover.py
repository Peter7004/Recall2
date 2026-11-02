"""Verify real PDF hover screenshots from reader_library_smoke.cjs (Pillow)."""
import argparse
import json
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--directory', type=Path, default=Path(__file__).resolve().parent.parent / 'build' / 'reader-library-smoke')
args = parser.parse_args()
point = json.loads((args.directory / 'hover-point.json').read_text(encoding='utf-8'))
x, y = int(point['x']), int(point['y'])
counts = {}
for name in ('hover-before', 'hover-known', 'hover-cleared'):
    with Image.open(args.directory / f'{name}.png') as source:
        image = source.convert('RGB')
        pixels = image.load()
        count = 0
        for row in range(max(0, y - 30), min(image.height, y + 30)):
            for column in range(max(0, x - 80), min(image.width, x + 90)):
                red, green, blue = pixels[column, row]
                if red > 180 and 110 < green < 250 and blue < 195 and red - green > 10 and green - blue > 35:
                    count += 1
        counts[name] = count
print('Gold pixels near recognized term:', counts)
assert counts['hover-known'] > counts['hover-before'] + 150, 'Expected visible hover highlight'
assert abs(counts['hover-cleared'] - counts['hover-before']) < 40, 'Hover highlight did not clear'
print('PASS: real PDF hover adds a visible highlight and leaving the term removes it')
