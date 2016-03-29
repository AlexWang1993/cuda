#include "lattice.h" 

__device__ int 
get_global_index(dim3 tid, 
                 dim3 bid, 
                 dim3 bdim)
{
    return tid.x + bid.x * bdim.x;
}

__device__ 
double compute(double coef,
               double p,
               double w1,
               double w2,
               double strike,
               double up,
               double down,
               double price,
               int ind,
               int n,
               int type)
{
    double euro = coef * (p * w2 + (1 - p) * w1);
    // double euro = (p * w2 + (1 - p) * w1);
    if (type == EUROPEAN) {
        return euro;
    }
    else if (type == AMERICAN) {
        // this is wrong becuase we need to take into account down for the drifting lattice
        // this is also wrong becuase calls
        return max(euro, max(strike - price * pow(up, 2 * ind - n), 0.0));
    }
    return 0.0;
}

__global__ void 
get_payoff(double* w, 
           double price, 
           double up,
           double down, 
           int opttype, 
           double strike, 
           int n, 
           int base)
{
    int index = get_global_index(threadIdx, blockIdx, blockDim);
    double payoff;
    while (index < n) {
        payoff = price * pow(down, n - 1 - index) * pow(up, index);
        if (opttype == CALL) {
            w[index] = payoff > strike ? payoff - strike : 0.0;
        } else {
            w[index] = strike > payoff ? strike - payoff : 0.0;
        }
        index += base;
    }
}

__global__ void
smooth_payoff(double * w, const int n){
    if (n < 5)
        return;
    int index = n / 2 - 2;
    while (w[++index] != 0);
    w[index-1] = (w[index-2] + w[index])/2;
    w[index] = (w[index-1] + w[index+1])/2;
    w[index+1] = (w[index] + w[index+2])/2;
}

__global__ void 
backward_recursion(double* w1, 
                   double* w2, 
                   int n, 
                   int base, 
                   double coef, 
                   double p, 
                   double strike, 
                   double up, 
                   double down, 
                   double price, 
                   int type)
{
    int index = get_global_index(threadIdx, blockIdx, blockDim);
    while (index < n) {
        w2[index] = compute(coef, p, w1[index], w1[index+1], strike, up, down, price, index, n, type);
        index += base;
    }
}


__global__ void 
backward_recursion_lower_triangle_multiple(double* w, 
                                           int n, 
                                           int chunk, 
                                           int len, 
                                           double coef, 
                                           double p, 
                                           double strike, 
                                           double up, 
                                           double down, 
                                           double price, 
                                           int type)
{

    int index = get_global_index(threadIdx, blockIdx, blockDim);
    int upper = min(chunk, n);

    for (int i = 0; i < upper; i++) {
        for (int j = 0; j < min(upper - i, n - i - index * upper); j++) {
            int ind = i * len + index * upper + j;
            double res = compute(coef, p, w[ind], w[ind+1], strike, up, down, price, index * upper + j, n - i - 1, type);
            w[ind + len] = res;
        }
    }   
    // __syncthreads();
}

__global__ void 
backward_recursion_upper_triangle_multiple(double* w, 
                                           int n, 
                                           int chunk, 
                                           int len, 
                                           double coef, 
                                           double p, 
                                           double strike, 
                                           double up, 
                                           double down, 
                                           double price, 
                                           int type)
{

    int index = get_global_index(threadIdx, blockIdx, blockDim);
    int upper = min(chunk, n); 

    for (int i = 1; i <= upper; i++) {
        int upper_triangle_row_len = upper - i;
        for (int j = 0; j < min(i, n - i - index * upper - upper_triangle_row_len); j++) {
            int ind = i * len + index * upper + upper_triangle_row_len + j;

            double res = compute(coef, p, w[ind], w[ind+1], strike, up, down, price, index * upper + upper_triangle_row_len + j, n - i - 1, type);
            if (i == upper) {
                w[index * upper + j] = res;
            } else {
                w[ind + len] = res;
            }   
        }   
    }   
    // __syncthreads();
}

