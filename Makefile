# ---- sources ----
TOP   = spi_master
SRC   = rtl/spi_master.v
TB    = tb/spi_master_tb.v

# ---- simulation ----
SIM_OUT = sim/sim.out
VCD     = sim/dump.vcd

# ---- synthesis (yosys + nextpnr). Change to the FPGA your teacher gives you ----
FREQ    = 50            # target clock, MHz
DEVICE  = --hx8k --package ct256     # iCE40 HX8K, replace as needed

.PHONY: all sim wave synth pnr report clean

all: sim

$(SIM_OUT): $(SRC) $(TB)
	@mkdir -p sim
	iverilog -g2012 -Wall -o $(SIM_OUT) $(TB) $(SRC)

sim: $(SIM_OUT)
	vvp $(SIM_OUT)

wave: sim
	gtkwave $(VCD) &

synth:
	@mkdir -p build docs/synth
	yosys -q -l docs/synth/yosys.log \
	  -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json build/$(TOP).json; stat"

pnr: synth
	nextpnr-ice40 $(DEVICE) --json build/$(TOP).json --freq $(FREQ) \
	  --log docs/synth/nextpnr.log -q || true

report: pnr
	@echo "=== Resources (yosys) ==="
	@grep -E "SB_LUT4|SB_DFF|Number of cells" docs/synth/yosys.log || true
	@echo "=== Timing (nextpnr) ==="
	@grep -E "Max frequency|Device utilisation|ICESTORM_LC" docs/synth/nextpnr.log || true

clean:
	rm -rf sim build
