# Build SystemC co-sim top (run inside `nix develop`)
LIBSOC       ?= $(error LIBSOC not set; run inside nix develop)
SYSTEMC_HOME ?= $(error SYSTEMC_HOME not set)
VERILATOR    ?= verilator
VROOT        := $(shell $(VERILATOR) --getenv VERILATOR_ROOT)
OBJ          := obj_dir

CFLAGS   += -O2 -g
CXXFLAGS += -std=c++17 -O2 -g
CPPFLAGS += -I$(SYSTEMC_HOME)/include -I$(OBJ) -I$(VROOT)/include -I$(VROOT)/include/vltstd \
            -I$(LIBSOC) -I$(LIBSOC)/libremote-port -I$(LIBSOC)/soc/xilinx/zynq \
            -I$(LIBSOC)/tests -I$(LIBSOC)/tests/test-modules
LDLIBS   += -L$(SYSTEMC_HOME)/lib -Wl,-rpath,$(SYSTEMC_HOME)/lib -lsystemc -pthread

LIBSOC_SRCS = \
	soc/xilinx/zynq/xilinx-zynq.cc \
	libremote-port/remote-port-tlm.cc \
	libremote-port/remote-port-tlm-memory-master.cc \
	libremote-port/remote-port-tlm-memory-slave.cc \
	libremote-port/remote-port-tlm-wires.cc \
	libremote-port/remote-port-tlm-ats.cc \
	libremote-port/remote-port-proto.c \
	libremote-port/remote-port-sk.c \
	libremote-port/safeio.c
LIBSOC_OBJS = $(addprefix build/,$(addsuffix .o,$(notdir $(basename $(LIBSOC_SRCS)))))

VACCEL = $(OBJ)/Vaccel__ALL.a

vpath %.cc $(addprefix $(LIBSOC)/,$(sort $(dir $(LIBSOC_SRCS))))
vpath %.c  $(addprefix $(LIBSOC)/,$(sort $(dir $(LIBSOC_SRCS))))

top: build/top.o $(LIBSOC_OBJS) $(VACCEL)
	$(CXX) -o $@ $^ $(OBJ)/libverilated.a $(LDLIBS)

build/top.o: top.cc $(VACCEL)
build/%.o: %.cc | build
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c -o $@ $<
build/%.o: %.c | build
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<
build:
	mkdir -p $@

$(VACCEL): ../rtl/accel.sv
	SYSTEMC_INCLUDE=$(SYSTEMC_HOME)/include SYSTEMC_LIBDIR=$(SYSTEMC_HOME)/lib \
	$(VERILATOR) --sc --pins-bv 2 --build -j 0 --Mdir $(OBJ) \
		-CFLAGS -std=c++17 $<

clean:
	rm -rf $(OBJ) build top

.PHONY: clean
