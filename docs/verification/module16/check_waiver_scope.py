"""Exercise native waiver matching using synthetic sources in a temporary tree.

No production files are edited. Each negative probe must still fail strict lint.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

waiver = Path('docs/verification/module16/trace_disabled.vlt').resolve()
logs = Path(sys.argv[1]).resolve()
cases = [
    ('exact_expected', 'rtl/core/wb_trace.sv',
     "module wb_trace(input logic clk, output logic value); assign value=1'b0; endmodule\n", None),
    ('different_signal', 'rtl/core/wb_trace.sv',
     "module wb_trace(input logic unexpected_input, output logic value); assign value=1'b0; endmodule\n", 'UNUSEDSIGNAL'),
    ('different_file', 'other/wb_trace.sv',
     "module wb_trace(input logic clk, output logic value); assign value=1'b0; endmodule\n", 'UNUSEDSIGNAL'),
    ('different_rule', 'rtl/core/wb_trace.sv',
     'module wb_trace(output logic clk); endmodule\n', 'UNDRIVEN'),
]
with tempfile.TemporaryDirectory(prefix='module16_waiver_') as workspace:
    for name, filename, source, warning in cases:
        path = Path(workspace, filename)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source)
        command = ['verilator', '--lint-only', '--Wall', '--top-module', 'wb_trace', str(waiver), filename]
        result = subprocess.run(command, cwd=workspace, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (logs / ('waiver_probe_' + name + '.log')).write_text(
            f'Synthetic source ({filename}):\n{source}\nCommand arguments: {command!r}\nExit: {result.returncode}\n{result.stdout}')
        if warning is None:
            assert result.returncode == 0 and not result.stdout, (name, result.stdout)
        else:
            assert result.returncode != 0 and '%Warning-' + warning + ':' in result.stdout, (name, result.stdout)
        print(f'PASS {name}: exit={result.returncode}; ' + ('exact diagnostic waived' if warning is None else f'{warning} remains fatal'))
print('RESULT waiver scope probes=4 passing=4 failures=0')
