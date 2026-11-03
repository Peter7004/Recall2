"""Controlled one-page PDF for cooperative multi-tab Reader write tests."""
from pathlib import Path
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.pagesizes import letter
root=Path(__file__).resolve().parent.parent
out=root/'build'/'reader-safety-fixtures'
out.mkdir(parents=True,exist_ok=True)
c=Canvas(str(out/'concurrency.pdf'),pagesize=letter,invariant=1)
c.setFont('Helvetica',12)
c.drawString(70,750,'Recall storage safety fixture')
c.setFont('Helvetica',18)
c.drawString(70,700,'Skin effect')
c.drawString(70,640,'Power factor')
c.drawString(70,580,'Skin effect')
c.showPage()
c.save()
print('Created controlled one-page concurrency PDF (not a performance fixture).')
