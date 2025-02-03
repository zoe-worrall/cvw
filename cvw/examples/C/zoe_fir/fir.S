.section .text.init
.globl rvtest_entry_point # label rvtest_entry_point viewable by other files
rvtest_entry_point: # label expected by linker that indicates start of program

    # s1 -> n
    # s2 -> m
    # s3 -> n - m

    # a2 -> y
    # a3 -> i
    # a4 -> j
    # a5 -> x
    # s11 -> c

    li s1, 20  # n
    li s2, 4   # m

    # y value
    li a2, 0

    # i value
    li a3, 0      # i value
    li a4, -1        # j value
    sub s3, s1, s2
    addi s3, s3, 1  # s3 -> n-m

    # s4 is the x[i] array
    li t0, 0x00000000
    li t1, 0x4B3C8C12
    li t2, 0x79BC384D
    li t3, 0xB4C373EE
    li t4, 0x8643C7B3

    sd t0, 0(a5)
    sd t1, 8(a5)
    sd t2, 16(a5)
    sd t2, 24(a5)
    sd t1, 32(a5)
    sd t0, 40(a5)
    sd t3, 48(a5)
    sd t4, 56(a5)
    sd t4, 64(a5)
    sd t3, 72(a5)
    sd t0, 80(a5)
    sd t1, 88(a5)
    sd t2, 96(a5)
    sd t2, 104(a5)
    sd t1, 112(a5)
    sd t0, 120(a5)
    sd t3, 128(a5)
    sd t4, 136(a5)
    sd t4, 144(a5)
    sd t3, 152(a5)
    
    # s5 is the c[i] array
    li t0, 0x20000001
    li t1, 0x20000002
    li t2, 0x20000003
    li t3, 0x20000004

    sd t0, 0(s11)
    sd t1, 8(s11)
    sd t2, 16(s11)
    sd t3, 24(s11)


    # s1 -> n
    # s2 -> m
    # s3 -> n - m

    # a2 -> y
    # a3 -> i
    # a4 -> j
    # a5 -> x
    # s11 -> c

fir_1:
    bgt a4, s1, done     # if j > m-n, go to done loop
    li a3, 0             # set s6 = i = 0
    addi a4, a4, 1       # set j++ (j starts as -1)
    li s7, 0
    addi a4, a4, 1  # i++

fir_2:
    bgt a3, s2, fir_1  # if i > m, go to outer for loop
    
    sub t0, a4, a3  # save j - i
    addi t1, s2, -1   # save m-1
    add t2, t0, t1    # save as j-n+m-1
    li t3, 8
    mul t2, t2, t3     # number of bits away

    add t2, t2, a5    # a5 is x[i]
    lw s8, 0(a5)       # save x[index] in s8

    mul t0, a3, t3
    add t0, s11, t0
    lw s9, 0(t0)    # save c[i]

    jal mul_q31       # jump to the multiplication matrix. save solution in s10
    
    add s7, s7, s10
    add a6, a5, t0    # add for the address
    sd s7, 0(a6)

    # save y as a value

    addi a3, a3, 1  # i++
    j fir_2            # start fir_2 loop again


mul_q31:
    mul s10, s9, s8    # save s8+s9 in s10
    ret

add_q31:
    add s7, s5, s6    # save s5+s6 in s7
    ret

done:

self_loop:
    j self_loop # infinite loop


## to run every time
# doing athings over and over is tiring, so we use a makefile