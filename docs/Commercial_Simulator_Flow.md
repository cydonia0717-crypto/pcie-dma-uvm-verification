# VCS / Verdi Flow

The public qualification baseline uses Verilator 5.052 plus UVM because GitHub-hosted CI does not provide commercial EDA licenses.  A separate VCS/Verdi path is maintained for an industry-style local environment.

## Prerequisites

- Synopsys VCS with SystemVerilog/UVM support
- Verdi for waveform/debug database browsing
- URG for merged code coverage
- a valid local license setup

## Commands

```bash
bash scripts/setup_dut.sh
make vcs-smoke
make vcs-regression
make verdi
```

`run_vcs.sh` compiles with `-debug_access+all -kdb` and line/condition/toggle/branch coverage.  Each run writes a separate VDB, and `vcs_regression.sh` merges them with URG when `urg` is available.

## Evidence boundary

These scripts are provided and statically maintained, but the repository does **not** claim VCS/URG results until they are executed on a licensed machine.  Resume metrics currently come from the reproducible public Verilator/UVM qualification flow only.
