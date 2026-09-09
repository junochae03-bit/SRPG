"""Import only referenced source sheets and coordinates; never edit art originals."""
from pathlib import Path
import argparse, hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=ROOT.parents[1]/'RPG2/art')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
packs = [('biomes', args.source/'backgrounds/biomes-20260909', 'atlas_manifest.json'),
         ('expansion', args.source/'dungeons/dungeon-expansion-20260909', 'catalog.json'),
         ('bosses', args.source/'dungeons/dungeon-bosses-20260909', 'catalog.json'),
         ('fantasy', args.source/'backgrounds/fantasy-expansion-20260909', 'catalog.json')]
env = {'version': 1, 'objects': {}, 'themes': {}, 'chapters': ['forest','cave','flood','spore','lava','snow','machine','autumn','nebula','core']}
world = {'version': 1, 'objects': {}, 'themes': {}, 'variants': {}}
records = []
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def emit(path, value):
    text = json.dumps(value, ensure_ascii=False, indent=2)+'\n'
    if args.check: assert path.read_text('utf-8') == text, f'Stale: {path}'
    else:
        path.parent.mkdir(parents=True, exist_ok=True);path.write_text(text, encoding='utf-8', newline='\n')
for pack_id, folder, manifest in packs:
    data = json.loads((folder/manifest).read_text('utf-8'))
    for sheet in data['sheets']:
        category = sheet.get('category', 'environment')
        theme = sheet['theme']; original = folder/sheet['sheet']
        assert digest(original) == sheet['sha256'], f'Changed original; review latest manifest: {original}'
        target = ROOT/'game/assets'/('environment/biomes-v04' if category=='environment' else 'world/dungeon-v04')/(theme+('-'+category if category!='environment' else '')+'.png')
        if args.check: assert target.is_file() and digest(target)==sheet['sha256'], target
        else:
            target.parent.mkdir(parents=True, exist_ok=True);shutil.copyfile(original, target)
        path = 'res://'+target.relative_to(ROOT/'game').as_posix()
        output = env if category=='environment' else world
        ids = []
        for row in sheet['objects']:
            r = row['rect']; foot = row['foot']; ident = row['id']
            assert r[0]>=0 and r[1]>=0 and r[2]>0 and r[3]>0 and r[0]+r[2]<=1536 and r[1]+r[3]<=1024,ident
            assert 0<=foot[0]<=r[2] and 0<=foot[1]<=r[3],ident
            item = {'id':ident,'name':row['name_ko'], 'theme':theme,'sheet':path,'rect':r,'foot':foot,
                    'source_cell':row.get('source_cell',row.get('grid_cell')), 'source_pack':pack_id}
            if category!='environment':
                item.update({'species':row['monster_id'],'pose':row['pose'],'hovering':row.get('hovering',False),
                             'body_height':row.get('content_rect',r)[3]})
            output['objects'][ident] = item;ids.append(ident)
        if category=='environment':env['themes'][theme]=ids
        else:world['themes'].setdefault(theme,{})[category]=ids
        records.append({'pack':pack_id,'source':str(original),'runtime':path,'sha256':sheet['sha256'],
                        'bytes':original.stat().st_size,'objects':ids, 'source_manifest_sha256':digest(folder/manifest)})
# Include the two earlier decorative themes in the corresponding new biomes.
env['themes']['flood'] += env['themes']['ruins']
env['themes']['spore'] += env['themes']['marsh']
env['themes']['town'] = env['themes']['forest'] + env['themes']['ruins']
# Secondary habitats enrich the existing ten chapters without changing their
# collision terrain, encounter IDs, monster mapping, or raid progression.
for secondary, primary in {'desert':'flood','sky':'nebula','ice':'snow','graveyard':'core','bamboo':'forest','dragon':'lava'}.items():
    env['themes'][primary] += env['themes'][secondary]
groups = {
 'flood':[['spider','frost_slime'],['goblin_shaman'],['skeleton','centurion']],
 'spore':[['spider','ember_slime'],['fairy'],['goblin_shaman','goblin_captain']],
 'lava':[['ember_slime'],['bat'],['orc_axeman','beetle','orc_champion']],
 'machine':[['clockwork','beetle'],['spellbook'],['skeleton','centurion']],
 'nebula':[['spider','clockwork'],['spellbook'],['frost_slime','centurion']],
 'core':[['clockwork','skeleton'],['spellbook','goblin_shaman'],['orc_axeman','centurion']]}
for theme, classes in groups.items():
    ids = world['themes'][theme]['monsters']; idle = [world['objects'][i] for i in ids if world['objects'][i]['pose']=='idle']
    world['variants'][theme]={}
    for i, kinds in enumerate(classes):
        for kind in kinds:world['variants'][theme][kind]=idle[i]['species']
assert len(env['objects'])==108 and len(world['objects'])==48 and len(records)==30
emit(ROOT/'game/assets/environment/biomes-v04/catalog.json',env)
emit(ROOT/'game/assets/world/dungeon-v04/catalog.json',world)
emit(ROOT/'docs/ENVIRONMENT_V04_PROVENANCE.json',{'source_pixels':'unaltered','tool':'image_gen (original packs)',
 'runtime_use':'108 environmental props, 18 chapter-specific common monster appearances, 6 raid appearances; idle/attack key poses only',
 'files':records})
print('ENVIRONMENT_IMPORT PASS sheets=30 props=108 monster_species=18 bosses=6 frames=48 mode='+('check' if args.check else 'write'))
