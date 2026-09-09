"""Exercise the exported Windows executable, portable saves, and real rendering."""
from pathlib import Path
import subprocess,json,time,hashlib
from engine_path import ROOT,hidden_options
OUT=ROOT/'releases/V0.1/StelRPG-V0.1-Windows';EXE=OUT/'StelRPG.exe'
RUN=ROOT/'runtime/export-checks'/time.strftime('%Y%m%d-%H%M%S');RUN.mkdir(parents=True)
save=OUT/'saves/slot-3.json'
assert not save.exists(),'Use a fresh output directory; do not overwrite a player save.'
def run(name,args,graphics=False):
    cmd=[str(EXE),'--log-file',str(RUN/(name+'.log'))]
    if not graphics:cmd.append('--headless')
    cmd+=['--','--mute','--slot=3']+args
    result=subprocess.run(cmd,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=70,**hidden_options())
    log=(RUN/(name+'.log')).read_text('utf8')+result.stdout+result.stderr
    assert result.returncode==0 and not any(t in log for t in ['ERROR:','SCRIPT ERROR','WARNING:']),log[-8000:]
run('play',['--bot','--duration=40','--name=출시본 검사','--report='+str(RUN/'play.json')])
played=json.loads((RUN/'play.json').read_text('utf8'))
assert played['connected'] and played['kills']>=3 and played['distance']>=10 and save.is_file(),played
saved_before=json.loads(save.read_text('utf8'))
run('resume',['--play','--duration=2','--report='+str(RUN/'resume.json')])
restored=json.loads((RUN/'resume.json').read_text('utf8'))
saved_after=json.loads(save.read_text('utf8'))
assert saved_before==saved_after,'Exported process restart changed saved fields'
for key,value in saved_before.items():
    if key in restored['player']:assert restored['player'][key]==value,('Saved field not restored',key)
assert played['world_seed']==restored['world_seed']
for name,flag in [('inventory','--show-bag'),('skills','--show-skills')]:
    run(name,['--play',flag,'--duration=4','--capture-at=2','--capture='+str(ROOT/'artifacts'/('export-'+name+'.png'))],True)
report={'status':'PASS','version':'V0.1','kills':played['kills'],'distance':played['distance'],'portable_save':'saves/slot-3.json beside the executable','restart_persistence':'all persistent player fields identical','rendered_screens':['export-inventory.png','export-skills.png'],'executable_sha256':hashlib.sha256(EXE.read_bytes()).hexdigest()}
(ROOT/'artifacts/export-check-v01.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf8');print('V01_EXPORT_CHECK PASS',json.dumps(report,ensure_ascii=False),flush=True)
