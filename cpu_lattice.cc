#include <iostream>
#include <cmath>
#include <time.h>
#include <cstdlib>
#include <iomanip>

#define CALL 0
#define PUT  1

#define EUROPEAN 0
#define AMERICAN 1

using namespace std;

double * getPayoff(double up, double down, double price, double strike, int n, int type){
    double * payoffs = new double[n];
    for (int i = 0; i <= n; i++){
        double payoff = price * pow(down, n - i - 1) * pow(up, i); 
        if (type == CALL)
            payoffs[i] = payoff > strike ? payoff - strike : 0.0;
        else if (type == PUT)
            payoffs[i] = payoff < strike ? strike - payoff : 0.0;
    }
    return payoffs;
}

void smooth_payoff(double * w, const int n){
    if (n < 5)
        return;
    int index = n / 2 - 2;
    while (w[++index] != 0);
    w[index-1] = (w[index-2] + w[index])/2;
    w[index] = (w[index-1] + w[index+1])/2;
    w[index+1] = (w[index] + w[index+2])/2;
}

double computeBackwards(double * payoffs, int n, double discount, double p, double strike, double price, double up, int type){
    bool fl;
    for (int j = 0 ; j <= n; j++) {
        cout << setprecision(20) << payoffs[j] << " ";
    }
    for (int i = n ; i > 0; i--){
        fl = true;
        for (int j = 0; j < i; j++){
            payoffs[j] = (payoffs[j] * (1-p) + payoffs[j+1] * p) * discount;
            if ((type == AMERICAN) && (fl == true)) {
                double payoff = strike - price * pow(up, 2 * j - i + 1);
                if (payoff > payoffs[j]) {
                    payoffs[j] = payoff;
                } else {
                    fl = false;
                }
            }
#ifdef DEBUG
            cout << setprecision(20) << payoffs[j] << " ";
#endif
        }
#ifdef DEBUG
        cout << endl;
#endif
    }
    return payoffs[0];
}

int main(int argc, char* argv[]){
    if (argc < 8)
        return 1;
    //parameters passed from command line
    double price = atof(argv[1]), strike = atof(argv[2]), time = atof(argv[3]), 
           rate = atof(argv[4]), sigma = atof(argv[5]);
    //opttype -> call or put, type -> euro or amer
    int opttype = atoi(argv[6]), type = atoi(argv[7]), 
        nsteps = atoi(argv[8]);

    // if we want to price american
    (void) type;

    if (nsteps > 500000){
        return 2;
    }

    //computational constants
    double delt = time / nsteps, c = exp(-rate * delt); 
    // model constants:
    double up = exp(sigma * sqrt(delt)), down = 1 / up;

    double prob = (1 + (rate / sigma - sigma / 2)*sqrt(delt))/2;

    double * payoffs = getPayoff(up, down, price, strike, nsteps + 1, opttype);
    smooth_payoff(payoffs, nsteps + 1);

#ifdef DEBUG
    cout << "p " << prob  << " up " << up << " down " << down << " discount " << c << endl;
    for (int i= 0; i < nsteps + 1; i++)
        cout << "Payoff " << setprecision(20) << payoffs[i] << endl;
#endif

#ifdef FIND_TIME 
    clock_t start = clock();
#endif
    double ans = computeBackwards(payoffs, nsteps, c, prob, strike, price, up, type);


#ifdef FIND_TIME 
    clock_t end = clock() - start;
    cout << setprecision(20) << ((float)end) / CLOCKS_PER_SEC << ", " ;
#endif

    cout << setprecision(20) << ans << endl;
}
