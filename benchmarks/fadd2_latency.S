.option norvc
.section .text
.globl _start

_start:
    li      t0, 0x3f800000
    fmv.w.x f0, x0
    fmv.w.x f1, t0
    fmv.w.x f2, t0

fadd_latency_begin:
    # 25 equivalent triple sums, two dependent FADD.S instructions per sum.
    .rept 25
        fadd.s  f0, f0, f1, rne
        fadd.s  f0, f0, f2, rne
    .endr
fadd_latency_end:

    # Expected result: 50.0 = 0x42480000.
    li      t1, 0x1000
    fmv.x.w t2, f0
    sw      t2, 0(t1)
    li      t2, 0x20000
    li      t1, 0x1000
    sw      t1, 4(t2)
    li      t1, 0x1004
    sw      t1, 8(t2)
    li      t1, 1
    sw      t1, 0(t2)

done:
    j       done
