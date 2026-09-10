"""Exercise the exported Windows executable, portable saves, and real rendering."""
from pathlib import Path
import subprocess,json,time,hashlib,shutil,copy
from PIL import Image,ImageChops,ImageFilter
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
    print('EXPORT_CHECK',name,flush=True)
    cmd=[str(EXE),'--log-file',str(RUN/(name+'.log'))]
    if not graphics:cmd.append('--headless')
    cmd+=['--','--mute','--slot=3']+args
    result=subprocess.run(cmd,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=70,**hidden_options())
    log=(RUN/(name+'.log')).read_text('utf8')+result.stdout+result.stderr
    assert result.returncode==0 and not any(t in log for t in ['ERROR:','SCRIPT ERROR','WARNING:']),log[-8000:]

def screenshot_evidence(path):
    """Inspect actual framebuffer output; this is not an artistic-quality test.

    Exact blue/magenta solid blocks catch unremoved chroma backgrounds without
    rejecting legitimate blue costumes or individual saturated effect pixels.
    Source-reader tests separately cover every animation frame and alpha mask.
    """
    assert path.is_file(),('Missing exported framebuffer capture',str(path))
    with Image.open(path) as source:
        rgb=source.convert('RGB')
    assert rgb.size==(1920,1080),('Explicit Full HD capture client area',rgb.size)
    assert any(lo!=hi for lo,hi in rgb.getextrema()),'Blank framebuffer'
    chroma={}
    for name,color in [('blue',(0,0,255)),('magenta',(255,0,255))]:
        difference=ImageChops.difference(rgb,Image.new('RGB',rgb.size,color))
        r,g,b=difference.split()
        maximum=ImageChops.lighter(ImageChops.lighter(r,g),b)
        mask=maximum.point(lambda value:255 if value<=2 else 0)
        pixels=mask.histogram()[255]
        # Nine consecutive rows and columns of chroma are a visible defect.
        solid_block=mask.filter(ImageFilter.MinFilter(9)).getbbox() is not None
        chroma[name]={'near_exact_pixels':pixels,'solid_9x9_block':solid_block}
        assert not solid_block,('Visible solid chroma block',str(path),name,pixels)
    return {'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'size':list(rgb.size),'chroma':chroma}

def icon_evidence(report):
    icons=report['art_usage']['icons']
    assert not icons['unknown_requests'],('Unrecognized semantic icon requests',icons)
    resolved=sorted(set(icons['resolved_keys']))
    assert resolved,'No semantic icon texture resolved in exported process'
    return {'resolved_keys':resolved,'unknown_requests':[],
            'scope':'Texture resolution recorded at runtime; framebuffer chroma inspected separately.'}

def fixture_capture(name,updates,args,capture_path):
    isolated=RUN/name;isolated.mkdir()
    fixture=copy.deepcopy(saved_before);fixture.update(updates)
    (isolated/'slot-3.json').write_text(json.dumps(fixture,ensure_ascii=False),'utf8')
    output=RUN/(name+'.json')
    run(name,['--play','--save-dir='+str(isolated),'--duration=2.4','--capture-at=1.2',
              '--capture='+str(capture_path),'--report='+str(output)]+args,True)
    restored=json.loads(output.read_text('utf8'))
    assert restored['connected'] and not restored['ui']['creator'],('Fixture rejected by executable',name,restored)
    assert not list(isolated.glob('*.corrupt-*')),('Invalid save fixture',name)
    return restored,screenshot_evidence(capture_path)

def source_sheets(value):
    """Read the catalog's declared sheets, including per-frame overrides."""
    result=set()
    if isinstance(value,dict):
        for key,entry in value.items():
            if key=='sheet' and isinstance(entry,str):result.add(entry)
            else:result.update(source_sheets(entry))
    elif isinstance(value,list):
        for entry in value:result.update(source_sheets(entry))
    return result

equipment_catalog=json.loads((ROOT/'game/assets/equipment/items.json').read_text('utf8'))
equipment_sources={row['sheet']:row for row in equipment_catalog['sheets'].values()}
render_cache=json.loads((ROOT/'game/assets/render_cache_v05/catalog.json').read_text('utf8'))['entries']
ground_catalog=json.loads((ROOT/'game/assets/floor_tiles_v04/catalog.json').read_text('utf8'))
ground_source=ROOT/'game'/ground_catalog['atlas'].removeprefix('res://')
assert hashlib.sha256(ground_source.read_bytes()).hexdigest()==ground_catalog['sha256'],'Ground atlas differs from approved original'

def equipment_evidence(report,required_sources=()):
    used=report['art_usage']['equipment']
    assert not used['failed_assets'],('Missing equipment asset in exported process',used)
    # DB.snapshot also illustrates the generic pre-smart-loot axe entry.
    # All new class-bound equipment must use the six approved atlases instead.
    generic_drop_axe={'id':'','key':'','category':'weapon','weapon_type':'axe','job_lock':'','reason':'legacy_appearance'}
    assert all(row==generic_drop_axe for row in used['fallback_requests']),('Unexpected equipment fallback in exported process',used)
    resolved=set(used['resolved_keys'])
    assert resolved and resolved<=equipment_catalog['items'].keys(),('Unknown or missing equipment keys',used)
    sheets={row['path']:row for row in used['sheets']}
    assert set(required_sources)<=sheets.keys(),('Equipment source never loaded from PCK',required_sources,used)
    for path,row in sheets.items():
        assert path in equipment_sources,('Unexpected equipment source',row)
        expected=equipment_sources[path]
        assert row['load_mode']=='prepared_rgba' and row['prepared_available'],('Expected prepared RGBA data in PCK',row)
        assert not row['source_png_available'] and not row['imported_available'],('Unused original equipment textures must be excluded from PCK',row)
        expected_cache=render_cache[path+'|magenta']
        assert row['prepared_path']==expected_cache['path'],('Wrong prepared source',row,expected_cache)
        assert [row['width'],row['height']]==[expected['width']+1,expected['height']+1],('Memory RGBA padding absent',row)
    return used

def equipment_thumbnail(value):
    assert value and value['key'] in equipment_catalog['items'],('Missing actual equipment UI texture',value)
    entry=equipment_catalog['items'][value['key']]
    assert value['source_path']==entry['sheet'] and value['rect']==entry['rect'] and value['rgba_padded'],('UI texture differs from original source bounds or shared RGBA reader',value)
    return value

def ground_evidence(report,profile):
    used=report['art_usage']['ground'];mapping=ground_catalog['mappings'][profile]
    assert used['profile']==profile and used['ground_id']==mapping['ground'] and used['path_id']==mapping['path'],('Wrong live terrain profile',profile,used)
    assert used['atlas']==ground_catalog['atlas'] and used['shader']=='res://shaders/forest_ground.gdshader',('Wrong terrain sampler/shader',used)
    for role in ['ground','path']:
        rect=ground_catalog['materials'][mapping[role]]['rect']
        assert used[role+'_panel']==[rect[0]/512,rect[1]/512],('Wrong actual material panel',role,used)
    assert used['draws']>0 and not used['fallback'] and used['sampling']=='world-anchored mirrored',('Terrain not submitted with new floor atlas',used)
    return used

icon_checks=[]
run('title',['--duration=2','--capture-at=1','--capture='+str(ROOT/'artifacts/export-title.png'),'--report='+str(RUN/'title.json')],True)
assert json.loads((RUN/'title.json').read_text('utf8'))['ui']['title'] and not save.exists()
run('creator',['--show-creation','--duration=2','--capture-at=1','--capture='+str(ROOT/'artifacts/export-creator.png'),'--report='+str(RUN/'creator.json')],True)
creator=json.loads((RUN/'creator.json').read_text('utf8'))
assert creator['ui']['creator'] and not creator['connected'] and not save.exists(),'Opening creator must not create a character'
assert creator['ui']['creator_appearance']['avatar']=='auto' and creator['ui']['creator_appearance']['costume']=='none','Exported creator uses only class default'
run('keyboard-title',['--show-keys','--duration=2','--capture-at=1','--capture='+str(ROOT/'artifacts/export-keyboard.png'),'--report='+str(RUN/'keyboard-title.json')],True)
keyboard=json.loads((RUN/'keyboard-title.json').read_text('utf8'))
assert keyboard['ui']['keyboard'] and keyboard['ui']['title'] and not keyboard['connected'] and not save.exists(),'Keyboard opens on title without creating save'
screenshot_evidence(ROOT/'artifacts/export-keyboard.png')
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
dialogue_dir=RUN/'dialogue';dialogue_dir.mkdir()
dialogue_fixture=dict(saved_before);dialogue_fixture.update(tutorial_done=True,quest_done=True)
(dialogue_dir/'slot-3.json').write_text(json.dumps(dialogue_fixture,ensure_ascii=False),'utf8')
run('dialogue',['--play','--show-dialogue=smith','--save-dir='+str(dialogue_dir),'--duration=3','--capture-at=1','--capture='+str(ROOT/'artifacts/export-dialogue.png'),'--report='+str(RUN/'dialogue.json')],True)
dialogue=json.loads((RUN/'dialogue.json').read_text('utf8'))
assert dialogue['ui']['dialogue'] and dialogue['paused'] and dialogue['ui']['speaker']=='대장장이 루아'
for name,flag in [('inventory','--show-bag'),('skills','--show-skills')]:
    capture=ROOT/'artifacts'/('export-'+name+'.png');output=RUN/(name+'.json')
    run(name,['--play',flag,'--duration=4','--capture-at=2','--capture='+str(capture),'--report='+str(output)],True)
    icon_checks.append({'screen':name,'icons':icon_evidence(json.loads(output.read_text('utf8'))),'capture':screenshot_evidence(capture)})
codex_screens=[]
for tab,minimum in [('equipment',2500),('monsters',34),('drops',1),('skills',1510)]:
    report_path=RUN/('codex-'+tab+'.json')
    run('codex-'+tab,['--play','--show-codex','--codex-tab='+tab,'--duration=4','--capture-at=1','--capture='+str(ROOT/'artifacts'/('export-codex-'+tab+'.png')),'--report='+str(report_path)],True)
    codex_report=json.loads(report_path.read_text('utf8'));codex=codex_report['codex']
    assert codex['visible'] and codex['tab']==tab and codex['total']>=minimum,codex
    icon_checks.append({'screen':'codex-'+tab,'icons':icon_evidence(codex_report),'capture':screenshot_evidence(ROOT/'artifacts'/('export-codex-'+tab+'.png'))})
    if tab=='equipment':
        consumers=codex_report['art_usage']['equipment_consumers']
        assert consumers['codex_visible'] and consumers['codex_rows'],'Exported equipment codex has no actual thumbnails'
        codex_equipment_thumbnails=[equipment_thumbnail(value) for value in consumers['codex_rows']]
        codex_equipment_detail=equipment_thumbnail(consumers['codex_detail'])
        visible_sources={value['source_path'] for value in codex_equipment_thumbnails+[codex_equipment_detail]}
        codex_equipment_reader=equipment_evidence(codex_report,visible_sources)
        assert len(codex_equipment_reader['sheets'])<len(equipment_sources),'Opening the first codex page must not eagerly load every equipment atlas'
        # The six-item inventory fixture below separately requires all six PCK
        # atlases; metadata-only codex construction now loads visible rows only.
    codex_screens.append(tab)

# Six real inventory items cover the three weapon atlases, two armor atlases and
# accessories in one exported process. The source gate already audits all 115.
database=json.loads((ROOT/'docs/database/stelrpg-database.json').read_text('utf8'))
equipment_fields=['id','name','base_name','category','slot','weapon_type','bonus','rarity','tier','affix','upgrade','family','job_lock','required_level','resonance']
sample_items=[]
for path in equipment_sources:
    candidates=[row for row in database['equipment'] if row['asset']['path']==path and row['family']=='warrior' and row.get('job_lock','') in ['', 'warrior']]
    assert candidates,('Regenerate DB after fixed equipment integration',path)
    chosen=min(candidates,key=lambda row:(row['tier'],row['rarity'],row['id']))
    sample_items.append({field:copy.deepcopy(chosen[field]) for field in equipment_fields})
assert len(sample_items)==6 and len({item['id'] for item in sample_items})==6
updates={'level':100,'class_id':'warrior','costume':'none','avatar':'auto','inventory':sample_items,
         'equipment':{slot:'' for slot in ['weapon','head','chest','hands','legs','feet','accessory']},'equipped':'',
         'bag_positions':{item['id']:{'x':index,'y':0,'rotated':False} for index,item in enumerate(sample_items)},
         'materials':{},'potions':0,'skill_ranks':{},'skill_loadout':{},'constellation_allocations':{},'tutorial_done':True,'quest_done':True}
equipment_report,equipment_capture=fixture_capture('equipment-six-atlases',updates,['--show-bag'],ROOT/'artifacts/export-equipment-six-atlases.png')
equipment_reader=equipment_evidence(equipment_report,equipment_sources.keys())
consumers=equipment_report['art_usage']['equipment_consumers']
assert consumers['bag_visible'],'Representative equipment fixture did not open the real inventory'
bag_thumbnails=[equipment_thumbnail(value) for value in consumers['bag_items']]
assert {value['item_id'] for value in bag_thumbnails}=={item['id'] for item in sample_items},('Not all six actual bag controls consume equipment art',bag_thumbnails)
assert {value['source_path'] for value in bag_thumbnails}==equipment_sources.keys()
for field in ['inventory','equipment','equipped','bag_positions','materials','potions','class_id','costume','avatar','skill_ranks','skill_loadout','constellation_allocations']:
    assert equipment_report['player'][field]==updates[field],('Artwork changed fixture property',field)
for field in ['stats','gold']:
    assert equipment_report['player'][field]==saved_before[field],('Artwork changed existing property',field)
equipment_checks={'representative_items':6,'source_atlases':6,'reader':equipment_reader,'bag_thumbnails':bag_thumbnails,
                  'codex_reader':codex_equipment_reader,'codex_thumbnails':codex_equipment_thumbnails,'codex_detail':codex_equipment_detail,
                  'capture':equipment_capture,'scope':'One actual portable save with six items, plus visible codex rows; original PNG/imported textures absent and prepared RGBA PCK files used. Source gate covers all 115 crops and all 2,500 definitions.'}

# Six additional, isolated V0.5.2 fixtures preserve all previous exported runs.
# These invoke ordinary UI actions inside the real executable; none replaces
# the simulation with source scripts or writes to the portable baseline slot.
v052_checks=[]
v052_portable_baseline=save.read_bytes()
v052_base={'level':100,'class_id':'warrior','costume':'none','avatar':'auto','owned_appearances':[],
           'tutorial_done':True,'quest_done':True,'inventory':[],
           'equipment':{slot:'' for slot in ['weapon','head','chest','hands','legs','feet','accessory']},'equipped':'',
           'bag_positions':{},'materials':{},'potions':0,'skill_ranks':{},'skill_loadout':{},
           'constellation_allocations':{}}

def v052_fixture(name,updates,args):
    fixture=copy.deepcopy(v052_base);fixture.update(updates)
    restored,capture=fixture_capture(name,fixture,['--v052-audit']+args,ROOT/'artifacts'/('export-'+name+'.png'))
    audit=restored['v052']
    assert all(audit['packed_resources'].values()),('Required V0.5.2 resources missing from PCK',audit['packed_resources'])
    for path,files in audit['excluded_packs'].items():
        local=ROOT/'game'/path.removeprefix('res://')
        assert local.is_dir() and any(local.glob('*.png')),('Excluded-pack probe must have real local source assets',path)
        assert not files,('Unreleased V0.6 assets were packed into this executable',path,files)
    # Opening/selecting/practising must preserve possessions and progression.
    # Runtime-derived fields such as stamina and motion are intentionally not saves.
    persistent=audit['persistent']
    for field in ['level','class_id','costume','avatar','owned_appearances','inventory','equipment','equipped',
                  'bag_positions','materials','potions','skill_ranks','skill_loadout','constellation_allocations',
                  'gold','xp','kills','boss_kills','highest_floor','cleared_floor','raid_clears']:
        expected=fixture[field] if field in fixture else saved_before.get(field)
        assert persistent.get(field)==expected,('V0.5.2 preview changed fixture field',name,field,persistent.get(field),expected)
    v052_checks.append({'screen':name,'evidence':audit,'icons':icon_evidence(restored),'capture':capture})
    return audit

settings=v052_fixture('v052-settings',{},['--show-settings','--settings-page=display'])
assert settings['settings']['visible'] and not settings['settings']['keyboard'] and settings['settings']['page']=='display'
assert set(settings['settings']['pages'])=={'sound','display','combat'} and '키 변경' in settings['settings']['keys_button']
nested=v052_fixture('v052-settings-keys',{},['--show-settings','--settings-keys'])
assert nested['settings']['keyboard'] and not nested['settings']['visible'] and nested['settings']['keyboard_returns_to_settings'],'Keyboard must be opened by the actual settings button with its return destination retained'

weapons=[row for row in database['equipment'] if row['category']=='weapon' and row['job_lock']=='warrior']
weak=min(weapons,key=lambda row:(row['tier'],row['rarity'],row['id']))
strong=max((row for row in weapons if row['tier']<=3 and row['rarity']==1),key=lambda row:(row['tier'],row['bonus'],row['id']))
equipped_weapon={field:copy.deepcopy(weak[field]) for field in equipment_fields};equipped_weapon['id']='export-v052-equipped'
bag_items=[]
for index in range(120):
    item={field:copy.deepcopy(strong[field]) for field in equipment_fields};item['id']='export-v052-bag-'+str(index)
    # The DB row is a base catalog definition; a saved rare focus item carries
    # its affix display name. Preserve all fields during the UI preview test.
    assert item['affix']=='focus' and item['upgrade']==0
    item['name']='완력의 '+item['base_name']
    bag_items.append(item)
comparison_fixture={'inventory':[equipped_weapon]+bag_items,'equipment':dict(v052_base['equipment'],weapon=equipped_weapon['id']),'equipped':equipped_weapon['id'],
                    'bag_positions':{item['id']:{'x':index%10,'y':index//10,'rotated':False} for index,item in enumerate(bag_items)}}
comparison=v052_fixture('v052-inventory-comparison',comparison_fixture,['--show-bag','--bag-select='+bag_items[-1]['id']])['inventory']
assert comparison['visible'] and comparison['capacity']==120 and comparison['grid_size']==[10,12] and comparison['capacity_label']=='120 / 120'
assert comparison['scroll']>0 and comparison['comparison_visible'] and comparison['selected']==bag_items[-1]['id'] and comparison['equipped']==equipped_weapon['id']
assert len(comparison['rows'])==5 and any(after>before for _,before,after in comparison['rows']),'Actual equipped-vs-selected derived stat comparison must show a meaningful improvement'

training_fixture={'skill_ranks':{'whirlwind':1},'skill_loadout':{'skill_q':'whirlwind'}}
for name,args in [('v052-training-world',['--show-training']),('v052-training-record',['--show-training','--show-facility=training'])]:
    training=v052_fixture(name,training_fixture,args)
    target=training['training'];enemy=target['enemy']
    assert target['count']==1 and target['actions']=={'attack':True,'skill_q':True}
    assert target['stats']['hits']>=2 and target['stats']['total_damage']>0 and target['stats']['last_skill_id']=='whirlwind'
    assert target['rendered'] and target['drawn_height']==300 and target['texture_source']=='res://assets/town_v052/training-scarecrow.png'
    assert all(dimension>200 for dimension in target['texture_size']),'Giant dummy must consume the real nonempty sprite region'
    assert enemy['hp']==enemy['max_hp']==1000000000 and enemy['position']==[37,30] and not enemy['rewarded'] and not enemy['raid'] and not enemy['guardian']
    assert target['drops']==0 and enemy['stagger']['state'] in ['ready','down','immune']
    assert 'training_stats' not in training['persistent']
    assert target['before']==training['persistent'],'Actual practice must preserve every persistent player field'
    if name.endswith('record'):assert training['facility']['visible'] and training['facility']['id']=='training' and training['facility']['nearest']=='training'
    else:assert not training['facility']['visible']

matching_v052=json.loads((ROOT/'game/assets/costume_v04/class_matching.json').read_text('utf8'))
costume_ids_v052=json.loads((ROOT/'game/assets/costume_v04/catalog.json').read_text('utf8')).keys()
costume_id=next(key for key in sorted(costume_ids_v052) if matching_v052[key]['runtime_role']!='town_npc' and 'warrior' in matching_v052[key]['allowed_base_classes'])
boutique=v052_fixture('v052-costume-boutique',{'gold':5000},['--show-facility=costume','--wardrobe-select=costume:'+costume_id])['facility']
assert boutique['visible'] and boutique['id']==boutique['nearest']=='costume' and boutique['walkable']
assert boutique['wardrobe']['visible'] and boutique['wardrobe']['selected']=='costume:'+costume_id
assert boutique['wardrobe']['action']=='구매하기' and '1200 G' in boutique['wardrobe']['price'] and boutique['wardrobe']['renaming']
assert boutique['wardrobe']['cards'] and boutique['wardrobe']['name'],'Boutique must show actual costume cards, name and purchase action'
assert save.read_bytes()==v052_portable_baseline,'Isolated V0.5.2 fixtures changed the existing portable slot'

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

# These fixtures use the same parser, persistence, renderer and PCK as ordinary
# saved characters. No source --script override or model-only sprite read counts.
art_captures=ROOT/'artifacts'/('export-art-'+KEY);art_captures.mkdir(exist_ok=True)
costume_catalog=json.loads((ROOT/'game/assets/costume_v04/catalog.json').read_text('utf8'))
assert len(costume_catalog)==33,('Expected the complete 33-costume release catalog',len(costume_catalog))
costume_checks=[]
matching=json.loads((ROOT/'game/assets/costume_v04/class_matching.json').read_text('utf8'))
for costume_id,definition in sorted(costume_catalog.items()):
    assert costume_id and all(ch.isalnum() or ch in '_-' for ch in costume_id),costume_id
    eligibility=matching[costume_id]
    if eligibility['runtime_role']=='town_npc':continue
    job=eligibility['allowed_base_classes'][0]
    restored,capture=fixture_capture('costume-'+costume_id,
        {'costume':costume_id,'owned_appearances':['costume:'+costume_id],'class_id':job,'avatar':'auto','inventory':[],'equipment':{},'equipped':'','bag_positions':{},'skill_ranks':{},'skill_loadout':{},'constellation_allocations':{},'tutorial_done':True,'quest_done':True},[],art_captures/('costume-'+costume_id+'.png'))
    assert restored['player']['costume']==costume_id,('Costume save not restored',costume_id)
    used=restored['art_usage']['costume']
    assert used['id']==costume_id and used['draws']>0 and not used['fallback'],('Costume did not reach draw branch',costume_id,used)
    assert 15 in used['frame_indices'],('Idle frame not submitted to renderer',costume_id,used)
    actual_sheets=set(used['source_sheets'])
    assert actual_sheets and actual_sheets<=source_sheets(definition),('Wrong costume sheet consumed',costume_id,used)
    for source in actual_sheets:
        matches=[key for key in restored['art_usage']['prepared'] if key.startswith(source+'|')]
        assert matches and all(restored['art_usage']['prepared'][key]==render_cache[key]['path'] for key in matches),('Costume used legacy pixel processing in exported process',costume_id,source)
    costume_checks.append({'id':costume_id,'restored':True,'draw_calls':used['draws'],
        'frame_indices':sorted(set(used['frame_indices'])),'source_sheets':sorted(actual_sheets),
        'fallback':False,'icons':icon_evidence(restored),'capture':capture})

assert len(costume_checks)==30
town,capture=fixture_capture('town-visitors',{'costume':'none','avatar':'auto','tutorial_done':True,'quest_done':True},[],art_captures/'town-visitors.png')
npcs=set(town['art_usage'].get('npcs',[]))
expected_npcs={key for key in costume_catalog if matching[key]['runtime_role']=='town_npc'}
assert npcs==expected_npcs and len(npcs)==3,('All three gun sprites drawn by town NPCs',npcs)
npc_checks={'drawn_ids':sorted(npcs),'capture':capture,'player_selection':'excluded because no current class uses guns'}

environment_catalog=json.loads((ROOT/'game/assets/environment/biomes-v04/catalog.json').read_text('utf8'))
monster_catalog=json.loads((ROOT/'game/assets/world/dungeon-v04/catalog.json').read_text('utf8'))
assert len(environment_catalog['chapters'])==10
biome_checks=[]
for chapter,theme in enumerate(environment_catalog['chapters']):
    floor=chapter*10+1
    restored,capture=fixture_capture('biome-'+theme,
        {'level':100,'tutorial_done':True,'quest_done':True,'highest_floor':floor,
         'cleared_floor':floor-1,'raid_clears':{},'constellation_allocations':{}},
        ['--floor='+str(floor),'--capture-view=encounter'],art_captures/('biome-'+theme+'.png'))
    assert restored['floor']==floor and restored['capture_view']=='encounter',('Encounter framing unavailable',theme,restored)
    used=restored['art_usage'];environment=used['environment'];monsters=used['monsters']
    assert ground_catalog['chapters'][chapter]==theme,('Floor and biome chapter catalog disagree',chapter,theme)
    ground=ground_evidence(restored,theme)
    expected_environment=set(environment_catalog['themes'][theme])
    environment_ids=set(environment['drawn_ids'])
    assert environment['theme']==theme and environment_ids & expected_environment,('New environment not drawn',theme,environment)
    assert environment_ids<=expected_environment,('Wrong biome environment drawn',theme,environment)
    expected_monsters={key for key,value in monster_catalog['objects'].items() if value['theme']==theme}
    monster_ids=set(monsters['drawn_ids'])
    prepared=theme in monster_catalog['themes']
    if prepared:
        assert monster_ids & expected_monsters,('Prepared monster variant never drawn',theme,monsters)
        assert monster_ids<=expected_monsters,('Wrong biome monster drawn',theme,monsters)
        assert not monsters['fallback_kinds'],('Prepared biome unexpectedly used legacy monster',theme,monsters)
    else:
        assert monsters['fallback_kinds'] and not monster_ids,('Expected retained monster artwork',theme,monsters)
    biome_checks.append({'theme':theme,'floor':floor,'environment_drawn_ids':sorted(environment_ids),
        'monster_drawn_ids':sorted(monster_ids),'legacy_monster_kinds':sorted(set(monsters['fallback_kinds'])),
        'new_monster_pack_prepared':prepared,'camera_only_encounter_framing':True,'ground':ground,
        'icons':icon_evidence(restored),'capture':capture})

isolated=RUN/'final-floor';isolated.mkdir()
fixture=dict(saved_before);fixture.update(level=100,class_id='swordsman',stats={'strength':150,'endurance':90,'technique':30,'agility':27,'magic':0},tutorial_done=True,quest_done=True,highest_floor=100,cleared_floor=99,raid_clears={},inventory=[],equipment={},equipped='',bag_positions={},skill_ranks={},skill_loadout={})
(isolated/'slot-3.json').write_text(json.dumps(fixture,ensure_ascii=False),'utf8')
run('final-floor',['--play','--floor=100','--capture-view=raid','--duration=3','--save-dir='+str(isolated),'--report='+str(RUN/'final-floor.json'),'--capture-at=1','--capture='+str(ROOT/'artifacts/export-floor-100.png')],True)
final_floor=json.loads((RUN/'final-floor.json').read_text('utf8'))
assert final_floor['floor']==100 and len(final_floor['guardians'])==1
assert final_floor['capture_view']=='raid'
final_boss_capture=screenshot_evidence(ROOT/'artifacts/export-floor-100.png')
boss=final_floor['guardians'][0]
assert boss['raid'] and boss['level']==100 and boss['max_hp']>=400000 and '아스트라' in boss['name'],boss
assert final_floor['player']['stats']==fixture['stats']
assert boss['stagger']['state']=='ready' and boss['stagger']['max_value']==260 and boss['stagger']['check_max']==85
# The release template disables script/path overrides. Exercise persisted completion
# through the public game entry point; the source gate separately clears all 100 floors.
fixture.update(cleared_floor=100,raid_clears={str(f):1 for f in range(10,101,10)})
(isolated/'slot-3.json').write_text(json.dumps(fixture,ensure_ascii=False),'utf8')
run('final-resume',['--play','--duration=2','--save-dir='+str(isolated),'--report='+str(RUN/'final-resume.json')])
completed=json.loads((RUN/'final-resume.json').read_text('utf8'))
assert completed['floor']==0 and completed['player']['cleared_floor']==100
assert completed['player']['raid_clears']==fixture['raid_clears']
report={'status':'PASS','version':VERSION,'kills':played['kills'],'distance':played['distance'],'portable_save':'saves/slot-3.json beside the executable','restart_persistence':'all persistent player fields identical','rendered_screens':['export-inventory.png','export-skills.png'],'executable_sha256':hashlib.sha256(EXE.read_bytes()).hexdigest()}
report['abyss']={'rendered_floor':100,'boss_name':boss['name'],'boss_hp':boss['max_hp'],'five_stats_restored':True,'completed_save_fixture_restored':100,'saved_raid_clears':10,'all_100_floors_cleared_by_source_gate':True,'camera_only_raid_framing':True,'capture':final_boss_capture}
report['exported_jobs_restored_and_rendered']=tested_jobs
report['codex_tabs_restored_and_rendered']=codex_screens
report['boss_stagger_state_present']=True
report['v052_features']={'fixtures':v052_checks,'added_runs':len(v052_checks),
    'scope':'Actual exported Windows screenshots and runtime state: settings with nested keyboard, 120-cell bag and equipped-item comparison, giant training sprite plus live damage/stagger with all save fields unchanged, and a separate costume boutique preview. No costume purchase or personal save was used. Required resources and excluded V0.6 directories were probed inside the exported process.'}
report['title_creator_dialogue_rendered']=True
report['empty_creator_does_not_write_save']=True
report['pck_sha256']=hashlib.sha256((portable/'StelRPG.pck').read_bytes()).hexdigest()
report['art_consumption']={'costumes':costume_checks,'town_visitors':npc_checks,'biomes':biome_checks,'icon_screens':icon_checks,'equipment':equipment_checks,
    'costume_scope':'30 compatible player costumes restored and idle frames submitted in independent exported Windows processes; three gun sprites drawn by town visitors. Source-reader tests cover all 528 motion frames.',
    'biome_scope':'Ten legal floor-entry save fixtures, with capture-only camera framing of the first encounter; these captures do not claim clearing those floors.',
    'ground_scope':'Existing ten biome captures inspect the actual terrain ShaderMaterial atlas and panel parameters, shader resource, and positive draw signal count. Source atlas SHA256 matches the approved original.',
    'chroma_scope':'Actual PNG framebuffer: no solid 9x9 near-exact blue or magenta block. This does not replace visual review of transparency edges or icon style.',
    'runtime_reports':str(RUN.relative_to(ROOT))}
report_path=ROOT/('artifacts/export-check-'+KEY+'.json')
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf8')
print('V01_EXPORT_CHECK PASS',json.dumps({'version':VERSION,'kills':played['kills'],
    'distance':played['distance'],'costumes_rendered':len(costume_checks),
    'biomes_rendered':len(biome_checks),'jobs_rendered':len(tested_jobs),
    'report':str(report_path)},ensure_ascii=False),flush=True)
