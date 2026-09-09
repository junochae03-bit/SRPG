"""Verify referenced pack files without altering their pixels."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[2]
ASSETS=PROJECT/'game/assets/costume_v04'
DOCS=PROJECT/'docs/costume_v04'
CALIBRATION=DOCS/'calibration'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
catalog=read(ASSETS/'catalog.json')
provenance=read(DOCS/'PROVENANCE.json')
assert len(catalog)==33
files={}
frames=0
minimum_patch_gap=None
for ident,entry in catalog.items():
    assert entry['name'] and entry['target_body_height']==112
    calibration_document=PROJECT/entry['calibration_document']
    assert calibration_document.resolve().is_relative_to(CALIBRATION.resolve())
    assert calibration_document.is_file()
    assert len(entry['frames'])==16
    assert sorted(i for indices in entry['action_map'].values() for i in indices)==list(range(16))
    for i,f in enumerate(entry['frames']):
        assert f['index']==i
        path=PROJECT/'game'/f.get('sheet',entry['sheet']).removeprefix('res://')
        assert path.resolve().is_relative_to(ASSETS.resolve())
        if path not in files:
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                a=np.asarray(image.convert('RGB'))
                files[path]={'size':image.size,'array':a,'rects':[],'frames':[],'key':entry['chroma_key']}
        data=files[path];w,h=data['size'];x,y,rw,rh=f['rect']
        assert all(isinstance(v,int) for v in f['rect'])
        assert 0<=x<x+rw<=w and 0<=y<y+rh<=h
        assert 0<=f['foot'][0]<=rw and 0<=f['foot'][1]<=rh
        assert f['body_height']>0
        for other in data['rects']:
            ox,oy,ow,oh=other
            assert not(x<ox+ow and ox<x+rw and y<oy+oh and oy<y+rh),(ident,i,'overlap')
        data['rects'].append(f['rect']);data['frames'].append(i)
        crop=data['array'][y:y+rh,x:x+rw]
        if entry['chroma_key']=='blue':key=(crop[:,:,0]<=63)&(crop[:,:,1]<=63)&(crop[:,:,2]>=166)
        else:key=(crop[:,:,0]>=166)&(crop[:,:,2]>=166)&(crop[:,:,1]<=89)
        assert (~key).sum()>100,(ident,i,'empty')
        frames+=1
assert frames==528 and len(files)==35
for image in provenance['images']:
    assert sha(ASSETS/image['file'])==image['sha256']
inventory_path=Path('D:/SSRPG/RPG2/art/skins/review-20260909/inventory-all.json')
if inventory_path.exists():
    for image in read(inventory_path)['archive_manifest']:
        assert sha(ASSETS/Path(image['package_relative_path']).name)==image['source_sha256']
for path,data in files.items():
    if '-attacks-v04' not in path.stem: continue
    assert data['frames']==[6,7]
    left,right=sorted(data['rects']);gap=right[0]-left[0]-left[2]
    assert gap>=100
    minimum_patch_gap=gap if minimum_patch_gap is None else min(minimum_patch_gap,gap)
    a=data['array']
    key=(a[:,:,0]>=166)&(a[:,:,2]>=166)&(a[:,:,1]<=89)
    covered=np.zeros(key.shape,dtype=bool)
    for x,y,w,h in data['rects']:covered[y:y+h,x:x+w]=True
    assert not((~key)&~covered).any()
result={'costumes':len(catalog),'frames':frames,'referenced_pngs':len(files),'all_rects_disjoint_within_referenced_sheet':True,'all_pivots_in_rect':True,'all_referenced_images_decode':True,'all_provenance_hashes_match':True,'all_original_33_hashes_match_prior_inventory':inventory_path.exists(),'mint_patches_replace_only_frames':[6,7],'minimum_patch_gutter_px':minimum_patch_gap,'catalog_sha256':sha(ASSETS/'catalog.json'),'provenance_sha256':sha(DOCS/'PROVENANCE.json'),'files':[{'path':p.name,'sha256':sha(p),'size':list(d['size']),'referenced_frames':d['frames']} for p,d in files.items()]}
output=PROJECT/'runtime/costume-v04-review/pack-verification.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='files'},indent=2))
