# Copilot Instructions for CV32E40P Codebase

## Overview
- This repository implements the CV32E40P: a 32-bit, 4-stage, in-order RISC-V core with optional PULP, FPU, and ZFINX extensions.
- Major RTL is in `rtl/`, with the top-level module in `rtl/cv32e40p_top.sv` and the core in `rtl/cv32e40p_core.sv`.
- Minimal testbenches are in `example_tb/` for basic sanity checks. Full verification is external (see below).
- Documentation is in `docs/` (reStructuredText, Sphinx build).

## Key Workflows
- **Linting:** Use scripts in `scripts/lint/` with SiemensEDA Questa AutoCheck. Run `./lint.sh <config>` (see config naming in the lint README).
- **Formal Coverage:** Use `scripts/formal/` with Siemens Questa Formal. Run `make run` or variants for different core configs.
- **ISA Formal Verification:** Use `scripts/riscv_isa_formal/` with Siemens Questa Processor. Run `make` with appropriate variables (see README for configs).
- **SLEC (Logic Equivalence):** Use `scripts/slec/` with Synopsys, Cadence, or Siemens tools. Run `./run.sh` with tool and parameter options.
- **Testbenches:** Minimal testbench in `example_tb/`. Use `make firmware-vsim-run` (requires RISC-V toolchain, set `RISCV` env var). For full verification, see [core-v-verif](https://github.com/openhwgroup/core-v-verif).
- **Formatting:** Run `./util/format-verible` to auto-format RTL with Verible.

## Project Conventions
- **Parameterization:** Top-level and core modules are highly parameterized (PULP, FPU, ZFINX, etc.). Use config directories and wrapper modules for different builds.
- **No mixed RTL/doc PRs:** Do not mix changes to `rtl/` and `docs/` in a single PR.
- **Changelog:** PRs must be labeled for changelog automation (see main README for label rules).
- **Coding Style:** Follow [lowRISC Verilog style guide](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md).
- **Frozen RTL:** Some parameter sets are "frozen"; only logic-equivalent changes are allowed for these (see SLEC README).

## Integration & External Dependencies
- **Verification:** Full verification is external to this repo (see [core-v-verif](https://github.com/openhwgroup/core-v-verif)).
- **Toolchains:** Requires RISC-V GCC (upstream or PULP variant) and SiemensEDA/Cadence/Synopsys tools for advanced flows.
- **Golden Reference:** SLEC scripts use tagged releases as golden RTL for equivalence checking.

## Examples
- To lint with PULP+FPU: `cd scripts/lint && ./lint.sh 1p_1f_0z_0lat_0c`
- To run formal coverage: `cd scripts/formal && make run_pulp_F0`
- To run testbench: `cd example_tb && make firmware-vsim-run RISCV=<toolchain-path>`

## Key Files & Directories
- `rtl/` — Main RTL source (SystemVerilog)
- `example_tb/` — Minimal testbench and scripts
- `scripts/` — Lint, formal, SLEC, and ISA formal flows
- `docs/` — Documentation (Sphinx/reST)
- `util/format-verible` — RTL formatting script

---
For more, see the main `README.md` and each script's README for tool-specific details.
