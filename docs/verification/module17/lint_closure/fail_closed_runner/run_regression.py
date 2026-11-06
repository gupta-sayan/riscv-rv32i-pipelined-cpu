from pathlib import Path
import json,subprocess,hashlib,datetime,re,tempfile
ROOT=Path.cwd();O=ROOT/'docs/verification/module17/lint_closure/fail_closed_runner';BASE=ROOT/'docs/verification/module17/final_campaign'
parent=O/'regression_runs';parent.mkdir(exist_ok=True);E=Path(tempfile.mkdtemp(prefix='run_',dir=parent))
text=(BASE/'scripts/f06.py').read_text().split('for item in items:')[0].replace('from common import *','').replace('out=begin(6);','')
exec(text)
results=[]
def command(a,d,label):
 d.mkdir(parents=True,exist_ok=True);start=datetime.datetime.now(datetime.timezone.utc).isoformat()
 try:r=subprocess.run(list(map(str,a)),cwd=ROOT,capture_output=True,timeout=60);rc=r.returncode;data=r.stdout+r.stderr
 except subprocess.TimeoutExpired as e:rc=124;data=(e.stdout or b'')+b'\nTIMEOUT'
 (d/(label+'.log')).write_bytes(data)
 with (E/'commands.jsonl').open('a') as f:f.write(json.dumps(dict(argv=list(map(str,a)),cwd=str(ROOT),start=start,exit=rc,log=str(d/(label+'.log'))))+'\n')
 return rc,data.decode(errors='replace')
rtl=sorted(ROOT.glob('rtl/**/*.sv'))
for item in items:
 t=item['trace'];d=E/'simulations'/(item['label']+f'_trace{t}');d.mkdir(parents=True,exist_ok=True)
 paths=[Path(p) if Path(p).is_absolute() else ROOT/p for p in [item['bench']]+item['extra']]
 (d/'sources.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths+rtl},indent=2))
 a=['iverilog','-g2012','-gassertions','-s',item['top'],'-P',f"{item['top']}.TRACE_EN={t}"]
 for p in item['params']:a+=['-P',item['top']+'.'+p]
 cr,log=command(a+['-o',d/'sim.vvp']+paths+rtl,d,'compile');rc=cr
 if cr==0:rc,log=command(['vvp',d/'sim.vvp'],d,'simulation')
 ok=cr==0 and rc==item['expected'] and item['marker'].format(t=t) in log
 if item['label']=='D01':ok=ok and f'D01_CONFIG TRACE_EN={t}' in log
 results.append(dict(**item,compile_exit=cr,simulation_exit=rc,pass_=ok));(E/'results.json').write_text(json.dumps(results,indent=2))
 print(item['label'],t,ok,flush=True)

print('REGRESSION EVIDENCE',E,flush=True)
