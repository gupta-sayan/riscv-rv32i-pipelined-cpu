#!/bin/bash
# Runs the portable lint runner's 4 Verilator commands on a tree; prints normalized warnings.
root=$1; cd $root
srcs=$(cd $root && find rtl -name '*.sv' | LC_ALL=C sort)
for cfg in core_trace0 core_trace1 bench_trace0 bench_trace1; do
  t=${cfg: -1}; w=$(mktemp -d)
  if [[ $cfg == bench* ]]; then top=tb_rv32i_core_top; extra="--timing tb/integration/tb_rv32i_core_top.sv"; else top=rv32i_core_top; extra=""; fi
  env -i PATH=/usr/bin:/bin LC_ALL=C LANG=C verilator --lint-only --Wall --top-module $top -GTRACE_EN=1\'b$t --Mdir $w $extra $srcs > $w/out.txt 2>&1
  rc=$?
  n=$(grep -c '^%Warning-' $w/out.txt)
  echo "$cfg exit=$rc warnings=$n"
  grep '^%Warning-' $w/out.txt | sed -E 's/:[0-9]+:[0-9]+:/:L:C:/' | sort > /tmp/lint_${2}_$cfg.txt
done
