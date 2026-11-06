#!/usr/bin/env python3
"""Fresh immutable evidence for packet-input A01 integration verification."""
from pathlib import Path
import hashlib,json,shlex,subprocess,tempfile,shutil,sys,datetime
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    out=Path(tempfile.mkdtemp(prefix='run_',dir=BASE)); print('Evidence:',out,flush=True)
    protected={str(p.relative_to(ROOT)):sha(p) for directory in ('rtl','tb','docs') for p in sorted((ROOT/directory).rglob('*')) if p.is_file() and BASE not in p.parents}
    (out/'protected_before.json').write_text(json.dumps(protected,indent=2))
    (out/'rtl_before.sha256').write_text(''.join(f'{v}  {k}\n' for k,v in protected.items() if k.startswith('rtl/')))
    (out/'started.txt').write_text(datetime.datetime.now(datetime.timezone.utc).isoformat()+'\n')
    def command(args,label,limit=30):
        with (out/'commands.log').open('a') as f:f.write(shlex.join(map(str,args))+'\n')
        try:
            r=subprocess.run(args,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=limit);rc,data=r.returncode,r.stdout
        except subprocess.TimeoutExpired as e:rc,data=124,(e.stdout or b'')+b'\nTIMEOUT\n'
        (out/(label+'.log')).write_bytes(data)
        with (out/'exit_codes.jsonl').open('a') as f:f.write(json.dumps({'action':label,'exit':rc})+'\n')
        return rc,data.decode(errors='replace')
    for args,label in [(['iverilog','-V'],'iverilog_version'),(['vvp','-V'],'vvp_version'),(['git','status','--short'],'git_status_before'),(['git','rev-parse','HEAD'],'git_head')]:command(args,label)
    for p in (BASE/'tb_d02_a01.sv',Path(__file__).resolve()):shutil.copy2(p,out/p.name)
    (out/'test_sources.sha256').write_text(''.join(f'{sha(p)}  {p.relative_to(ROOT)}\n' for p in (BASE/'tb_d02_a01.sv',Path(__file__).resolve())))
    sources=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'rtl').rglob('*.sv'))]
    statuses=[]
    for label,top,bench,cases,marker in [
        ('a01','tb_d02_a01',BASE/'tb_d02_a01.sv',3,'PASS ALL D02 trace={t} events=3'),
        ('integration','tb_rv32i_core_top',ROOT/'tb/integration/tb_rv32i_core_top.sv',12,'PASS ALL TRACE_EN={t} tests=12')]:
        for t in (0,1):
            binary=out/f'{label}_trace{t}.vvp'
            rc,log=command(['iverilog','-g2012','-s',top,'-P',f'{top}.TRACE_EN={t}','-o',str(binary),str(bench.relative_to(ROOT)),*sources],f'compile_{label}_trace{t}')
            if rc==0:rc,log=command(['vvp',str(binary)],f'simulation_{label}_trace{t}')
            ok=rc==0 and marker.format(t=t) in log
            statuses.append({'test':label,'trace':t,'pass':ok,'cases':cases,'exit':rc})
            print(label,t,'PASS' if ok else 'FAIL','exit',rc,flush=True)
    after={k:sha(ROOT/k) if (ROOT/k).is_file() else 'MISSING' for k in protected}
    (out/'protected_after.json').write_text(json.dumps(after,indent=2))
    (out/'rtl_after.sha256').write_text(''.join(f'{v}  {k}\n' for k,v in after.items() if k.startswith('rtl/')))
    unchanged=protected==after
    (out/'integrity.json').write_text(json.dumps({'unchanged':unchanged,'protected_files':len(protected),'changed':[k for k in protected if protected[k]!=after[k]]},indent=2))
    command(['git','status','--short'],'git_status_after')
    ok=all(r['pass'] for r in statuses) and unchanged
    (out/'status.json').write_text(json.dumps({'pass':ok,'results':statuses,'integrity':unchanged,'exit':0 if ok else 1},indent=2))
    (out/'ARTIFACTS.sha256').write_text(''.join(f'{sha(p)}  {p.relative_to(out)}\n' for p in sorted(out.rglob('*')) if p.is_file() and p.name!='ARTIFACTS.sha256'))
    print('Overall:',ok,'protected unchanged:',unchanged,flush=True)
    return 0 if ok else 1
if __name__=='__main__':sys.exit(main())
