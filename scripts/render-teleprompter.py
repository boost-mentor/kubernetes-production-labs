#!/usr/bin/env python3
"""Render square PDFOverlay teleprompters from the generated Markdown files."""

from __future__ import annotations

import argparse
import html
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
OUTPUT_DIR = REPO_ROOT / "output" / "pdf"
PART_PDF_NAMES = {
    1: "суфлёр_VIDEO2_ч1.pdf",
    2: "суфлёр_VIDEO2_ч2.pdf",
    3: "суфлёр_VIDEO2_ч3.pdf",
    4: "суфлёр_VIDEO2_ч4.pdf",
}


def inline(text: str) -> str:
    value = html.escape(text.strip())
    value = re.sub(r"`([^`]+)`", r"<code>\1</code>", value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", value)
    value = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", value)
    return value


def markdown_to_html(markdown: str, title: str) -> str:
    lines = markdown.splitlines()
    # The source begins with authoring notes for maintainers.  PDFOverlay must
    # open directly on the first spoken scene, exactly like the Video 1 deck.
    first_scene = next(
        (index for index, line in enumerate(lines) if re.match(r"^## C", line.strip())),
        0,
    )
    lines = lines[first_scene:]
    out: list[str] = []
    paragraph: list[str] = []
    list_items: list[str] = []
    in_code = False
    code_lines: list[str] = []
    section_open = False
    mode = "body"

    def flush_paragraph() -> None:
        nonlocal paragraph
        if not paragraph:
            return
        css = "say" if mode == "say" else "body"
        out.append(f'<div class="{css}">{inline(" ".join(paragraph))}</div>')
        paragraph = []

    def flush_list() -> None:
        nonlocal list_items
        if not list_items:
            return
        out.append("<ul>" + "".join(f"<li>{inline(item)}</li>" for item in list_items) + "</ul>")
        list_items = []

    def flush_code() -> None:
        nonlocal code_lines
        if not code_lines:
            return
        out.append(f'<div class="cmd"><pre>{html.escape(chr(10).join(code_lines).rstrip())}</pre></div>')
        code_lines = []

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()
        if stripped.startswith("```"):
            flush_paragraph()
            flush_list()
            if in_code:
                flush_code()
                in_code = False
            else:
                in_code = True
            continue
        if in_code:
            code_lines.append(line)
            continue
        if not stripped:
            flush_paragraph()
            flush_list()
            continue
        if stripped.startswith("<!--") or stripped == "---":
            continue
        if stripped.startswith("# "):
            continue
        if stripped.startswith(">"):
            flush_paragraph()
            flush_list()
            out.append(f'<div class="cue note">{inline(stripped.lstrip("> "))}</div>')
            continue
        match = re.match(r"^## (C[^·]+) · (.+)$", stripped)
        if match:
            flush_paragraph()
            flush_list()
            if section_open:
                out.append("</section>")
            section_open = True
            mode = "body"
            out.append(
                '<section class="scene">'
                f'<div class="head"><span class="num">{inline(match.group(1))}</span>'
                f"<h2>{inline(match.group(2))}</h2></div>"
            )
            continue
        if stripped.startswith("## "):
            flush_paragraph()
            flush_list()
            if section_open:
                out.append("</section>")
            section_open = True
            mode = "body"
            out.append(
                '<section class="scene">'
                f'<div class="head"><h2>{inline(stripped[3:])}</h2></div>'
            )
            continue
        if stripped.startswith("### "):
            flush_paragraph()
            flush_list()
            heading = stripped[4:].strip()
            mode = "say" if "ГОВОРЮ" in heading else "body"
            css = "speak-label" if mode == "say" else "subhead"
            out.append(f'<h3 class="{css}">{inline(heading)}</h3>')
            continue
        if stripped.startswith("- "):
            flush_paragraph()
            list_items.append(stripped[2:])
            continue
        if re.match(r"^\d+\. ", stripped):
            flush_paragraph()
            list_items.append(re.sub(r"^\d+\. ", "", stripped))
            continue
        if stripped.startswith("**Время:**"):
            flush_paragraph()
            flush_list()
            out.append(f'<div class="meta">{inline(stripped)}</div>')
            continue
        paragraph.append(stripped)

    flush_paragraph()
    flush_list()
    flush_code()
    if section_open:
        out.append("</section>")
    body = "\n".join(out)
    return f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
  <style>
    * {{ box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
    @page {{ size: 232mm 232mm; margin: 12mm; }}
    html, body {{ margin: 0; padding: 0; }}
    body {{
      color: #000; background: #fff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
      font-size: 18px; line-height: 1.5;
    }}
    section.scene {{ page-break-before: always; padding-top: 2px; }}
    section.scene:first-child {{ page-break-before: auto; }}
    .head {{
      display: flex; align-items: baseline; gap: 10px;
      border-bottom: 2px solid #000; padding-bottom: 6px; margin-bottom: 10px;
    }}
    .num {{
      background: #000; color: #fff; border-radius: 5px;
      font-size: 12.5px; font-weight: 750; padding: 3px 9px; white-space: nowrap;
    }}
    h2 {{ margin: 0; font-size: 23px; line-height: 1.25; }}
    h3 {{ margin: 14px 0 6px; font-size: 18px; line-height: 1.3; break-after: avoid-page; }}
    h3.speak-label {{ border-left: 4px solid #000; padding: 5px 10px; }}
    .say {{
      margin: 8px 0; padding-left: 12px; border-left: 4px solid #000;
      font-size: 19px; line-height: 1.62; orphans: 3; widows: 3;
    }}
    .body {{ margin: 7px 0; font-size: 18px; line-height: 1.5; orphans: 3; widows: 3; }}
    .meta {{ font-size: 13px; margin: 4px 0 8px; }}
    .cue {{
      border-left: 4px dashed #000; padding: 6px 12px; margin: 8px 0;
      font-size: 16px; line-height: 1.45; break-inside: avoid;
    }}
    ul {{ margin: 6px 0 10px 22px; padding: 0; font-size: 17px; line-height: 1.45; }}
    li {{ margin: 3px 0; }}
    .cmd {{ margin: 7px 0 10px; break-inside: avoid; }}
    pre {{
      margin: 0; padding: 10px 13px; border: 1.5px solid #000; border-radius: 8px;
      font: 15.5px/1.5 "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
      white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word;
    }}
    code {{
      border: 1px solid #000; border-radius: 3px; padding: 0 3px;
      font: .9em "SF Mono", Menlo, monospace;
    }}
    strong {{ font-weight: 750; }}
  </style>
</head>
<body>{body}</body>
</html>
"""


def render(markdown_path: Path, pdf_path: Path) -> None:
    if not CHROME.is_file():
        raise SystemExit(f"Chrome not found: {CHROME}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    html_path = pdf_path.with_suffix(".html")
    rendered = markdown_to_html(markdown_path.read_text(encoding="utf-8"), pdf_path.stem)
    html_path.write_text(rendered, encoding="utf-8")
    profile = Path(tempfile.mkdtemp(prefix="video2-chrome-"))
    rendered_pdf = profile / "rendered.pdf"
    process: subprocess.Popen[str] | None = None
    try:
        process = subprocess.Popen(
            [
                str(CHROME),
                "--headless",
                "--disable-gpu",
                "--no-pdf-header-footer",
                f"--user-data-dir={profile}",
                f"--print-to-pdf={rendered_pdf}",
                f"file://{html_path}",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        # Headless Chrome occasionally leaves background processes running even
        # after the PDF is fully written.  Treat a stable non-empty PDF as the
        # completion signal, then close the isolated profile cleanly.
        deadline = time.monotonic() + 120
        previous_size = -1
        stable_ticks = 0
        while time.monotonic() < deadline:
            if process.poll() is not None:
                if process.returncode != 0:
                    stderr = process.stderr.read() if process.stderr else ""
                    raise SystemExit(f"Chrome failed ({process.returncode}): {stderr}")
                break
            size = rendered_pdf.stat().st_size if rendered_pdf.is_file() else 0
            if size > 0 and size == previous_size:
                stable_ticks += 1
                if stable_ticks >= 4:
                    break
            else:
                stable_ticks = 0
            previous_size = size
            time.sleep(0.25)
        else:
            raise SystemExit(f"Chrome timed out while rendering {pdf_path}")
        if not rendered_pdf.is_file() or rendered_pdf.stat().st_size == 0:
            raise SystemExit(f"Chrome did not create a temporary PDF for {pdf_path}")
        # The Desktop folder is managed by FileProvider.  Deleting and
        # immediately recreating the same Unicode filename can make it invent
        # a collision suffix (" 2").  Render outside that folder, then
        # overwrite the canonical inode in place.
        with rendered_pdf.open("rb") as source, pdf_path.open("wb") as target:
            shutil.copyfileobj(source, target)
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        shutil.rmtree(profile, ignore_errors=True)
    if not pdf_path.is_file() or pdf_path.stat().st_size == 0:
        raise SystemExit(f"Chrome did not create {pdf_path}")
    print(f"rendered {pdf_path.relative_to(REPO_ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("markdown", type=Path, nargs="?")
    parser.add_argument("pdf", type=Path, nargs="?")
    parser.add_argument(
        "--all",
        action="store_true",
        help="render four canonical parts and concatenate their PDFs exactly",
    )
    args = parser.parse_args()
    if args.all:
        if args.markdown or args.pdf:
            parser.error("--all does not accept positional paths")
        part_paths: list[Path] = []
        for part, filename in PART_PDF_NAMES.items():
            markdown_path = REPO_ROOT / "teleprompter" / f"VIDEO2_PART{part}.md"
            pdf_path = OUTPUT_DIR / filename
            if not markdown_path.is_file():
                raise SystemExit(f"missing canonical teleprompter: {markdown_path}")
            render(markdown_path, pdf_path)
            part_paths.append(pdf_path)
        merged = OUTPUT_DIR / "суфлёр_VIDEO2_СЛИТЫЙ.pdf"
        subprocess.run(
            ["pdfunite", *(str(path) for path in part_paths), str(merged)],
            check=True,
        )
        print(f"concatenated {merged.relative_to(REPO_ROOT)}")
        return
    if not args.markdown or not args.pdf:
        parser.error("provide markdown and pdf paths, or use --all")
    render(args.markdown.resolve(), args.pdf.resolve())


if __name__ == "__main__":
    main()
