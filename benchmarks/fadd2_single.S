.option norvc
.section .text
.globl _start

_start:
    # Dva ulazna FP broja:
    # f1 = 1.5  (IEEE-754: 0x3fc00000)
    # f2 = 2.25 (IEEE-754: 0x40100000)
    # Ocekivani rezultat: f4 = 3.75 (IEEE-754: 0x40700000)
    li      t0, 0x3fc00000
    fmv.w.x f1, t0
    li      t0, 0x40100000
    fmv.w.x f2, t0

fadd2_single_begin:
    # Jedna standardna instrukcija: f4 = f1 + f2
    fadd.s  f4, f1, f2, rne
fadd2_single_end:

    # Sacuvaj bitove FP rezultata u memoriju radi provjere.
    fmv.x.w t0, f4
    li      t1, 0x1000
    sw      t0, 0(t1)

    # Signature opseg: [0x1000, 0x1004)
    li      t2, 0x20000
    li      t1, 0x1000
    sw      t1, 4(t2)
    li      t1, 0x1004
    sw      t1, 8(t2)
    li      t1, 1
    sw      t1, 0(t2)

done:
    j       done
