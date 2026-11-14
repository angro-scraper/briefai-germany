"""Render an English, fictional-letter organic short for human review.

This creates a local draft only. It does not post the video anywhere.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

from render_organic_jobcenter_short import (
    H, INK, MUTED, PALE, PURPLE, ROOT, W, WHITE, base, font, lines,
)


def foot(draw: ImageDraw.ImageDraw, number: int) -> None:
    draw.text((70, H - 118), f"{number:02d} / 05", font=font(22, True), fill=MUTED)
    draw.text((420, H - 118), "FICTIONAL EXAMPLE", font=font(18, True), fill=MUTED)


def slide_one() -> Image.Image:
    image, draw = base()
    draw.rounded_rectangle((70, 254, 650, 334), radius=24, fill=PURPLE)
    draw.text((96, 274), "UNDERSTAND OFFICIAL MAIL", font=font(27, True), fill=WHITE)
    lines(draw, "German official letter?", 70, 392, 580, 65, bold=True)
    lines(draw, "Check these 4 things first.", 70, 620, 560, 46, fill=PALE, bold=True)
    draw.rounded_rectangle((72, 830, 648, 1014), radius=30, fill="#243760")
    draw.text((110, 875), "Open the letter", font=font(37, True), fill=WHITE)
    draw.text((110, 942), "Follow the facts, not a guess", font=font(26), fill=MUTED)
    foot(draw, 1)
    return image


def slide_two() -> Image.Image:
    image, draw = base()
    lines(draw, "What does it ask?", 70, 210, 580, 54, bold=True)
    draw.rounded_rectangle((70, 365, 650, 1002), radius=30, fill="#F8F9FF")
    draw.text((108, 405), "SAMPLE LETTER", font=font(24, True), fill=PURPLE)
    draw.line((108, 463, 608, 463), fill="#CAD2E6", width=3)
    items = [
        ("SENDER", "Issuing office (example)"),
        ("REFERENCE", "SAMPLE-12345"),
        ("DATE / DEADLINE", "Check the original letter"),
        ("REQUEST", "What action is required?"),
    ]
    y = 500
    for label, value in items:
        draw.text((108, y), label, font=font(22, True), fill="#5144C3")
        lines(draw, value, 108, y + 38, 500, 28, fill=INK)
        y += 119
    draw.text((88, 1051), "No real names or file references", font=font(22), fill=MUTED)
    foot(draw, 2)
    return image


def slide_three() -> Image.Image:
    image, draw = base()
    lines(draw, "The 4-point check", 70, 220, 580, 56, bold=True)
    entries = [
        ("1", "Sender & reference"),
        ("2", "Every date or deadline"),
        ("3", "Requested action"),
        ("4", "Official contact route"),
    ]
    y = 398
    for number, title in entries:
        draw.rounded_rectangle((70, y, 650, y + 130), radius=24, fill="#273A66")
        draw.ellipse((93, y + 31, 159, y + 97), fill=PURPLE)
        draw.text((114, y + 44), number, font=font(29, True), fill=WHITE)
        lines(draw, title, 184, y + 39, 420, 32, bold=True)
        y += 148
    foot(draw, 3)
    return image


def slide_four() -> Image.Image:
    image, draw = base()
    lines(draw, "Deadline unclear?", 70, 247, 580, 62, bold=True)
    lines(draw, "Do not guess.", 70, 365, 580, 68, fill=PALE, bold=True)
    draw.rounded_rectangle((70, 575, 650, 910), radius=30, fill="#273A66")
    lines(
        draw,
        "Check the original letter. If it affects your rights or money, contact the issuing office or a qualified adviser promptly.",
        108, 625, 500, 34,
    )
    foot(draw, 4)
    return image


def slide_five() -> Image.Image:
    image, draw = base()
    logo = Image.open(ROOT / "install-site/app/assets/assets/branding/briefai_logo_v2.png").convert("RGB")
    logo = logo.resize((220, 220), Image.Resampling.LANCZOS)
    image.paste(logo, (250, 245))
    lines(draw, "BriefAI Germany", 93, 514, 540, 63, bold=True)
    lines(draw, "by AMIA Technologies", 129, 610, 500, 32, fill=PALE)
    draw.rounded_rectangle((70, 736, 650, 945), radius=30, fill=PURPLE)
    lines(draw, "Read a clearer explanation. Review an editable German reply draft.", 111, 775, 500, 33, bold=True)
    lines(draw, "First 5 letter analyses free.", 72, 976, 575, 28, fill=WHITE, bold=True)
    lines(draw, "Information tool — not legal advice.", 72, 1030, 575, 27, fill=PALE, bold=True)
    foot(draw, 5)
    return image


def render(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    slides = [slide_one(), slide_two(), slide_three(), slide_four(), slide_five()]
    durations = [5, 6, 6, 6, 6]
    with tempfile.TemporaryDirectory(prefix="briefai-english-short-") as temp_dir:
        slide_paths = []
        for index, slide in enumerate(slides, start=1):
            slide_path = Path(temp_dir) / f"slide-{index}.png"
            slide.save(slide_path)
            slide_paths.append(slide_path)
        inputs = []
        for slide_path, duration in zip(slide_paths, durations):
            inputs += ["-loop", "1", "-framerate", "24", "-t", str(duration), "-i", str(slide_path)]
        filters = []
        previous = "0:v"
        for index, offset in enumerate((4.5, 10.0, 15.5, 21.0), start=1):
            result = f"v{index}"
            filters.append(f"[{previous}][{index}:v]xfade=transition=fade:duration=0.5:offset={offset}[{result}]")
            previous = result
        command = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
            "-filter_complex", ";".join(filters), "-map", "[v4]", "-an",
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output),
        ]
        subprocess.run(command, check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output", type=Path,
        default=ROOT / "outputs/organic-official-letter-en.mp4",
    )
    args = parser.parse_args()
    render(args.output)
    print(args.output.resolve())
