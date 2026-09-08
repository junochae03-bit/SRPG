from pathlib import Path
import subprocess,sys
from engine_path import engine,hidden_options
ROOT=Path(__file__).resolve().parents[1]
script=sys.argv[1]
args=[engine(),'--path',str(ROOT/'game'),'--script','res://tests/'+script+'.gd']
if len(sys.argv)<3:args.insert(1,'--headless')
result=subprocess.run(args,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=60,**hidden_options())
(ROOT/'runtime').mkdir(exist_ok=True)
log=ROOT/'runtime'/('check-'+script+'.log');log.write_text(result.stdout+result.stderr,'utf8')
print(result.stdout[-2400:]);print(result.stderr[-2400:]);print('EXIT',result.returncode,'LOG',log)
sys.exit(result.returncode or int('ERROR:' in result.stderr or 'SCRIPT ERROR' in result.stdout))
