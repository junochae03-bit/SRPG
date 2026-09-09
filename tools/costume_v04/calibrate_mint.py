"""Manual source-sheet shoe landmarks, not bounding-box foot guesses."""
import json
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[2]
DOCS=PROJECT/'docs/costume_v04'
CALIBRATION=DOCS/'calibration'
regions=json.loads((CALIBRATION/'mint-regions.json').read_text(encoding='utf-8'))
# Coordinates on the actual selected PNG. The repair frames use their own 1774x887 sheet.
landmarks={
 'mint-summer':[(164,303),(481,305),(793,303),(1112,303),(177,615),(477,615),(386,662),(1354,663),(91,908),(484,923),(743,913),(1059,914),(103,1195),(479,1209),(796,1213),(1101,1225)],
 'mint-silver-knight':[(184,302),(504,302),(806,302),(1120,302),(180,597),(510,597),(349,679),(1365,681),(202,915),(485,923),(779,909),(1079,910),(146,1202),(458,1207),(808,1218),(1110,1223)],
}
heights={
 'mint-summer':[240,240,240,240,235,235,430,430,235,235,235,235,235,235,235,235],
 'mint-silver-knight':[255,255,255,255,245,245,440,440,245,245,245,245,245,245,245,245],
}
result={}
for ident,points in landmarks.items():
    frames=[]
    for i,((px,py),f) in enumerate(zip(points,regions[ident])):
        x,y,w,h=f['rect'];foot=[px-x,py-y]
        assert 0<=foot[0]<=w and 0<=foot[1]<=h,(ident,i,foot,f)
        note='Manual visible shoe midpoint at ground-contact level; accessories, sword and cape excluded.'
        confidence='medium'
        if i in (8,12,13):
            note='Manual planted shoe/support-foot estimate in crouched or airborne pose; hand, sword and trailing effect excluded. Standing-equivalent body height retained.'
            confidence='medium-low'
        if i in (6,7):
            note='Manual midpoint of silver boots/sandals in imagegen replacement strip, independently scaled to original character standing size.'
        frames.append({'index':i,'foot':foot,'body_height':heights[ident][i],'confidence':confidence,'note':note,'source_contact':list(points[i]),'source_rect':f['rect'],'estimated_contact_uncertainty_source_px':6 if i not in (6,7) else 10})
    result[ident]={'body_height':235 if ident=='mint-summer' else 245,'method':'Visible shoe contacts manually read on original sheets and the two imagegen repair strips. Coordinates approximate, source PNGs unchanged. Per-frame height is standing-equivalent, not pose bounding height.','frames':frames}
(CALIBRATION/'part-mint.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('2 costumes / 32 manual shoe pivots / all source bounds valid')
