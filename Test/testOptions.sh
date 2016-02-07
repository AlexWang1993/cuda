#!/bin/bash
while IFS=, read price strike vol rate time c p
do
    echo "Running with $price $strike $time $rate $vol" >&2
    # USAGE: ./app <price> <strike> <time to exp> <rate> <volatility> <option type> <type> <steps> <lattice method> 
    # Run app with European Call option with binomial lattice
    ../app_debug $price $strike $time $rate $vol 0 0 20480 0 >> binCallResult.log &
    # Run app with European Call option with no arb lattice
    ../app_debug $price $strike $time $rate $vol 0 0 20480 1 >> noArbCallResult.log &
    # Run app with European Call option with drifting lattice
    ../app_debug $price $strike $time $rate $vol 0 0 20480 2 >> driftCallResult.log &
    # Run app with European Call option with binomial lattice
    ../app_debug $price $strike $time $rate $vol 1 0 20480 0 >> binPutResult.log &
    # Run app with European Call option with no arb lattice
    ../app_debug $price $strike $time $rate $vol 1 0 20480 1 >> noArbPutResult.log &
    # Run app with European Call option with drifting lattice
    ../app_debug $price $strike $time $rate $vol 1 0 20480 2 >> driftPutResult.log &
    echo "$price, $strike, $time, $rate, $vol, $c" >> callValue.log &
    echo "$price, $strike, $time, $rate, $vol, $p" >> putValue.log &
    wait
done < tests.csv

echo "PRICE, STRIKE, TIME, RATE, VOL, ACTUAL, BIN, NOARB, DRIFT" > callResults.log
echo "PRICE, STRIKE, TIME, RATE, VOL, ACTUAL, BIN, NOARB, DRIFT" > putResults.log
#paste -d "," callValue.log binCallResult.log noArbCallResult.log driftCallResult.log >> callResults.log
#paste -d "," putValue.log binPutResult.log noArbPutResult.log driftPutResult.log >> putResults.log

#rm putValue.log callValue.log driftCallResult.log driftPutResult.log noArbCallResult.log noArbPutResult.log binCallResult.log binPutResult.log
