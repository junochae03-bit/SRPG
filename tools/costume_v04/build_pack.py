"""Build this costume pack from preserved source sheets and manual calibration.
No source pixels are edited. The two mint repair strips are imagegen outputs.
"""
from pathlib import Path
import hashlib, json, shutil
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
ASSETS = PROJECT/'game/assets/costume_v04'
DOCS = PROJECT/'docs/costume_v04'
CALIBRATION = DOCS/'calibration'
SOURCES = Path('D:/SSRPG/RPG2/art/skins')
REVIEW = SOURCES/'review-20260909'
def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def mask(p):
    a=np.asarray(Image.open(p).convert('RGB'))/255
    return ~((a[:,:,0]>.65)&(a[:,:,2]>.65)&(a[:,:,1]<.35))
def bbox(m,x=0,y=0):
    ys,xs=np.where(m)
    return [int(xs.min()+x),int(ys.min()+y),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)]
def gap(active,target,radius):
    blank=np.flatnonzero(~active)
    runs=[r for r in np.split(blank,np.where(np.diff(blank)>1)[0]+1) if len(r)]
    options=[r for r in runs if abs(float(r.mean())-target)<radius]
    if not options: raise ValueError(f'No safe divider near {target}')
    best=max(options,key=len)
    return int(round(float(best.mean())))
def mint_frames(ident):
    original=ASSETS/(ident+'-sheet.png')
    m=mask(original);h,w=m.shape
    rows=[0]+[gap(m.any(axis=1),h*i/4,h*.12) for i in (1,2,3)]+[h]
    frames=[]
    for row in range(4):
        y0,y1=rows[row:row+2];rowmask=m[y0:y1]
        cols=[0]+[gap(rowmask.any(axis=0),w*i/4,w*.12) for i in ((1,2) if row==1 else (1,2,3))]+[w]
        for col in range(4):
            i=row*4+col
            if i in (6,7):
                frames.append({'index':i})
                continue
            x0,x1=cols[col:col+2]
            r=bbox(rowmask[:,x0:x1],x0,y0)
            frames.append({'index':i,'rect':r})
    patch=ASSETS/(ident+'-attacks-v04.png');pm=mask(patch);ph,pw=pm.shape
    cut=gap(pm.any(axis=0),pw/2,pw*.2)
    for i,(x0,x1) in enumerate(((0,cut),(cut,pw)),6):
        r=bbox(pm[:,x0:x1],x0,0)
        assert min(r[0]-x0,r[1],x1-r[0]-r[2],ph-r[1]-r[3])>=10
        frames[i]={'index':i,'rect':r,'sheet':'res://assets/costume_v04/'+patch.name}
    return frames

def prepare_sources():
    ASSETS.mkdir(parents=True,exist_ok=True)
    inventory=read(REVIEW/'inventory-all.json')
    for entry in inventory['archive_manifest']:
        p=SOURCES/entry['package_relative_path'];dest=ASSETS/p.name
        assert sha(p)==entry['source_sha256']
        if not dest.exists(): shutil.copyfile(p,dest)
        assert sha(dest)==entry['source_sha256']
    mint={ident:mint_frames(ident) for ident in ('mint-summer','mint-silver-knight')}
    CALIBRATION.mkdir(parents=True,exist_ok=True)
    write(CALIBRATION/'mint-regions.json',mint)
    return inventory,mint

ACTION_MAP={'idle':[15],'move':[0,1,2,3],'normal':[4,5,6,7],'strong':[8,9,10,11],'dodge':[12,13],'hurt':[14]}
GROUP_NAMES={'mint':'민트','pink':'핑크','lavender':'라벤더','aqua':'아쿠아','crimson':'크림슨','silvercat':'실버캣','raven':'레이븐','amethyst':'아메시스트','pearlcat':'펄캣','cobalt':'코발트'}
OUTFIT_NAMES={'summer':'여름','hanbok':'한복','silver-knight':'은기사','bunny-hoodie':'토끼 후드','black-veil-hanbok':'검은 베일 한복','beret-gunner':'베레모 거너','sailor':'세일러','winter-hanbok':'겨울 한복','shrine-maiden':'무녀','pajama':'파자마','rabbit-stage':'토끼 무대복','goggles-explorer':'고글 탐험가','rose-gothic':'장미 고딕','black-dress':'블랙 드레스','black-jacket':'블랙 재킷','pastel-rabbit':'파스텔 토끼','summer-resort':'여름 리조트','pink-maid':'핑크 메이드','blossom-hanbok':'꽃 한복','street':'스트리트','black-uniform':'블랙 제복','black-punk':'블랙 펑크','navy-hanbok':'남색 한복','pink-dress':'핑크 드레스','school-uniform':'교복','purple-dress':'보라 드레스','summer-shawl':'여름 숄','black-ribbon-maid':'블랙 리본 메이드','broom-maid':'빗자루 메이드'}

