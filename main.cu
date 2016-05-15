#include "lattice.h"
#include <iostream>
#include <time.h>

double * local;
double * l;

static void usage(){
    fprintf(stderr, "usage: ./app price strike timeToExp rate volatility optionType type digits steps latticeMethod\n");
    fprintf(stderr, "\nOption Args\n\t\t price: current price for the stock\n");
    fprintf(stderr, "\t\t strike: option strike price\n");
    fprintf(stderr, "\t\t timeToExp: time to option expiry in years\n");
    fprintf(stderr, "\t\t rate: current risk free rate\n");
    fprintf(stderr, "\t\t volatility: option pricing volatility\n");
    fprintf(stderr, "\t\t optionType: 0 = Call, 1 = Put\n");
    fprintf(stderr, "\t\t type: 0 = European, 1 = American\n");
    fprintf(stderr, "\n Pricing Method Args \n");
    fprintf(stderr, "\t\t digits: Required digits of accuracy. (If this is 0, then steps will be used)\n");
    fprintf(stderr, "\t\t steps: Number of timesteps. (Only used if digits are 0) \n");
    fprintf(stderr, "\t\t latticeType: 0 = Binomial lattice, 1 = No arbitrage lattice, 2 = Drifting Lattice\n");
}

static void 
checkCudaError(const char* err){
    cudaError_t error = cudaGetLastError();
    if (cudaSuccess != error) {
        fprintf(stderr, "ERROR: %s, %s\n", err, cudaGetErrorString(error));
        exit(2);
    }
}

static double
computeOptionValue(
    double price,
    double strike,
    double time,
    double rate,
    double sigma,
    int opttype, 
    int type,
    int nsteps,
    int latticeType){
    //computational constants
    double delt = time / nsteps,
           coef = exp(rate * delt),
           c = exp(-rate * delt);

    // model constants:
    double up = exp(sigma * sqrt(delt)),
           down = 1 / up;

    double prob = 0.0;

    if (latticeType == 0){
        prob = (1 + (rate / sigma - sigma / 2)*sqrt(delt))/2;
    } else if (latticeType == 1){
        prob = (coef - down) / (up - down);
    } else if (latticeType == 2){
        prob = 1/2.0;
        up = exp(sigma * sqrt(delt) + 
                (rate - sigma * sigma / 2) * delt);
        down = exp(-sigma * sqrt(delt) + 
                (rate - sigma * sigma / 2) * delt);
    }


    double *w, *w1, *w2;
    int step_limit = THREAD_LIMIT * BLOCK_LIMIT;
    int len = nsteps + 1;
    size_t dsize = sizeof(double), 
        size = len * dsize;

  //  printf("%d", size);
    double* answer = (double *)malloc(dsize);


#ifdef DEBUG1
    printf("Calling method with: up: %f \n"
                                 "down: %f \n"
                                 "prob: %f \n", up, down, prob);
#endif 
    if (nsteps > TRIANGLE_CEILING) {
        cudaMalloc((void **) &w1, size);
        checkCudaError("cudaMalloc failed for w1.");
        cudaMalloc((void **) &w2, size);
        checkCudaError("cudaMalloc failed for w2.");

        get_payoff<<<BLOCK_LIMIT, THREAD_LIMIT>>>(w1, price, up, down, opttype, strike, len, step_limit);
        checkCudaError("Failed to compute payoffs.");
        smooth_payoff<<<1,1>>>(w1, len);
        checkCudaError("Failed to smooth payoffs.");

        bool alter = true;
        for (int i = nsteps; i > 0; i--, alter = !alter) {
            int block_num = min(BLOCK_LIMIT, (i / THREAD_LIMIT) + 1); 
            if (alter) {
                backward_recursion<<<block_num, THREAD_LIMIT>>>(w1, w2, i, step_limit, c, prob, strike, up, down, price, type);
                checkCudaError("Failed to do normal backward recursion.");
            } else {
                backward_recursion<<<block_num, THREAD_LIMIT>>>(w2, w1, i, step_limit, c, prob, strike, up, down, price, type);
                checkCudaError("Failed to do normal backward recursion.");
            }
        }
        if (alter) {
            cudaMemcpy(answer, w1, dsize, cudaMemcpyDeviceToHost);
        } else {
            cudaMemcpy(answer, w1, dsize, cudaMemcpyDeviceToHost);
        }
        cudaFree(w1);
        cudaFree(w2);
    } else {
	//printf("pre-debug2");
        fprintf(stderr, "space needed: %d\n", (THREAD_LIMIT + 1) * size);
        cudaMalloc((void **) &w, 4 * size);
        checkCudaError("cudaMalloc failed for w.");

	//printf("still-alive");
        get_payoff<<<BLOCK_LIMIT, THREAD_LIMIT>>>(w, price, up, down, opttype, strike, len, step_limit);
        checkCudaError("Failed to compute payoffs.");
        // if (len % 2 == 0) {
            // cudaMemcpy(w + len, w, size, cudaMemcpyDeviceToDevice);
            // local = (double *)malloc(size);
            // cudaMemcpy(local, w , size, cudaMemcpyDeviceToHost);
            // cudaMemcpy(w + len, local, size, cudaMemcpyHostToDevice);

        // }
        checkCudaError("Failed to copy payoffs.");

#ifdef DEBUG2
	//printf("debug2");
        local = (double *)malloc(size);
        cudaMemcpy(local, w, size, cudaMemcpyDeviceToHost);
        fprintf(stderr, "Array after it: %d\n", 0);

        for (int j = 0; j < len; j++){
            fprintf(stderr, "%.20f\n", local[j]);
        }

        free(local);
        fprintf(stderr, "DOne Printing pre smoothed");
#endif
        smooth_payoff<<<1,1>>>(w, len);
        cudaMemcpy(w + len, w, size, cudaMemcpyDeviceToDevice);
        checkCudaError("Failed to smooth payoffs.");

#ifdef DEBUG2
        local = (double *)malloc(size);
        cudaMemcpy(local, w +len, size, cudaMemcpyDeviceToHost);
        fprintf(stderr, "Array after it: %d\n", 0);

        for (int j = 0; j < len; j++){
            fprintf(stderr, "%f\n", local[j]);
        }

        free(local);
        fprintf(stderr, "Done Printing post smoothed");
#endif

        // for (int i = min(nsteps, TRIANGLE_CEILING); i > 0; i -= THREAD_LIMIT) {
        //     int block_num = min(BLOCK_LIMIT, (i / THREAD_LIMIT) + 2);
        //     backward_recursion_lower_triangle_less_memory<<<block_num, THREAD_LIMIT>>>(w, i, step_limit, len, c, prob, strike, up, down, price, type);
        //     checkCudaError("Failed to compute upper triangles.");
        //     backward_recursion_upper_triangle_less_memory<<<block_num, THREAD_LIMIT>>>(w, i, step_limit, len, c, prob, strike, up, down, price, type);
        //     checkCudaError("Failed to compute lower triangles.");
        // }
        int last_ans_index;
        for (int i = min(nsteps, TRIANGLE_CEILING); i > 0; i -= TRIANGLE_SIZE_PER_THREAD + 1) {
            last_ans_index = len * min(TRIANGLE_SIZE_PER_THREAD, i) ;
            int thread_num = 32;
            int block_num = min(BLOCK_LIMIT, i / (thread_num * TRIANGLE_SIZE_PER_THREAD) + 1);
            backward_recursion_lower_triangle_multiple<<<block_num, thread_num>>>(w, i, TRIANGLE_SIZE_PER_THREAD, len, c, prob, strike, up, down, price, type);
            checkCudaError("Failed to compute upper triangles.");
            backward_recursion_upper_triangle_multiple<<<block_num, thread_num>>>(w, i, TRIANGLE_SIZE_PER_THREAD, len, c, prob, strike, up, down, price, type);
            checkCudaError("Failed to compute lower triangles.");
        }
        cudaMemcpy(answer, w + last_ans_index, dsize, cudaMemcpyDeviceToHost);
        cudaMemcpy(answer, w , dsize, cudaMemcpyDeviceToHost);
        cudaFree(w);
        // answer[0] = answer[0] * pow(c, nsteps);
    }

    return answer[0];
}

