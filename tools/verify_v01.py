"""Current complete gate: models, UI, real rendering, copy-only save migration."""
from pathlib import Path
import subprocess,json,time,shutil,hashlib,re,struct
from engine_path import ROOT,engine,hidden_options
from asset_inventory import inventory
RUN=ROOT/'runtime/v01-checks'/time.strftime('%Y%m%d-%H%M%S');RUN.mkdir(parents=True)
(ROOT/'artifacts').mkdir(exist_ok=True)
results=[];checks=0
imported=subprocess.run([engine(),'--headless','--path',str(ROOT/'game'),'--editor','--import','--quit'],capture_output=True,text=True,encoding='utf8',errors='replace',timeout=90,**hidden_options())
import_log=imported.stdout+imported.stderr;(RUN/'import.log').write_text(import_log,'utf8')
assert imported.returncode==0 and not any(t in import_log for t in ['ERROR:','SCRIPT ERROR','WARNING:']),import_log[-8000:]
print('Godot project import PASS',flush=True)
def run(test,args=None,graphics=False):
    global checks
    command=[engine(),'--path',str(ROOT/'game'),'--script','res://tests/'+test+'.gd']
    if not graphics:command+=['--headless']
    if args:command+=['--']+args
    process=subprocess.run(command,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=60,**hidden_options())
    output=process.stdout+process.stderr;(RUN/(test+'-'+str(len(results))+'.log')).write_text(output,'utf8')
    assert process.returncode==0 and not any(t in output for t in ['ERROR:','SCRIPT ERROR','WARNING:']),output[-8000:]
    matches=re.findall(r'checks=(\d+)\s+failures=(\d+)',output)
    checks+=sum(int(a) for a,b in matches)
    assert all(int(b)==0 for a,b in matches)
    markers=[line for line in output.splitlines() if any(t in line for t in ['TESTS checks=','LEGACY_SAVE_PASS','FOREST_STABILITY','VISUAL_V05_PASS','VISUAL_V01_PASS'])]
    results.append({'test':test,'status':'PASS','checks':sum(int(a) for a,b in matches),'markers':markers})
    print(test, 'PASS', '; '.join(markers),flush=True)
for test in ['forest_stability','rules','inventory_grid','inventory_ui','combat','skills_v04','loot_v04','single_player','expansion_ui','appearance_v041','expansion_v05','polish_v05','monsters_v05','skills_v01','ui_v01']:run(test)
user_save=ROOT/'runtime/saves/slot-1.json';save_integrity='not present in this checkout'
if user_save.is_file():
    before=hashlib.sha256(user_save.read_bytes()).hexdigest();copy=RUN/'user-copy';copy.mkdir();shutil.copy2(user_save,copy/'slot-1.json');run('legacy_save',['--save-dir='+str(copy)])
    assert hashlib.sha256(user_save.read_bytes()).hexdigest()==before,'Original save changed during check'
    save_integrity='original SHA256 unchanged; copied save migrated and restarted'
old={'schema_version':2,'name':'이전 저장 검증','level':5,'xp':13,'gold':57,'potions':4,'inventory':[],'equipped':'','kills':2,'boss_kills':0,'quest_done':False,'world_seed':20260908,'class_id':'warrior','skill_ranks':{'blade':1,'combo':3},'costume':'witch'}
legacy=RUN/'legacy-combo';legacy.mkdir();(legacy/'slot-1.json').write_text(json.dumps(old,ensure_ascii=False),'utf8');run('legacy_save',['--save-dir='+str(legacy)])
upgraded=json.loads((legacy/'slot-1.json').read_text('utf8'))
assert upgraded['schema_version']==5 and upgraded['skill_ranks']=={'blade':1,'heavy_training':3} and upgraded['costume']=='none'
rows=inventory();assert all(x['bytes']<100*1024*1024 for x in rows)
for file in ['world/catalog.json','motions/catalog.json','gat/catalog.json','icons/catalog.json']:
    catalog=json.loads((ROOT/'game/assets'/file).read_text('utf8'))
    for entry in catalog.values():
        png=ROOT/'game'/entry['sheet'].removeprefix('res://');w,h=struct.unpack('>II',png.read_bytes()[16:24])
        for frame in entry['frames']:
            x,y,fw,fh=frame['rect'] if isinstance(frame,dict) else frame
            assert fw>0 and fh>0 and 0<=x<x+fw<=w and 0<=y<y+fh<=h,(png,frame)
ui=json.loads((ROOT/'game/assets/ui/catalog.json').read_text('utf8'))
png=ROOT/'game'/ui['kit'].removeprefix('res://');w,h=struct.unpack('>II',png.read_bytes()[16:24])
for x,y,fw,fh in ui['frames'].values():assert fw>0 and fh>0 and 0<=x<x+fw<=w and 0<=y<y+fh<=h
run('visual_v05',graphics=True)
run('visual_v01',graphics=True)
report={'status':'PASS','checks':checks,'results':results,'save_integrity':save_integrity,'runtime_files':len(rows),'runtime_mib':round(sum(x['bytes'] for x in rows)/1048576,2),'verified_at':time.strftime('%Y-%m-%d %H:%M:%S'),'run_directory':str(RUN)}
(ROOT/'artifacts/v01_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf8')
print('V01_GATE PASS checks='+str(checks),flush=True)
