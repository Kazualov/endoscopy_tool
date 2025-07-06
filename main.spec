# -*- mode: python ; coding: utf-8 -*-
import sys ; sys.setrecursionlimit(sys.getrecursionlimit() * 5)


a = Analysis(
    ['videoQueries/main.py'],
    pathex=['.'],
    binaries=[('/Users/kite/PycharmProjects/1/.venv/lib/python3.12/site-packages/vosk//libvosk.dyld', 'vosk')],
    datas=[
        ('videoQueries/data/videos', 'videoQueries/data/videos'),
        ('videoQueries/data/screenshots', 'videoQueries/data/screenshots'),
        ('videoQueries/vosk-model-small-ru-0.22', 'videoQueries/vosk-model-small-ru-0.22'),
        ('videoQueries/Detection_model/best.pt', 'videoQueries/Detection_model'),
    ],
    hiddenimports=['python-multipart'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='main',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    name='main',
)
