"""Export the curated project; keep binaries out of source control."""
from pathlib import Path
import subprocess,shutil,json,hashlib
from engine_path import ROOT,engine,hidden_options
from release_version import VERSION,KEY
from asset_inventory import inventory
runtime_before={row['path']:row['sha256'] for row in inventory()}
verification=json.loads((ROOT/'artifacts/v01_verification.json').read_text('utf8'))
assert verification['status']=='PASS' and verification.get('runtime_sha256')==runtime_before,'Run the complete source gate on the current runtime before export'
OUT=ROOT/'releases'/VERSION/('StelRPG-'+VERSION+'-Windows');OUT.mkdir(parents=True,exist_ok=True)
assert (ROOT/'tools/godot-templates/windows_release_x86_64.exe').is_file(),'Run python tools/fetch_windows_template.py first.'
for args in [['--editor','--import','--quit'],['--export-release','Windows Desktop',str(OUT/'StelRPG.exe')]]:
    result=subprocess.run([engine(),'--headless','--path',str(ROOT/'game')]+args,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180,**hidden_options())
    log=result.stdout+result.stderr;(ROOT/'runtime').mkdir(exist_ok=True);(ROOT/'runtime/export-v01.log').write_text(log,'utf8')
    assert result.returncode==0 and not any(token in log for token in ['ERROR:','SCRIPT ERROR','WARNING:']),log[-8000:]
for source,name in [('docs/PLAY_CURRENT.ko.md','시작 안내.txt'),('docs/ASSET_SOURCES.md','ASSET_SOURCES.md'),('docs/GODOT_LICENSE.txt','GODOT_LICENSE.txt'),('docs/GODOT_COPYRIGHT.txt','GODOT_COPYRIGHT.txt')]:shutil.copy2(ROOT/source,OUT/name)
files=[]
for name in ['StelRPG.exe','StelRPG.pck','시작 안내.txt','ASSET_SOURCES.md','GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt']:
    file=OUT/name;files.append({'name':name,'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
assert runtime_before=={row['path']:row['sha256'] for row in inventory()},'Runtime changed during export'
(ROOT/'artifacts').mkdir(exist_ok=True);(ROOT/('artifacts/export-'+KEY+'.json')).write_text(json.dumps({'status':'PASS','version':VERSION,'files':files,'verified_runtime_sha256':runtime_before},indent=2),'utf8')
print('V01_EXPORT PASS',json.dumps(files),flush=True)
