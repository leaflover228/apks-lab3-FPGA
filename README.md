# Lab III: SPI master (variant 30, Verilog)

SPI master, mode 0 (CPOL=0, CPHA=0), MSB first, 8 bit, configurable SCK divider.

## Structure
- `rtl/spi_master.v`: synthesizable design
- `tb/spi_master_tb.v`: self-checking testbench with behavioural slave
- `docs/`: FSM diagram, waveform screenshots, synthesis reports and etc
- `Makefile`: `make sim`, `make wave`, `make report`, `make clean`

## Ports
| Port | Dir | Description |
|---|---|---|
| clk, rst_n | in | system clock, active-low sync reset |
| start | in | 1-cycle pulse, begins a transfer |
| data_in[7:0] | in | byte to send |
| data_out[7:0] | out | received byte, valid on `done` |
| busy, done | out | transfer in progress / 1-cycle end pulse |
| sck, mosi, ss_n | out | SPI lines |
| miso | in | SPI input |

`f_sck = f_clk / (2 * CLK_DIV)`

## Run
```
make sim      # compile + run testbench
make wave     # open GTKWave
make report   # yosys + nextpnr: resources and Fmax
```

## FSM
IDLE -> SETUP -> TRANSFER (8 bits) -> FINISH -> IDLE
