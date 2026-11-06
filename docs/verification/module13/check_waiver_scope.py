"""Exercise native waiver matching using synthetic sources in a temporary tree.

No production files are edited. Each negative probe must still fail strict lint.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

waiver = Path('docs/verification/module13/trace_disabled.vlt').resolve()
logs = Path(sys.argv[1]).resolve()
cases = [
    ('exact_expected', 'rtl/core/pipeline_regs.sv',
     "module pipeline_regs(input logic id_instr, output logic value); assign value=1'b0; endmodule\n", None),
    ('different_signal', 'rtl/core/pipeline_regs.sv',
     "module pipeline_regs(input logic unexpected_input, output logic value); assign value=1'b0; endmodule\n", 'UNUSEDSIGNAL'),
    ('different_file', 'other/pipeline_regs.sv',
     "module pipeline_regs(input logic id_instr, output logic value); assign value=1'b0; endmodule\n", 'UNUSEDSIGNAL'),
    ('different_rule', 'rtl/core/pipeline_regs.sv',
     'module pipeline_regs(output logic id_instr); endmodule\n', 'UNDRIVEN'),
]
with tempfile.TemporaryDirectory(prefix='module13_waiver_') as workspace:
    for name, filename, source, warning in cases:
        path = Path(workspace, filename)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source)
        command = ['verilator', '--lint-only', '--Wall', '--top-module', 'pipeline_regs', str(waiver), filename]
        result = subprocess.run(command, cwd=workspace, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (logs / ('waiver_probe_' + name + '.log')).write_text(
            f'Synthetic source ({filename}):\n{source}\nCommand arguments: {command!r}\nExit: {result.returncode}\n{result.stdout}')
        if warning is None:
            passed = result.returncode == 0 and not result.stdout
            expected = 'exit 0 with no diagnostics'
        else:
            passed = result.returncode != 0 and '%Warning-' + warning + ':' in result.stdout
            expected = f"nonzero exit containing %Warning-{warning}:"
        # Verification decisions must remain active under -O/PYTHONOPTIMIZE.
        if not passed:
            print(f'FAIL {name}: expected {expected}; exit={result.returncode}; '
                  f'diagnostics={result.stdout!r}', file=sys.stderr)
            raise SystemExit(1)
        print(f'PASS {name}: exit={result.returncode}; ' + ('exact diagnostic waived' if warning is None else f'{warning} remains fatal'))
print('RESULT waiver scope probes=4 passing=4 failures=0')
