"""Build runtime metadata from reviewed V06 candidates; never writes image pixels."""
from pathlib import Path
import hashlib
import json
import argparse
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'docs/sprite_v06/expanded-catalog.json'
REVIEW = ROOT/'docs/qa/costume-expanded-v06-calibration.json'
OUTPUT = ROOT/'game/assets/costume_v06/runtime.json'
INSPECTION = ROOT/'docs/qa/costume-expanded-v06-candidates.json'
AUDIT = ROOT/'docs/qa/costume-expanded-v06-review.json'


def build(include_candidates=False):
    candidate = json.loads(SOURCE.read_text(encoding='utf-8'))
    reviews = json.loads(REVIEW.read_text(encoding='utf-8')) if REVIEW.exists() else {'entries': {}}
    result = {'schema': 1, 'candidate_catalog_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'body_pixels': 112, 'entries': {}, 'source_hashes': {}}
    images = {}
    for key, entry in candidate['entries'].items():
        review = reviews['entries'].get(key, {})
        approved_ids = set()
        if entry['class_matching'].get('runtime_role') != 'town_npc':
            for action in review.get('approved_actions',[]):
                sequence = entry['animation_sequences'][action]
                playback = review.get('idle_playback',[sequence[0]]) if action=='idle' else review.get('playback',{}).get(action,sequence)
                approved_ids.update(playback)
        frames = {}
        for f in entry['frames']:
            # A clean runtime checkout deliberately omits rejected/NPC sheets
            # and repair candidates. Only explicit inspection requires those.
            if not include_candidates and f['id'] not in approved_ids:
                continue
            suffix = '-attack-repair.png' if f['id'] >= 100 else '-32.png'
            path = ROOT/'game/assets/costume_v06'/(key+suffix)
            resource = 'res://assets/costume_v06/'+path.name
            if resource not in images:
                images[resource] = np.asarray(Image.open(path).convert('RGBA'))
                result['source_hashes'][resource] = hashlib.sha256(path.read_bytes()).hexdigest()
            image = images[resource]
            x, y, w, h = f['rect']
            assert min(x,y) >= 0 and x+w <= image.shape[1] and y+h <= image.shape[0], (key,f['id'],'bounds')
            crop = image[y:y+h,x:x+w]
            assert hashlib.sha256(crop.tobytes()).hexdigest() == f['crop_sha256'], (key,f['id'],'candidate pixels changed')
            foot = list(f['foot'])
            ground = None
            if f['action'] in ('idle','hurt'):
                r,g,b = crop[:,:,:3].transpose(2,0,1)
                mask = (crop[:,:,3]>0) & ~((g>=166)&(r<=89)&(b<=89))
                # Review-specific shoe window excludes held broom/umbrella and
                # tails. Only the lowest shoe band determines the support point.
                default_window={'cobalt-broom-maid':[.34,.66],'crimson-rose-gothic':[.4,.8]}.get(key,[.2,.9])
                low, high = review.get('shoe_window',default_window)
                left, right = int(w*low), int(w*high)
                mask[:int(h*.75)] = False
                mask[:,:left] = False; mask[:,right:] = False
                yy,xx = np.nonzero(mask)
                assert len(xx), (key,f['id'],'no support pixels')
                sole = int(yy.max())+1
                contacts = np.flatnonzero(mask[max(0,sole-8):sole].any(axis=0))
                foot = [float((contacts.min()+contacts.max()+1)/2),sole]
                ground = {'shoe_window':[left,right], 'contact_x_range':[int(contacts.min()),int(contacts.max())+1], 'sole_y':sole}
            frames[str(f['id'])] = {'pose_id':f['id'],'source_index':f['source_index'],'sheet':resource,
                'rect':f['rect'],'foot':foot,'body_height':float(review.get('body_height',f['body_height'])),
                'source_facing':float(review.get('source_facing',1)), 'action':f['action'],
                'crop_sha256':f['crop_sha256'], 'ground_measurement':ground}
        sequences = {}
        for action, ids in entry['animation_sequences'].items():
            if include_candidates:
                assert all(str(i) in frames for i in ids), (key,action,'excluded/missing pose')
            playback = review.get('playback',{}).get(action,ids)
            if action == 'idle': playback = review.get('idle_playback',[ids[0]])
            assert all(i in ids for i in playback), (key,action,'unapproved candidate reference')
            approved = action in review.get('approved_actions',[])
            if entry['class_matching'].get('runtime_role') == 'town_npc': approved = False
            if approved:
                assert all(str(i) in frames for i in playback), (key,action,'approved pose missing')
            reason = 'reviewed support, body scale and source direction' if approved else {
                'move':'unverified alternating stride and old/new loop continuity; retain V04 walk',
                'normal':'release socket/timing and complete anticipation-release-recovery not calibrated',
                'strong':'release socket/timing and planted or airborne support not calibrated',
                'dodge':'airborne support and old/new transition not calibrated',
                'hurt':'reaction support and interrupted-state transition not calibrated',
                'idle':'pending visual review of support, skull-to-sole size and direction',
            }[action]
            if not approved:
                reason = review.get('fallback_reasons',{}).get(action,reason)
                if entry['class_matching'].get('runtime_role') == 'town_npc':
                    reason = 'NPC-only appearance; player reader deliberately retains existing NPC route'
            sequences[action] = {'poses':playback if approved else ids,'candidate_poses':ids,'approved':approved,'reason':reason}
        result['entries'][key] = {'id':key,'name':entry['name'],'role':entry['class_matching']['runtime_role'],
            'allowed_base_classes':entry['class_matching'].get('allowed_base_classes',[]),
            'sequences':sequences,'frames':frames,'excluded':candidate['excluded'].get(key,[]),
            'idle_playback':review.get('idle_playback',[entry['animation_sequences']['idle'][0]]),
            'calibration':review.get('note','unreviewed; no expanded animation enabled')}
    return result


def runtime_only(candidate):
    result = {k:v for k,v in candidate.items() if k not in ('entries','source_hashes')}
    result['entries'] = {}
    sources = set()
    for key, entry in candidate['entries'].items():
        sequences = {action:{k:v for k,v in seq.items() if k!='candidate_poses'}
                     for action,seq in entry['sequences'].items() if seq['approved']}
        ids = {str(i) for seq in sequences.values() for i in seq['poses']}
        frames = {i:entry['frames'][i] for i in sorted(ids,key=int)}
        sources.update(f['sheet'] for f in frames.values())
        result['entries'][key] = {k:v for k,v in entry.items() if k not in ('frames','sequences','excluded')}
        result['entries'][key].update(frames=frames,sequences=sequences)
        if not sequences: result['entries'][key]['idle_playback'] = []
    result['source_hashes'] = {k:v for k,v in candidate['source_hashes'].items() if k in sources}
    return result


def save_or_check(path, data, check):
    if check:
        assert json.loads(path.read_text(encoding='utf-8'))==data, str(path)+' differs from reviewed sources'
    else:
        path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--review',action='store_true',help='Write inspection-only candidates under docs/qa; runtime stays approved-only')
    args=parser.parse_args()
    candidate=build(include_candidates=args.review)
    result=runtime_only(candidate)
    save_or_check(OUTPUT,result,args.check)
    # Human review/fallback records are not regenerated by a runtime build.
    if args.review: save_or_check(INSPECTION,candidate,args.check)
    approved=sum(s['approved'] for e in result['entries'].values() for s in e['sequences'].values())
    print('COSTUME_EXPANDED_METADATA_PASS entries=%d runtime_frames=%d approved_actions=%d source_images=%d'%(
        len(result['entries']),sum(len(e['frames']) for e in result['entries'].values()),approved,len(result['source_hashes'])))
