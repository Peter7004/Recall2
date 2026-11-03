"""Generate controlled Reader source-return fixtures, never modify user PDFs."""
from pathlib import Path
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.pagesizes import letter
root = Path(__file__).resolve().parent.parent
out = root / 'build' / 'reader-learning-fixtures'
out.mkdir(parents=True, exist_ok=True)
for name in ('source-a', 'source-b'):
    c = Canvas(str(out / f'{name}.pdf'), pagesize=letter, invariant=1)
    for page in range(1, 6):
        c.setFont('Helvetica', 12)
        c.drawString(70, 740, f'Reader source fixture {name}, page {page}')
        if name == 'source-a' and page == 1:
            c.setFont('Helvetica', 18)
            c.drawString(70, 680, 'Skin effect')
            c.drawString(70, 380, 'Skin effect')
        if name == 'source-b' and page == 3:
            c.setFont('Helvetica', 18)
            c.drawString(70, 550, 'Skin effect')
        c.showPage()
    c.save()
c = Canvas(str(out / 'image-only.pdf'), pagesize=letter, invariant=1)
c.drawImage(str(root / 'web' / 'branding' / 'recall-logo.png'), 70, 380, width=300, height=300)
c.showPage()
c.save()
print(f'Created source-a/source-b (5 pages each) and synthetic image-only (1 page) under {out}')
