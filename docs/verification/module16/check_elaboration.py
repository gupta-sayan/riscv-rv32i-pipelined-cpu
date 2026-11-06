"""Check architectural ports and optional register pruning in Icarus VVP output.

Icarus 12 text format is intentional; unsupported format fails instead of silently
claiming pruning. Schema is independently transcribed from ARCH section 8.
"""
import json
import re
import sys
from pathlib import Path

schema = json.loads(Path('docs/verification/module16/packet_schema.json').read_text())
text = Path(sys.argv[1]).read_text()
modules = re.findall(r'\.scope module, "dut" "wb_trace"[^\n]*;\n(.*?)(?=S_\w+ \.scope|\Z)', text, re.S)
assert len(modules) == 2, 'Expected two elaborated pipeline register modules'
checks = 0
for trace, body in enumerate(modules):
    ports = {'inputs': {}, 'outputs': {}}
    for direction, width, name in re.findall(r'\.port_info \d+ /(INPUT|OUTPUT) (\d+) "([^"]+)";', body):
        ports['inputs' if direction == 'INPUT' else 'outputs'][name] = int(width)
    for direction in ('inputs', 'outputs'):
        assert ports[direction] == schema[direction], (trace, direction, 'port mismatch')
        checks += 1
    variables = set(re.findall(r'\.var "([^"]+)"', body))
    expected = set(schema['outputs'])
    if not trace:
        expected -= set(schema['trace'])
    assert variables == expected, (trace, 'unexpected or missing storage', variables ^ expected)
    checks += 1
    for name in schema['trace']:
        if trace:
            assert name in variables
        else:
            match = re.search(r'\.net "' + re.escape(name) + r'", \d+ 0, (\w+);', body)
            assert match, (name, 'disabled output is not a net')
            driver = re.search(r'^' + re.escape(match[1]) + r' \.functor BUFT 1, C4<(0+)>', text, re.M)
            assert driver, (name, 'disabled output is not constant zero')
        checks += 1
    print(f'TRACE_EN={trace}: ports match schema; procedural output variables={len(variables)}; retirement registers={12 if trace else 0}')
print(f'RESULT elaboration checks={checks} failures=0 (Icarus elaboration, not synthesis/STA)')
