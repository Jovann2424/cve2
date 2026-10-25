.option norvc
.section .text
.globl _start

.macro FADD3 rd, rs1, rs2, rs3
    .word (((\rs3) << 27) | ((\rs2) << 20) | ((\rs1) << 15) | ((\rd) << 7) | 0x0b)
.endm

_start:
    li      t0, 0x3f800000
    fmv.w.x f0, x0
    fmv.w.x f1, t0
    fmv.w.x f2, t0

fadd3_latency_begin:
    # 25 dependent instructions; each computes (acc + 1.0) + 1.0.
    .rept 25
        FADD3 0, 0, 1, 2
    .endr
fadd3_latency_end:

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


