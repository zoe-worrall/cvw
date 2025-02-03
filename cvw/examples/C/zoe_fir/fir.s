# 0 "fir.S"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 0 "<command-line>" 2
# 1 "fir.S"
.section .text.init
.globl rvtest_entry_point # label rvtest_entry_point viewable by other files
rvtest_entry_point: # label expected by linker that indicates start of program

    li s1, 20 # n
    li s2, 4 # m

    # y value
    li a2, zero

    # i value
    li a3, zero

    # j value
    li a4, zero

    sub s3, s1, s2 # n - m

    # s4 is the x[i] array
    ld 0x00000000, s4(0)
    ld 0x4B3C8C12, s4(1)
    ld 0x79BC384D, s4(2)
    ld 0x79BC384D, s4(3)
    ld 0x4B3C8C12, s4(4)
    ld 0x00000000, s4(5)
    ld 0xB4C373EE, s4(6)
    ld 0x8643C7B3, s4(7)
    ld 0x8643C7B3, s4(8)
    ld 0xB4C373EE, s4(9)
    ld 0x00000000, s4(a)
    ld 0x4B3C8C12, s4(b)
    ld 0x79BC384D, s4(c)
    ld 0x79BC384D, s4(d)
    ld 0x4B3C8C12, s4(e)
    ld 0x00000000, s4(f)
    ld 0xB4C373EE, s4(10)
    ld 0x8643C7B3, s4(11)
    ld 0x8643C7B3, s4(12)
    ld 0xB4C373EE, s4(13)

    # s5 is the c[i] array
    ld 0x20000001, s11(0)
    ld 0x20000002, s11(1)
    ld 0x20000003, s11(2)
    ld 0x20000004, s11(3)

fir_1:
    bgt a4, s1, done # if j > m-n, go to done loop
    li a3, zero # set s6 = i = 0
    addi a4, 1 # set j++
    li s7, zero

fir_2:
    bgt a3, s2, fir_1 # if i > m, go to outer for loop

    sub t0, a4, a3 # save j - n
    addi t1, s2, -1 # save m-1
    add t2, t0, t1 # save as j-n+m-1
    li s8, s4(t2) # save x[index] in s8
    li s9, s11(s2) # save c[i]
    jal mul_q31 # jump to the multiplication matrix. save solution in s10

    add s7, s7, s10
    sd s7, a2(a4)
    # save y as a value

    addi a3, 1 # i++
    j fir_2 # start fir_2 loop again


mul_q31:
    mul s10, s9, s8 # save s8+s9 in s10
    ret

add_q31:
    add s7, s5, s6 # save s5+s6 in s7
    ret

done:

self_loop:
    j self_loop # infinite loop
