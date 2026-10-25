.option norvc
.section .text
.globl _start

.macro FADD3 rd, rs1, rs2, rs3
    .word (((\rs3) << 27) | ((\rs2) << 20) | ((\rs1) << 15) | ((\rd) << 7) | 0x0b)
.endm

_start:
    # Four independent accumulators; each FADD3 adds 1.0 twice.
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

fadd3_throughput_begin:
    # 25 rounds x 4 independent FADD3 = 100 instructions.
    # Total arithmetic work: 200 FP additions.
    .rept 25
        FADD3 0, 0, 1, 2
        FADD3 3, 3, 4, 5
        FADD3 6, 6, 7, 8
        FADD3 9, 9, 10, 11
    .endr
fadd3_throughput_end:

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


