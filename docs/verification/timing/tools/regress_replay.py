# Out-of-tree replay of f06's item list: same benches, args and pass markers; writes only to /tmp.
import json, subprocess, sys, tempfile
from pathlib import Path
ROOT = Path(sys.argv[1]).resolve()
BASE = ROOT/'docs/verification/module17/final_campaign'
RTL = sorted(str(p) for p in (ROOT/'rtl').rglob('*.sv'))
items = []
def add(label, top, bench, cases, marker, extra=(), params=(), expected=0):
    for t in (0, 1):
        items.append(dict(label=label, top=top, bench=bench, cases=cases, marker=marker,
                          extra=list(extra), params=list(params), trace=t, expected=expected))
add('integration','tb_rv32i_core_top','tb/integration/tb_rv32i_core_top.sv',12,'PASS ALL TRACE_EN={t} tests=12')
for n in range(1, 28):
    cp = ROOT/f'docs/verification/module17/full_campaign/tests/v{n:02}/cases.json'
    c = len(json.loads(cp.read_text()))
    add(f'V{n:02}','tb_campaign',str(cp.with_name('tb_campaign.sv')),c,f'PASS ALL V{n:02} trace={{t}} cases={c}')
add('V15_a01','tb_a01','docs/verification/module17/full_campaign/tests/v15/tb_a01.sv',1,'PASS ALL A01 vectors=8 trace={t}')
add('V23_reset','tb_reset','docs/verification/module17/full_campaign/tests/v23/tb_reset.sv',5,'PASS ALL RESET cases=5 trace={t}')
add('V23_fetch','tb_accepted_fetch_reset','docs/verification/module17/full_campaign/tests/v23/tb_accepted_fetch_reset.sv',1,'PASS ALL IV01 trace={t}')
add('D01','checked_d01',str(BASE/'tests/checked_d01.sv'),1,'PASS ALL D01 selectors=4 checks=8',extra=['docs/verification/module17/d01/tb_d01.sv'])
add('D02','tb_d02_a01','docs/verification/module17/d02_a01/tb_d02_a01.sv',3,'PASS ALL D02 trace={t} events=3')
for lab, old, cc, mk in [('legal','tb/integration/tb_rv32i_core_top.sv',12,'PASS ALL TRACE_EN={t} tests=12'),
                         ('injected','docs/verification/module17/d02_a01/tb_d02_a01.sv',3,'PASS ALL D02 trace={t} events=3')]:
    add('F02_'+lab,'checked_'+lab,str(BASE/f'tests/checked_{lab}.sv'),cc,mk,extra=[str(BASE/'tests/cpu_checker.sv'),old],params=['MUTATION=0'])
for m, pid in {1:1,2:4,3:19,4:8,5:9}.items():
    add(f'F02_neg{m}','checked_legal',str(BASE/'tests/checked_legal.sv'),1,f'CHECKER_FAIL P{pid} ',
        extra=[str(BASE/'tests/cpu_checker.sv'),'tb/integration/tb_rv32i_core_top.sv'],params=[f'MUTATION={m}'],expected=1)
out = Path(tempfile.mkdtemp(prefix='regress-'))
pos = posok = neg = negok = 0; fails = []
for it in items:
    t = it['trace']; b = out/f"{it['label']}_t{t}.vvp"
    paths = [str(p if Path(p).is_absolute() else ROOT/p) for p in [it['bench'], *it['extra']]]
    args = ['iverilog','-g2012','-gassertions','-s',it['top'],'-P',f"{it['top']}.TRACE_EN={t}"]
    for p in it['params']: args += ['-P', it['top']+'.'+p]
    c = subprocess.run([*args,'-o',str(b),*paths,*RTL],capture_output=True,text=True,cwd=ROOT)
    rc, log = c.returncode, ''
    if rc == 0:
        s = subprocess.run(['vvp',str(b)],capture_output=True,text=True,cwd=ROOT,timeout=120)
        rc, log = s.returncode, s.stdout+s.stderr
    ok = c.returncode == 0 and rc == it['expected'] and it['marker'].format(t=t) in log
    if it['label']=='D01': ok = ok and f'D01_CONFIG TRACE_EN={t}' in log
    if it['expected']: neg += 1; negok += ok
    else: pos += it['cases']; posok += it['cases'] if ok else 0
    if not ok:
        fails.append(f"{it['label']} t{t}")
        (out/f"FAIL_{it['label']}_t{t}.log").write_text(c.stderr+log)
print(f"positive {posok}/{pos}  expected-negative {negok}/{neg}  sims {len(items)}  logs {out}")
print("FAILS:", fails or "none")
