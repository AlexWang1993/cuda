price=100
strike=100
time=1
rate=0.02
vol=0.3
steps=10
digits=0
: '
while [ $steps -lt 120000 ]; do
    echo "Running, steps = $steps"
    ../app_debug $price $strike $time $rate $vol 1 1 $digits $steps 0 
#>> amerPutBinomialTimeResult_2.log 
    wait
    steps=$((steps*10))
done
exit
'
while [ $steps -lt 120000 ]; do
    echo "Running, steps = $steps"
    ../app_debug $price $strike $time $rate $vol 1 0 $digits $steps 0 #>> putBinomialTimeResult_2.log 
    if [ $steps -lt 205000 ]; then
        ../cpu_app_debug $price $strike $time $rate $vol 1 0 $steps 0 #>> putCpuBinomial_2.log 
    fi
    wait
    steps=$((steps*10))
done
steps=500
while [ $steps -lt 50000 ]; do
    echo "Running, steps = $steps"
    ../app_debug $price $strike $time $rate $vol 0 0 $digits $steps 0 >> callBinomialTimeResult_2.log 
    if [ $steps -lt 205000 ]; then
        ../cpu_app_debug $price $strike $time $rate $vol 0 0 $steps 0 >> callCpuBinomial_2.log 
    fi
    wait
    steps=$((steps*2))
done
echo "DONE"
