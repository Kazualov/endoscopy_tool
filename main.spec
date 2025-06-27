# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['videoQueries\\main.py'],
    pathex=['.'],
    binaries=[('venv\\Lib\\site-packages\\vosk\\libvosk.dll', 'vosk')],
    datas=[('videoQueries\\data\\videos', 'videoQueries\\data\\videos'),
     ('videoQueries\\data\\screenshots', 'videoQueries\\data\\screenshots'),
      ('videoQueries\\vosk-model-small-ru-0.22', 'videoQueries\\vosk-model-small-ru-0.22')],
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
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='main',
)
