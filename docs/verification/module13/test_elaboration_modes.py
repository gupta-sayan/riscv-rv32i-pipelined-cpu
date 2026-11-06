"""Exercise the 32-check elaboration contract with valid and corrupted VVP text.

Every outcome guard is explicit and remains active under Python optimization.
Fixtures derive from a real Icarus dual-configuration elaboration, without edits
to RTL, schema, unit stimulus or any previously recorded evidence.
"""
import ast
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def require(condition, detail):
    if not condition:
        raise RuntimeError(detail)


if len(sys.argv) != 3:
    raise SystemExit('Usage: test_elaboration_modes.py INPUT.vvp FRESH_EVIDENCE_PARENT')
checker = Path('docs/verification/module13/check_elaboration.py').resolve()
source = Path(sys.argv[1]).resolve()
text = source.read_text()
output = Path(sys.argv[2]).resolve() / 'elaboration_mode_tests'
output.mkdir(exist_ok=False)
require(not any(isinstance(node, ast.Assert) for node in ast.walk(
    ast.parse(checker.read_text()))), 'Checker contains an optimization-removable assertion')
module_pattern = r'\.scope module, "dut" "pipeline_regs"[^\n]*;\n(.*?)(?=S_\w+ \.scope|\Z)'


def modules(value):
    return list(re.finditer(module_pattern, value, re.S))


def replace_one(value, pattern, replacement):
    result, count = re.subn(pattern, replacement, value, flags=re.M)
    require(count == 1, f'Fixture mutation must affect exactly one match: {pattern}: {count}')
    return result


def change_body(index, transform):
    found = modules(text)
    require(len(found) == 2, 'Expected a real two-module positive fixture')
    match = found[index]
    return text[:match.start(1)] + transform(match[1]) + text[match.end(1):]


found = modules(text)
require(len(found) == 2, 'Input must contain the real two-module elaboration')
header = text[found[1].start():found[1].start(1)]
one_module = text[:found[1].start()] + header.replace('"dut"', '"other_dut"', 1) + text[found[1].start(1):]
no_modules = text.replace('.scope module, "dut" "pipeline_regs"',
                          '.scope module, "other_dut" "pipeline_regs"')
extra_module = text + '\nS_fixture .scope module, "dut" "pipeline_regs";\n' + found[0][1]

zero_net = re.search(r'\.net "exmem_instr", \d+ 0, (\w+);', found[0][1])
require(zero_net is not None, 'Positive fixture lacks disabled exmem_instr net')
driver_pattern = r'^(' + re.escape(zero_net[1]) + r' \.functor BUFT 1, C4<)(0+)(>)'
nonzero_driver = replace_one(text, driver_pattern,
                             lambda m: m[1] + '1' + m[2][1:] + m[3])

fixtures = {
    'positive': text,
    'no_modules': no_modules,
    'one_module': one_module,
    'extra_module': extra_module,
    'wrong_input_width': change_body(0, lambda body: replace_one(
        body, r'(\.port_info \d+ /INPUT )1( "rst";)', r'\g<1>2\2')),
    'wrong_output_width': change_body(0, lambda body: replace_one(
        body, r'(\.port_info \d+ /OUTPUT )32( "ifid_pc";)', r'\g<1>31\2')),
    'missing_functional_storage': change_body(0, lambda body: replace_one(
        body, r'^.*\.var "idex_valid"[^\n]*\n', '')),
    'disabled_trace_register': change_body(0, lambda body: replace_one(
        body, r'^.*\.net "exmem_instr"[^\n]*\n', 'v_fixture .var "exmem_instr", 31 0;\n')),
    'missing_disabled_net': change_body(0, lambda body: replace_one(
        body, r'^.*\.net "exmem_instr"[^\n]*\n', '')),
    'nonzero_disabled_driver': nonzero_driver,
    'missing_enabled_trace_register': change_body(1, lambda body: replace_one(
        body, r'^.*\.var "memwb_instr"[^\n]*\n', '')),
}
fixture_dir = output / 'fixtures'
fixture_dir.mkdir()
for name, value in fixtures.items():
    if name != 'positive':
        require(value != text, f'{name}: mutation did not change the fixture')
    (fixture_dir / (name + '.vvp')).write_text(value)

results = []
for mode, flags, optimize in [('normal', [], None), ('env_optimize', [], '1'), ('dash_O', ['-O'], None)]:
    for name in fixtures:
        case = output / (mode + '_' + name)
        case.mkdir()
        command = [sys.executable, *flags, str(checker), str(fixture_dir / (name + '.vvp'))]
        env = os.environ.copy()
        env.pop('PYTHONOPTIMIZE', None)
        if optimize is not None:
            env['PYTHONOPTIMIZE'] = optimize
        result = subprocess.run(command, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (case / 'checker.log').write_text(result.stdout)
        record = dict(mode=mode, fixture=name, command=command, pythonoptimize=optimize,
                      actual_exit=result.returncode, expected='zero' if name == 'positive' else 'nonzero')
        (case / 'execution.json').write_text(json.dumps(record, indent=2) + '\n')
        if name == 'positive':
            labels = re.findall(r'^PASS check=(\d+) ', result.stdout, re.M)
            require(result.returncode == 0 and labels == [f'{i:02d}' for i in range(1, 33)],
                    f'{mode}: not all 32 elaboration checks passed: {result.stdout}')
            require('RESULT elaboration checks=32 failures=0' in result.stdout,
                    f'{mode}: missing positive summary')
        else:
            require(result.returncode != 0 and 'FAIL elaboration:' in result.stdout,
                    f'{mode}/{name}: invalid elaboration accepted: {result.stdout}')
            require('RESULT elaboration checks=' not in result.stdout,
                    f'{mode}/{name}: false successful summary')
        results.append(record)
        print(f'PASS {mode}/{name}: checker exit={result.returncode}, expected={record["expected"]}')

(output / 'summary.json').write_text(json.dumps(dict(
    input_vvp=str(source), input_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    executions=results, positive=3, negative=30, failures=0), indent=2) + '\n')
print('RESULT elaboration mode executions=33 passing=33 failures=0 '
      'positive=3 negative=30 positive_checks_per_mode=32; checker Assert nodes=0')
