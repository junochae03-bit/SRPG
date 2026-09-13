"""Prepare lossless padded RGBA render data; preserve all authored source files.

The byte thresholds match the existing costume/equipment readers exactly. This
is a build cache, not new artwork. Runtime native gzip decoding replaces millions
of GDScript byte operations each time the client first displays a source sheet.
"""
from pathlib import Path
import gzip,hashlib,json,sys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'game'
OUT=GAME/'assets/render_cache_v05'
MANIFEST=OUT/'catalog.json'

def sources():
    entries={}
    costumes=json.loads((GAME/'assets/costume_v04/catalog.json').read_text('utf8'))
    for item in costumes.values():
        entries[item['sheet']+'|'+item['chroma_key']]=(item['sheet'],item['chroma_key'])
        for frame in item['frames']:
            path=frame.get('sheet',item['sheet']);key=frame.get('chroma_key',item['chroma_key'])
            entries[path+'|'+key]=(path,key)
    equipment=json.loads((GAME/'assets/equipment/items.json').read_text('utf8'))
    for item in equipment['items'].values():entries[item['sheet']+'|magenta']=(item['sheet'],'magenta')
    motions=json.loads((GAME/"assets/skill_motions_v06/catalog.json").read_text("utf8"))
    for item in motions["sprites"].values():
        entries[item["sheet"]+"|green"]=(item["sheet"],"green")
    costumes_v06=json.loads((GAME/"assets/costume_v06/runtime.json").read_text("utf8"))
    for item in costumes_v06["entries"].values():
        for frame in item["frames"].values():
            path=frame["sheet"]
            entries[path+"|green"]=(path,"green")
    monsters=json.loads((GAME/"assets/monster_motions_v06/catalog.json").read_text("utf8"))
    for path in monsters["sheets"]:
        entries[path+"|magenta_narrow"]=(path,"magenta_narrow")
    objects=json.loads((GAME/"assets/exploration_objects_v06/catalog.json").read_text("utf8"))
    for path in objects["sheets"]:
        entries[path+"|magenta_narrow"]=(path,"magenta_narrow")
    ecology=json.loads((GAME/"assets/monster_ecology_v071/catalog.json").read_text("utf8"))
    for row in ecology["species"].values():
        path=row["sheet"];entries[path+"|magenta_narrow"]=(path,"magenta_narrow")
    return entries

def prepared_bytes(path,key):
    with Image.open(path) as image: rgba=np.array(image.convert('RGBA'),copy=True)
    r,g,b=rgba[:,:,0],rgba[:,:,1],rgba[:,:,2]
    mask=((r<=63)&(g<=63)&(b>=166)) if key=='blue' else ((r>=166)&(b>=166)&(g<=89))
    if key=="green":mask=(g>=166)&(r<=89)&(b<=89)
    if key=="magenta_narrow":
        distance=np.maximum(np.maximum(255-r,g),255-b).astype(np.float64)
        t=np.clip((distance-38.25)/12.75,0,1)
        rgba[:,:,3]=np.floor(rgba[:,:,3]*t*t*(3-2*t)+.5).astype(np.uint8)
    else:rgba[:,:,3][mask]=0
    if key=="green":
        # Only unmix an outline pixel touching removed background. Mint hair
        # and green clothes inside the silhouette are not globally desaturated.
        clear=rgba[:,:,3]==0
        edge=np.zeros(clear.shape,dtype=bool)
        edge[1:]|=clear[:-1];edge[:-1]|=clear[1:]
        edge[:,1:]|=clear[:,:-1];edge[:,:-1]|=clear[:,1:]
        rgb=rgba[:,:,:3].astype(np.float64)
        mix=np.clip((rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2]))/255.,0,.85)*edge
        coverage=1-mix
        rgb[:,:,1]-=255*mix
        rgba[:,:,:3]=np.floor(np.clip(rgb/coverage[:,:,None],0,255)+.5).astype(np.uint8)
        rgba[:,:,3]=np.floor(rgba[:,:,3]*coverage+.5).astype(np.uint8)
    h,w=rgba.shape[:2]
    padded=np.zeros((h+1,w+1,4),dtype=np.uint8)
    # Godot Color.TRANSPARENT is transparent white; match padding RGB as well.
    padded[:,:,:3]=255;padded[:h,:w]=rgba
    return padded.tobytes(),w+1,h+1

def build(check=False):
    entries={};total=0
    if not check:OUT.mkdir(parents=True,exist_ok=True)
    for identity,(source,key) in sorted(sources().items()):
        source_file=GAME/source.removeprefix('res://')
        raw,w,h=prepared_bytes(source_file,key)
        packed=gzip.compress(raw,compresslevel=6,mtime=0)
        name=source_file.stem+'-'+key+'.rgba.gz'
        path=OUT/name
        row={'source':source,'key':key,'path':'res://assets/render_cache_v05/'+name,'width':w,'height':h,'source_sha256':hashlib.sha256(source_file.read_bytes()).hexdigest(),'sha256':hashlib.sha256(packed).hexdigest(),'rgba_sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(packed),'rgba_bytes':len(raw)}
        if check:assert path.is_file() and path.read_bytes()==packed,('Stale render cache',name)
        else:path.write_bytes(packed)
        entries[identity]=row;total+=len(packed)
    document={'schema_version':1,'algorithm':'strict blue/magenta/green key; narrow magenta alpha; green boundary despill; original sources preserved; transparent right/bottom 1px padding; RGBA8 gzip','entries':entries}
    text=json.dumps(document,ensure_ascii=False,indent=2)+'\n'
    if check:assert MANIFEST.read_text('utf8')==text,'Stale render cache manifest'
    else:MANIFEST.write_text(text,'utf8')
    if not check:
        expected={Path(row["path"]).name for row in entries.values()}
        for stale in OUT.glob("*.rgba.gz"):
            assert stale.resolve().parent==OUT.resolve()
            if stale.name not in expected:stale.unlink()
    print(json.dumps({'status':'PASS','check':check,'sheets':len(entries),'bytes':total}),flush=True)
    return document

if __name__=='__main__':build('--check' in sys.argv)
