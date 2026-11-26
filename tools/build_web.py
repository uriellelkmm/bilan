"""Construit docs/index.html (version web) à partir de index.html (version Claude).
Lancer depuis la racine du dépôt :  python3 tools/build_web.py"""
import pathlib, re
root = pathlib.Path(__file__).resolve().parent.parent
s = (root / 'index.html').read_text(encoding='utf-8')
def rep(a, b):
    global s
    assert s.count(a) == 1, a
    s = s.replace(a, b)
rep('<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">')
rep('<meta name="apple-mobile-web-app-title" content="Bilan">',
    '<meta name="apple-mobile-web-app-title" content="Bilan">\n'
    '<meta name="apple-mobile-web-app-capable" content="yes">\n'
    '<meta name="mobile-web-app-capable" content="yes">\n'
    '<meta name="apple-mobile-web-app-status-bar-style" content="default">\n'
    '<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">\n'
    '<meta name="theme-color" content="#0e0e0e" media="(prefers-color-scheme: dark)">\n'
    '<link rel="manifest" href="manifest.webmanifest">\n'
    '<link rel="icon" type="image/png" href="icon-192.png">\n'
    '<link rel="apple-touch-icon" href="apple-touch-icon.png">')
i = s.rfind('<script>\n{')
assert i > 0
s = s[:i] + '<script src="config.js"></script>\n<script src="vendor/supabase.js"></script>\n<script src="platform.js"></script>\n' + s[i:]
s = s.replace('<!DOCTYPE html>', '<!DOCTYPE html>\n<!-- Fichier généré par tools/build_web.py à partir de index.html : modifiez index.html, puis relancez le script. -->', 1)
(root / 'docs' / 'index.html').write_text(s, encoding='utf-8')
print('docs/index.html écrit,', len(s), 'caractères')
