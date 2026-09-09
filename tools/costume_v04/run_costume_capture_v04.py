"""Run the dedicated GPU render audit invisibly; source assets are read only."""
from pathlib import Path
import subprocess

PROJECT=Path(__file__).resolve().parents[2]
GAME=PROJECT/'game'
OUTPUT=PROJECT/'runtime/costume-v04-review'
engine=Path('D:/SSRPG/RPG2/tools/godot/Godot_v4.6-stable_win64_console.exe')
log=OUTPUT/'capture.log'
log.parent.mkdir(parents=True,exist_ok=True)
startup=subprocess.STARTUPINFO()
startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow=0
command=[str(engine),'--path',str(GAME),'--rendering-method','gl_compatibility','--position','-4000,-4000','--log-file',str(log),'--script','res://tests/costume_render_v04.gd']
result=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW)
print(result.stdout[-5000:])
print(result.stderr[-3000:])
raise SystemExit(result.returncode)
