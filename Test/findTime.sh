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
while [ $steps -lt 200000 ]; do
    echo "Running, steps = $steps"
    echo "Old implementation:"
    ../app_debug $price $strike $time $rate $vol 0 0 $digits $steps 0 0 0 
    echo "Less memory:"
    ../app_debug $price $strike $time $rate $vol 0 0 $digits $steps 0 0 1 
    echo "One triangle per thread:"
    ../app_debug $price $strike $time $rate $vol 0 0 $digits $steps 0 0 2 
    if [ $steps -lt 90000 ]; then
        echo "CPU implementation:"
        ../cpu_app_debug $price $strike $time $rate $vol 0 0 $steps 0 0 
    fi
    wait

    echo ""
    steps=$((steps*10))
done
steps=10
while [ $steps -lt 200000 ]; do
    echo "Running, steps = $steps"
    ../app_debug $price $strike $time $rate $vol 1 1 $digits $steps 0 0 0 
    echo "Less memory:"
    ../app_debug $price $strike $time $rate $vol 1 1 $digits $steps 0 0 1 
    echo "One triangle per thread:"
    ../app_debug $price $strike $time $rate $vol 1 1 $digits $steps 0 0 2 
    if [ $steps -lt 90000 ]; then
        echo "CPU implementation:"
        ../cpu_app_debug $price $strike $time $rate $vol 1 1 $steps 0 0 
    fi
    wait

    echo ""
    steps=$((steps*10))
done
echo "DONE"
