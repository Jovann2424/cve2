.option norvc
.section .text
.globl _start
.globl fadd2_throughput_begin
.globl fadd2_throughput_end

_start:
    # Nontrivial, exactly representable binary32 operands.
    li      t0, 0x3fa00000
    fmv.w.x f0, t0              # accumulator 1 = 1.25
    li      t0, 0x40100000
    fmv.w.x f1, t0              # operand 1 = 2.25
    li      t0, 0x3f400000
    fmv.w.x f2, t0              # operand 2 = 0.75

    li      t0, 0x40200000
    fmv.w.x f3, t0              # accumulator 2 = 2.5
    li      t0, 0x3fc00000
    fmv.w.x f4, t0              # operand 1 = 1.5
    li      t0, 0x40500000
    fmv.w.x f5, t0              # operand 2 = 3.25

    li      t0, 0x40700000
    fmv.w.x f6, t0              # accumulator 3 = 3.75
    li      t0, 0x40900000
    fmv.w.x f7, t0              # operand 1 = 4.5
    li      t0, 0x3e000000
    fmv.w.x f8, t0              # operand 2 = 0.125

    li      t0, 0x40880000
    fmv.w.x f9, t0              # accumulator 4 = 4.25
    li      t0, 0x40300000
    fmv.w.x f10, t0             # operand 1 = 2.75
    li      t0, 0x3fa00000
    fmv.w.x f11, t0             # operand 2 = 1.25

fadd2_throughput_begin:
    # Each round performs 8 FADD.S instructions = 8 binary FP additions.
    # The order matches the two additions performed by each FADD3 accumulator.
    .rept 1000
        fadd.s  f0, f0, f1, rne
        fadd.s  f3, f3, f4, rne
        fadd.s  f6, f6, f7, rne
        fadd.s  f9, f9, f10, rne
        fadd.s  f0, f0, f2, rne
        fadd.s  f3, f3, f5, rne
        fadd.s  f6, f6, f8, rne
        fadd.s  f9, f9, f11, rne
    .endr
fadd2_throughput_end:

    # Store all four accumulators as the compliance signature.
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
