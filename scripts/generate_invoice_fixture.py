#!/usr/bin/env python3

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "fixtures" / "synthetic-invoice.pdf"


def build_invoice() -> None:
    styles = getSampleStyleSheet()
    document = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=22 * mm,
        leftMargin=22 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title="Synthetic Invoice HC-2026-0804",
        author="Aevatar workflow acceptance cases",
    )
    story = [
        Paragraph("SYNTHETIC INVOICE", styles["Title"]),
        Spacer(1, 6 * mm),
        Paragraph("Harbor Cloud Pte Ltd", styles["Heading2"]),
        Paragraph("18 Test Harbour Road, Singapore 018956", styles["BodyText"]),
        Spacer(1, 5 * mm),
        Table(
            [
                ["Invoice number", "HC-2026-0804"],
                ["Invoice date", "2026-08-04"],
                ["Bill to", "Example Platform Operations"],
            ],
            colWidths=[48 * mm, 90 * mm],
            style=TableStyle(
                [
                    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#E8EEF1")),
                    ("TEXTCOLOR", (0, 0), (-1, -1), colors.HexColor("#172126")),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#708087")),
                    ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                    ("TOPPADDING", (0, 0), (-1, -1), 7),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ]
            ),
        ),
        Spacer(1, 8 * mm),
        Table(
            [
                ["Description", "Quantity", "Unit price", "Line total"],
                ["Managed cloud operations", "1", "S$ 1,000.00", "S$ 1,000.00"],
                ["Incident response retainer", "1", "S$ 234.50", "S$ 234.50"],
                ["TOTAL", "", "", "S$ 1,234.50"],
            ],
            colWidths=[67 * mm, 24 * mm, 31 * mm, 32 * mm],
            style=TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#263A42")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#708087")),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
                    ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
                    ("TOPPADDING", (0, 0), (-1, -1), 7),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ]
            ),
        ),
        Spacer(1, 9 * mm),
        Paragraph(
            "Acceptance fixture only. This document has no payment value and contains no real customer data.",
            styles["Italic"],
        ),
    ]
    document.build(story)


if __name__ == "__main__":
    build_invoice()
    print(f"已生成 {OUTPUT}")
