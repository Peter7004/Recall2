"""Create controlled outline/plain PDF copies for P3 tests (pypdf). Originals stay unchanged."""
import argparse
from pathlib import Path
from pypdf import PdfReader, PdfWriter
from pypdf.generic import Fit

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=root / 'output/pdf/Recall_User_Manual_v1.0.3_ko.pdf')
parser.add_argument('--output', type=Path, default=root / 'build/reader-navigator-fixtures')
args = parser.parse_args()
reader = PdfReader(args.source)
if len(reader.pages) < 4:
    raise ValueError('Fixture source must have at least four pages')
args.output.mkdir(parents=True, exist_ok=True)
for outlined in [True, False]:
    writer = PdfWriter()
    writer.append(reader, import_outline=False)
    if outlined:
        parent = writer.add_outline_item('Chapter A', 0)
        writer.add_outline_item('Section A.1', 1, parent=parent, fit=Fit.xyz(left=0, top=600, zoom=1.5))
        writer.add_outline_item('Chapter B', 3)
    target = args.output / ('p3-outline-fixture.pdf' if outlined else 'p3-plain-fixture.pdf')
    with target.open('wb') as stream:
        writer.write(stream)
    actual = PdfReader(target)
    assert len(actual.pages) == len(reader.pages)
    assert bool(actual.outline) == outlined
    print(f'PASS: {target.name}: {len(actual.pages)} pages, outline={outlined}')
