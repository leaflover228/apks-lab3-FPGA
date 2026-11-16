// ============================================================
// Testbench for spi_master
//  - clock + reset generation
//  - behavioural SPI slave (mode 0) that
//      * captures the byte sent on MOSI  -> slave_rx
//      * answers with slave_byte on MISO
//  - self-checking: compares both directions, prints PASS/FAIL
// Run from the project root: make sim
// ============================================================
`timescale 1ns/1ps

module spi_master_tb;

    localparam CLK_PERIOD = 20;        // 50 MHz
    localparam CLK_DIV    = 4;         // SCK = 50 MHz / 8 = 6.25 MHz

    // ---- DUT signals ----
    reg        clk = 0;
    reg        rst_n = 0;
    reg        start = 0;
    reg  [7:0] data_in = 8'h00;
    wire [7:0] data_out;
    wire       busy, done;
    wire       sck, mosi, ss_n;
    reg        miso = 0;

    spi_master #(.CLK_DIV(CLK_DIV)) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .data_in(data_in), .data_out(data_out),
        .busy(busy), .done(done),
        .sck(sck), .mosi(mosi), .miso(miso), .ss_n(ss_n)
    );

    // ---- clock ----
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- behavioural SPI slave, mode 0 ----
    reg [7:0] slave_byte = 8'h00;      // what the slave wants to send
    reg [7:0] slave_tx   = 8'h00;      // slave transmit shift register
    reg [7:0] slave_rx   = 8'h00;      // what the slave received
    integer   slave_bits = 0;

    // SS falls: load first bit of the reply
    always @(negedge ss_n) begin
        slave_tx   = slave_byte;
        miso       = slave_tx[7];
        slave_bits = 0;
    end
    // rising SCK: slave samples MOSI
    always @(posedge sck) if (!ss_n) begin
        slave_rx   = {slave_rx[6:0], mosi};
        slave_bits = slave_bits + 1;
    end
    // falling SCK: slave shifts out next bit
    always @(negedge sck) if (!ss_n) begin
        slave_tx = slave_tx << 1;
        miso     = slave_tx[7];
    end

    // ---- checking ----
    integer errors = 0;
    integer tests  = 0;

    task xfer(input [7:0] m_byte, input [7:0] s_byte);
        begin
            slave_byte = s_byte;
            @(negedge clk);
            data_in = m_byte;
            start   = 1;
            @(negedge clk);
            start   = 0;
            @(posedge done);
            #1;
            tests = tests + 1;
            if (data_out !== s_byte) begin
                errors = errors + 1;
                $display("[%0t] FAIL RX: master got %h, slave sent %h", $time, data_out, s_byte);
            end
            if (slave_rx !== m_byte) begin
                errors = errors + 1;
                $display("[%0t] FAIL TX: slave got %h, master sent %h", $time, slave_rx, m_byte);
            end
            if (slave_bits != 8) begin
                errors = errors + 1;
                $display("[%0t] FAIL: slave counted %0d SCK pulses", $time, slave_bits);
            end
            if (errors == 0)
                $display("[%0t] ok   master->%h  slave->%h", $time, m_byte, s_byte);
            wait (!busy);
            repeat (3) @(negedge clk);
        end
    endtask

    // ---- watchdog ----
    initial begin
        #2_000_000;
        $display("TIMEOUT");
        $finish;
    end

    // ---- stimulus ----
    integer i;
    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, spi_master_tb);

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);

        xfer(8'hA5, 8'h3C);
        xfer(8'h00, 8'hFF);
        xfer(8'hFF, 8'h00);
        xfer(8'h55, 8'hAA);
        xfer(8'h01, 8'h80);
        for (i = 0; i < 10; i = i + 1)
            xfer($urandom, $urandom);

        $display("----------------------------------------");
        if (errors == 0) $display("PASS: %0d transfers", tests);
        else             $display("FAIL: %0d errors in %0d transfers", errors, tests);
        $finish;
    end

endmodule
