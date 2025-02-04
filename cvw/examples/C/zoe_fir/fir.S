// fir.s
// Zoe Worrall - zworrall@g.hmc.edu, Feb 3, 2025
// do a weird fir method that we're supposed to make from class ;-;


//     for (int j=0; j<=n-m; j += 1) {
//         y[j] = 0;
//         for (int i=0; i<m; i += 1) {
//             y[j] = add_q31(y[j], mul_q31(c[i], x[j - i + m - 1]));
//         }
//     }
//     return;
// }

.global fir
fir:
    addi sp, sp, -16
    sd s0, 0(sp)        # j
    sd s1, 8(sp)        # i

    li s0, 0            # j = 0
    li s1, 0            # i = 0

    # a0 = x, a1 = c, a2 = y, a3 = m, a4 = n

    sub s2, a3, a4      # s2 = m-n
    j fir_2

fir_1:
    bgt s0, s2, done     # if j > m-n, go to done loop
    li s1, 0             # set a3 (i.e. i) = 0
    addi s0, s0, 1       # set a4 (i.e. j)++

fir_2:
    bgt s1, a3, fir_1    # if i > m, go to outer for loop
    
    sub t0, s0, s1       # save j - i
    addi t1, a3, -1      # save m-1
    add t2, t0, t1       # save j-n+m-1 in t2
    li t3, 4             # keep t3 in 4
    mul t2, t2, t3       # the index in the x array should be multiplied by 4
    
    # index location
    add t0, a2, t2       # address of x + INDEX ( j-1+m-1 )
    sw s8, 0(t0)         # put value in s8

    mul t1, s1, t3       # INDEX location of i
    add t1, a1, t1       # address of c + INDEX
    lw s9, 0(t1)         # save c[i] in s9

    # use mul_q31 ( c[i] * x[j-i + m-1] ) -- saves in x3
    jal x3, mul_q31

    lw s9, (x3)          # save output of mul_q31 into s9

    # calculate address j
    mul t1, s0, t3     # index from j (diff * 4)
    add t1, t1, a2     # we're at a2 + t1  (j*4 + a2)
    lw s8, 0(t1)       # save into s8 index

    jal x3, add_q31

    # store word output back into index
    sw x3, 0(t1)

    addi s1, s1, 1  # i++

    j fir_2            # start fir_2 loop again


mul_q31:
    mul x3, s9, s8    # save s8+s9 in s10
    ret

add_q31:
    add x3, s9, s8    # save s5+s6 in s7
    ret

done:
    mv a0, a2           # put result in a0 to return
    ld s0, 0(sp)        # restore s0 and s1 from stack
    ld s1, 8(sp)
    addi sp, sp, 16  
    ret                 # return from function