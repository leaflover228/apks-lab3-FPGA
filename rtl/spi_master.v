// ============================================================
// SPI Master, mode 0 (CPOL=0, CPHA=0), MSB first, 8 bit
// Lab III, variant 30 (SPI, Verilog)
//
// Mode 0 timing:
//   - SCK idles low
//   - MOSI changes on the falling edge of SCK
//   - MOSI/MISO are sampled on the rising edge of SCK
//
// SCK frequency: f_sck = f_clk / (2 * CLK_DIV)
// ============================================================
module spi_master #(
    parameter CLK_DIV = 4          // half-period of SCK, in clk cycles (>= 1)
)(
    input  wire       clk,         // system clock
    input  wire       rst_n,       // active-low synchronous reset

    // ---- user side ----
    input  wire       start,       // 1-cycle pulse: begin transfer (ignored if busy)
    input  wire [7:0] data_in,     // byte to send, latched on start
    output wire [7:0] data_out,    // byte received, valid when done = 1
    output wire       busy,        // 1 while a transfer is in progress
    output wire       done,        // 1-cycle pulse at the end of a transfer

    // ---- SPI side ----
    output reg        sck,         // serial clock
    output reg        mosi,        // master out, slave in
    input  wire       miso,        // master in, slave out
    output reg        ss_n         // slave select, active low
);

    // --------------------------------------------------------
    // 1. FSM state encoding
    // --------------------------------------------------------
    localparam [1:0] IDLE     = 2'd0,
                     SETUP    = 2'd1,
                     TRANSFER = 2'd2,
                     FINISH   = 2'd3;

    reg [1:0] state, next_state;

    // --------------------------------------------------------
    // 2. Internal registers
    // --------------------------------------------------------
    reg [7:0] tx_shift;                        // transmit shift register
    reg [7:0] rx_shift;                        // receive shift register
    reg [3:0] bit_cnt;                         // number of sampled bits (0..8)
    reg [$clog2(CLK_DIV+1)-1:0] div_cnt;       // clock divider counter

    // --------------------------------------------------------
    // 3. Clock divider: tick = one pulse per half-period of SCK
    //    Held at zero in IDLE and FINISH.
    // --------------------------------------------------------
    wire tick = (div_cnt == CLK_DIV - 1);

    always @(posedge clk) begin
        if (!rst_n)
            div_cnt <= 0;
        else if (state == IDLE || state == FINISH)
            div_cnt <= 0;
        else if (tick)
            div_cnt <= 0;
        else
            div_cnt <= div_cnt + 1'b1;
    end

    // --------------------------------------------------------
    // 4. FSM, block A: state register
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // --------------------------------------------------------
    // 5. FSM, block B: next-state logic
    // --------------------------------------------------------
    always @(*) begin
        next_state = state;                    // default: stay (no latches)
        case (state)
            IDLE:
                if (start)
                    next_state = SETUP;
            SETUP:
                if (tick)                      // wait t_su after SS goes low
                    next_state = TRANSFER;
            TRANSFER:
                // 8 bits sampled and the last falling edge is happening now
                if (bit_cnt == 4'd8 && tick && sck)
                    next_state = FINISH;
            FINISH:
                next_state = IDLE;
            default:
                next_state = IDLE;
        endcase
    end

    // --------------------------------------------------------
    // 6. Datapath
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            sck      <= 1'b0;
            mosi     <= 1'b0;
            ss_n     <= 1'b1;
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            bit_cnt  <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    sck     <= 1'b0;
                    ss_n    <= 1'b1;
                    bit_cnt <= 4'd0;
                    if (start)
                        tx_shift <= data_in;   // latch the byte
                end

                SETUP: begin
                    ss_n <= 1'b0;              // select slave
                    mosi <= tx_shift[7];       // MSB ready before first rising edge
                end

                TRANSFER: begin
                    if (tick) begin
                        if (!sck) begin
                            // rising edge: sample MISO, count the bit
                            sck      <= 1'b1;
                            rx_shift <= {rx_shift[6:0], miso};
                            bit_cnt  <= bit_cnt + 1'b1;
                        end else begin
                            // falling edge: present the next MOSI bit
                            sck <= 1'b0;
                            if (bit_cnt != 4'd8) begin
                                tx_shift <= tx_shift << 1;
                                mosi     <= tx_shift[6];
                            end
                        end
                    end
                end

                FINISH: begin
                    ss_n <= 1'b1;              // release slave
                end

                default: ;
            endcase
        end
    end

    // --------------------------------------------------------
    // 7. Outputs
    // --------------------------------------------------------
    assign data_out = rx_shift;
    assign busy     = (state != IDLE);
    assign done     = (state == FINISH);

endmodule
