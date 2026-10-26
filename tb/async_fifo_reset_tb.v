
`timescale 1ns / 1ps

module async_fifo_reset_tb;

    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 16;

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

    // Device under test
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .w_en(w_en),
        .w_data(w_data),
        .w_full(w_full),
        .w_accept(w_accept),

        .rclk(rclk),
        .rrst_n(rrst_n),
        .r_en(r_en),
        .r_data(r_data),
        .r_empty(r_empty),
        .r_accept(r_accept)
    );

    // Independent write clock: 10 ns period
    initial begin
        wclk = 1'b0;
        forever #5 wclk = ~wclk;
    end

    // Independent read clock: 14 ns period
    initial begin
        rclk = 1'b0;
        forever #7 rclk = ~rclk;
    end

    // Allow both clock domains to settle
    task wait_for_settle;
        integer j;
        begin
            for (j = 0; j < 6; j = j + 1)
                @(posedge wclk);

            for (j = 0; j < 6; j = j + 1)
                @(posedge rclk);

            #1;
        end
    endtask

    // Write one item and verify that the FIFO accepts it
    task write_item;
        input [DATA_WIDTH-1:0] value;
        begin
            @(negedge wclk);
            w_data = value;
            w_en = 1'b1;

            #1;
            if (w_accept !== 1'b1) begin
                $display("ERROR: Write %h was not accepted at time %0t",
                         value, $time);
                errors = errors + 1;
            end

            @(posedge wclk);
            @(negedge wclk);
            w_en = 1'b0;

            // Keep write requests separated
            @(posedge wclk);
            #1;
        end
    endtask

    // Wait for synchronized write-pointer information
    // to make the FIFO appear non-empty in the read domain.
    task wait_for_data;
        integer j;
        begin
            j = 0;

            while ((r_empty === 1'b1) && (j < 20)) begin
                @(posedge rclk);
                #1;
                j = j + 1;
            end

            if (r_empty !== 1'b0) begin
                $display("ERROR: FIFO did not show pending data.");
                $display("wbin=%0d wgray=%b wgray_sync_r=%b rgray=%b",
                         dut.wbin, dut.wgray,
                         dut.wgray_sync_r, dut.rgray);
                errors = errors + 1;
            end
            else begin
                $display("PASS: FIFO contains pending data.");
            end
        end
    endtask

    // Read one item and check its value
    task read_item;
        input [DATA_WIDTH-1:0] expected;
        begin
            wait_for_data;

            if (r_empty === 1'b0) begin
                @(negedge rclk);
                r_en = 1'b1;
                #1;

                if (r_accept !== 1'b1) begin
                    $display("ERROR: Read request was not accepted.");
                    errors = errors + 1;
                end
                else if (r_data !== expected) begin
                    $display("ERROR: Read data=%h expected=%h at time %0t",
                             r_data, expected, $time);
                    errors = errors + 1;
                end
                else begin
                    $display("PASS: Read data=%h", r_data);
                end

                @(posedge rclk);
                @(negedge rclk);
                r_en = 1'b0;
            end
        end
    endtask

    initial begin
        errors = 0;
        test_done = 1'b0;

        wclk = 1'b0;
        rclk = 1'b0;
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        w_en = 1'b0;
        w_data = {DATA_WIDTH{1'b0}};
        r_en = 1'b0;

        $display("Starting async_fifo_reset_tb");

        // TEST 1: Initial reset
        $display("TEST 1: Initial reset");
        wait_for_settle;

        if (w_full !== 1'b0) begin
            $display("ERROR: Full should be 0 after reset.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Full is 0 after reset.");
        end

        if (r_empty !== 1'b1) begin
            $display("ERROR: Empty should be 1 after reset.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Empty is 1 after reset.");
        end

        // Release reset away from the active write edge
        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;
        wait_for_settle;

        // TEST 2: Write data before reset
        $display("TEST 2: Write data before reset");
        for (i = 0; i < 6; i = i + 1)
            write_item(8'h40 + i);

        wait_for_data;

        // TEST 3: Assert reset while data is pending
        $display("TEST 3: Reset while FIFO contains data");
        #2;
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        w_en = 1'b0;
        r_en = 1'b0;

        #1;

        if (w_full !== 1'b0) begin
            $display("ERROR: Full should clear on reset.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Full cleared on reset.");
        end

        if (r_empty !== 1'b1) begin
            $display("ERROR: Empty should assert on reset.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Empty asserted on reset.");
        end

        repeat (4) @(posedge wclk);

        // TEST 4: Release reset and verify recovery
        $display("TEST 4: Reset release and recovery");
        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;

        wait_for_settle;

        if (w_full !== 1'b0) begin
            $display("ERROR: Full should be 0 after reset release.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Full is 0 after reset release.");
        end

        if (r_empty !== 1'b1) begin
            $display("ERROR: Empty should be 1 after reset release.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Empty is 1 after reset release.");
        end

        // TEST 5: Write fresh data after reset
        $display("TEST 5: Write fresh post-reset data");
        for (i = 0; i < 6; i = i + 1)
            write_item(8'hA0 + i);

        wait_for_data;

        // TEST 6: Read back the fresh data in order
        $display("TEST 6: Read post-reset data");
        for (i = 0; i < 6; i = i + 1)
            read_item(8'hA0 + i);

        wait_for_settle;

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty after draining.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO empty after draining.");
        end

        // Final result
        if (errors == 0)
            $display("PASS: All async_fifo_reset_tb checks passed.");
        else
            $display("FAIL: %0d error(s) detected.", errors);

        test_done = 1'b1;
        $display("Test completed at %0t", $time);
        $finish;
    end

    // Watchdog prevents a hung simulation
    initial begin
        #100000;
        if (test_done !== 1'b1) begin
            $display("ERROR: Watchdog timeout.");
            $finish;
        end
    end

endmodule
