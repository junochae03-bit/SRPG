"""Prove the published V0.7 executable cannot roll back V0.7.1 work."""
import hashlib,json,subprocess,time
from engine_path import ROOT,engine,hidden_options

run=ROOT/'runtime'/('save-generation-export-'+str(time.time_ns()))
run.mkdir(parents=True)
exe=ROOT/'releases/V0.7/StelRPG-V0.7-Windows/StelRPG.exe'
assert exe.is_file(),'Published V0.7 executable is required for the rollback reproduction'
def execute(name,command,marker=None):
    result=subprocess.run(command,capture_output=True,text=True,encoding='utf8',timeout=45,**hidden_options())
    output=result.stdout+result.stderr
    (run/(name+'.log')).write_text(output,'utf8')
    assert result.returncode==0 and not any(x in output for x in ('ERROR:','SCRIPT ERROR','WARNING:')),output
    if marker:assert marker in output,output
    print(name,output,flush=True)
base=[engine(),'--headless','--path',str(ROOT/'game'),'--script','res://tests/save_generation.gd','--','--directory='+str(run)]
execute('prepare',base,'failures=0')
execute('published-v07',[str(exe),'--headless','--','--mute','--play','--slot=3','--duration=2','--save-dir='+str(run),'--report='+str(run/'old-report.json')])
old=json.loads((run/'slot-3.json').read_text('utf8'))
assert old['schema_version']==7,'Control must reproduce the old-client backup rollback'
execute('verify',base+['--verify=true'],'failures=0')
proof={'status':'PASS','published_executable_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
       'legacy_control_rolled_back_to_schema':7,'new_primary_and_backup_unchanged':True,
       'reserved_queue_restored':True,'run':str(run.relative_to(ROOT))}
(ROOT/'artifacts/save-generation-export.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2),'utf8')
print('SAVE_GENERATION_EXPORT PASS',run)