__global__ void 
backward_recursion_lower_triangle_less_memory(double* w, 
                                              int n, 
                                              int base, 
                                              int len, 
                                              double coef, 
                                              double p, 
                                              double strike, 
                                              double up, 
                                              double down, 
                                              double price, 
                                              int type)
{
    int tid = threadIdx.x;
    
    int upper = min(THREAD_LIMIT, n); 
    // int index = get_global_index(threadIdx, blockIdx, blockDim);
    int index = blockIdx * upper + tid;

    if (index <= len) {
      w[2 * len + index - tid] = w[n % 2 * len + index - tid];
      w[3 * len + index - tid] = w[n % 2 * len + upper + index - tid - 1];
    }
    for (int k = 1; k < upper; k++) {
        if (tid < upper - k && index < n - k + 1) {
            int i = (n - k + 1) % 2 * len + index;

            double res = compute(coef, p, w[i], w[i+1], strike, up, down, price, index, n - k, type);
            w[(n - k) % 2 * len + index] = res;
            printf("level: %d, left: %d, %f, right: %d, %f, self: %d, %f\n", k, i, w[i], i+1, w[i+1], (n - k) % 2 * len + index, res);
            if (tid == 0) {
                w[2 * len + index + k] = res;
            }
            if (tid == upper - k -1) {
                w[3 * len + index - tid + k] = res; 
            }
        }   
        __syncthreads();
    }   
}

__global__ void 
backward_recursion_upper_triangle_less_memory(double* w, 
                                              int n, 
                                              int base, 
                                              int len, 
                                              double coef, 
                                              double p, 
                                              double strike, 
                                              double up, 
                                              double down, 
                                              double price, 
                                              int type)
{
    int tid = threadIdx.x;
    // int index = get_global_index(threadIdx, blockIdx, blockDim);
    int upper = min(THREAD_LIMIT, n); 

    int index = blockIdx * upper + tid;
    for (int k = 1; k <= upper; k++) {
        if (tid >= upper - k && index < n - k + 1) {

            int i_left = (n - k + 1) % 2 * len + index;
            int i_right = i_left + 1;

            if (tid == upper - k) {
              i_left = 3 * len + index - tid + k - 1;
            }
            if (tid == upper - 1) {
              i_right = 2 * len + index - tid + upper + k - 1;
            }
            printf("level: %d, left: %d, %f, right: %d, %f, self: %d\n", k, i_left, w[i_left], i_right, w[i_right], (n - k) % 2 * len + index);
            double res = compute(coef, p, w[i_left], w[i_right], strike, up, down, price, index, n - k, type);
            w[(n - k) % 2 * len + index] = res;
        }   
        __syncthreads();
    }   
}


__global__ void 
backward_recursion_lower_triangle(double* w, 
                                  int n, 
                                  int base, 
                                  int len, 
                                  double coef, 
                                  double p, 
                                  double strike, 
                                  double up, 
                                  double down, 
                                  double price, 
                                  int type) 

{
    int tid = threadIdx.x;
    int index = get_global_index(threadIdx, blockIdx, blockDim);
    int upper = min(THREAD_LIMIT, n);  
    for (int k = 1; k < upper; k++) {
        if (tid < upper - k && index < n - k + 1) {
            int i = (k - 1) * len + index;
            double res = compute(coef, p, w[i], w[i+1], strike, up, down, price, index, n - k, type);
            w[i + len] = res;
        }   
        __syncthreads();
    }   
}

__global__ void 
backward_recursion_upper_triangle(double* w, 
                                  int n, 
                                  int base, 
                                  int len, 
                                  double coef, 
                                  double p, 
                                  double strike, 
                                  double up, 
                                  double down, 
                                  double price, 
                                  int type)
{
    int tid = threadIdx.x;
    int index = get_global_index(threadIdx, blockIdx, blockDim);
    int upper = min(THREAD_LIMIT, n); 
    for (int k = 1; k <= upper; k++) {
        if (tid >= upper - k && index < n - k + 1) {
            int i = (k - 1) * len + index;
            double res = compute(coef, p, w[i], w[i+1], strike, up, down, price, index, n - k, type);
            if (k == upper) {
                w[index] = res;
            } else {
                w[i + len] = res;
            }   
        }   
        __syncthreads();
    }   
}
