#include <stdio.h>
#include <cuda.h>
#include <math.h>
#include <stdlib.h>

#ifndef LATTICE
#define LATTICE

#define BLOCK_LIMIT 65535
#define THREAD_LIMIT 1024
#define TRIANGLE_CEILING 65535 * 1024
#define TRIANGLE_SIZE_PER_THREAD 800

#define EUROPEAN 0
#define AMERICAN 1

#define CALL 0
#define PUT 1

__device__ int get_index(dim3 tid, dim3 bid, dim3 bdim);

__global__ void get_payoff(double* w, double price, double up,
        double down, int opttype, double strike, int n, int base);

__global__ void backward_recursion(double* w1, double* w2,
        int n, int base, double discount, double p, double strike,
        double down, double up, double price, int type);

__global__ void backward_recursion_lower_triangle(double* w,
        int n, int base, int len, double discount, double p,
        double strike, double up, double down, double price, int type);

__global__ void backward_recursion_upper_triangle(double* w,
        int n, int base, int len, double discount, double p,
        double strike, double up, double down, double price, int type);

__global__ void smooth_payoff(double *w, int n);

#endif
