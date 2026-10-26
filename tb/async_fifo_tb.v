
`timescale 1ns / 1ps

module async_fifo_tb;

    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH);

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
    wire r_empty;
    wire r_accept;

    integer errors;
    integer i;
    reg test_done;

    reg [DATA_WIDTH-1:0] expected_data [0:FIFO_DEPTH-1];

    // ---------------------------------------------------------
    // 1. Independent clocks
    // ---------------------------------------------------------

    // Write clock: 100 MHz equivalent (10 ns period)
    initial begin
        wclk = 1'b0;
        forever #5 wclk = ~wclk;
    end

    // Read clock: different frequency (14 ns period)
    initial begin
        rclk = 1'b0;
        forever #7 rclk = ~rclk;
    end

    // ---------------------------------------------------------
    // 2. Device under test
    // ---------------------------------------------------------

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
    // 3. Wait for pointer synchronization
    // ---------------------------------------------------------

    task wait_for_fifo_settle;
        begin
            repeat (5) @(posedge wclk);
            repeat (5) @(posedge rclk);
            #1;
        end
    endtask

    // ---------------------------------------------------------
    // 4. Write one item
    // ---------------------------------------------------------

    task write_item;
        input [DATA_WIDTH-1:0] data_in;
        begin
            // Change inputs away from the rising edge.
            @(negedge wclk);
            w_en   = 1'b1;
            w_data = data_in;

            // Sample acceptance before the active edge.
            #1;
            if (w_accept !== 1'b1) begin
                $display(
                    "ERROR: Write not accepted, data=%h at %0t",
                    data_in, $time
                );
                errors = errors + 1;
            end

            // The next rising edge performs the write.
            @(posedge wclk);

            // Deassert request away from the next rising edge.
            @(negedge wclk);
            w_en = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // 5. Read one item
    // ---------------------------------------------------------

    task read_item;
        input [DATA_WIDTH-1:0] expected;
        begin
            // Wait until synchronized empty flag is deasserted.
            wait (r_empty === 1'b0);

            // Assert request away from the active edge.
            @(negedge rclk);
            r_en = 1'b1;

            // For this asynchronous-read FIFO, r_data points
            // to the current rbin address before the read edge.
            #1;
            if (r_data !== expected) begin
                $display(
                    "ERROR: Read data=%h expected=%h at %0t",
                    r_data, expected, $time
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Read data=%h at %0t",
                    r_data, $time
                );
            end

            // Check that the read request is accepted before
            // the pointer and empty flag update.
            if (r_accept !== 1'b1) begin
                $display(
                    "ERROR: Read not accepted at %0t",
                    $time
                );
                errors = errors + 1;
            end

            // The rising edge advances the read pointer.
            @(posedge rclk);

            // Deassert request away from the next rising edge.
            @(negedge rclk);
            r_en = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // 6. Main test sequence
    // ---------------------------------------------------------

    initial begin
        errors    = 0;
        test_done = 1'b0;

        wrst_n = 1'b0;
        rrst_n = 1'b0;

        w_en   = 1'b0;
        w_data = {DATA_WIDTH{1'b0}};
        r_en   = 1'b0;

        $display("----------------------------------------");
        $display("Starting async_fifo_tb");
        $display("----------------------------------------");

        // Apply reset for at least three write-clock edges.
        repeat (3) @(posedge wclk);

        // Release reset away from the active edge.
        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;

        wait_for_fifo_settle;

        // -----------------------------------------------------
        // Test 1: Initial flags
        // -----------------------------------------------------

        $display("TEST 1: Initial FIFO flags");

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO should initially be empty");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO initially empty");
        end

        if (w_full !== 1'b0) begin
            $display("ERROR: FIFO should initially not be full");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO initially not full");
        end

        // -----------------------------------------------------
        // Test 2: Write FIFO_DEPTH items
        // -----------------------------------------------------

        $display("TEST 2: Write sequence");

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            expected_data[i] = i + 8'h20;
            write_item(expected_data[i]);
        end

        // Allow the final write and flag update to settle.
        @(posedge wclk);
        #1;

        if (w_full !== 1'b1) begin
            $display(
                "ERROR: FIFO did not assert full after %0d writes",
                FIFO_DEPTH
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO full flag asserted");
        end

        // -----------------------------------------------------
        // Test 3: Reject a write while full
        // -----------------------------------------------------

        $display("TEST 3: Write while full");

        @(negedge wclk);
        w_en   = 1'b1;
        w_data = 8'hEE;

        #1;
        if (w_accept !== 1'b0) begin
            $display("ERROR: Write accepted while FIFO full");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Write rejected while full");
        end

        @(negedge wclk);
        w_en = 1'b0;

        // -----------------------------------------------------
        // Test 4: Read FIFO_DEPTH items in order
        // -----------------------------------------------------

        $display("TEST 4: Read sequence");

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_item(expected_data[i]);
        end

        // Allow the final read and flag update to settle.
        @(posedge rclk);
        #1;

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO did not assert empty after draining");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO empty flag asserted");
        end

        // -----------------------------------------------------
        // Test 5: Reject a read while empty
        // -----------------------------------------------------

        $display("TEST 5: Read while empty");

        @(negedge rclk);
        r_en = 1'b1;

        #1;
        if (r_accept !== 1'b0) begin
            $display("ERROR: Read accepted while FIFO empty");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Read rejected while empty");
        end

        @(negedge rclk);
        r_en = 1'b0;

        // -----------------------------------------------------
        // 7. Final result
        // -----------------------------------------------------

        if (errors == 0) begin
            $display("----------------------------------------");
            $display("PASS: All async_fifo checks passed.");
            $display("----------------------------------------");
        end
        else begin
            $display("----------------------------------------");
            $display("FAIL: %0d error(s) detected.", errors);
            $display("----------------------------------------");
        end

        test_done = 1'b1;
        $display("Test completed at %0t ns", $time);

        $finish;
    end

    // ---------------------------------------------------------
    // 8. Watchdog
    // ---------------------------------------------------------

    initial begin
        #10000;
        if (!test_done) begin
            $display("ERROR: Testbench timeout at %0t ns", $time);
            $finish;
        end
    end

endmodule
