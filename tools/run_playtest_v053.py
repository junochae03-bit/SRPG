"""Observe normal gameplay in the actual client, with fresh isolated saves.

No level, inventory, position, enemy or currency overrides are accepted.
Artifacts distinguish startup, screenshots, gameplay, focus and final samples.
"""
import argparse,ctypes,hashlib,json,subprocess,time
from pathlib import Path
from engine_path import ROOT,engine,hidden_options

class Memory(ctypes.Structure):
    _fields_=[('cb',ctypes.c_ulong),('faults',ctypes.c_ulong)]+[(name,ctypes.c_size_t) for name in ['peak_working','working','peak_paged','paged','peak_nonpaged','nonpaged','pagefile','peak_pagefile','private']]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--seconds',type=int,default=1800)
    p.add_argument('--class-id',choices=['warrior','ranger','mage'],default='warrior')
    p.add_argument('--exe',type=Path)
    p.add_argument('--vsync',choices=['on','off'],default='on')
    args=p.parse_args()
    assert 10<=args.seconds<=7200
    run=ROOT/'artifacts/playtest-v053'/(args.class_id+'-'+time.strftime('%Y%m%d-%H%M%S'))
    run.mkdir(parents=True,exist_ok=False)
    exe=args.exe.resolve() if args.exe else Path(engine()).with_name(Path(engine()).name.replace('_console',''))
    assert exe.is_file()
    files=[exe]+([exe.with_suffix('.pck')] if args.exe else [])
    hashes={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    command=[str(exe)]
    if not args.exe:command+=['--path',str(ROOT/'game')]
    command+=['--log-file',str(run/'engine.log'),'--','--playtest','--mute','--observation-output='+str(run),'--observation-seconds='+str(args.seconds),'--observation-class='+args.class_id,'--observation-vsync='+args.vsync]
    (run/'runner.json').write_text(json.dumps({'command':command,'mode':'exported_executable' if args.exe else 'source_gui_engine','sha256':hashes,'clock_anchor':{'unix_ns':time.time_ns(),'monotonic_ns':time.monotonic_ns()}},ensure_ascii=False,indent=2),encoding='utf8')
    started=time.monotonic();memory_times=[];memory_errors=[]
    with (run/'console.log').open('w',encoding='utf8') as log,(run/'process-memory.jsonl').open('w',encoding='utf8') as memory,(run/'collector-timing.jsonl').open('w',encoding='utf8') as trace:
        child=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,**hidden_options())
        print('PLAYTEST_START',json.dumps({'pid':child.pid,'output':str(run),'seconds':args.seconds,'mode':'EXE' if args.exe else 'source'}),flush=True)
        read_memory=ctypes.WinDLL('psapi').GetProcessMemoryInfo
        read_memory.argtypes=[ctypes.c_void_p,ctypes.POINTER(Memory),ctypes.c_ulong]
        while child.poll() is None:
            before_sleep=time.monotonic();cpu_before=time.process_time()
            time.sleep(5)
            after_sleep=time.monotonic()
            if child.poll() is not None:break
            sample=Memory();sample.cb=ctypes.sizeof(sample)
            if read_memory(int(child._handle),ctypes.byref(sample),sample.cb):
                at=time.monotonic()-started;memory_times.append(at)
                memory.write(json.dumps({'at_s':at,'working':sample.working,'private':sample.private})+'\n');memory.flush()
            else:memory_errors.append(time.monotonic()-started)
            after_memory=time.monotonic()
            content=(run/'engine.log').read_text(encoding='utf8',errors='replace') if (run/'engine.log').exists() else ''
            after_log=time.monotonic()
            trace.write(json.dumps({'at_s':after_log-started,'unix_ns':time.time_ns(),'sleep_s':after_sleep-before_sleep,'memory_s':after_memory-after_sleep,'log_read_s':after_log-after_memory,'collector_cpu_s':time.process_time()-cpu_before})+'\n');trace.flush()
            if any(t in content for t in ['SCRIPT ERROR:','Parse Error:']) or time.monotonic()-started>args.seconds+90:
                child.terminate();break
            if time.monotonic()-started>45 and not (run/'events.jsonl').exists():
                child.terminate();break
        code=child.wait()
    ended=time.monotonic()-started
    memory_report={'samples':len(memory_times),'failed_at_s':memory_errors,'first_at_s':memory_times[0] if memory_times else None,'last_at_s':memory_times[-1] if memory_times else None,'process_end_at_s':ended,'tail_gap_s':ended-memory_times[-1] if memory_times else None,'max_gap_s':max([b-a for a,b in zip(memory_times,memory_times[1:])],default=0)}
    (run/'memory-collection.json').write_text(json.dumps(memory_report,indent=2),encoding='utf8')
    content=(run/'console.log').read_text(encoding='utf8',errors='replace')+(run/'engine.log').read_text(encoding='utf8',errors='replace')
    assert code==0 and 'ERROR:' not in content,content[-6000:]
    assert hashes=={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in files},'Client changed during observation'
    events=[json.loads(line) for line in (run/'events.jsonl').read_text(encoding='utf8').splitlines()]
    final=next((row for row in reversed(events) if row['kind']=='finish'),None)
    assert final is not None and final['elapsed_s']>=args.seconds-.1,('Incomplete actual duration',final)
    assert memory_times and not memory_errors and memory_report['max_gap_s']<15,('Incomplete memory collection',memory_report)
    assert memory_times[0]<=15 and memory_report['tail_gap_s']<15,('Memory start/end gap',memory_report)
    assert memory_times[-1]>=args.seconds-10,('Memory collection ended early',memory_report)
    (run/'result.json').write_text(json.dumps({'status':'PASS','mode':'exported_executable' if args.exe else 'source_gui_engine','exit_code':code,'same_exe_and_pck':True,'memory_collection':'PASS','requested_seconds':args.seconds,'actual_driver_seconds':final['elapsed_s'],'process_end_at_s':ended,'sha256':hashes},ensure_ascii=False,indent=2),encoding='utf8')
    print('PLAYTEST_FINISH',json.dumps(final,ensure_ascii=False),str(run),flush=True)

if __name__=='__main__':main()
