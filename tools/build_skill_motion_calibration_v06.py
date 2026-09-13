"""Record inspected head/sole landmarks without modifying sprite pixels."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/'game/assets/skill_motions_v06/catalog.json'
OUTPUT=ROOT/'game/assets/skill_motions_v06/calibration.json'
# Source-sheet coordinates, inspected against all sixteen poses in each sheet.
# crown x/y, approximate sole y, horizontal shoe-only search interval.
LANDMARKS={
    'warrior':(205,70,228,125,257),
    'ranger':(180,100,302,97,225),
    'mage':(165,83,315,97,214),
    'fighter':(166,39,311,83,245),
    'thief':(145,71,317,95,218),
    'tank':(185,35,246,103,227),
    'swordsman':(190,46,233,113,233),
    'runesword':(174,72,309,91,237),
    'summoner':(165,82,310,96,219),
    'elementalist':(165,82,311,112,215),
    'healer':(160,86,315,93,225),
    'sniper':(168,100,324,95,231),
    'hunter':(194,96,321,103,242),
    'explorer':(186,76,248,125,234),
    'reaper':(198,69,258,153,238),
    'gambler':(173,56,326,121,216),
    'infighter':(172,39,309,82,240),
    'breaker':(172,42,319,78,257),
    'martialist':(168,31,313,92,234),
}
OCCLUDED={'ranger','sniper','hunter','explorer'}


def build():
    source=json.loads(CATALOG.read_text(encoding='utf-8'))
    assert set(source['sprites'])==set(LANDMARKS)
    result={'schema_version':1,'body_pixels':112,
            'measurement_basis':'frame 0 head crown to shoe sole; excludes projecting ears, hat silhouette, weapons and tails',
            'limitations':'A head crown hidden by a hat is an anatomical estimate, not an observable pixel boundary. No per-pose density override is asserted from crouching alone.',
            'coordinate_space':'reference landmarks are source-sheet pixels; foot_local is relative to catalog frame rect',
            'catalog_sha256':hashlib.sha256(CATALOG.read_bytes()).hexdigest(),'sprites':{}}
    for key,entry in source['sprites'].items():
        path=ROOT/'game'/entry['sheet'].removeprefix('res://')
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest==entry['sha256'],(key,'source changed')
        pixels=np.asarray(Image.open(path).convert('RGBA'))
        x,crown_y,approx_sole,left,right=LANDMARKS[key]
        r,g,b=pixels[:,:,:3].transpose(2,0,1)
        mask=(pixels[:,:,3]>0)&~((g>=166)&(r<=89)&(b<=89))
        assert mask[crown_y,x],(key,'crown marker on background')
        rows,cols=np.nonzero(mask[approx_sole-12:approx_sole+2,left:right])
        assert len(cols),(key,'shoe support missing')
        sole=int(rows.max())+approx_sole-12+1
        contacts=np.flatnonzero(mask[sole-8:sole,left:right].any(axis=0))+left
        foot_x=float(contacts.min()+contacts.max()+1)/2
        rect=entry['frames'][0]['rect']
        assert rect[0]<=x<rect[0]+rect[2] and rect[1]<=crown_y<sole<=rect[1]+rect[3]
        height=sole-crown_y
        result['sprites'][key]={
            'sheet_sha256':digest,'body_height':height,'source_facing':1,
            'reference':{'index':0,'rect':rect,'crown_sheet':[x,crown_y],'sole_sheet_y':sole,
                         'shoe_contact_x_range':[int(contacts.min()),int(contacts.max())+1],
                         'foot_local':[foot_x-rect[0],sole-rect[1]],
                         'crown_status':'occluded_under_hat_estimate' if key in OCCLUDED else 'visible_hair_crown',
                         'crown_uncertainty_px':10 if key in OCCLUDED else 4},
            'density_review':{'inspected_pose_ids':list(range(16)),
                              'decision':'common source scale; preserve authored crouch, leaning, kicks and airborne compression; no confirmed density-only outlier'},
            'frame_overrides':{},
            'previous_height':entry['standing_height_estimate'],
            'scale_change':round(entry['standing_height_estimate']/height,4),
            'foot_status':'reference measurement only; full action foot trajectory not calibrated here'}
        if key=='thief':
            # Only the first row faces left; the forward dash in row 2 faces right.
            for index in range(4):
                result['sprites'][key]['frame_overrides'][str(index)]={
                    'source_facing':-1,
                    'reason':'Visually inspected row 0: face and dagger thrust point left; other rows retain their existing facing'}
        if key=='reaper':
            # Release pose 2 has a scythe below both boots. The generic lowest
            # foreground pivot anchors the blade and visibly levitates the feet.
            frame=entry['frames'][2]
            shoe_mask=mask[236:260,845:980]
            ys,xs=np.nonzero(shoe_mask)
            support_y=int(ys.max())+237
            contact=np.flatnonzero(mask[support_y-8:support_y,845:980].any(axis=0))+845
            support_x=float(contact.min()+contact.max()+1)/2
            result['sprites'][key]['frame_overrides']['2']={
                'foot':[support_x-frame['rect'][0],support_y-frame['rect'][1]],
                'reason':'GPU-confirmed scythe-tip pivot; replace with both visible boot soles',
                'measurement':{'shoe_window_sheet':[845,236,135,24],
                               'sole_sheet_y':support_y,'contact_x_range':[int(contact.min()),int(contact.max())+1]}}
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    data=build()
    if args.check:
        assert json.loads(OUTPUT.read_text(encoding='utf-8'))==data,'Calibration differs from inspected landmarks/source hashes'
    else:
        OUTPUT.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('SKILL_MOTION_CALIBRATION_PASS sprites=19 source_poses=304 hat_occluded_crowns=4')
    for key,value in data['sprites'].items():
        print(key,value['previous_height'],'->',value['body_height'],'scale',value['scale_change'])
