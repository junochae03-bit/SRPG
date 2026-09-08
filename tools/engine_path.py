"""Locate Godot without committing an engine binary."""
from pathlib import Path
import os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
def engine():
    configured=os.environ.get('GODOT_EXE')
    if configured and Path(configured).is_file():return configured
    for name in ['Godot_v4.6-stable_win64_console.exe','Godot_v4.6-stable_win64.exe']:
        bundled=ROOT/'tools/godot'/name
        if bundled.is_file():return str(bundled)
    for name in ['godot','godot4']:
        resolved=shutil.which(name)
        if resolved:return resolved
    raise FileNotFoundError('Set GODOT_EXE to Godot 4.6 or add godot to PATH.')
def hidden_options():
    if os.name!='nt':return {}
    si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
    return {'startupinfo':si,'creationflags':subprocess.CREATE_NO_WINDOW}
