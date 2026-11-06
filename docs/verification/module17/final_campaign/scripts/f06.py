from common import *
import re
out=begin(6);items=[];results=[]
def add(label,top,bench,cases,marker,extra=None,params=None,expected=0,property_id=None):
    for t in (0,1):items.append(dict(label=label,top=top,bench=bench,cases=cases,marker=marker,extra=extra or [],params=params or [],trace=t,expected=expected,property_id=property_id))
add('integration','tb_rv32i_core_top','tb/integration/tb_rv32i_core_top.sv',12,'PASS ALL TRACE_EN={t} tests=12')
for n in range(1,28):
    casepath=ROOT/f'docs/verification/module17/full_campaign/tests/v{n:02}/cases.json'
    count=len(json.loads(casepath.read_text()))
    add(f'V{n:02}','tb_campaign',str(casepath.with_name('tb_campaign.sv').relative_to(ROOT)),count,f'PASS ALL V{n:02} trace={{t}} cases={count}')
add('V15_original_a01','tb_a01','docs/verification/module17/full_campaign/tests/v15/tb_a01.sv',1,'PASS ALL A01 vectors=8 trace={t}')
add('V23_original_reset','tb_reset','docs/verification/module17/full_campaign/tests/v23/tb_reset.sv',5,'PASS ALL RESET cases=5 trace={t}')
add('V23_accepted_fetch','tb_accepted_fetch_reset','docs/verification/module17/full_campaign/tests/v23/tb_accepted_fetch_reset.sv',1,'PASS ALL IV01 trace={t}')
add('D01','checked_d01',str(BASE/'tests/checked_d01.sv'),1,'PASS ALL D01 selectors=4 checks=8',extra=['docs/verification/module17/d01/tb_d01.sv'])
add('D02','tb_d02_a01','docs/verification/module17/d02_a01/tb_d02_a01.sv',3,'PASS ALL D02 trace={t} events=3')
for label,old,casecount,marker in [('legal','tb/integration/tb_rv32i_core_top.sv',12,'PASS ALL TRACE_EN={t} tests=12'),
                                 ('injected','docs/verification/module17/d02_a01/tb_d02_a01.sv',3,'PASS ALL D02 trace={t} events=3')]:
    add('F02_'+label,'checked_'+label,str(BASE/f'tests/checked_{label}.sv'),casecount,marker,extra=[str(BASE/'tests/cpu_checker.sv'),old],params=['MUTATION=0'])
for m,pid in {1:1,2:4,3:19,4:8,5:9}.items():
    add(f'F02_negative{m}','checked_legal',str(BASE/'tests/checked_legal.sv'),1,f'CHECKER_FAIL P{pid} ',
        extra=[str(BASE/'tests/cpu_checker.sv'),'tb/integration/tb_rv32i_core_top.sv'],params=[f'MUTATION={m}'],expected=1,property_id=pid)
for item in items:
    t=item['trace'];label=item['label']+f'_trace{t}'
    dest=out/label;dest.mkdir();binary=dest/'simulation.vvp'
    paths=[Path(item['bench']) if Path(item['bench']).is_absolute() else ROOT/item['bench']]
    paths+=[Path(p) if Path(p).is_absolute() else ROOT/p for p in item['extra']]
    (dest/'test_sources.sha256').write_text(''.join(f'{sha(p)}  {p.relative_to(ROOT)}\n' for p in paths))
    for p in paths:
        target=dest/'sources'/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    args=['iverilog','-g2012','-gassertions','-s',item['top'],'-P',f"{item['top']}.TRACE_EN={t}"]
    for param in item['params']:args+=['-P',item['top']+'.'+param]
    rc,log=command([*args,'-o',str(binary),*map(str,paths),*rtl_sources()],dest,'compile',60)
    cr=rc
    if rc==0:rc,log=command(['vvp',str(binary)],dest,'simulation',30,expected=f"exit {item['expected']}")
    ok=cr==0 and rc==item['expected'] and item['marker'].format(t=t) in log
    if item['label']=='D01':ok=ok and f'D01_CONFIG TRACE_EN={t}' in log
    r=dict(**item,compile_exit=cr,simulation_exit=rc,pass_=ok,evidence=str(dest.relative_to(BASE)))
    results.append(r)
    (out/'results.json').write_text(json.dumps(results,indent=2))
    print(label,'compile',cr,'sim',rc,'expected outcome',ok,flush=True)
rc,log=command(['python3','-B','docs/verification/module17/full_campaign/scripts/check_model.py'],out,'model_anchors')
anchors=rc==0 and 'PASS ALL MODEL ANCHORS cases=12' in log
# The accepted model script is executed directly, never imported; no historic pycache writes.
integrity(out)
positive=[r for r in results if r['expected']==0];negative=[r for r in results if r['expected']!=0]
summary=dict(positive_case_executions=sum(r['cases'] for r in positive),positive_simulations=len(positive),negative_simulations=len(negative),
             positive_cases_pass=sum(r['cases'] for r in positive if r['pass_']),negative_expected=sum(r['pass_'] for r in negative),model_anchors=anchors)
(out/'summary.json').write_text(json.dumps(summary,indent=2))
ok=all(r['pass_'] for r in results) and anchors
lines=['# F06 — complete fresh regression','',f"Result: {'PASS' if ok else 'FAIL'}. Evidence: {out.relative_to(BASE)}.",
       'Accepted benches, expectations and original source files are unchanged. Their compile/simulation argv are replayed with new output paths inside final_campaign; old supported runners were not invoked because they write into their historical directories. Every benchmark source is copied/hash-identified per run. Finite compile/simulation limits: 60/30 seconds.',
       'Both static trace modes run for every suite. D01 uses a new wrapper with defparam to configure the original accepted bench’s actual core and an executable parameter check; all original eight selector checks remain unchanged. V01–V27 use the existing final generated programs/oracles, not regenerated expectations. Original V15 output injection and D02 actual-packet injection remain clearly distinct. F02 wrappers add observation-only assertions; expected negative runs mutate checker inputs only.',
       f"Positive case/configuration executions: {summary['positive_case_executions']}; passed: {summary['positive_cases_pass']}. Positive simulator processes: {summary['positive_simulations']}. Expected negative processes: {summary['negative_expected']}/{summary['negative_simulations']}. Twelve model-anchor checks: {anchors}. Counts include repeated accepted integration/D02 programs under F02 checkers; they are not unique ISA programs. D01 is one aggregate case per build containing eight exact selector checks.",
       '', '| Suite | Trace | Cases | Compile exit | Simulation exit | Required outcome | Evidence |','|---|---|---|---|---|---|---|']
for r in results:lines.append(f"| {r['label']} | {r['trace']} | {r['cases']} | {r['compile_exit']} | {r['simulation_exit']} | {'PASS' if r['pass_'] else 'FAIL'} {'expected negative' if r['expected'] else ''} | {r['evidence']} |")
lines+=['','All raw compiler notices and failures are retained; no warning suppression. Both trace builds must pass their common independent architectural expectations. Exact final natural-program signatures are retained in per-group logs; the F07 audit compares signatures directly rather than treating individual exit 0 as equivalence proof. D02 injects prohibited packet states intentionally; no defined consumer recovery result is inferred.']
atomic(BASE/'REGRESSION_REPORT.md','\n'.join(lines)+'\n');finish(6,'PASS' if ok else 'FAIL',f"{summary['positive_cases_pass']}/{summary['positive_case_executions']} positive cases; {summary['negative_expected']}/10 expected negatives; anchors {anchors}")
