"""Run the actual Module 16 runner against an isolated verification-only fixture.

Only a copied testbench gains an unrelated unused variable. Copied production RTL
and baseline remain byte-identical. This script is a separate check to avoid
recursively launching itself. It preserves the child's evidence in the given run.
"""
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

repo = Path.cwd()
output = Path(tempfile.mkdtemp(prefix='negative_runner_', dir=Path(sys.argv[1]).resolve()))
print(f'Negative fixture evidence: {output}', flush=True)
verification = Path('docs/verification/module16')
with tempfile.TemporaryDirectory(prefix='module16_runner_negative_') as workspace:
    fixture = Path(workspace)
    for filename in ('rtl/core/wb_trace.sv', 'tb/unit/tb_wb_trace.sv'):
        dest = fixture / filename
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo / filename, dest)
    for name in ('run.sh', 'rtl_before.sha256', 'trace_disabled.vlt', 'check_waiver_scope.py',
                 'check_elaboration.py', 'packet_schema.json'):
        dest = fixture / verification / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo / verification / name, dest)
    tb = fixture / 'tb/unit/tb_wb_trace.sv'
    original = tb.read_text()
    replacement = original.replace('endmodule', '    logic unexpected_probe;\nendmodule')
    assert replacement != original
    tb.write_text(replacement)
    (output / 'testbench_fixture.diff').write_text(''.join(difflib.unified_diff(
        original.splitlines(True), replacement.splitlines(True),
        fromfile='original/tb/unit/tb_wb_trace.sv', tofile='fixture/tb/unit/tb_wb_trace.sv')))
    assert (fixture / 'rtl/core/wb_trace.sv').read_bytes() == (repo / 'rtl/core/wb_trace.sv').read_bytes()
    assert (fixture / verification / 'run.sh').read_bytes() == (repo / verification / 'run.sh').read_bytes()
    result = subprocess.run(['bash', str(verification / 'run.sh')], cwd=fixture,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output / 'runner_stdout.log').write_text(result.stdout)
    children = list((fixture / verification / 'runs').iterdir())
    assert len(children) == 1
    child = children[0]
    for path in child.iterdir():
        if path.suffix in ('.log', '.sha256'):
            shutil.copy2(path, output / path.name)
    status = (child / 'status.log').read_text()
    lint = (child / 'lint_tb_waived.log').read_text()
    errors = [(name, code) for name, code in re.findall(r'^(\S+) exit=([1-9]\d*)$', status, re.M) if name != 'OVERALL']
    assert result.returncode == 1, result.stdout
    assert errors == [('lint_tb_waived', '1')], status
    assert "Signal is not driven, nor used: 'unexpected_probe'" in lint, lint
    assert re.findall(r'^%Warning-(\w+):', lint, re.M) == ['UNUSEDSIGNAL'], lint
    assert 'OVERALL exit=1' in status
    (output / 'summary.json').write_text(json.dumps({
        'runner_exit': result.returncode, 'only_failed_check': 'lint_tb_waived',
        'unwaived_warning': 'UNUSEDSIGNAL', 'signal': 'unexpected_probe',
        'production_rtl_unchanged': True, 'actual_runner_byte_identical': True,
        'runner_sha256': hashlib.sha256((repo / verification / 'run.sh').read_bytes()).hexdigest(),
        'all_other_checks_passed': True
    }, indent=2) + '\n')
print('PASS actual runner negative fixture: unrelated TB UNUSEDSIGNAL -> lint exit 1, runner exit 1; all other checks pass')
