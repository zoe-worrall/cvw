.section .text.init

.global rvtest_entry_point
rvtest_entry_point:
    la sp, topofstack   # Initialize stack pointer

    # a0 = x, a1 = c, a2 = y, a3 = m, a4 = n

    la t0, X            # get address of N in data
    ld a0, 0(t0)        # load x
    la t1, C            # get address of N in data
    ld a1, 0(t1)        # load c
    la t2, Y            # get address of N in data
    ld a2, 0(t2)        # load y
    la t3, N            # get address of N in data
    ld a3, 0(t3)        # load n
    la t4, M            # get address of N in data
    ld a4, 0(t4)        # load m


    csrr s8, instret    # count instructions before call

    jal fir             # call fir(X, C, Y, M, N)

    csrr s9, instret    # count instructions after call

    sub s9, s9, s8      # length of call

    la t0, begin_signature  # address of signature

    sd a0, 0(t0)        # store sum(N) in signature
    
    sd s9, 8(t0)        # record performance

write_tohost:
    la t1, tohost
    li t0, 1            # 1 for success, 3 for failure
    sd t0, 0(t1)        # send success code

self_loop:
    j self_loop         # wait
    
.section .tohost 
tohost:                 # write to HTIF
    .dword 0
fromhost:
    .dword 0

.data
X:
    .dword 4

    .data
C:
    .dword 4

.data
Y:
    .dword 4

.data
M:
    .dword 4

.data
N:
    .dword 4

.EQU XLEN,64
begin_signature:
    .fill 2*(XLEN/32),4,0xdeadbeef    # 
end_signature:

# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:

////////

# .global fir # label rvtest_entry_point viewable by other files
# fir: # label expected by linker that indicates start of program

#     # s1 -> n
#     # s2 -> m
#     # s3 -> n - m
#     # s4 -> x
#     # s5 -> c
#     # s6 -> added to c in add_q31
    
#     # s8 -> used in mul_q31
#     # s9 -> used in mul_q31

#     # a2 -> y
#     # a3 -> i
#     # a4 -> j

#     j fir_2    # jump to the inner for loop

#     # for loop 1
# fir_1:
#     bgt a4, s1, done     # if j > m-n, go to done loop
#     li a3, 0             # set a3 (i.e. i) = 0
#     addi a4, a4, 1       # set a4 (i.e. j)++

# fir_2:
#     bgt a3, s2, fir_1    # if i > m, go to outer for loop
    
#     sub t0, a4, a3       # save j - i
#     addi t1, s2, -1      # save m-1
#     add t2, t0, t1       # save j-n+m-1 in t2
#     li t3, 4             # keep t3 in 4
#     mul t2, t2, t3       # the index in the x arx3y should be multiplied by 4
    
#     # index location
#     add t0, s4, t2
#     sw s8, 0(t0)         # address of x + INDEX ( j-1+m-1 ) in s8

#     mul t1, a3, t3       # INDEX location of i
#     add t1, s5, t1      # address of c + INDEX
#     lw s9, 0(t1)         # save c[i] in s9

#     # use mul_q31 ( c[i] * x[j-i + m-1] ) -- saves in x3
#     jal x3, mul_q31

#     lw s9, (x3)          # save output of mul_q31 into s9

#     # calculate address j
#     mul t1, a4, t3     # index from j (diff * 4)
#     add t1, t1, a2    # we're at a2 + t1  (j*4 + a2)
#     lw s8, 0(t1)       # save into s8 index

#     jal x3, add_q31

#     # store word output back into index
#     sw x3, 0(t1)

#     addi a3, a3, 1  # i++

#     j fir_2            # start fir_2 loop again


# mul_q31:
#     mul x3, s9, s8    # save s8+s9 in s10
#     ret

# add_q31:
#     add x3, s9, s8    # save s5+s6 in s7
#     ret

# done:

# self_loop:
#     j self_loop # infinite loop


## to run every time
# doing athings over and over is tiring, so we use a makefile



    # li s1, 20  # n
    # li s2, 4   # m

    # # i value
    # li a3, 0         # i value = 0
    # li a4, 0         # j value = 0
    # sub s3, s1, s2   # s3 = n-m

    # # return register (not ra for some reason?)
    # li x3, 0

    # # s4 is the x[i] array
    # li t0, 0x00000000 
    # li t1, 0x4B3C8C12
    # li t2, 0x79BC384D
    # li t3, 0xB4C373EE
    # li t4, 0x8643C7B3

    # # make array of x
    # addi s4, s4, -76
    # sw t0, 0(s4)
    # sw t1, 4(s4)
    # sw t2, 8(s4)
    # sw t2, 12(s4)
    # sw t1, 16(s4)
    # sw t0, 20(s4)
    # sw t3, 24(s4)
    # sw t4, 28(s4)
    # sw t4, 32(s4)
    # sw t3, 36(s4)
    # sw t0, 40(s4)
    # sw t1, 44(s4)
    # sw t2, 48(s4)
    # sw t2, 52(s4)
    # sw t1, 56(s4)
    # sw t0, 60(s4)
    # sw t3, 64(s4)
    # sw t4, 68(s4)
    # sw t4, 72(s4)
    # sw t3, 76(s4)
    
    # # s5 is the c[i] array
    # li t0, 0x20000001
    # li t1, 0x20000002
    # li t2, 0x20000003
    # li t3, 0x20000004

    # # make array of c
    # addi s5, s5, -12
    # sd t0, 0(s5)
    # sd t1, 4(s5)
    # sd t2, 8(s5)
    # sd t3, 12(s5)