int main(int argc, char* argv[])
{
    if (argc < 11) {
        fprintf(stderr, "ERROR: Wrong number of arguments. See README.txt for usage.\n");
        usage();
        return 1;
    }
    //parameters passed from command line
    double price = atof(argv[1]),
           strike = atof(argv[2]),
           time = atof(argv[3]),
           rate = atof(argv[4]),
           sigma = atof(argv[5]);
    int opttype = atoi(argv[6]),
        type = atoi(argv[7]),
        digits = atoi(argv[8]),
        nsteps = atoi(argv[9]),
        latticeType = atoi(argv[10]);
#ifdef FIND_TIME 
    clock_t start = clock();
#endif
    cudaSetDevice(0);
    cudaDeviceSynchronize();
    cudaThreadSynchronize();
    double prev_ans = computeOptionValue(price, strike, time, rate, sigma,
                                    opttype, type, nsteps, latticeType);
    if (digits == 0 && nsteps > 0){
        // no op, already computed our answer
    } else if (digits > 0){
        // impossible option price
        double ans = -5.0;
        int steps = 2500;
        while (abs(ans - prev_ans) > pow(10, -digits)){
            prev_ans = ans;
            ans = computeOptionValue(price, strike, time, rate, sigma,
                                        opttype, type, steps, latticeType);
            steps *= 2;
        }
    } else {
        fprintf(stderr, "ERROR: digits and nsteps = 0\n");
        usage();
        return 1;
    }
#ifdef FIND_TIME 
    clock_t end = clock() - start;
    printf("%.20f, ", ((float)end) / CLOCKS_PER_SEC);
#endif

    printf("%.20F\n", prev_ans);
    return 0;
}
