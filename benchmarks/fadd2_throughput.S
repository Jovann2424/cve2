.option norvc
.section .text
.globl _start

_start:
    # Four independent accumulators; each receives two sequential FADD.S adds.
    li      t0, 0x3f800000
    fmv.w.x f0, x0
    fmv.w.x f3, x0
    fmv.w.x f6, x0
    fmv.w.x f9, x0
    fmv.w.x f1, t0
    fmv.w.x f2, t0
    fmv.w.x f4, t0
    fmv.w.x f5, t0
    fmv.w.x f7, t0
    fmv.w.x f8, t0
    fmv.w.x f10, t0
    fmv.w.x f11, t0

fadd_throughput_begin:
    # 25 rounds x 8 FADD.S = 200 instructions and 200 FP additions.
    # Each round computes four equivalent two-step triple sums.
    .rept 25
        fadd.s  f0, f0, f1, rne
        fadd.s  f3, f3, f4, rne
        fadd.s  f6, f6, f7, rne
        fadd.s  f9, f9, f10, rne

        fadd.s  f0, f0, f2, rne
        fadd.s  f3, f3, f5, rne
        fadd.s  f6, f6, f8, rne
        fadd.s  f9, f9, f11, rne
    .endr
fadd_throughput_end:

    # Each accumulator is 50.0 = 0x42480000.
    li      t1, 0x1000
    fmv.x.w t2, f0
    sw      t2, 0(t1)
    fmv.x.w t2, f3
    sw      t2, 4(t1)
    fmv.x.w t2, f6
    sw      t2, 8(t1)
    fmv.x.w t2, f9
    sw      t2, 12(t1)

    li      t2, 0x20000
    li      t1, 0x1000
    sw      t1, 4(t2)
    li      t1, 0x1010
    sw      t1, 8(t2)
    li      t1, 1
    sw      t1, 0(t2)

done:
    j       done
