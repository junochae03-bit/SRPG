from pathlib import Path
import subprocess,json,time
from engine_path import engine,hidden_options
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'runtime'/'single-runs'/time.strftime('%Y%m%d-%H%M%S');RUN.mkdir(parents=True)
ENGINE=engine()
(ROOT/'artifacts').mkdir(exist_ok=True)
(ROOT/'artifacts/single_player_result.json').write_text(json.dumps({'status':'RUNNING','run_directory':str(RUN)}),'utf8')

def run(name,arguments,headless=True,script=None):
    cmd=[str(ENGINE),'--path',str(ROOT/'game'),'--log-file',str(RUN/(name+'.log'))]
    if headless:cmd.append('--headless')
    if script:cmd+=['--script','res://tests/'+script+'.gd']
    cmd+=['--','--mute',f'--save-dir={RUN / "saves"}']+arguments
    proc=subprocess.Popen(cmd,**hidden_options())
    try:assert proc.wait(timeout=65)==0,name+' failed'
    finally:
        if proc.poll() is None:proc.kill();proc.wait()
    text=(RUN/(name+'.log')).read_text('utf8',errors='replace')
    assert not any(s in text for s in ['ERROR:','SCRIPT ERROR','WARNING:']),text[-4000:]

print('Single-player gameplay and process restart verification...',flush=True)
run('play',['--bot','--name=모험가','--duration=40',f'--report={RUN / "play.json"}'])
played=json.loads((RUN/'play.json').read_text('utf8'))
assert played['connected'] and played['kills']>=3 and played['distance']>=10,played
# Equipment is probabilistic; this journey must collect a material drop.
assert sum(played['player']['materials'].values())>0,played
run('resume',['--play','--duration=2',f'--report={RUN / "resume.json"}'])
restored=json.loads((RUN/'resume.json').read_text('utf8'))
for key in ['name','level','xp','gold','inventory','equipped','kills','boss_kills','quest_done','potions','equipment','bag_positions','materials','class_id','skill_ranks','costume','training_given','avatar','legacy_costume','stats','skill_loadout','guild_contract','dungeon_clears']:
    assert played['player'][key]==restored['player'][key],key
assert played['world_seed']==restored['world_seed']
run('elite-loot',[f'--report={RUN / "elite.json"}'],script='process_elite_loot')
elite=json.loads((RUN/'elite.json').read_text('utf8'))
run('elite-resume',['--play','--duration=2',f'--report={RUN / "elite-resume.json"}'])
elite_restored=json.loads((RUN/'elite-resume.json').read_text('utf8'))['player']
for key in elite:
    assert elite[key]==elite_restored[key],key
print('Play and restart passed. Rendering final screens...',flush=True)
run('title',['--duration=4','--capture-at=2',f'--capture={ROOT / "artifacts/title.png"}'],False)
run('field',['--bot','--duration=14','--capture-at=10',f'--capture={ROOT / "artifacts/gameplay.png"}'],False)
run('inventory',['--play','--duration=4','--capture-at=2','--show-bag',f'--capture={ROOT / "artifacts/inventory.png"}'],False)
result={'status':'PASS','mode':'single-player; no server process','run_directory':str(RUN),'kills':played['kills'],'distance':played['distance'],'items':len(played['player']['inventory']),'materials':played['player']['materials'],'updates':played['snapshots'],'restart_persistence':'PASS','elite_fixture':'A weakened elite is defeated through the attack action; guaranteed gear is picked up and compared after a separate process restart.','elite_items':len(elite['inventory']),'elite_persistence':'PASS','rendered_screens':['title.png','gameplay.png','inventory.png']}
(ROOT/'artifacts/single_player_result.json').write_text(json.dumps(result,indent=2),'utf8')
print(json.dumps(result,indent=2),flush=True)
