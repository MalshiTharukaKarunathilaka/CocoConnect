"""One-page colorful KapConnect fertilizer workflow PDF."""
from pathlib import Path

from reportlab.lib.colors import Color, HexColor, white, black
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

OUT = Path(__file__).resolve().parent / "KapConnect_Fertilizer_Workflows.pdf"

# Brand-ish palette (green agriculture, not purple AI default)
GREEN = HexColor("#1B7A4E")
GREEN_DK = HexColor("#0F4D32")
GREEN_LT = HexColor("#E8F6EE")
GOLD = HexColor("#C9A227")
TEAL = HexColor("#0E7C86")
ORANGE = HexColor("#E07A2F")
BLUE = HexColor("#2F6FED")
CORAL = HexColor("#D64550")
GRAY = HexColor("#5A6570")
BG = HexColor("#F7FBF8")
CARD = HexColor("#FFFFFF")
LINE = HexColor("#D5E5DB")


def rounded_rect(c, x, y, w, h, r, fill=None, stroke=None, sw=1):
    c.saveState()
    if fill:
        c.setFillColor(fill)
    if stroke:
        c.setStrokeColor(stroke)
        c.setLineWidth(sw)
    else:
        c.setStrokeColor(fill or white)
        c.setLineWidth(0)
    c.roundRect(x, y, w, h, r, fill=1 if fill else 0, stroke=1 if stroke else 0)
    c.restoreState()


def pill(c, x, y, w, h, text, fill, text_color=white, font="Helvetica-Bold", size=8):
    rounded_rect(c, x, y, w, h, h / 2, fill=fill)
    c.setFillColor(text_color)
    c.setFont(font, size)
    c.drawCentredString(x + w / 2, y + (h - size) / 2 + 0.5, text)


def arrow_right(c, x, y, length=14, color=GREEN):
    c.setStrokeColor(color)
    c.setFillColor(color)
    c.setLineWidth(1.4)
    c.line(x, y, x + length - 3, y)
    path = c.beginPath()
    path.moveTo(x + length - 3, y + 3.5)
    path.lineTo(x + length + 1, y)
    path.lineTo(x + length - 3, y - 3.5)
    path.close()
    c.drawPath(path, fill=1, stroke=0)


def flow_row(c, x, y, steps, colors, gap=6):
    """Draw a horizontal sequence of pill steps with arrows."""
    n = len(steps)
    total_gap = gap * (n - 1) + 12 * (n - 1)
    avail = 250  # will be overridden by caller via max_w
    return  # unused


def draw_flow(c, x, y, max_w, steps, colors):
    """steps: list of short labels. colors: matching HexColors."""
    n = len(steps)
    arrow_w = 11
    gap = 4
    pill_w = (max_w - (n - 1) * (arrow_w + gap)) / n
    pill_h = 16
    cx = x
    for i, (label, col) in enumerate(zip(steps, colors)):
        pill(c, cx, y, pill_w, pill_h, label, col, size=7)
        if i < n - 1:
            arrow_right(c, cx + pill_w + 1, y + pill_h / 2, length=arrow_w - 1, color=GRAY)
            cx += pill_w + arrow_w + gap
        else:
            cx += pill_w
    return pill_h


def role_card(c, x, y, w, h, title, subtitle, accent, bullets):
    rounded_rect(c, x, y, w, h, 8, fill=CARD, stroke=LINE, sw=1)
    # accent bar
    c.setFillColor(accent)
    c.rect(x, y + h - 6, w, 6, fill=1, stroke=0)
    rounded_rect(c, x, y + h - 14, w, 14, 6, fill=accent)
    c.setFillColor(accent)
    c.rect(x, y + h - 14, w, 8, fill=1, stroke=0)

    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 10)
    c.drawString(x + 10, y + h - 20, title)
    c.setFont("Helvetica", 7.5)
    c.setFillColor(HexColor("#E8FFF2") if accent == GREEN else white)
    c.setFillColor(Color(1, 1, 1, alpha=0.92))
    c.drawString(x + 10, y + h - 31, subtitle)

    c.setFillColor(GRAY)
    c.setFont("Helvetica", 7.8)
    ty = y + h - 48
    for b in bullets:
        c.setFillColor(accent)
        c.circle(x + 12, ty + 2.5, 2.2, fill=1, stroke=0)
        c.setFillColor(HexColor("#2C3A33"))
        c.drawString(x + 18, ty, b)
        ty -= 12


