objects = main.o lattice.o
CXXFLAGS = --compiler-options -Wall

all: $(objects) cpu
	nvcc $(objects) $(CXXFLAGS) -o app

cpu: cpu_lattice.cc
	nvcc $(CXXFLAGS) cpu_lattice.cc -o cpu_app

cpu2: cpu_lattice.cc
	g++ -D FIND_TIME cpu_lattice.cc -o cpu_app

cpu3: cpu_lattice2.cc
	g++ -D FIND_TIME cpu_lattice2.cc -o cpu_app2

%.o: %.cu
	nvcc $(CXXFLAGS) -c $< 

test: all cpu_test
	./app 10 10 0.1 0.02 0.2 0 0 5 25000 0

cpu_test: cpu 
	./cpu_app 10 10 0.1 0.02 0.2 0 0 25000

timeExec: cpu_lattice.cc lattice.cu main.cu lattice.h
	nvcc $(CXXFLAGS) -D FIND_TIME cpu_lattice.cc -o cpu_app_debug
	nvcc $(CXXFLAGS) -D FIND_TIME -c lattice.cu -o lattice_debug.o
	nvcc $(CXXFLAGS) -D FIND_TIME -c main.cu -o main_debug.o
	nvcc $(CXXFLAGS) main_debug.o lattice_debug.o -o app_debug

option_test: timeExec
	cd Test; ./testOptions.sh

speed_test: timeExec
	cd Test; ./findTime.sh

clean: 
	rm -f *.o app cpu_app app_debug cpu_app_debug Test/*.log
