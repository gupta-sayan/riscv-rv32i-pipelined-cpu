#!/usr/bin/env python3
"""Qualify the new portable contract using native runs and explicit controls.

All fixtures and outputs are isolated. Recorded historical controls are only a
comparison reference; this suite reports its own cases and outcomes.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
from unittest import mock

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("qualified_portable_runner",
                                            Path(__file__).with_name("portable_runner.py"))
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)


class TestFailure(Exception):
    pass


def require(value, message):
    if not value:
        raise TestFailure(message)


def render(records):
    return ("".join(
        "%Warning-" + r["category"] + ": " + r["path"] + ":"
        + str(r["line"]) + ":" + str(r["column"]) + ": "
        + r["message"] + "\n" + r["details"] for r in records)
        + "%Error: Exiting due to " + str(len(records)) + " warning(s)\n").encode()


def qualify(root, output):
    root = Path(root).resolve()
    output = R.reserve_output(root, output)
    manifest = R.load_contract(root)
    R.source_snapshot(root, manifest)
    baseline = R.read_json(root / manifest["baseline_path"])
    config = next(c for c in baseline["configurations"] if c["configuration"] == "core_trace1")
    records = config["diagnostics"]
    raw = config["origin_transcript"]["content_utf8"].encode()
    controls = []
    (output / "controls").mkdir()
    (output / "fixtures").mkdir()

    def save():
        R.write_json(output / "controls.json", controls)

    def control(cid, action, code=None, mode="offline_comparator"):
        row = {"id": cid, "mode": mode, "expected": code or "ACCEPT"}
        try:
            action()
            row.update(actual="ACCEPT", pass_=code is None)
        except R.Rejected as exc:
            row.update(actual=exc.code, pass_=code == exc.code,
                       intended_rejection=code == exc.code)
        except Exception as exc:
            row.update(actual="UNEXPECTED_EXCEPTION", pass_=False,
                       exception_type=type(exc).__name__)
        controls.append(row)
        save()

    def diagnostic(cid, payload, code, stdout=b"", exit_code=1):
        directory = output / "controls" / cid
        directory.mkdir()
        (directory / "stderr.bin").write_bytes(payload)
        (directory / "stdout.bin").write_bytes(stdout)
        R.write_json(directory / "invocation.json", {"native_exit": exit_code})
        control(cid, lambda: R.compare(stdout, payload, exit_code, records, root), code)

    def changed(field, value):
        value_records = copy.deepcopy(records)
        value_records[0][field] = value
        return render(value_records)

    added = copy.deepcopy(records)
    added.append(dict(added[0], category="LATCH", message="Unexpected synthetic warning"))
    diagnostic("N01_warning_added", render(added), "DIAGNOSTICS")
    diagnostic("N02_warning_removed", render(records[1:]), "DIAGNOSTICS")
    diagnostic("N03_category", changed("category", "LATCH"), "DIAGNOSTICS")
    diagnostic("N04_source_path", changed("path", "rtl/core/other.sv"), "DIAGNOSTICS")
    diagnostic("N05_line", changed("line", records[0]["line"] + 1), "DIAGNOSTICS")
    diagnostic("N06_column", changed("column", records[0]["column"] + 1), "DIAGNOSTICS")
    diagnostic("N07_message", changed("message", records[0]["message"] + " changed"), "DIAGNOSTICS")
    diagnostic("N08_multiline", changed("details", records[0]["details"] + " changed detail\n"), "DIAGNOSTICS")
    diagnostic("N09_multiplicity", render(records + [records[0]]), "DIAGNOSTICS")
    diagnostic("N10_same_count_remove_duplicate", render(records[1:] + [records[1]]), "DIAGNOSTICS")
    diagnostic("N11_exit_zero", raw, "NATIVE_EXIT", exit_code=0)
    diagnostic("N12_crash_exit", raw, "NATIVE_EXIT", exit_code=-11)
    diagnostic("N13_stdout_noise", raw, "CHANNEL", stdout=b"noise\n")
    diagnostic("N14_wrong_channel", b"", "CHANNEL", stdout=raw)
    diagnostic("N15_malformed_header", raw.replace(b"%Warning-", b"%Warning???-", 1), "FRAMING")
    diagnostic("N16_truncated", raw[:-1], "FRAMING")
    diagnostic("N17_missing_summary", raw.rsplit(b"%Error:", 1)[0], "FRAMING")
    diagnostic("N18_wrong_summary", raw.replace(b"5 warning(s)", b"6 warning(s)"), "FRAMING")
    diagnostic("N19_non_utf8", b"\xff" + raw, "ENCODING")
    diagnostic("N20_null_byte", raw + b"\0", "FRAMING")
    diagnostic("N21_empty_stderr", b"", "FRAMING")
    diagnostic("N22_extra_fatal", raw + b"%Error: unexpected fatal\n", "FRAMING")
    diagnostic("N23_path_escape", changed("path", "../../outside.sv"), "DIAGNOSTIC_PATH")
    diagnostic("N24_backslash_path", changed("path", "rtl\\core\\other.sv"), "DIAGNOSTIC_PATH")
    diagnostic("P01_multiline", raw, None)
    diagnostic("P02_reordered", render(list(reversed(records))), None)
    dot_records = [dict(r, path="./" + r["path"]) for r in records]
    diagnostic("P03_dot_relative", render(dot_records), None)
    absolute = [dict(r, path=str(root / r["path"])) for r in records]
    diagnostic("P04_absolute_within_root", render(absolute), None)

    def version_mismatch():
        result = subprocess.CompletedProcess(["version"], 0, b"Different version\n", b"")
        R.validate_version(result, manifest)
    control("N25_version_mismatch", version_mismatch, "TOOL_VERSION", "metadata_injection")

    def timeout():
        with mock.patch.object(R.subprocess, "run",
                               side_effect=subprocess.TimeoutExpired(["synthetic"], 60,
                                                                     output=b"partial")):
            R.invoke(["synthetic"], root, 60)
    control("N26_timeout", timeout, "TIMEOUT", "timeout_exception_injection")

    def missing_launch():
        with mock.patch.object(R.subprocess, "run", side_effect=FileNotFoundError()):
            R.invoke(["unavailable"], root, 60)
    control("N27_missing_launch", missing_launch, "TOOL_MISSING", "launch_failure_injection")

    def bad_command():
        changed_contract = copy.deepcopy(manifest)
        changed_contract["configurations"]["core_trace0"]["argv"][6] = "-GTRACE_EN=7"
        R.validate_contract(changed_contract)
    control("N28_invalid_parameters", bad_command, "COMMAND", "in_memory_contract_mutation")

    def bad_environment():
        changed_contract = copy.deepcopy(manifest)
        changed_contract["environment"]["LANG"] = "different"
        R.validate_contract(changed_contract)
    control("N29_environment", bad_environment, "ENVIRONMENT", "in_memory_contract_mutation")

    def clone(name):
        dest = output / "fixtures" / name
        dest.mkdir()
        names = list(manifest["sources"]) + [
            str(R.BASE / n) for n in
            ("portable_runner.py", "portable_manifest.json", "test_portable_runner.py")]
        for name in names:
            target = dest / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / name, target)
        return dest

    def cli(project, destination, extra=(), config="core_trace1", infer_root=False):
        args = [sys.executable, "-B", str(project / R.BASE / "portable_runner.py"), config,
                "--output", str(destination)]
        if not infer_root:
            args += ["--root", str(project)]
        args += list(extra)
        process = subprocess.run(args, capture_output=True, timeout=180)
        label = destination.name
        (output / (label + ".stdout.log")).write_bytes(process.stdout)
        (output / (label + ".stderr.log")).write_bytes(process.stderr)
        R.write_json(output / (label + ".command.json"), {"argv": args, "exit": process.returncode})
        try:
            report = json.loads(process.stdout)
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise TestFailure("Runner did not produce structured outcome") from exc
        return process.returncode, report

    def rejected_cli(project, destination, expected, extra=(), config="core_trace1"):
        rc, report = cli(project, destination, extra, config)
        require(rc == 2 and report.get("status") == "REJECTED"
                and report.get("reason_code") == expected,
                "Wrong rejection outcome: " + str(report.get("reason_code")))
        raise R.Rejected(expected, "Actual runner CLI rejected intended violation")

    for cid,mutation,reason in [
        ("N30_source_hash", "source_hash", "SOURCE_HASH"),
        ("N31_missing_source", "missing_source", "SOURCE_MISSING"),
        ("N32_baseline_hash", "baseline", "SOURCE_HASH"),
        ("N33_extra_source", "extra", "SOURCE_SET"),
        ("N34_source_symlink", "symlink", "SOURCE_PATH"),
        ("N35_contract_tamper", "contract", "CONTRACT_HASH")]:
        project = clone(cid)
        source = project / "rtl/core/alu.sv"
        if mutation == "source_hash":
            source.write_bytes(source.read_bytes() + b"\n")
        elif mutation == "missing_source":
            source.unlink()
        elif mutation == "baseline":
            path = project / manifest["baseline_path"]
            path.write_bytes(path.read_bytes() + b"\n")
        elif mutation == "extra":
            (project / "rtl/core/extra.sv").write_text("module extra; endmodule\n")
        elif mutation == "symlink":
            other = output / "aliased_source.sv"
            other.write_bytes(source.read_bytes())
            source.unlink()
            source.symlink_to(other)
        else:
            path = project / R.BASE / "portable_manifest.json"
            path.write_bytes(path.read_bytes() + b"\n")
        destination = output / ("execution_" + cid)
        control(cid, lambda p=project, d=destination, r=reason:
                rejected_cli(p, d, r), reason, "actual_runner_CLI")

    project = clone("tool_and_output_controls")
    control("N36_tool_fingerprint", lambda: rejected_cli(
        project, output / "wrong_tool", "TOOL_FINGERPRINT",
        ("--tool", "/usr/bin/true")), "TOOL_FINGERPRINT", "actual_runner_CLI")
    control("N37_tool_missing", lambda: rejected_cli(
        project, output / "missing_tool", "TOOL_MISSING",
        ("--tool", str(output / "absent_executable"))),
        "TOOL_MISSING", "actual_runner_CLI")
    control("N38_output_inside_root", lambda: rejected_cli(
        project, project / "unsafe_output", "OUTPUT_UNSAFE"),
        "OUTPUT_UNSAFE", "actual_runner_CLI")
    require(not (project / "unsafe_output").exists(), "Unsafe output was created")
    reused = output / "reused_output"
    reused.mkdir()
    (reused / "sentinel").write_text("preserve\n")
    control("N39_output_reuse", lambda: rejected_cli(
        project, reused, "OUTPUT_EXISTS"), "OUTPUT_EXISTS", "actual_runner_CLI")
    require((reused / "sentinel").read_text() == "preserve\n", "Existing output altered")
    control("N40_unknown_configuration", lambda: rejected_cli(
        project, output / "invalid_configuration", "ARGUMENTS", config="invalid"),
        "ARGUMENTS", "actual_runner_CLI")
    control("N41_cli_override", lambda: rejected_cli(
        project, output / "invalid_override", "ARGUMENTS",
        ("--extra-args=-Wno-fatal",)), "ARGUMENTS", "actual_runner_CLI")

    # Native qualification is performed in minimal, relocated trees.
    first = clone("native_project")
    before = {str(p.relative_to(first)): R.digest(p) for p in first.rglob("*") if p.is_file()}
    rc, native = cli(first, output / "native_four_configurations", config="all")
    require(rc == 0 and native["status"] == "PASS"
            and len(native["configurations"]) == 4, "Native qualification failed")
    for row in native["configurations"]:
        require(row["status"] == "PASS" and row["native_exit"] == 1
                and row["warning_occurrences"] == R.COUNTS[row["configuration"]]
                and row["full_multiset_equal"], "Native configuration differs")
    after = {str(p.relative_to(first)): R.digest(p) for p in first.rglob("*") if p.is_file()}
    require(before == after, "Native inputs or directory contents changed")

    second = clone("second relocated project")
    def relocated():
        rc, report = cli(second, output / "second_root_execution", infer_root=True)
        require(rc == 0 and report["status"] == "PASS"
                and report["configurations"][0]["full_multiset_equal"],
                "Relocated script-root execution failed")
    control("P05_second_root_default_detection", relocated, None, "native_relocated_root")

    failed = [r for r in controls if not r["pass_"]]
    summary = {"schema_id": "rv32i.portable-lint-qualification", "schema_version": "1.0.0",
               "record_id": "PORTABLE-QUALIFICATION",
               "status": "PASS" if not failed else "FAIL",
               "controls": len(controls), "rejection_controls": sum(r["expected"] != "ACCEPT" for r in controls),
               "positive_controls": sum(r["expected"] == "ACCEPT" for r in controls),
               "failed_controls": failed, "control_results": controls,
               "positive_configurations": native["configurations"],
               "source_inputs": native["source_inputs"], "tool": native["tool"],
               "manifest_sha256": R.MANIFEST_SHA256,
               "runner_sha256": R.digest(Path(__file__).with_name("portable_runner.py")),
               "test_suite_sha256": R.digest(__file__),
               "relocation": "Two minimal project roots; second has spaces and implicit root detection",
               "input_integrity": before == after,
               "qualification_scope": "Four native configurations plus explicit offline/CLI controls; not historical control reruns"}
    R.write_json(output / "qualification.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        summary = qualify(args.root, args.output)
    except Exception as exc:
        print(json.dumps({"status": "HARNESS_ERROR", "exception_type": type(exc).__name__,
                          "message": str(exc)}))
        return 3
    print(json.dumps({"status": summary["status"], "controls": summary["controls"],
                      "failed_controls": len(summary["failed_controls"])}))
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