def build():
    inventory,mint=prepare_sources()
    calibrations={}
    for fn in ('part-a.json','part-b.json','part-mint.json'):
        part=read(CALIBRATION/fn)
        if 'items' in part:
            part=part['items']
            if isinstance(part,list): part={v['id']:v for v in part}
        calibrations.update(part)
    assert len(calibrations)==33, len(calibrations)
    catalog={}
    for record in inventory['archive_manifest']:
        source=SOURCES/record['package_relative_path'];ident=source.stem.removesuffix('-sheet')
        group=ident.split('-')[0];outfit=ident[len(group)+1:]
        raw=mint[ident] if ident in mint else read(SOURCES/record['atlas_package_relative_path'])['frames']
        cal=calibrations[ident]
        cf=cal['frames'];cf={int(f['index']):f for f in cf} if isinstance(cf,list) else {int(k):v for k,v in cf.items()}
        frames=[]
        for i,f in enumerate(raw):
            c=cf[i];r=f['rect'];foot=c['foot'];height=c['body_height']
            assert 0<=foot[0]<=r[2] and 0<=foot[1]<=r[3]+1,(ident,i,r,foot)
            assert height>0,(ident,i)
            data={'index':i,'rect':r,'foot':foot,'body_height':height,'action':next(k for k,v in ACTION_MAP.items() if i in v),'pivot_confidence':c.get('confidence','manual_approximation'),'pivot_note':c.get('note','Visually selected shoe contact point; approximate source-pixel coordinates.')}
            if 'sheet' in f:data['sheet']=f['sheet']
            frames.append(data)
        catalog[ident]={'id':ident,'name':GROUP_NAMES[group]+' · '+OUTFIT_NAMES.get(outfit,outfit),'group':group,'sheet':'res://assets/costume_v04/'+source.name,'chroma_key':'magenta' if group in ('mint','aqua','cobalt') else 'blue','body_height':cal['body_height'],'target_body_height':112,'frames':frames,'action_map':ACTION_MAP,'source_sha256':record['source_sha256'],'body_metric':'Manual standing-equivalent body height per frame; posture and accessories excluded where visible.','pivot_method':'Manual visible shoe contact; two-foot midpoint for grounded stance, support-foot for raised foot.','calibration_document':'docs/costume_v04/calibration/'+('part-mint.json' if ident in mint else ('part-a.json' if group in ('aqua','crimson','lavender','cobalt','amethyst') else 'part-b.json'))}
    write(ASSETS/'catalog.json',catalog)
    image_paths=sorted({e['sheet'] for e in catalog.values()}|{f['sheet'] for e in catalog.values() for f in e['frames'] if 'sheet' in f})
    provenance={'images':[{'file':Path(s).name,'sha256':sha(ASSETS/Path(s).name)} for s in image_paths],'original_source_sheets_preserved':33,'new_attack_patch_strips':2,'generated_with':'built-in image_gen','raster_postprocessing':'none; chroma conversion occurs only in runtime memory','total_costumes':len(catalog),'total_frames':sum(len(e['frames']) for e in catalog.values())}
    write(DOCS/'PROVENANCE.json',provenance)
    print(json.dumps({'catalog':len(catalog),'frames':provenance['total_frames'],'referenced_pngs':len(image_paths)}))

if __name__=='__main__':
    import sys
    if '--sources-only' in sys.argv:
        inv,mint=prepare_sources();print(json.dumps(mint,indent=2))
    else:build()
