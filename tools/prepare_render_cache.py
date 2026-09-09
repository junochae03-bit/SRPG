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
    return entries

def prepared_bytes(path,key):
    with Image.open(path) as image: rgba=np.array(image.convert('RGBA'),copy=True)
    r,g,b=rgba[:,:,0],rgba[:,:,1],rgba[:,:,2]
    mask=((r<=63)&(g<=63)&(b>=166)) if key=='blue' else ((r>=166)&(b>=166)&(g<=89))
    rgba[:,:,3][mask]=0
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
    document={'schema_version':1,'algorithm':'strict byte chroma key; unchanged RGB; transparent right/bottom 1px padding; RGBA8 gzip','entries':entries}
    text=json.dumps(document,ensure_ascii=False,indent=2)+'\n'
    if check:assert MANIFEST.read_text('utf8')==text,'Stale render cache manifest'
    else:MANIFEST.write_text(text,'utf8')
    print(json.dumps({'status':'PASS','check':check,'sheets':len(entries),'bytes':total}),flush=True)
    return document

if __name__=='__main__':build('--check' in sys.argv)
