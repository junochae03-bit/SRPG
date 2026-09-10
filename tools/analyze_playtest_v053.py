"""Report measured gameplay; never turn short runs or fixtures into soak passes."""
import argparse,bisect,hashlib,json,statistics
from pathlib import Path

def rows(path):
    return [json.loads(line) for line in path.read_text(encoding='utf8').splitlines() if line.strip()]

def distribution(values):
    values=sorted(values)
    def at(p):
        if not values:return None
        i=(len(values)-1)*p;lo=int(i);hi=min(lo+1,len(values)-1)
        return round(values[lo]+(values[hi]-values[lo])*(i-lo),3)
    return {'frames':len(values),'p50_ms':at(.5),'p95_ms':at(.95),'p99_ms':at(.99),'max_ms':round(max(values),3) if values else None}

def analyze(root):
    events=rows(root/'events.jsonl');samples=rows(root/'samples.jsonl')
    runner=json.loads((root/'runner.json').read_text(encoding='utf8'))
    result=json.loads((root/'result.json').read_text(encoding='utf8')) if (root/'result.json').exists() else {}
    collection=json.loads((root/'memory-collection.json').read_text(encoding='utf8')) if (root/'memory-collection.json').exists() else {}
    memory=rows(root/'process-memory.jsonl')
    end=next((row for row in reversed(events) if row['kind']=='finish'),None)
    duration=end['elapsed_s'] if end else 0
    config=next((r for r in events if r['kind']=='configuration'),{})
    transitions=[r for r in events if r['kind']=='frame_state']
    transition_times=[r['at_s'] for r in transitions]
    marks=[r for r in events if r['kind'] in ['map','menu','capture_begin','capture_end']]
    mark_times=[r['at_s'] for r in marks]
    captures=[];opened={}
    for row in marks:
        if row['kind']=='capture_begin':opened[row['name']]=row['at_s']
        elif row['kind']=='capture_end' and row['name'] in opened:captures.append((opened.pop(row['name']),row['at_s']))
    captures.extend((start,duration) for start in opened.values())
    all_frames=[];stable=[];mixed=[];stalls=[];previous_end=0.
    for sample in samples:
        frame_values=sample['frames_ms'];at=sample['at_s']
        all_frames.extend(frame_values)
        changes=transitions[bisect.bisect_right(transition_times,previous_end):bisect.bisect_right(transition_times,at)]
        related=marks[bisect.bisect_left(mark_times,previous_end-.5):bisect.bisect_right(mark_times,at+.5)]
        i=bisect.bisect_right(transition_times,previous_end)-1
        state=transitions[i] if i>=0 else {}
        # Only whole stable windows qualify. View/focus is not inferred from the final sample.
        capturing=any(start<=at and stop>=previous_end for start,stop in captures)
        if previous_end>=30 and state.get('view')=='gameplay' and state.get('focused') and not changes and not related and not capturing:
            stable.extend(frame_values)
        else:mixed.extend(frame_values)
        cursor=at
        for ms in reversed(frame_values):
            if ms>=100:
                near=marks[bisect.bisect_left(mark_times,cursor-1.):bisect.bisect_right(mark_times,cursor+.25)]
                kinds=sorted({r['kind'] for r in near})
                stalls.append({'at_s':round(cursor,3),'ms':ms,'nearby_events':kinds or (['startup'] if cursor<30 else ['unexplained'])})
            cursor-=ms/1000.
        previous_end=at
    # All memory windows use runner time. Keep shutdown out of the tail median.
    memory_end=collection.get('process_end_at_s',0)
    warm=[r for r in memory if 600<=r['at_s']<1200]
    tail=[r for r in memory if max(1200,memory_end-600)<=r['at_s']<=memory_end-15]
    memory_result={'clock':'runner seconds; windows relative to process end, not exact gameplay end','excludes':'last 15 seconds before observed process end','warm_samples':len(warm),'tail_samples':len(tail),'collection':collection}
    for key in ['working','private']:
        first=statistics.median(r[key] for r in warm) if warm else None
        last=statistics.median(r[key] for r in tail) if tail else None
        memory_result[key]={'warm_median_bytes':first,'tail_median_bytes':last,'growth_percent':round((last/first-1)*100,3) if first and last else None}
    actions={}
    for row in events:
        if row['kind']=='action':actions[row['action']]=actions.get(row['action'],0)+1
    model=distribution(stable)
    ordered=all(b['at_s']>a['at_s'] for a,b in zip(samples,samples[1:]))
    covered_seconds=sum(all_frames)/1000.
    coverage=ordered and abs(covered_seconds-duration)<1. and all(ms>0 for ms in all_frames)
    runner_ok=result.get('status')=='PASS' and result.get('exit_code')==0 and result.get('same_exe_and_pck') and result.get('sha256')==runner.get('sha256') and result.get('memory_collection')=='PASS'
    complete=bool(runner_ok and coverage and duration>=3599.9 and runner['mode']=='exported_executable')
    growth=memory_result['private']['growth_percent']
    report={'mode':runner['mode'],'configuration':config,'completed_elapsed_s':duration,'milestones':end.get('milestones',{}) if end else {},'frame_intervals':{'all':distribution(all_frames),'stable_focused_gameplay_windows':model,'mixed_or_startup':distribution(mixed)},'stalls_100ms':sorted(stalls,key=lambda r:r['at_s']),'memory':memory_result,'successful_actions':actions,'scope':['Automated normal-action gameplay, not human usability or win rate.','Frame end times reconstructed from sample end and frame intervals, with millisecond quantization.','Nearby events classify correlation, not proven stall causes.','method_ms.collector_prefix/process is instrumentation overhead, never main CPU time.'],'sixty_minute_gate':{'actual_exported_60_minutes':complete,'frame_target':bool(model['frames'] and model['p95_ms']<=20 and model['p99_ms']<=33.4),'memory_target':growth is not None and growth<=10,'unexplained_stalls':sum(r['nearby_events']==['unexplained'] for r in stalls)},'evidence_sha256':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ['runner.json','events.jsonl','samples.jsonl','process-memory.jsonl']}}
    report['coverage']={'runner_success':bool(runner_ok),'ordered_samples':ordered,'recorded_frame_seconds':covered_seconds,'duration_match':coverage,'stable_gameplay_seconds':sum(stable)/1000.}
    enough=complete and sum(stable)/1000.>=1800
    report['sixty_minute_gate']['frame_target']=report['sixty_minute_gate']['frame_target'] if enough else None
    report['sixty_minute_gate']['memory_target']=report['sixty_minute_gate']['memory_target'] if complete and len(warm)>=100 and len(tail)>=100 else None
    report['sixty_minute_gate']['stable_observation_sufficient']=enough
    if (root/'result.json').exists():report['evidence_sha256']['result.json']=hashlib.sha256((root/'result.json').read_bytes()).hexdigest()
    if (root/'memory-collection.json').exists():report['evidence_sha256']['memory-collection.json']=hashlib.sha256((root/'memory-collection.json').read_bytes()).hexdigest()
    (root/'analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path)
    report=analyze(parser.parse_args().directory)
    print(json.dumps({key:report[key] for key in ['mode','completed_elapsed_s','frame_intervals','memory','sixty_minute_gate']},ensure_ascii=False,indent=2))
