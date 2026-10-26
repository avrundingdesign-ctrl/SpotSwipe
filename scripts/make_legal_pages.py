"""Erzeugt die öffentlichen Rechtstext-Seiten von Swipez aus SpotSwipe/Resources/Legal/*.md.

Die App zeigt dieselben Dateien an – so können App- und Web-Fassung nicht auseinanderlaufen.
Die Seiten liefert der Meanwhile-Proxy aus (Maps_Ki/server/swipez_pages.go, per go:embed):

    /swipez/datenschutz   /swipez/privacy   /swipez/impressum   /swipez/legal-notice

Aufruf:  python3 scripts/make_legal_pages.py ~/Downloads/Maps_Ki/server/public
"""
import html
import pathlib
import sys

LEGAL = pathlib.Path(__file__).resolve().parent.parent / "SpotSwipe" / "Resources" / "Legal"

PAGES = {
    # Datei            Quelle             Sprache  Gegenstück (Pfad, Linktext)
    "swipez-datenschutz.html": ("privacy.de.md", "de", ("/swipez/privacy", "English version")),
    "swipez-privacy.html": ("privacy.en.md", "en", ("/swipez/datenschutz", "Deutsche Fassung")),
    "swipez-impressum.html": ("imprint.de.md", "de", ("/swipez/legal-notice", "English version")),
    "swipez-legal-notice.html": ("imprint.en.md", "en", ("/swipez/impressum", "Deutsche Fassung")),
}

TEMPLATE = """<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  :root {{ color-scheme: light dark; --bg: #F4F6FB; --text: #0E1530; --muted: #5A6280; --accent: #2F4BFF; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --bg: #0B0F1E; --text: #EEF1FA; --muted: #9AA3BF; --accent: #5B74FF; }} }}
  body {{ margin: 0; background: var(--bg); color: var(--text);
         font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }}
  main {{ max-width: 680px; margin: 0 auto; padding: 40px 20px 64px; }}
  h1 {{ font-size: 30px; line-height: 1.15; margin: 0 0 8px; letter-spacing: -0.02em; }}
  h2 {{ font-size: 18px; margin: 32px 0 6px; }}
  p {{ margin: 0 0 14px; color: var(--muted); white-space: pre-line; }}
  a {{ color: var(--accent); }}
  .brand {{ color: var(--accent); font-weight: 700; margin-bottom: 24px; }}
</style>
</head>
<body>
<main>
<div class="brand">Swipez</div>
{body}
<p><a href="{other_href}">{other_text}</a></p>
</main>
</body>
</html>
"""


def render(markdown: str) -> tuple[str, str]:
    title, parts = "Swipez", []
    for chunk in markdown.strip().split("\n\n"):
        chunk = chunk.strip()
        if chunk.startswith("## "):
            parts.append(f"<h2>{html.escape(chunk[3:])}</h2>")
        elif chunk.startswith("# "):
            title = chunk[2:]
            parts.append(f"<h1>{html.escape(title)}</h1>")
        elif chunk:
            parts.append(f"<p>{html.escape(chunk)}</p>")
    return title, "\n".join(parts)


def main() -> None:
    out = pathlib.Path(sys.argv[1]).expanduser()
    for name, (source, lang, (other_href, other_text)) in PAGES.items():
        title, body = render((LEGAL / source).read_text(encoding="utf-8"))
        page = TEMPLATE.format(lang=lang, title=html.escape(title), body=body,
                               other_href=other_href, other_text=other_text)
        (out / name).write_text(page, encoding="utf-8")
        print("geschrieben:", out / name)


if __name__ == "__main__":
    main()
