"""Regression for waiver-checker decisions with and without Python optimization.

Real Verilator exercises unchanged waiver semantics. Synthetic Verilator tools
then deliberately return incorrect outcomes; each must make the checker fail.
All test pass/fail decisions use explicit exceptions, never Python assertions.
Run from repository root with a fresh parent evidence directory as argument.
"""
import ast
import json
import os
import subprocess
import sys
from pathlib import Path


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


checker = Path('docs/verification/module13/check_waiver_scope.py').resolve()
output = Path(sys.argv[1]).resolve() / 'waiver_mode_tests'
output.mkdir(exist_ok=False)
require(not any(isinstance(node, ast.Assert) for node in ast.walk(
    ast.parse(checker.read_text()))), 'Checker contains an optimization-removable assertion')

fake_bin = output / 'synthetic_tools'
fake_bin.mkdir()
fake_tool = fake_bin / 'verilator'
fake_tool.write_text('''#!/usr/bin/env python3
import os
import sys
from pathlib import Path
mode = os.environ['M17_WAIVER_FAKE_RESULT']
if mode == 'all_success':
    sys.exit(0)
if mode == 'positive_nonzero':
    print('Deliberately incorrect nonzero result for expected waived diagnostic')
    sys.exit(1)
if mode == 'positive_noise':
    print('%Warning-UNUSEDSIGNAL: deliberately incorrect diagnostic on expected clean result')
    sys.exit(0)
if mode == 'wrong_warning':
    if 'unexpected_input' in Path(sys.argv[-1]).read_text():
        print('%Warning-UNDRIVEN: deliberately wrong warning type')
        sys.exit(1)
    sys.exit(0)
sys.exit(2)
''')
fake_tool.chmod(0o755)

modes = [('normal', [], None), ('env_optimize', [], '1'), ('dash_O', ['-O'], None)]
behaviors = [None, 'all_success', 'positive_nonzero', 'positive_noise', 'wrong_warning']
results = []
for mode, flags, optimize in modes:
    for behavior in behaviors:
        name = f'{mode}_{behavior or "real_verilator"}'
        case = output / name
        case.mkdir()
        probes = case / 'probes'
        probes.mkdir()
        env = os.environ.copy()
        env.pop('PYTHONOPTIMIZE', None)
        env.pop('M17_WAIVER_FAKE_RESULT', None)
        if optimize is not None:
            env['PYTHONOPTIMIZE'] = optimize
        if behavior is not None:
            env['M17_WAIVER_FAKE_RESULT'] = behavior
            env['PATH'] = str(fake_bin) + os.pathsep + env.get('PATH', '')
        command = [sys.executable, *flags, str(checker), str(probes)]
        result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        (case / 'checker.log').write_text(result.stdout)
        record = dict(name=name, command=command, pythonoptimize=optimize,
                      fake_result=behavior, actual_exit=result.returncode,
                      expected='zero' if behavior is None else 'nonzero')
        (case / 'execution.json').write_text(json.dumps(record, indent=2) + '\n')
        if behavior is None:
            require(result.returncode == 0, f'{name}: checker failed: {result.stdout}')
            require(result.stdout.count('PASS ') == 4 and
                    'RESULT waiver scope probes=4 passing=4 failures=0' in result.stdout,
                    f'{name}: incomplete real waiver checks')
            require(len(list(probes.glob('waiver_probe_*.log'))) == 4,
                    f'{name}: incomplete raw probe evidence')
        else:
            require(result.returncode != 0 and 'FAIL ' in result.stdout,
                    f'{name}: incorrect result accepted: {result.stdout}')
            require('RESULT waiver scope probes=4 passing=4 failures=0' not in result.stdout,
                    f'{name}: false all-passing summary')
        results.append(record)
        print(f'PASS {name}: checker exit={result.returncode}, expected={record["expected"]}')

(output / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
print('RESULT mode regression executions=15 passing=15 failures=0 '
      'real_modes=3 incorrect_outcomes_rejected=12; checker Assert nodes=0')
