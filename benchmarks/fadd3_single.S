.option norvc
.section .text
.globl _start

# Custom FADD3 encoding: rd, rs1, rs2, rs3
.macro FADD3 rd, rs1, rs2, rs3
    .word (((\rs3) << 27) | ((\rs2) << 20) | ((\rs1) << 15) | ((\rd) << 7) | 0x0b)
.endm

_start:
    # Three distinct FP inputs:
    # f1 = 1.5, f2 = 2.25, f3 = 4.0
    li      t0, 0x3fc00000
    fmv.w.x f1, t0
    li      t0, 0x40100000
    fmv.w.x f2, t0
    li      t0, 0x40800000
    fmv.w.x f3, t0

fadd3_single_begin:
    # Exactly one arithmetic instruction: f4 = (f1 + f2) + f3 = 7.75
    FADD3   4, 1, 2, 3
fadd3_single_end:

    # Capture the result bits and store them in the signature area.
    fmv.x.w t0, f4
    li      t1, 0x1000
    sw      t0, 0(t1)

    # Signature range: [0x1000, 0x1004)
    li      t2, 0x20000
    li      t1, 0x1000
    sw      t1, 4(t2)
    li      t1, 0x1004
    sw      t1, 8(t2)
    li      t1, 1
    sw      t1, 0(t2)

done:
    j       done
