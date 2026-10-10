#!/usr/bin/env python3
"""Baut TX-16_Live.html aus den Quelldateien in src/ (läuft auf Linux, Mac und Windows).

  python3 tools/build.py          -> TX-16_Live.html (die App)
  python3 tools/build.py --test   -> tools/test.html (gleiche App + window.__tx für Test-Skripte)
  python3 tools/build.py --backup -> sichert die bisherige TX-16_Live.html vorher in versionen/
"""
import sys, pathlib, shutil, datetime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'src'
PARTS = ['a.html', 'b.js', 'c.js', 'd.js']

# Test-Hook: macht Engine und Zustand von außen erreichbar (nur in tools/test.html, nie in der App)
HOOK = ("window.__tx={get cur(){return cur},get E(){return E},get ctx(){return ctx},get ui(){return ui},"
        "trigger,voice,SRC,G,CTRL,FN,MENU,OSCS,FILTERS,MODS,GATEARPS,SCALES,IFXS,MFXS};\n")


def build(test=False):
    texts = [(SRC / p).read_text(encoding='utf-8') for p in PARTS]
    if test:
        d = texts[3]
        i = d.rstrip().rfind('})();')
        texts[3] = d[:i] + HOOK + d[i:]
    return ''.join(texts)


if __name__ == '__main__':
    if '--test' in sys.argv:
        out = ROOT / 'tools' / 'test.html'
        out.write_text(build(test=True), encoding='utf-8')
        print('Testseite:', out)
    else:
        out = ROOT / 'TX-16_Live.html'
        if '--backup' in sys.argv and out.exists():
            (ROOT / 'versionen').mkdir(exist_ok=True)
            stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M')
            shutil.copy2(out, ROOT / 'versionen' / f'TX-16_Live_{stamp}.html')
        out.write_text(build(), encoding='utf-8')
        print('App gebaut:', out, f'({out.stat().st_size // 1024} KB)')
