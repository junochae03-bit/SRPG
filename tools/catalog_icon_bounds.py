"""Record atlas crop coordinates from original pixels; never modifies PNGs."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'game/assets/icons/semantic_catalog.json'
catalog=json.loads(path.read_text('utf-8-sig'))
def runs(counts,threshold):
    indices=np.where(counts>threshold)[0]
    groups=np.split(indices,np.where(np.diff(indices)>1)[0]+1)
    return [(int(g[0]),int(g[-1])+1) for g in groups if len(g)>40]
for sheet in catalog['sheets']:
    sheet['path']='res://assets/icons/wood-'+sheet['name']+'.png'
    with Image.open(ROOT/'game/assets/icons'/('wood-'+sheet['name']+'.png')) as image:
        pixels=np.asarray(image.convert('RGB'))
    dark=(pixels[:,:,0]<205)&(pixels[:,:,1]<170)&(pixels[:,:,2]<145)
    yr=runs(dark.sum(axis=1),200)
    xr=runs(dark.sum(axis=0),100)
    assert len(yr)==4 and len(xr)==6,(sheet['name'],xr,yr)
    frames=[]
    for y0,y1 in yr:
        for x0,x1 in xr:
            ys,xs=np.where(dark[y0:y1,x0:x1])
            left,right=x0+int(xs.min()),x0+int(xs.max())+1
            top,bottom=y0+int(ys.min()),y0+int(ys.max())+1
            x=left-4; y=top-4; width=right-left+8; height=bottom-top+8
            assert x>=0 and y>=0 and x+width<=1536 and y+height<=1024
            frames.append([x,y,width,height])
    sheet['frames']=frames
    print(sheet['name'], 'rows',yr,'columns',xr,'sides',min(r[2] for r in frames),max(r[2] for r in frames))
catalog['background']='Magenta RGB chroma key removed by existing gat_chroma shader. Original generated pixels preserved; atlas cropping only.'
path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n','utf-8')
