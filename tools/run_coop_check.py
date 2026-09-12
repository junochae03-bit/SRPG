"""Six independent ENet processes with isolated personal saves, no external server."""
import subprocess,time,sys,socket
from pathlib import Path
from engine_path import ROOT,engine,hidden_options
run=ROOT/'runtime'/('coop-check-'+str(time.time_ns()));run.mkdir(parents=True)
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
processes=[];logs=[]
closing_race='--closing-race' in sys.argv
try:
    for i in range(3 if closing_race else 7):
        if (closing_race and i==2) or (not closing_race and i==6):
            deadline=time.monotonic()+25
            while time.monotonic()<deadline:
                if ('HOST_CLOSING' if closing_race else 'SIX_READY') in (run/'0'/'run.log').read_text('utf8'):break
                if processes[0].poll() is not None:raise RuntimeError((run/'0'/'run.log').read_text('utf8'))
                time.sleep(.1)
            else:raise RuntimeError('Six players never became ready for the capacity probe')
        folder=run/str(i);folder.mkdir();log=(folder/'run.log').open('w',encoding='utf8');logs.append(log)
        role='host' if i==0 else 'late' if closing_race and i==2 else 'overflow' if i==6 else 'guest'
        script='coop_exit_race' if closing_race else 'coop_network'
        command=[engine(),'--headless','--path',str(ROOT/'game'),'--script','res://tests/'+script+'.gd','--','--role='+role,'--directory='+str(folder),'--port='+str(port)]
        if '--host-exit' in sys.argv:command+=['--exit-mode=host']
        if '--visual' in sys.argv and i<6:
            command.remove('--headless');command+=['--visual=true']
        processes.append(subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,**hidden_options()))
        if i==0:
            deadline=time.monotonic()+15
            while time.monotonic()<deadline:
                if 'HOST_READY' in (folder/'run.log').read_text('utf8'):break
                if processes[0].poll() is not None:raise RuntimeError((folder/'run.log').read_text('utf8'))
                time.sleep(.1)
    for process in processes:process.wait(timeout=45)
    for log in logs:log.flush()
    failures=[]
    for i,process in enumerate(processes):
        output=(run/str(i)/'run.log').read_text('utf8')
        if process.returncode or 'failures=0' not in output or any(token in output for token in ['SCRIPT ERROR','ERROR:','WARNING:']):failures.append((i,output[-5000:]))
    for entry in failures:print(entry)
    print('COOP_CLOSING_RACE' if closing_race else 'COOP_SIX_PROCESS', 'PASS' if not failures else 'FAIL',run)
    sys.exit(bool(failures))
finally:
    for process in processes:
        if process.poll() is None:process.kill();process.wait()
    for log in logs:log.close()
