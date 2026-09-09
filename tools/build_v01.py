"""Export the curated project; keep binaries out of source control."""
from pathlib import Path
import subprocess,shutil,json,hashlib
from engine_path import ROOT,engine,hidden_options
OUT=ROOT/'releases/V0.1/StelRPG-V0.1-Windows';OUT.mkdir(parents=True,exist_ok=True)
assert (ROOT/'tools/godot-templates/windows_release_x86_64.exe').is_file(),'Run python tools/fetch_windows_template.py first.'
for args in [['--editor','--import','--quit'],['--export-release','Windows Desktop',str(OUT/'StelRPG.exe')]]:
    result=subprocess.run([engine(),'--headless','--path',str(ROOT/'game')]+args,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180,**hidden_options())
    log=result.stdout+result.stderr;(ROOT/'runtime').mkdir(exist_ok=True);(ROOT/'runtime/export-v01.log').write_text(log,'utf8')
    assert result.returncode==0 and not any(token in log for token in ['ERROR:','SCRIPT ERROR','WARNING:']),log[-8000:]
for source,name in [('docs/PLAY_V01.ko.md','시작 안내.txt'),('docs/ASSET_SOURCES.md','ASSET_SOURCES.md'),('docs/GODOT_LICENSE.txt','GODOT_LICENSE.txt'),('docs/GODOT_COPYRIGHT.txt','GODOT_COPYRIGHT.txt')]:shutil.copy2(ROOT/source,OUT/name)
files=[]
for file in sorted(OUT.iterdir()):
    if file.is_file():files.append({'name':file.name,'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
(ROOT/'artifacts').mkdir(exist_ok=True);(ROOT/'artifacts/export-v01.json').write_text(json.dumps({'status':'PASS','version':'V0.1','files':files},indent=2),'utf8')
print('V01_EXPORT PASS',json.dumps(files),flush=True)
