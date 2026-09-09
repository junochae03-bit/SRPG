"""Current complete gate: models, UI, real rendering, copy-only save migration."""
from pathlib import Path
import subprocess,json,time,shutil,hashlib,re,struct,sys
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
    try:
        process=subprocess.run(command,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=60,**hidden_options())
    except subprocess.TimeoutExpired as failure:
        decode=lambda value:value.decode('utf8','replace') if isinstance(value,bytes) else value or ''
        output=decode(failure.stdout)+decode(failure.stderr)
        (RUN/(test+'-'+str(len(results))+'.log')).write_text(output,'utf8')
        raise RuntimeError('Test timed out: '+test+'; log directory '+str(RUN)) from failure
    output=process.stdout+process.stderr;(RUN/(test+'-'+str(len(results))+'.log')).write_text(output,'utf8')
    assert process.returncode==0 and not any(t in output for t in ['ERROR:','SCRIPT ERROR','WARNING:']),output[-8000:]
    matches=re.findall(r'checks=(\d+)\s+failures=(\d+)',output)
    checks+=sum(int(a) for a,b in matches)
    assert all(int(b)==0 for a,b in matches)
    markers=[line for line in output.splitlines() if any(t in line for t in ['TESTS checks=','LEGACY_SAVE_PASS','FOREST_STABILITY','VISUAL_V05_PASS','VISUAL_V01_PASS'])]
    results.append({'test':test,'status':'PASS','checks':sum(int(a) for a,b in matches),'markers':markers})
    print(test, 'PASS', '; '.join(markers),flush=True)
    return output
for test in ['forest_stability','rules','inventory_grid','inventory_ui','combat','skills_v04','loot_v04','single_player','expansion_ui','appearance_v041','expansion_v05','polish_v05','monsters_v05','skills_v01','ui_v01','jobs','job_balance','job_ui','progression_v02','equipment_v02','dungeon_v02','floor_balance_v02']:run(test)
user_save=ROOT/'runtime/saves/slot-1.json';save_integrity='not present in this checkout'
for test in ['database_v03','boss_stagger_v03','skill_vfx','skill_build_v04','database_v04','constellation_combat_v04','character_creation_v04','skill_build_session_v04','icons','environment_v04','dungeon_entry_v04','costume_art_v04','battle_camera_v04','appearance_matching_v04']:run(test)
if user_save.is_file():
    before=hashlib.sha256(user_save.read_bytes()).hexdigest();copy=RUN/'user-copy';copy.mkdir();shutil.copy2(user_save,copy/'slot-1.json');run('legacy_save',['--save-dir='+str(copy)])
    assert hashlib.sha256(user_save.read_bytes()).hexdigest()==before,'Original save changed during check'
    save_integrity='original SHA256 unchanged; copied save migrated and restarted'
old={'schema_version':2,'name':'이전 저장 검증','level':5,'xp':13,'gold':57,'potions':4,'inventory':[],'equipped':'','kills':2,'boss_kills':0,'quest_done':False,'world_seed':20260908,'class_id':'warrior','skill_ranks':{'blade':1,'combo':3},'costume':'witch'}
legacy=RUN/'legacy-combo';legacy.mkdir();(legacy/'slot-1.json').write_text(json.dumps(old,ensure_ascii=False),'utf8');run('legacy_save',['--save-dir='+str(legacy)])
upgraded=json.loads((legacy/'slot-1.json').read_text('utf8'))
assert upgraded['schema_version']==7 and upgraded['skill_ranks']=={'blade':1,'heavy_training':3} and upgraded['costume']=='none'
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
run('visual_jobs',graphics=True)
run('job_benchmark')
run('ui_v02',graphics=True)
run('codex_ui_v03',graphics=True)
run('stagger_ui_v03',graphics=True)
run('visual_skill_vfx',graphics=True)
run('skill_tree_ui_v04',graphics=True)
run('character_dialogue_ui_v04',graphics=True)
from check_icons import audit_assets as audit_icon_assets, audit_rendered_captures
icon_assets=audit_icon_assets()
assert icon_assets['status']=='PASS',icon_assets['failures']
icon_capture_started=time.time_ns()
icon_output=run('visual_icons',graphics=True)
icon_pixels=audit_rendered_captures(icon_capture_started,icon_output)
assert icon_pixels['status']=='PASS',icon_pixels['failures']
run('environment_visual_v04',graphics=True)
run('dungeon_entry_visual_v04',graphics=True)
run('costume_render_v04',graphics=True)
run('costume_session_v04',graphics=True)
run('hud_layout_v04',graphics=True)
run('inventory_ui',graphics=True)
run('ui_legibility_v04',graphics=True)
run('audio_shutdown_v04')
run('equipment_art')
from check_equipment_art import asset_audit, chroma_mask
from PIL import Image
equipment_assets=asset_audit()
assert equipment_assets['status']=='PASS',equipment_assets['failures']
equipment_capture_started=time.time_ns()
run('visual_equipment_art',graphics=True)
equipment_capture=ROOT/'artifacts/equipment-items-gallery.png'
assert equipment_capture.stat().st_mtime_ns>=equipment_capture_started-2_000_000_000,'Stale equipment framebuffer'
with Image.open(equipment_capture) as rendered_equipment:
    assert rendered_equipment.size==(1920,1080)
    assert chroma_mask(rendered_equipment).histogram()[255]==0,'Magenta residue in current equipment gallery'
run('floor_tiles_v04')
run('floor_tiles_visual_v04',graphics=True)
run('art_registry_v05')
portable_db=subprocess.run([sys.executable,str(ROOT/'tools/test_art_registry.py')],capture_output=True,text=True,encoding='utf8',errors='replace',timeout=60,**hidden_options())
portable_log=portable_db.stdout+portable_db.stderr
(RUN/'art_registry_portable.log').write_text(portable_log,'utf8')
assert portable_db.returncode==0 and 'ART_REGISTRY_PORTABLE PASS' in portable_log,portable_log[-8000:]
portable_count=int(re.search(r'PASS checks=(\d+)',portable_log).group(1));checks+=portable_count
results.append({'test':'art_registry_portable','status':'PASS','checks':portable_count,'markers':portable_log.splitlines()})
print(portable_log.strip(),flush=True)
report={'status':'PASS','checks':checks,'results':results,'save_integrity':save_integrity,'runtime_files':len(rows),'runtime_mib':round(sum(x['bytes'] for x in rows)/1048576,2),'verified_at':time.strftime('%Y-%m-%d %H:%M:%S'),'run_directory':str(RUN)}
final_rows=inventory()
assert final_rows==rows,'Runtime source changed while verification was running'
report['runtime_sha256']={row['path']:row['sha256'] for row in final_rows}
report['equipment_asset_pixels']={'status':'PASS','regions':len(equipment_assets['regions']),'sheets':equipment_assets['sheets'],'gallery_sha256':hashlib.sha256(equipment_capture.read_bytes()).hexdigest(),'bright_magenta_pixels':0}
report['icon_asset_pixels']={'status':'PASS','regions':len(icon_assets['icons']),'sheets':icon_assets['sheets'],'rendered_captures':icon_pixels}
(ROOT/'artifacts/v01_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf8')
print('V01_GATE PASS checks='+str(checks),flush=True)
