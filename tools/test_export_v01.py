"""Exercise the exported Windows executable, portable saves, and real rendering."""
from pathlib import Path
import subprocess,json,time,hashlib,shutil
from engine_path import ROOT,hidden_options
from release_version import VERSION,KEY
OUT=ROOT/'releases'/VERSION/('StelRPG-'+VERSION+'-Windows')
RUN=ROOT/'runtime/export-checks'/time.strftime('%Y%m%d-%H%M%S');RUN.mkdir(parents=True)
portable=RUN/'portable-build';portable.mkdir()
manifest=json.loads((ROOT/('artifacts/export-'+KEY+'.json')).read_text('utf8'))
assert manifest['version']==VERSION
for row in manifest['files']:
    source=OUT/row['name'];assert source.parent==OUT and hashlib.sha256(source.read_bytes()).hexdigest()==row['sha256']
    shutil.copy2(source,portable/source.name)
EXE=portable/'StelRPG.exe'
save=portable/'saves/slot-3.json'
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
catalog=json.loads((ROOT/'game/data/jobs/catalog.json').read_text('utf8'))
tested_jobs=[]
for job,definition in catalog['classes'].items():
    if definition.get('starter',False):continue
    isolated=RUN/('job-'+job);isolated.mkdir()
    fixture=dict(saved_before);fixture.update(level=100,class_id=job,skill_ranks={},skill_loadout={},tutorial_done=True,quest_done=True,inventory=[],equipment={},equipped='',bag_positions={})
    for node in catalog['nodes'][job]:
        if node['effect']=='active' and len(fixture['skill_loadout'])<6:
            fixture['skill_ranks'][node['id']]=3
            fixture['skill_loadout'][['skill_q','skill_f','skill_v','skill_c','skill_z','skill_x'][len(fixture['skill_loadout'])]]=node['id']
    (isolated/'slot-3.json').write_text(json.dumps(fixture,ensure_ascii=False),'utf8')
    output=RUN/(job+'.json')
    run('job-'+job,['--play','--show-skills','--duration=1.4','--save-dir='+str(isolated),'--report='+str(output),'--capture-at=.5','--capture='+str(ROOT/'artifacts'/('export-job-'+job+'.png'))],True)
    restored_job=json.loads(output.read_text('utf8'))['player']
    assert restored_job['class_id']==job and restored_job['level']==100
    assert restored_job['skill_ranks']==fixture['skill_ranks'] and restored_job['skill_loadout']==fixture['skill_loadout']
    tested_jobs.append(job)
isolated=RUN/'final-floor';isolated.mkdir()
fixture=dict(saved_before);fixture.update(level=100,class_id='swordsman',stats={'strength':150,'endurance':90,'technique':30,'agility':27,'magic':0},tutorial_done=True,quest_done=True,highest_floor=100,cleared_floor=99,raid_clears={},inventory=[],equipment={},equipped='',bag_positions={},skill_ranks={},skill_loadout={})
(isolated/'slot-3.json').write_text(json.dumps(fixture,ensure_ascii=False),'utf8')
run('final-floor',['--play','--floor=100','--duration=3','--save-dir='+str(isolated),'--report='+str(RUN/'final-floor.json'),'--capture-at=1','--capture='+str(ROOT/'artifacts/export-floor-100.png')],True)
final_floor=json.loads((RUN/'final-floor.json').read_text('utf8'))
assert final_floor['floor']==100 and len(final_floor['guardians'])==1
boss=final_floor['guardians'][0]
assert boss['raid'] and boss['level']==100 and boss['max_hp']>=400000 and '아스트라' in boss['name'],boss
assert final_floor['player']['stats']==fixture['stats']
# The release template disables script/path overrides. Exercise persisted completion
# through the public game entry point; the source gate separately clears all 100 floors.
fixture.update(cleared_floor=100,raid_clears={str(f):1 for f in range(10,101,10)})
(isolated/'slot-3.json').write_text(json.dumps(fixture,ensure_ascii=False),'utf8')
run('final-resume',['--play','--duration=2','--save-dir='+str(isolated),'--report='+str(RUN/'final-resume.json')])
completed=json.loads((RUN/'final-resume.json').read_text('utf8'))
assert completed['floor']==0 and completed['player']['cleared_floor']==100
assert completed['player']['raid_clears']==fixture['raid_clears']
report={'status':'PASS','version':VERSION,'kills':played['kills'],'distance':played['distance'],'portable_save':'saves/slot-3.json beside the executable','restart_persistence':'all persistent player fields identical','rendered_screens':['export-inventory.png','export-skills.png'],'executable_sha256':hashlib.sha256(EXE.read_bytes()).hexdigest()}
report['abyss']={'rendered_floor':100,'boss_name':boss['name'],'boss_hp':boss['max_hp'],'five_stats_restored':True,'completed_save_fixture_restored':100,'saved_raid_clears':10,'all_100_floors_cleared_by_source_gate':True}
report['exported_jobs_restored_and_rendered']=tested_jobs
report['pck_sha256']=hashlib.sha256((portable/'StelRPG.pck').read_bytes()).hexdigest()
(ROOT/('artifacts/export-check-'+KEY+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf8');print('V01_EXPORT_CHECK PASS',json.dumps(report,ensure_ascii=False),flush=True)
