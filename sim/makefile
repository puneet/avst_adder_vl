CC              = gcc
CFLAGS		= -Wall -O3 -fPIC

DFLAGS = -relocation-model=pic -w

LDC2BINDIR = $(dir $(shell which ldc2))
VLBINDIR = $(dir $(shell which verilator))

VLATOR_SRC = euvm_dir/Vadder_avst_euvm.d euvm_dir/Vadder_avst_euvm_funcs.cpp obj_dir/Vadder_avst.cpp obj_dir/Vadder_avst.h

all: avst_adder

clean:
	rm -rf avst_adder* euvm_dir obj_dir verilator.stamp

run: avst_adder
	./avst_adder +UVM_TESTNAME=adder_avst.random_test +UVM_VERBOSITY=LOW # +UVM_OBJECTION_TRACE

verilator.stamp: ../rtl/adder_avst.v
	touch verilator.stamp
	verilator --trace --cc --euvm $^
	(cd euvm_dir; g++ -c -I ../obj_dir/ -I $(VLBINDIR)/../share/verilator/include Vadder_avst_euvm_funcs.cpp)
	(cd euvm_dir; g++ -c -I ../obj_dir/ -I $(VLBINDIR)/../share/verilator/include $(LDC2BINDIR)/../import/esdl/intf/verilator/cpp/verilated_vcd_d.cpp -o verilated_vcd_d.o)
	(cd obj_dir; make OPT=" -ggdb " -f Vadder_avst.mk Vadder_avst__ALL.a verilated.o verilated_vcd_c.o)

euvm_dir/Vadder_avst_euvm.d euvm_dir/Vadder_avst_euvm_funcs.o euvm_dir/verilated_vcd_d.o obj_dir/Vadder_avst__ALL.a obj_dir/verilated.o: verilator.stamp


avst_adder: euvm_dir/Vadder_avst_euvm.d ../testbench/adder_avst.d \
	   $(LDC2BINDIR)/../import/esdl/intf/verilator/verilated.d \
	   euvm_dir/Vadder_avst_euvm_funcs.o euvm_dir/verilated_vcd_d.o \
	   obj_dir/Vadder_avst__ALL.a \
	   obj_dir/verilated.o  obj_dir/verilated_vcd_c.o
	ldc2 -g $(DFLAGS) -Ieuvm_dir -link-defaultlib-shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared \
		-L-lphobos2-ldc-shared -L-lz3 -L-ldl $^ -L-lstdc++