def main():
    page = landscape(A4)
    W, H = page
    c = canvas.Canvas(str(OUT), pagesize=page)

    # Background
    c.setFillColor(BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    # Soft decorative blobs
    c.setFillColor(HexColor("#DFF0E6"))
    c.circle(40, H - 30, 55, fill=1, stroke=0)
    c.setFillColor(HexColor("#FFF3D6"))
    c.circle(W - 30, 40, 70, fill=1, stroke=0)
    c.setFillColor(HexColor("#D9F0F2"))
    c.circle(W - 80, H - 20, 40, fill=1, stroke=0)

    margin = 14 * mm
    # Header
    rounded_rect(c, margin, H - 28 * mm, W - 2 * margin, 18 * mm, 9, fill=GREEN_DK)
    c.setFillColor(GOLD)
    c.circle(margin + 12 * mm, H - 19 * mm, 5.5 * mm, fill=1, stroke=0)
    c.setFillColor(GREEN_DK)
    c.setFont("Helvetica-Bold", 11)
    c.drawCentredString(margin + 12 * mm, H - 20.5 * mm, "KC")

    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(margin + 22 * mm, H - 16 * mm, "KapConnect Fertilizer — Role Workflows")
    c.setFont("Helvetica", 8.5)
    c.setFillColor(HexColor("#B8E0C8"))
    c.drawString(
        margin + 22 * mm,
        H - 22.5 * mm,
        "One-page guide · Estate Owner · Supplier · CDO · Shared order lifecycle",
    )
    c.setFillColor(GOLD)
    c.setFont("Helvetica-Bold", 8)
    c.drawRightString(W - margin - 4 * mm, H - 16 * mm, "CocoConnect")
    c.setFillColor(HexColor("#B8E0C8"))
    c.setFont("Helvetica", 7)
    c.drawRightString(W - margin - 4 * mm, H - 21.5 * mm, "Demo · fertilizer-nushrath")

    # Main shared lifecycle banner
    life_y = H - 42 * mm
    rounded_rect(c, margin, life_y, W - 2 * margin, 12 * mm, 7, fill=CARD, stroke=LINE)
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 9)
    c.drawString(margin + 4 * mm, life_y + 8.2 * mm, "Shared order lifecycle")
    steps = [
        "Request",
        "Pending Ack",
        "Accepted",
        "Delivered",
        "Confirm / Dispute",
        "Completed + Rate",
    ]
    cols = [TEAL, BLUE, GREEN, ORANGE, CORAL, GOLD]
    draw_flow(c, margin + 4 * mm, life_y + 2.2 * mm, W - 2 * margin - 8 * mm, steps, cols)

    # Three role cards
    card_y = 38 * mm
    card_h = H - 48 * mm - card_y
    gap = 5 * mm
    card_w = (W - 2 * margin - 2 * gap) / 3

    role_card(
        c,
        margin,
        card_y,
        card_w,
        card_h,
        "Estate Owner",
        "Buys fertilizer for the estate",
        GREEN,
        [
            "Sign in with estate phone",
            "Browse map / suppliers & place order",
            "Track My orders + alerts",
            "When Delivered → Confirm received",
            "Or tap Dispute (wrong / damaged / missing)",
            "After confirm → rate supplier",
            "See complaints if disputed",
        ],
    )

    # Mini flow under estate bullets area - draw inside card bottom
    ex = margin + 8
    ey = card_y + 10
    c.setFont("Helvetica-Bold", 7)
    c.setFillColor(GREEN)
    c.drawString(ex, ey + 28, "Estate path")
    draw_flow(
        c,
        ex,
        ey + 8,
        card_w - 16,
        ["Order", "Wait", "Confirm", "Rate"],
        [GREEN, BLUE, ORANGE, GOLD],
    )
    c.setFillColor(CORAL)
    c.setFont("Helvetica", 6.5)
    c.drawString(ex, ey, "Alt: Dispute instead of Confirm → status Disputed")

    role_card(
        c,
        margin + card_w + gap,
        card_y,
        card_w,
        card_h,
        "Supplier",
        "Private fertilizer provider",
        ORANGE,
        [
            "Sign in with supplier phone",
            "See incoming requests / calendar",
            "Accept, negotiate, or decline",
            "Mark Delivered when bags arrive",
            "Wait for estate confirm",
            "After complete → rate estate",
            "Can also dispute (no-show, etc.)",
        ],
    )
    sx = margin + card_w + gap + 8
    c.setFont("Helvetica-Bold", 7)
    c.setFillColor(ORANGE)
    c.drawString(sx, ey + 28, "Supplier path")
    draw_flow(
        c,
        sx,
        ey + 8,
        card_w - 16,
        ["Ack", "Accept", "Deliver", "Rated"],
        [BLUE, GREEN, ORANGE, GOLD],
    )
    c.setFillColor(GRAY)
    c.setFont("Helvetica", 6.5)
    c.drawString(sx, ey, "Gov / private orders share the same status ideas")

    role_card(
        c,
        margin + 2 * (card_w + gap),
        card_y,
        card_w,
        card_h,
        "CDO",
        "Area officer · stock · messages",
        TEAL,
        [
            "Sign in with CDO phone",
            "Area: estates & visits (in-tab)",
            "Stock: fertilizer availability",
            "Messages: chat with estates",
            "Handle / support gov supply flow",
            "Can mark distributed / delivered",
            "Help resolve area issues",
        ],
    )
    cx = margin + 2 * (card_w + gap) + 8
    c.setFont("Helvetica-Bold", 7)
    c.setFillColor(TEAL)
    c.drawString(cx, ey + 28, "CDO path")
    draw_flow(
        c,
        cx,
        ey + 8,
        card_w - 16,
        ["Area", "Stock", "Msgs", "Deliver"],
        [TEAL, GREEN, BLUE, ORANGE],
    )
    c.setFillColor(GRAY)
    c.setFont("Helvetica", 6.5)
    c.drawString(cx, ey, "Mobile-friendly hub · no full-page jump for Area")

    # Footer strip
    rounded_rect(c, margin, 8 * mm, W - 2 * margin, 26 * mm, 8, fill=CARD, stroke=LINE)
    c.setFillColor(GREEN_DK)
    c.setFont("Helvetica-Bold", 8.5)
    c.drawString(margin + 5 * mm, 28 * mm, "How the three roles connect")

    # Connection diagram: simple boxes + arrows
    box_y = 12 * mm
    box_h = 12 * mm
    boxes = [
        (margin + 8 * mm, "Estate", GREEN, "Orders & confirms"),
        (margin + 70 * mm, "Supplier", ORANGE, "Accepts & delivers"),
        (margin + 132 * mm, "CDO", TEAL, "Area · stock · chat"),
        (margin + 194 * mm, "Shared store", GOLD, "Statuses & ratings"),
    ]
    for bx, label, col, sub in boxes:
        rounded_rect(c, bx, box_y, 52 * mm, box_h, 5, fill=col)
        c.setFillColor(white)
        c.setFont("Helvetica-Bold", 8)
        c.drawCentredString(bx + 26 * mm, box_y + 7 * mm, label)
        c.setFont("Helvetica", 6.5)
        c.drawCentredString(bx + 26 * mm, box_y + 2.5 * mm, sub)

    # arrows between
    for i in range(3):
        x0 = boxes[i][0] + 52 * mm
        x1 = boxes[i + 1][0]
        mid = (x0 + x1) / 2
        arrow_right(c, x0 + 2, box_y + box_h / 2, length=x1 - x0 - 4, color=GREEN_DK)

    c.setFillColor(GRAY)
    c.setFont("Helvetica", 6.5)
    c.drawRightString(
        W - margin - 3 * mm,
        9.5 * mm,
        "Demo phones: Estate 0711000001 · Supplier 0771112233 · CDO 0372223344 · password demo123",
    )

    c.showPage()
    c.save()
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
