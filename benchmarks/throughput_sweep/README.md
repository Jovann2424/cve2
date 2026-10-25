# Throughput sweep

There are eight workloads for each implementation. Repetitions is the number of rounds.
Each round performs the same arithmetic work in both programs:
- FADD3: 4 instructions, each with two cascaded FP additions = 8 additions.
- FADD.S: 8 instructions = 8 additions.

The operands are nonzero, varied, exactly representable binary32 values; none is 1.0.
Both programs use the same four accumulators and operand pairs and should produce matching signatures.

| Repetitions | Equivalent FP additions | Range |
|---:|---:|---|
| 25 | 200 | low |
| 50 | 400 | low |
| 75 | 600 | low |
| 100 | 800 | low endpoint |
| 100 | 800 | high start; repeated boundary measurement |
| 400 | 3200 | high |
| 700 | 5600 | high |
| 1000 | 8000 | high |

Build each source to an ELF with the same toolchain options as the existing benchmarks.
For example, from the repository root:

riscv64-unknown-elf-gcc -march=rv32imf -mabi=ilp32f -nostdlib -nostartfiles -Wl,-Ttext=0x0 -Wl,--no-relax -o fadd3_low_25.elf benchmarks/throughput_sweep/fadd3_low_25.S

The source basenames identify the workload. Run each ELF with the existing Verilator compliance executable and a unique tracer filename.

Measure the loop interval from the trace:
1. Get fadd3_throughput_begin and fadd3_throughput_end addresses with riscv64-unknown-elf-nm -n <elf>. Use the corresponding fadd2 symbols for FADD.S.
2. Find the cycle of the first instruction at the begin address and the cycle of the first instruction at the end address.
3. Record end cycle minus begin cycle in region_cycles in measurements.csv. The end label is immediately after the arithmetic loop, so the interval includes loop stalls and excludes setup and signature code.

Throughput is calculated as fp_additions divided by region_cycles. This reports additions per simulated clock cycle, not a comparison of physical clock frequencies.

After filling every region_cycles cell, run python3 benchmarks/throughput_sweep/plot_throughput.py.
It writes throughput_comparison.png. The plotting script requires matplotlib.
