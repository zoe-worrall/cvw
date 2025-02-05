
#include <stdio.h>  // supports printf
#include "util.h"   // supports verify

// Add two Q1.31 fixed point numbers
int64_t add_q31(int a, int b) {
    return (int64_t)a+(int64_t)b;
}

// Multiply two Q1.31 fixed point numbers
int32_t mul_q31(int a, int b) {
    int64_t res = (int64_t)((int64_t)a * (int64_t)b);    // 64-bit Q2.62
    int32_t midres = res >> 31;                  // 32-bit Q1.31
    return midres;
}

// low pass filter x with coefficients c, result in y
// n is the length of x, m is the length of c
// y[j] = c[0]*x[j] + c[1]*x[j+1] + ... + c[m-1]*x[j+m-1]
// inputs in Q1.31 format
// void fir(int x[], int c[], int y[], int n, int m) {
	// your code here, use add_q31 and mul_q31
void fir(int x[], int c[], int y[], int n, int m) {
    for (int j=0; j<=n-m; j += 1) {
        y[j] = 0;
        for (int i=0; i<m; i += 1) {
            // printf("X values: %x, xindex: %x --- C values: %x, Y value: %x\n", x[j - i + m - 1], j-i+m-1, c[i], y[j]);
            y[j] = add_q31(y[j], mul_q31(c[i], x[j - i + m - 1]));
        }
        // printf("\n");
    }
}

            //  x            c          y         n   m
// extern void fir(int32_t *, int32_t *, int32_t *, int, int);

// extern void fir(int x[], int c[], int y[], int n, int m)

int main(void) {
    // printf("we testing :D");
    // printf(":  %lxx", mul_q31(0x50000000, 0xA0000000));
    // printf("\n\n\n\n");

    int32_t sin_table[20] = { // in Q1.31 format
        0x00000000, // sin(0*2pi/10)
        0x4B3C8C12, // sin(1*2pi/10)
        0x79BC384D, // sin(2*2pi/10)
        0x79BC384D, // sin(3*2pi/10)
        0x4B3C8C12, // sin(4*2pi/10)
        0x00000000, // sin(5*2pi/10)
        0xB4C373EE, // sin(6*2pi/10)
        0x8643C7B3, // sin(7*2pi/10)
        0x8643C7B3, // sin(8*2pi/10)
        0xB4C373EE, // sin(9*2pi/10)
        0x00000000, // sin(10*2pi/10)
        0x4B3C8C12, // sin(11*2pi/10)
        0x79BC384D, // sin(12*2pi/10)
        0x79BC384D, // sin(13*2pi/10)
        0x4B3C8C12, // sin(14*2pi/10)
        0x00000000, // sin(15*2pi/10)
        0xB4C373EE, // sin(16*2pi/10)
        0x8643C7B3, // sin(17*2pi/10)
        0x8643C7B3, // sin(18*2pi/10)
        0xB4C373EE  // sin(19*2pi/10)
    };  
    int lowpass[4] = {0x20000001, 0x20000002, 0x20000003, 0x20000004}; // 1/4 in Q1.31 format
    int y[17];
    int expected[17] = { // in Q1.31 format
        0x4fad3f2f,
        0x627c6236,
        0x4fad3f32,
        0x1e6f0e17,
        0xe190f1eb,
        0xb052c0ce,
        0x9d839dc6,
        0xb052c0cb,
        0xe190f1e6,
        0x1e6f0e12,
        0x4fad3f2f,
        0x627c6236,
        0x4fad3f32,
        0x1e6f0e17,
        0xe190f1eb,
        0xb052c0ce,
        0x9d839dc6
    };
    // printf("Expected: %lx\n", expected[0]);

    int val = 20;
    setStats(1);        // record initial mcycle and minstret
    fir(sin_table, lowpass, y, 20, 4);
    setStats(0);        // record elapsed mcycle and minstret

    // printf("%x VS. %x VS. %x", &y, *y, y);

    return verify(17, y, expected); 
// check the 1 element of s matches expected. 0 means success
}

// Normal Runtime:      mcycle = 374096,     minstret = 374112
// O1 Runtime:          mcycle = 856         minstret = 863
// O2 RunTime:          mcycle = 787         minstret = 792