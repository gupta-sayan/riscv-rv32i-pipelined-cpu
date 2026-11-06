#!/usr/bin/env python3
"""Pinned technical lint contract with external-only runtime evidence.

This procedure has its own identity. It does not execute any earlier runner.
"""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
MANIFEST_SHA256 = "09f2d79a9b585759aaf7f03f90683f131f38db0675818205ba6bd2697e7aa1a4"
BASE = Path("docs/verification/module17/lint_closure/fail_closed_runner")
CONFIGURATIONS = ("core_trace0", "core_trace1", "bench_trace0", "bench_trace1")
COUNTS = dict(zip(CONFIGURATIONS, (27, 5, 49, 27)))
ENVIRONMENT = {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "LANG": "C"}


class Rejected(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def require(condition, code, message):
    if not condition:
        raise Rejected(code, message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "CONTRACT_SCHEMA", "Duplicate JSON key")
        result[key] = value
    return result


def read_json(path):
    try:
        return json.loads(Path(path).read_text(), object_pairs_hook=reject_duplicate_keys)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise Rejected("CONTRACT_SCHEMA", "Unreadable or invalid JSON") from exc


def command_template(name, sources):
    trace = name[-1]
    bench = name.startswith("bench")
    result = ["{tool}", "--lint-only", "--Wall", "--top-module",
              "tb_rv32i_core_top" if bench else "rv32i_core_top",
              "-GTRACE_EN=1'b" + trace, "--Mdir", "{workdir}"]
    if bench:
        result += ["--timing", "tb/integration/tb_rv32i_core_top.sv"]
    return result + sorted(p for p in sources if p.startswith("rtl/"))


def validate_contract(manifest):
    require(manifest.get("schema_id") == "rv32i.portable-lint-contract"
            and manifest.get("schema_version") == "1.0.0",
            "CONTRACT_SCHEMA", "Unsupported contract schema")
    require(manifest.get("environment") == ENVIRONMENT,
            "ENVIRONMENT", "Controlled environment differs")
    require(manifest.get("timeout_seconds") == 60 and manifest.get("version_timeout_seconds") == 15,
            "CONTRACT_SCHEMA", "Unexpected execution limit")
    require(set(manifest.get("configurations", {})) == set(CONFIGURATIONS),
            "COMMAND", "Configuration set differs")
    sources = manifest.get("sources", {})
    require(len([p for p in sources if p.startswith("rtl/")]) == 17
            and "tb/integration/tb_rv32i_core_top.sv" in sources
            and len(sources) == 19,
            "CONTRACT_SCHEMA", "Unexpected technical input set")
    primary = set()
    for name in CONFIGURATIONS:
        config = manifest["configurations"][name]
        require(config["argv"] == command_template(name, sources),
                "COMMAND", "Command parameters differ")
        require(config["native_exit"] == 1
                and config["stdout"] == "empty"
                and len(config["diagnostics"]) == COUNTS[name],
                "CONTRACT_SCHEMA", "Diagnostic or channel contract differs")
        for record in config["diagnostics"]:
            require(set(record) == {"category", "path", "line", "column",
                                    "message", "details"},
                    "CONTRACT_SCHEMA", "Diagnostic fields differ")
            primary.add(tuple(record[k] for k in
                              ("category", "path", "line", "column", "message")))
    require(len(primary) == 50, "CONTRACT_SCHEMA", "Primary identity scope differs")


def load_contract(root):
    path = root / BASE / "portable_manifest.json"
    require(path.is_file() and not path.is_symlink(),
            "CONTRACT_HASH", "Technical contract unavailable")
    require(digest(path) == MANIFEST_SHA256,
            "CONTRACT_HASH", "Technical contract fingerprint differs")
    manifest = read_json(path)
    validate_contract(manifest)
    return manifest


def source_path(root, name):
    rel = Path(name)
    require(not rel.is_absolute() and ".." not in rel.parts
            and rel.as_posix() == name, "SOURCE_PATH", "Invalid logical source path")
    path = root / rel
    require(all(not (root.joinpath(*rel.parts[:i])).is_symlink()
                for i in range(1, len(rel.parts) + 1)),
            "SOURCE_PATH", "Symlinked source input")
    require(path.resolve().is_relative_to(root),
            "SOURCE_PATH", "Source escapes root")
    require(path.is_file(), "SOURCE_MISSING", "Required source missing")
    return path


def source_snapshot(root, manifest):
    observed = {}
    for name, expected in sorted(manifest["sources"].items()):
        path = source_path(root, name)
        observed[name] = digest(path)
        require(observed[name] == expected, "SOURCE_HASH", "Source fingerprint differs")
    actual_sv = sorted(p.relative_to(root).as_posix()
                       for folder in ("rtl", "tb/integration")
                       for p in (root / folder).rglob("*.sv"))
    expected_sv = sorted(p for p in manifest["sources"] if p.endswith(".sv"))
    require(actual_sv == expected_sv, "SOURCE_SET", "SystemVerilog source set differs")
    baseline = read_json(root / manifest["baseline_path"])
    require(baseline.get("schema_id") == "rv32i.technical-lint-evidence",
            "BASELINE", "Unexpected technical evidence schema")
    records = {c["configuration"]: c["diagnostics"]
               for c in baseline["configurations"]}
    require(set(records) == set(CONFIGURATIONS), "BASELINE", "Baseline configurations differ")
    for name in CONFIGURATIONS:
        require(inventory_counter(records[name]) ==
                inventory_counter(manifest["configurations"][name]["diagnostics"]),
                "BASELINE", "Pinned diagnostic baseline differs")
    return observed


def reserve_output(root, output):
    candidate = Path(output)
    require(candidate.is_absolute() and ".." not in candidate.parts,
            "OUTPUT_UNSAFE", "Output must be an unambiguous absolute path")
    require(not candidate.is_symlink()
            and all(not p.is_symlink() for p in candidate.parents),
            "OUTPUT_UNSAFE", "Symlinked output location")
    output = candidate.resolve()
    require(not output.is_relative_to(root) and not root.is_relative_to(output),
            "OUTPUT_UNSAFE", "Output must be disjoint from project root")
    require(not output.exists(), "OUTPUT_EXISTS", "Output location already exists")
    require(output.parent.is_dir(), "OUTPUT_UNSAFE", "Output parent is unavailable")
    try:
        output.mkdir(mode=0o700)
    except OSError as exc:
        raise Rejected("OUTPUT_UNSAFE", "Cannot reserve fresh output") from exc
    return output


def invoke(argv, cwd, timeout):
    try:
        return subprocess.run(argv, cwd=cwd, env=ENVIRONMENT,
                              stdin=subprocess.DEVNULL, capture_output=True,
                              timeout=timeout, check=False)
    except subprocess.TimeoutExpired as exc:
        failure = Rejected("TIMEOUT", "Tool exceeded contract time limit")
        failure.stdout = exc.stdout or b""
        failure.stderr = exc.stderr or b""
        raise failure from exc
    except (FileNotFoundError, PermissionError, OSError) as exc:
        raise Rejected("TOOL_MISSING", "Tool cannot be executed") from exc


def validate_version(result, manifest):
    tool = manifest["tool"]
    require(result.returncode == 0 and result.stdout == tool["version_stdout"].encode()
            and result.stderr == tool["version_stderr"].encode(),
            "TOOL_VERSION", "Tool version or channels differ")


def tool_identity(manifest, executable=None):
    name = executable or shutil.which("verilator", path=ENVIRONMENT["PATH"])
    require(name is not None and Path(name).is_file(),
            "TOOL_MISSING", "Verilator executable unavailable")
    tool = Path(name).resolve()
    paths = {"verilator": tool, "verilator_bin": tool.parent / "verilator_bin"}
    perl = shutil.which("perl", path=ENVIRONMENT["PATH"])
    require(perl is not None, "TOOL_MISSING", "Required interpreter unavailable")
    paths["perl"] = Path(perl).resolve()
    hashes = {}
    for logical, path in paths.items():
        require(path.is_file(), "TOOL_MISSING", "Tool dependency unavailable")
        hashes[logical] = digest(path)
        require(hashes[logical] == manifest["tool"]["sha256"][logical],
                "TOOL_FINGERPRINT", "Executable fingerprint incompatible")
    return {"executable": str(tool),
            "paths": {k: str(v) for k, v in paths.items()}, "sha256": hashes}


def canonical_path(value, root):
    require("\\" not in value and "\0" not in value,
            "DIAGNOSTIC_PATH", "Invalid diagnostic source path")
    path = Path(value)
    path = (root / path).resolve() if not path.is_absolute() else path.resolve()
    require(path.is_relative_to(root), "DIAGNOSTIC_PATH", "Diagnostic escapes source root")
    return path.relative_to(root).as_posix()


def parse(data, root):
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeError as exc:
        raise Rejected("ENCODING", "Non-UTF8 diagnostic stream") from exc
    require(bool(text) and text.endswith("\n") and "\0" not in text,
            "FRAMING", "Empty, truncated or nontext output")
    header = re.compile(r"^%Warning-([A-Z][A-Z0-9_]*): (.+):(\d+):(\d+): (.+)\n$")
    terminal_pattern = re.compile(r"^%Error: Exiting due to ([1-9][0-9]*) warning\(s\)\n$")
    lines = text.splitlines(keepends=True)
    records = []
    terminal = None
    for index, line in enumerate(lines):
        match = header.fullmatch(line)
        if match:
            require(terminal is None, "FRAMING", "Warning follows terminal")
            category, path, ln, col, message = match.groups()
            require(int(ln) > 0 and int(col) > 0, "FRAMING", "Invalid source position")
            records.append(dict(category=category, path=canonical_path(path, root),
                                line=int(ln), column=int(col), message=message, details=""))
        elif (match := terminal_pattern.fullmatch(line)):
            require(terminal is None and index == len(lines) - 1,
                    "FRAMING", "Duplicate or nonterminal summary")
            terminal = int(match[1])
        elif line.startswith("%") or terminal is not None or not records:
            raise Rejected("FRAMING", "Unframed tool output")
        else:
            records[-1]["details"] += line
    require(terminal == len(records) and terminal is not None,
            "FRAMING", "Missing or inconsistent warning summary")
    require(all(r["details"] for r in records), "FRAMING", "Diagnostic lacks details")
    return records


def inventory_counter(records):
    return collections.Counter(json.dumps(r, sort_keys=True, separators=(",", ":"))
                               for r in records)


def compare(stdout, stderr, native_exit, expected, root):
    require(not stdout, "CHANNEL", "Unexpected stdout")
    require(native_exit == 1, "NATIVE_EXIT", "Unexpected native exit")
    actual = parse(stderr, root)
    require(inventory_counter(actual) == inventory_counter(expected),
            "DIAGNOSTICS", "Complete diagnostic multiset differs")
    return actual


def run_contract(root, output, configuration="all", executable=None):
    root = Path(root).resolve()
    require(root.is_dir(), "SOURCE_PATH", "Project root unavailable")
    output = reserve_output(root, output)
    report = {"schema_id": "rv32i.portable-lint-execution", "schema_version": "1.0.0",
              "record_id": "PORTABLE-LINT-EXECUTION", "status": "ERROR",
              "configurations": [], "manifest_sha256": MANIFEST_SHA256}
    try:
        manifest = load_contract(root)
        source_before = source_snapshot(root, manifest)
        report["source_inputs"] = source_before
        own_path = Path(__file__).resolve()
        own_hash = digest(own_path)
        require(digest(source_path(root, (BASE / "portable_runner.py").as_posix())) == own_hash,
                "RUNNER_IDENTITY", "Root runner differs from executing runner")
        report["runner_sha256"] = own_hash
        identity = tool_identity(manifest, executable)
        version = invoke([identity["executable"], "--version"], root, 15)
        (output / "version.stdout.bin").write_bytes(version.stdout)
        (output / "version.stderr.bin").write_bytes(version.stderr)
        validate_version(version, manifest)
        report["tool"] = dict(identity, version_stdout=version.stdout.decode(),
                              version_stderr=version.stderr.decode(), version_exit=version.returncode)
        write_json(output / "source_inputs.json", source_before)
        write_json(output / "tool_identity.json", report["tool"])
        names = CONFIGURATIONS if configuration == "all" else (configuration,)
        require(all(n in CONFIGURATIONS for n in names), "ARGUMENTS", "Unknown configuration")
        for name in names:
            config = manifest["configurations"][name]
            source_snapshot(root, manifest)
            require(tool_identity(manifest, executable) == identity,
                    "TOOL_FINGERPRINT", "Tool changed before execution")
            directory = output / name
            directory.mkdir()
            work = directory / "work"
            argv = [identity["executable"] if a == "{tool}" else
                    str(work) if a == "{workdir}" else a for a in config["argv"]]
            row = {"record_id": "PORTABLE-" + name, "configuration": name,
                   "argv": argv, "cwd": str(root), "expected_native_exit": 1}
            report["configurations"].append(row)
            write_json(directory / "command.json", row)
            native = invoke(argv, root, manifest["timeout_seconds"])
            (directory / "stdout.bin").write_bytes(native.stdout)
            (directory / "stderr.bin").write_bytes(native.stderr)
            row.update(native_exit=native.returncode,
                       stdout_bytes=len(native.stdout), stdout_sha256=hashlib.sha256(native.stdout).hexdigest(),
                       stderr_bytes=len(native.stderr), stderr_sha256=hashlib.sha256(native.stderr).hexdigest())
            actual = compare(native.stdout, native.stderr, native.returncode,
                             config["diagnostics"], root)
            row.update(status="PASS", warning_occurrences=len(actual), full_multiset_equal=True)
            write_json(directory / "parsed_diagnostics.json", actual)
            write_json(directory / "multiset_comparison.json",
                       {"equal": True, "occurrences": len(actual),
                        "actual": dict(inventory_counter(actual)),
                        "expected": dict(inventory_counter(config["diagnostics"]))})
        require(source_snapshot(root, manifest) == source_before,
                "SOURCE_HASH", "Input changed during execution")
        load_contract(root)
        require(digest(own_path) == own_hash, "RUNNER_IDENTITY", "Runner changed during execution")
        require(tool_identity(manifest, executable) == identity,
                "TOOL_FINGERPRINT", "Tool changed during execution")
        validate_version(invoke([identity["executable"], "--version"], root, 15), manifest)
        report.update(status="PASS", source_integrity=True, output_outside_root=True)
    except Rejected as exc:
        report.update(status="REJECTED", reason_code=exc.code, reason=str(exc))
        if hasattr(exc, "stdout"):
            (output / "failure.stdout.bin").write_bytes(exc.stdout)
            (output / "failure.stderr.bin").write_bytes(exc.stderr)
    except Exception as exc:
        report.update(status="ERROR", exception_type=type(exc).__name__,
                      reason="Unexpected implementation or environment error")
    write_json(output / "result.json", report)
    return report


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Rejected("ARGUMENTS", message)


def main(argv=None):
    parser = Parser(description=__doc__)
    parser.add_argument("configuration", choices=("all",) + CONFIGURATIONS)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[5])
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--tool")
    try:
        args = parser.parse_args(argv)
        report = run_contract(args.root, args.output, args.configuration, args.tool)
    except Rejected as exc:
        report = {"status": "REJECTED", "reason_code": exc.code, "reason": str(exc)}
    print(json.dumps(report, sort_keys=True))
    return {"PASS": 0, "REJECTED": 2, "ERROR": 3}[report["status"]]


if __name__ == "__main__":
    raise SystemExit(main())
