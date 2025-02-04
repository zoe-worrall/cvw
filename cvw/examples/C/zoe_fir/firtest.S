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

# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:
