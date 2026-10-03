#!/usr/bin/env python3
"""Ortak head/header/footer/scripts parçalarını sayfalara işler.

Kullanım (repo kökünden):
    python3 landing/tools/sync_partials.py          # sayfaları günceller
    python3 landing/tools/sync_partials.py --check  # fark varsa 1 ile çıkar

Her sayfada `<!-- partial:AD -->` ile `<!-- /partial:AD -->` arasındaki içerik
landing/_partials/AD.html dosyasıyla değiştirilir. en/ altındaki sayfalarda
AD.en.html varsa o kullanılır. `{{nav:ANAHTAR}}` yer tutucusu,
`<body data-page="ANAHTAR">` olan sayfada aktif menü işaretine dönüşür.
Site statik kalır: Cloudflare yalnızca üretilmiş HTML dosyalarını yayınlar.
"""
import pathlib
import re
import sys

LANDING = pathlib.Path(__file__).resolve().parent.parent
PARTIALS = LANDING / "_partials"
BLOCK_RE = re.compile(r"(<!-- partial:([a-z-]+) -->\n)(.*?)(^[ \t]*<!-- /partial:\2 -->)", re.S | re.M)
PAGE_RE = re.compile(r'<body[^>]*\bdata-page="([^"]+)"')
NAV_RE = re.compile(r"\{\{nav:([a-z-]+)\}\}")


def partial_text(name, is_en):
    if is_en and (PARTIALS / f"{name}.en.html").exists():
        return (PARTIALS / f"{name}.en.html").read_text(encoding="utf-8")
    return (PARTIALS / f"{name}.html").read_text(encoding="utf-8")


def render(page_path):
    html = page_path.read_text(encoding="utf-8")
    is_en = page_path.parent.name == "en"
    m = PAGE_RE.search(html)
    page_key = m.group(1) if m else ""

    def sub_block(match):
        text = partial_text(match.group(2), is_en)
        text = NAV_RE.sub(
            lambda n: ' class="active" aria-current="page"' if n.group(1) == page_key else "",
            text,
        )
        return match.group(1) + text + match.group(4)

    return html, BLOCK_RE.sub(sub_block, html)


def main():
    check = "--check" in sys.argv
    pages = sorted(LANDING.glob("*.html")) + sorted((LANDING / "en").glob("*.html"))
    changed = []
    for page in pages:
        old, new = render(page)
        if old != new:
            changed.append(page.relative_to(LANDING))
            if not check:
                page.write_text(new, encoding="utf-8")
    for c in changed:
        print(("güncel değil: " if check else "güncellendi: ") + str(c))
    if check and changed:
        sys.exit(1)


if __name__ == "__main__":
    main()
