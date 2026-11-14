"""Render a silent, fictional-letter German short for human review.

This does not publish anything. The German text and the final channel caption
must be reviewed by a fluent speaker before use.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
W, H = 720, 1280
INK = "#102044"
PURPLE = "#6C59F7"
PALE = "#E8E5FF"
MUTED = "#BCC9E1"
WHITE = "#FFFFFF"
FONT = Path("C:/Windows/Fonts/arial.ttf")
BOLD = Path("C:/Windows/Fonts/arialbd.ttf")


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(BOLD if bold else FONT), size)


def base() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGB", (W, H), INK)
    d = ImageDraw.Draw(im)
    for y in range(H):
        blend = y / H
        d.line((0, y, W, y), fill=(int(16 + 16 * blend), int(32 + 10 * blend), int(68 + 24 * blend)))
    d.rounded_rectangle((42, 56, W - 42, H - 56), radius=42, outline="#47547F", width=2)
    d.text((70, 90), "BRIEFAI GERMANY  /  AMIA TECHNOLOGIES", font=font(20, True), fill=PALE)
    d.rounded_rectangle((70, H - 143, W - 70, H - 136), radius=4, fill="#4F5D86")
    return im, d


def lines(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, max_width: int,
          size: int, fill: str = WHITE, spacing: int = 12, bold: bool = False) -> int:
    face = font(size, bold)
    for paragraph in text.split("\n"):
        words = paragraph.split()
        row = ""
        for word in words:
            proposed = f"{row} {word}".strip()
            if row and draw.textbbox((0, 0), proposed, font=face)[2] > max_width:
                draw.text((x, y), row, font=face, fill=fill)
                y += size + spacing
                row = word
            else:
                row = proposed
        if row:
            draw.text((x, y), row, font=face, fill=fill)
            y += size + spacing
        else:
            y += size + spacing
    return y


def foot(d: ImageDraw.ImageDraw, number: int) -> None:
    d.text((70, H - 118), f"{number:02d} / 05", font=font(22, True), fill=MUTED)
    d.text((430, H - 118), "FIKTIVES BEISPIEL", font=font(19, True), fill=MUTED)


def slide_one() -> Image.Image:
    im, d = base()
    d.rounded_rectangle((70, 254, 650, 334), radius=24, fill=PURPLE)
    d.text((96, 274), "BEHÖRDENPOST VERSTEHEN", font=font(27, True), fill=WHITE)
    lines(d, "Post vom Jobcenter?", 70, 392, 580, 75, bold=True)
    lines(d, "Vier Dinge zuerst prüfen.", 70, 620, 560, 48, fill=PALE, bold=True)
    d.rounded_rectangle((72, 830, 648, 1014), radius=30, fill="#243760")
    d.text((110, 880), "Brief öffnen", font=font(37, True), fill=WHITE)
    d.text((110, 945), "Schritt für Schritt statt raten", font=font(25), fill=MUTED)
    foot(d, 1)
    return im


def slide_two() -> Image.Image:
    im, d = base()
    lines(d, "Was steht im Schreiben?", 70, 210, 580, 54, bold=True)
    d.rounded_rectangle((70, 365, 650, 1002), radius=30, fill="#F8F9FF")
    d.text((108, 405), "MUSTERBRIEF", font=font(24, True), fill="#6C59F7")
    d.line((108, 463, 608, 463), fill="#CAD2E6", width=3)
    items = [
        ("ABSENDER", "Jobcenter (Beispiel)"),
        ("AKTENZEICHEN", "MUSTER-12345"),
        ("FRIST", "Datum im Original prüfen"),
        ("AUFGABE", "Welche Unterlagen werden verlangt?"),
    ]
    y = 500
    for label, value in items:
        d.text((108, y), label, font=font(22, True), fill="#5144C3")
        lines(d, value, 108, y + 38, 500, 28, fill=INK)
        y += 119
    d.text((88, 1051), "Keine echten Namen oder Aktenzeichen", font=font(22), fill=MUTED)
    foot(d, 2)
    return im


def slide_three() -> Image.Image:
    im, d = base()
    lines(d, "Die kurze Checkliste", 70, 220, 580, 56, bold=True)
    entries = [
        ("1", "Absender & Aktenzeichen"),
        ("2", "Konkrete Frist"),
        ("3", "Geforderte Handlung"),
        ("4", "Offizieller Kontaktweg"),
    ]
    y = 398
    for n, title in entries:
        d.rounded_rectangle((70, y, 650, y + 130), radius=24, fill="#273A66")
        d.ellipse((93, y + 31, 159, y + 97), fill=PURPLE)
        d.text((114, y + 44), n, font=font(29, True), fill=WHITE)
        lines(d, title, 184, y + 39, 420, 32, bold=True)
        y += 148
    foot(d, 3)
    return im


def slide_four() -> Image.Image:
    im, d = base()
    lines(d, "Frist unklar?", 70, 247, 580, 70, bold=True)
    lines(d, "Nicht raten.", 70, 360, 580, 70, fill=PALE, bold=True)
    d.rounded_rectangle((70, 575, 650, 910), radius=30, fill="#273A66")
    lines(d, "Prüfen Sie das Originalschreiben und fragen Sie bei wichtigen Entscheidungen rechtzeitig bei der zuständigen Stelle oder einer unabhängigen Beratungsstelle nach.", 108, 625, 500, 33)
    foot(d, 4)
    return im


def slide_five() -> Image.Image:
    im, d = base()
    logo = Image.open(ROOT / "install-site/app/assets/assets/branding/briefai_logo_v2.png").convert("RGB")
    logo = logo.resize((220, 220), Image.Resampling.LANCZOS)
    im.paste(logo, (250, 245))
    lines(d, "BriefAI Germany", 93, 514, 540, 63, bold=True)
    lines(d, "by AMIA Technologies", 129, 610, 500, 32, fill=PALE)
    d.rounded_rectangle((70, 736, 650, 945), radius=30, fill=PURPLE)
    lines(d, "Schreiben verständlich strukturieren. Antwortentwurf selbst prüfen.", 111, 775, 500, 33, bold=True)
    lines(d, "Informationswerkzeug — keine Rechtsberatung.", 72, 1010, 575, 29, fill=PALE, bold=True)
    foot(d, 5)
    return im


def render(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    slides = [slide_one(), slide_two(), slide_three(), slide_four(), slide_five()]
    durations = [5, 6, 6, 6, 6]
    with tempfile.TemporaryDirectory(prefix="briefai-short-") as tmp:
        paths = []
        for i, slide in enumerate(slides):
            p = Path(tmp) / f"slide-{i + 1}.png"
            slide.save(p)
            paths.append(p)
        inputs = []
        for path, duration in zip(paths, durations):
            inputs += ["-loop", "1", "-framerate", "24", "-t", str(duration), "-i", str(path)]
        offsets = [4.5, 10.0, 15.5, 21.0]
        filters = []
        previous = "0:v"
        for i, offset in enumerate(offsets, start=1):
            result = f"v{i}"
            filters.append(
                f"[{previous}][{i}:v]xfade=transition=fade:duration=0.5:offset={offset}[{result}]"
            )
            previous = result
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
            "-filter_complex", ";".join(filters), "-map", "[v4]", "-an",
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output),
        ]
        subprocess.run(cmd, check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "outputs/organic-jobcenter-checklist.mp4")
    args = parser.parse_args()
    render(args.output)
    print(args.output.resolve())
