
`timescale 1ns / 1ps

module async_fifo_param_tb;

    wire done_a;
    wire done_b;
    wire done_c;
    wire done_d;

    // Configuration A: 8-bit data, depth 4
    fifo_param_checker #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(4),
        .WCLK_HALF(5),
        .RCLK_HALF(7),
        .TEST_ID("A: WIDTH=8 DEPTH=4")
    ) cfg_a (
        .done(done_a)
    );

    // Configuration B: 8-bit data, depth 16
    fifo_param_checker #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(16),
        .WCLK_HALF(4),
        .RCLK_HALF(6),
        .TEST_ID("B: WIDTH=8 DEPTH=16")
    ) cfg_b (
        .done(done_b)
    );

    // Configuration C: 12-bit data, depth 16
    fifo_param_checker #(
        .DATA_WIDTH(12),
        .FIFO_DEPTH(16),
        .WCLK_HALF(6),
        .RCLK_HALF(9),
        .TEST_ID("C: WIDTH=12 DEPTH=16")
    ) cfg_c (
        .done(done_c)
    );

    // Configuration D: 16-bit data, depth 32
    fifo_param_checker #(
        .DATA_WIDTH(16),
        .FIFO_DEPTH(32),
        .WCLK_HALF(5),
        .RCLK_HALF(8),
        .TEST_ID("D: WIDTH=16 DEPTH=32")
    ) cfg_d (
        .done(done_d)
    );

    initial begin
        $display("==============================================");
        $display("Starting async_fifo_param_tb");
        $display("==============================================");

        wait (done_a && done_b && done_c && done_d);

        $display("==============================================");
        $display("PASS: All parameter configurations completed.");
        $display("==============================================");
        $finish;
    end

    initial begin
        #1000000;
        $display("ERROR: Parameter testbench watchdog timeout.");
        $finish;
    end

endmodule


// =============================================================
// Simulation-only checker. It instantiates the existing FIFO.
// =============================================================

module fifo_param_checker #(
    parameter integer DATA_WIDTH = 8,
    parameter integer FIFO_DEPTH = 16,
    parameter integer WCLK_HALF = 5,
    parameter integer RCLK_HALF = 7,
    parameter TEST_ID = "FIFO CONFIG"
)(
    output reg done
);

    localparam integer PTR_WIDTH = $clog2(FIFO_DEPTH) + 1;

    reg wclk;
    reg rclk;
    reg wrst_n;
    reg rrst_n;

    reg w_en;
    reg [DATA_WIDTH-1:0] w_data;
    wire w_full;
    wire w_accept;

    reg r_en;
    wire [DATA_WIDTH-1:0] r_data;
    wire r_accept;
    wire r_empty;

    integer errors;
    integer i;

    reg [DATA_WIDTH-1:0] expected_data [0:FIFO_DEPTH-1];

    // Independent write clock.
    initial begin
        wclk = 1'b0;
        forever #(WCLK_HALF) wclk = ~wclk;
    end

    // Independent read clock.
    initial begin
        rclk = 1'b0;
        forever #(RCLK_HALF) rclk = ~rclk;
    end

    // Device under test.
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .w_en     (w_en),
        .w_data   (w_data),
        .w_full   (w_full),
        .w_accept (w_accept),

        .rclk     (rclk),
        .rrst_n   (rrst_n),
        .r_en     (r_en),
        .r_data   (r_data),
        .r_empty  (r_empty),
        .r_accept (r_accept)
    );

    // ---------------------------------------------------------
    // Write one item; check acceptance before the rising edge.
    // ---------------------------------------------------------

    task write_item;
        input [DATA_WIDTH-1:0] data_in;
        begin
            @(negedge wclk);
            w_data = data_in;
            w_en = 1'b1;

            #1;
            if (w_accept !== 1'b1) begin
                $display(
                    "ERROR [%0s]: Write rejected, data=%h at %0t",
                    TEST_ID, data_in, $time
                );
                errors = errors + 1;
            end

            @(posedge wclk);
            @(negedge wclk);
            w_en = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // Read one item; check asynchronous data before pointer
    // advancement, then check read acceptance.
    // ---------------------------------------------------------

    task read_item;
        input [DATA_WIDTH-1:0] expected;
        begin
            wait (r_empty === 1'b0);

            @(negedge rclk);
            r_en = 1'b1;

            #1;
            if (r_accept !== 1'b1) begin
                $display(
                    "ERROR [%0s]: Read not accepted at %0t",
                    TEST_ID, $time
                );
                errors = errors + 1;
            end

            if (r_data !== expected) begin
                $display(
                    "ERROR [%0s]: Data=%h expected=%h at %0t",
                    TEST_ID, r_data, expected, $time
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS [%0s]: Read data=%h",
                    TEST_ID, r_data
                );
            end

            @(posedge rclk);
            @(negedge rclk);
            r_en = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // Run tests for this configuration.
    // ---------------------------------------------------------

    initial begin
        done = 1'b0;
        errors = 0;

        wrst_n = 1'b0;
        rrst_n = 1'b0;

        w_en = 1'b0;
        w_data = {DATA_WIDTH{1'b0}};
        r_en = 1'b0;

        $display("----------------------------------------------");
        $display("Starting %0s", TEST_ID);
        $display("----------------------------------------------");

        // Reset both domains.
        repeat (3) @(posedge wclk);
        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;

        // Wait for reset release and pointer synchronizers.
        repeat (6) @(posedge wclk);
        repeat (6) @(posedge rclk);
        #1;

        // Test 1: Initial flags.
        if (r_empty !== 1'b1) begin
            $display("ERROR [%0s]: Initial empty flag incorrect", TEST_ID);
            errors = errors + 1;
        end

        if (w_full !== 1'b0) begin
            $display("ERROR [%0s]: Initial full flag incorrect", TEST_ID);
            errors = errors + 1;
        end

        // Test 2: Fill the FIFO with unique data.
        $display("[%0s] Writing %0d words", TEST_ID, FIFO_DEPTH);

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            expected_data[i] = i + 1;
            write_item(expected_data[i]);
        end

        // Allow the full flag to settle.
        repeat (5) @(posedge wclk);
        #1;

        if (w_full !== 1'b1) begin
            $display("ERROR [%0s]: Full flag did not assert", TEST_ID);
            errors = errors + 1;
        end
        else begin
            $display("PASS [%0s]: Full flag asserted", TEST_ID);
        end

        // Test 3: Reject write while full.
        @(negedge wclk);
        w_en = 1'b1;
        w_data = {DATA_WIDTH{1'b1}};

        #1;
        if (w_accept !== 1'b0) begin
            $display("ERROR [%0s]: Write accepted while full", TEST_ID);
            errors = errors + 1;
        end
        else begin
            $display("PASS [%0s]: Write rejected while full", TEST_ID);
        end

        @(negedge wclk);
        w_en = 1'b0;

        // Test 4: Read and verify all words in order.
        $display("[%0s] Reading %0d words", TEST_ID, FIFO_DEPTH);

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_item(expected_data[i]);
        end

        // Allow empty flag to settle.
        repeat (5) @(posedge rclk);
        #1;

        if (r_empty !== 1'b1) begin
            $display("ERROR [%0s]: Empty flag did not assert", TEST_ID);
            errors = errors + 1;
        end
        else begin
            $display("PASS [%0s]: Empty flag asserted", TEST_ID);
        end

        // Test 5: Reject read while empty.
        @(negedge rclk);
        r_en = 1'b1;

        #1;
        if (r_accept !== 1'b0) begin
            $display("ERROR [%0s]: Read accepted while empty", TEST_ID);
            errors = errors + 1;
        end
        else begin
            $display("PASS [%0s]: Read rejected while empty", TEST_ID);
        end

        @(negedge rclk);
        r_en = 1'b0;

        // Final status.
        if (errors == 0) begin
            $display("PASS [%0s]: All checks passed", TEST_ID);
        end
        else begin
            $display(
                "FAIL [%0s]: %0d error(s)",
                TEST_ID, errors
            );
        end

        done = 1'b1;
    end

endmodule
