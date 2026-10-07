from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import base64, collections, hashlib, json, re

ROOT = Path(__file__).resolve().parents[3] / 'landing'
class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.refs, self.inline, self.integrity = [], [], [], []
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if 'id' in d:
            self.ids.append(d['id'])
        for attr in ('href', 'src', 'poster'):
            if d.get(attr):
                self.refs.append((tag, attr, d[attr]))
        if 'style' in d:
            self.inline.append('style attribute')
        if tag == 'style':
            self.inline.append('inline style block')
        if tag == 'script' and not d.get('src') and d.get('type') != 'application/ld+json':
            self.inline.append('inline script')
        if d.get('src') and d.get('integrity'):
            self.integrity.append((d['src'], d['integrity']))

pages = sorted(p for p in ROOT.rglob('*.html') if '_partials' not in p.parts)
parsed = {p: Page() for p in pages}
for path, page in parsed.items():
    page.feed(path.read_text())

issues, reference_count, integrity_count = [], 0, 0
for path, page in parsed.items():
    label = str(path.relative_to(ROOT))
    for id, count in collections.Counter(page.ids).items():
        if count > 1:
            issues.append({'page': label, 'issue': 'duplicate id', 'id': id})
    for issue in page.inline:
        issues.append({'page': label, 'issue': issue})
    for _, _, ref in page.refs:
        url = urlsplit(ref)
        if url.scheme or url.netloc:
            continue
        url_path = unquote(url.path)
        target = ROOT / url_path.lstrip('/') if url_path.startswith('/') else path.parent / url_path
        if url_path == '/':
            target = ROOT / 'index.html'
        elif not url_path:
            target = path
        elif not target.suffix and not target.is_file():
            target = Path(str(target) + '.html')
        reference_count += 1
        if not target.is_file():
            issues.append({'page': label, 'issue': 'missing target', 'ref': ref})
        # HTML's special #top fragment scrolls to the document top without an id.
        elif url.fragment and url.fragment.lower() != 'top' and target in parsed and url.fragment not in parsed[target].ids:
            issues.append({'page': label, 'issue': 'missing fragment', 'ref': ref})
    for src, integrity in page.integrity:
        source = ROOT / urlsplit(src).path.lstrip('/')
        actual = 'sha384-' + base64.b64encode(hashlib.sha384(source.read_bytes()).digest()).decode()
        integrity_count += 1
        if actual != integrity:
            issues.append({'page': label, 'issue': 'SRI mismatch', 'src': src})

css_reference_count = 0
for path in ROOT.joinpath('css').glob('*.css'):
    for ref in re.findall(r'url\([\s\'\"]*([^\)\'\"]+)', path.read_text()):
        url = urlsplit(ref.strip())
        if url.scheme or url.netloc:
            continue
        target = ROOT / url.path.lstrip('/') if url.path.startswith('/') else path.parent / url.path
        css_reference_count += 1
        if not target.is_file():
            issues.append({'page': str(path.relative_to(ROOT)), 'issue': 'missing CSS asset', 'ref': ref})

result = {
    'pages': len(pages),
    'internal_references': reference_count,
    'css_asset_references': css_reference_count,
    'SRI_checks': integrity_count,
    'issues': issues,
    'result': 'pass' if not issues else 'fail',
}
Path(__file__).with_name('static_audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(0 if not issues else 1)
