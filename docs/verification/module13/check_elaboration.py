"""Check architectural ports and optional register pruning in Icarus VVP output.

Icarus 12 text format is intentional; unsupported format fails instead of silently
claiming pruning. Schema is independently transcribed from ARCH section 8.
"""
import json
import re
import sys
from pathlib import Path


def require(condition, detail):
    """Verification guards must execute even under -O/PYTHONOPTIMIZE."""
    if not condition:
        print(f'FAIL elaboration: {detail}', file=sys.stderr)
        raise SystemExit(1)


def record_check(detail):
    global checks
    checks += 1
    print(f'PASS check={checks:02d} {detail}')


schema = json.loads(Path('docs/verification/module13/packet_schema.json').read_text())
text = Path(sys.argv[1]).read_text()
modules = re.findall(r'\.scope module, "dut" "pipeline_regs"[^\n]*;\n(.*?)(?=S_\w+ \.scope|\Z)', text, re.S)
require(len(modules) == 2, f'Expected two elaborated pipeline register modules, found {len(modules)}')
checks = 0
for trace, body in enumerate(modules):
    ports = {'inputs': {}, 'outputs': {}}
    for direction, width, name in re.findall(r'\.port_info \d+ /(INPUT|OUTPUT) (\d+) "([^"]+)";', body):
        ports['inputs' if direction == 'INPUT' else 'outputs'][name] = int(width)
    for direction in ('inputs', 'outputs'):
        require(ports[direction] == schema[direction], (trace, direction, 'port mismatch'))
        record_check(f'TRACE_EN={trace} {direction} match schema')
    variables = set(re.findall(r'\.var "([^"]+)"', body))
    expected = set(schema['outputs'])
    if not trace:
        expected -= set(schema['trace'])
    require(variables == expected, (trace, 'unexpected or missing storage', variables ^ expected))
    record_check(f'TRACE_EN={trace} exact storage set')
    for name in schema['trace']:
        if trace:
            require(name in variables, (trace, name, 'enabled trace register missing'))
        else:
            match = re.search(r'\.net "' + re.escape(name) + r'", \d+ 0, (\w+);', body)
            require(match is not None, (name, 'disabled output is not a net'))
            driver = re.search(r'^' + re.escape(match[1]) + r' \.functor BUFT 1, C4<(0+)>', text, re.M)
            require(driver is not None, (name, 'disabled output is not constant zero'))
        record_check(f'TRACE_EN={trace} {name}: ' + ('register present' if trace else 'constant-zero net, no register'))
    print(f'TRACE_EN={trace}: ports match schema; registered outputs={len(variables)}; optional registers={13 if trace else 0}')
print(f'RESULT elaboration checks={checks} failures=0 (Icarus elaboration, not synthesis/STA)')
