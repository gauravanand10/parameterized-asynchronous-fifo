
`timescale 1ns / 1ps

module async_fifo_boundary_tb;

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
    integer timeout_count;

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

    // Write clock: 10 ns period.
    initial begin
        wclk = 1'b0;
        forever #5 wclk = ~wclk;
    end

    // Read clock: 14 ns period.
    initial begin
        rclk = 1'b0;
        forever #7 rclk = ~rclk;
    end

    // ---------------------------------------------------------
    // Reset initialization
    // ---------------------------------------------------------
    initial begin
        wrst_n = 1'b0;
        rrst_n = 1'b0;

        w_en   = 1'b0;
        w_data = {DATA_WIDTH{1'b0}};
        r_en   = 1'b0;

        errors = 0;

        repeat (5) @(posedge wclk);
        repeat (3) @(posedge rclk);

        @(negedge wclk);
        wrst_n = 1'b1;

        @(negedge rclk);
        rrst_n = 1'b1;

        repeat (3) @(posedge wclk);
        repeat (3) @(posedge rclk);
        #1;
    end

    // ---------------------------------------------------------
    // Write exactly one item.
    // Acceptance is checked BEFORE the active write edge.
    // ---------------------------------------------------------
    task write_item;
        input [DATA_WIDTH-1:0] data_in;
        integer wait_count;
        begin
            wait_count = 0;

            while ((w_full !== 1'b0) && (wait_count < 100)) begin
                @(negedge wclk);
                #1;
                wait_count = wait_count + 1;
            end

            if (w_full !== 1'b0) begin
                $display(
                    "ERROR: Timeout waiting for write space. Data=%h",
                    data_in
                );
                errors = errors + 1;
            end
            else begin
                @(negedge wclk);
                w_data = data_in;
                w_en   = 1'b1;

                // Allow combinational acceptance logic to settle.
                #1;

                if (w_accept !== 1'b1) begin
                    $display(
                        "ERROR: Write not accepted before edge. Data=%h",
                        data_in
                    );
                    errors = errors + 1;

                    @(negedge wclk);
                    w_en = 1'b0;
                end
                else begin
                    // The next rising edge performs the write.
                    @(posedge wclk);
                    #1;

                    @(negedge wclk);
                    w_en = 1'b0;
                end
            end
        end
    endtask

    // ---------------------------------------------------------
    // Read exactly one item.
    // Check acceptance before the read edge.
    // ---------------------------------------------------------
    task read_item;
        input [DATA_WIDTH-1:0] expected_data;
        integer wait_count;
        reg [DATA_WIDTH-1:0] sampled_data;
        begin
            wait_count = 0;

            while ((r_empty !== 1'b0) && (wait_count < 100)) begin
                @(negedge rclk);
                #1;
                wait_count = wait_count + 1;
            end

            if (r_empty !== 1'b0) begin
                $display(
                    "ERROR: Timeout waiting for read data. Expected=%h",
                    expected_data
                );
                errors = errors + 1;
            end
            else begin
                @(negedge rclk);
                r_en = 1'b1;

                #1;

                if (r_accept !== 1'b1) begin
                    $display(
                        "ERROR: Read not accepted before edge. Expected=%h",
                        expected_data
                    );
                    errors = errors + 1;

                    @(negedge rclk);
                    r_en = 1'b0;
                end
                else begin
                    // Async read data is sampled before pointer advance.
                    sampled_data = r_data;

                    if (sampled_data !== expected_data) begin
                        $display(
                            "ERROR: Expected %h, got %h at time %0t",
                            expected_data, sampled_data, $time
                        );
                        errors = errors + 1;
                    end
                    else begin
                        $display("PASS: Read %h", sampled_data);
                    end

                    @(posedge rclk);
                    #1;

                    @(negedge rclk);
                    r_en = 1'b0;
                end
            end
        end
    endtask

    // ---------------------------------------------------------
    // Wait for full to clear.
    // ---------------------------------------------------------
    task wait_for_not_full;
        integer count;
        begin
            count = 0;

            while ((w_full !== 1'b0) && (count < 100)) begin
                @(posedge wclk);
                #1;
                count = count + 1;
            end

            if (w_full !== 1'b0) begin
                $display("ERROR: Full flag did not clear.");
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Full cleared after synchronized read progress."
                );
            end
        end
    endtask

    // ---------------------------------------------------------
    // Wait for empty to assert.
    // ---------------------------------------------------------
    task wait_for_empty;
        integer count;
        begin
            count = 0;

            while ((r_empty !== 1'b1) && (count < 100)) begin
                @(posedge rclk);
                #1;
                count = count + 1;
            end

            if (r_empty !== 1'b1) begin
                $display("ERROR: FIFO did not become empty.");
                errors = errors + 1;
            end
            else begin
                $display("PASS: FIFO empty after drain.");
            end
        end
    endtask

    // ---------------------------------------------------------
    // Main test sequence
    // ---------------------------------------------------------
    initial begin
        wait (wrst_n === 1'b1);
        wait (rrst_n === 1'b1);

        repeat (2) @(posedge rclk);
        #1;

        $display("");
        $display("==========================================");
        $display("Starting async_fifo_boundary_tb");
        $display("==========================================");

        // 1. Initial flags.
        if ((w_full === 1'b0) && (r_empty === 1'b1)) begin
            $display("PASS: Initial flags are correct.");
        end
        else begin
            $display("ERROR: Incorrect initial flags.");
            errors = errors + 1;
        end

        // 2. Fill FIFO to capacity.
        $display("");
        $display("TEST: Fill FIFO to capacity");

        for (i = 0; i < FIFO_DEPTH; i = i + 1)
            write_item(8'h20 + i);

        timeout_count = 0;

        while ((w_full !== 1'b1) && (timeout_count < 20)) begin
            @(posedge wclk);
            #1;
            timeout_count = timeout_count + 1;
        end

        if (w_full === 1'b1)
            $display("PASS: Full flag asserted at capacity.");
        else begin
            $display("ERROR: Full flag did not assert.");
            errors = errors + 1;
        end

        // 3. Attempt a write while full.
        @(negedge wclk);
        w_data = 8'hEE;
        w_en   = 1'b1;
        #1;

        if (w_accept === 1'b0) begin
            $display("PASS: Write rejected while full.");
        end
        else begin
            $display("ERROR: Write accepted while full.");
            errors = errors + 1;
        end

        @(posedge wclk);
        #1;
        @(negedge wclk);
        w_en = 1'b0;

        // 4. Read the first item and wait for full to clear.
        read_item(8'h20);
        wait_for_not_full();

        // 5. Refill the freed slot.
        write_item(8'hEE);

        timeout_count = 0;

        while ((w_full !== 1'b1) && (timeout_count < 20)) begin
            @(posedge wclk);
            #1;
            timeout_count = timeout_count + 1;
        end

        if (w_full === 1'b1)
            $display("PASS: FIFO returned to full after refill.");
        else begin
            $display("ERROR: FIFO did not return to full.");
            errors = errors + 1;
        end

        // 6. Drain remaining original data in order.
        $display("");
        $display("TEST: Drain FIFO in order");

        for (i = 1; i < FIFO_DEPTH; i = i + 1)
            read_item(8'h20 + i);

        read_item(8'hEE);
        wait_for_empty();

        // 7. Attempt a read while empty.
        @(negedge rclk);
        r_en = 1'b1;
        #1;

        if (r_accept === 1'b0) begin
            $display("PASS: Read rejected while empty.");
        end
        else begin
            $display("ERROR: Read accepted while empty.");
            errors = errors + 1;
        end

        @(posedge rclk);
        #1;
        @(negedge rclk);
        r_en = 1'b0;

        // 8. Write A1 for the simultaneous operation test.
        write_item(8'hA1);

        timeout_count = 0;

        while ((r_empty !== 1'b0) && (timeout_count < 100)) begin
            @(posedge rclk);
            #1;
            timeout_count = timeout_count + 1;
        end

        if (r_empty !== 1'b0) begin
            $display("ERROR: A1 did not become visible to read side.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: A1 is available for simultaneous test.");
        end

        // 9. Simultaneous read of A1 and write of B2.
        $display("");
        $display("TEST: Simultaneous read and write");

        // Drive requests away from active clock edges.
        @(negedge wclk);
        w_data = 8'hB2;
        w_en   = 1'b1;

        @(negedge rclk);
        r_en = 1'b1;

        #1;

        // Check both operations before their active edges.
        if (w_accept !== 1'b1) begin
            $display("ERROR: Simultaneous write not accepted.");
            errors = errors + 1;
        end

        if (r_accept !== 1'b1) begin
            $display("ERROR: Simultaneous read not accepted.");
            errors = errors + 1;
        end

        // Each request is deasserted independently.
        fork
            begin
                @(posedge wclk);
                #1;
                @(negedge wclk);
                w_en = 1'b0;
            end

            begin
                // Read data before the read pointer advances.
                #1;

                if (r_data !== 8'hA1) begin
                    $display(
                        "ERROR: Expected A1 at simultaneous read, got %h",
                        r_data
                    );
                    errors = errors + 1;
                end
                else begin
                    $display("PASS: Read side observed old head A1.");
                end

                @(posedge rclk);
                #1;
                @(negedge rclk);
                r_en = 1'b0;
            end
        join

        // 10. B2 must be the next item.
        read_item(8'hB2);
        wait_for_empty();

        // 11. Debug pointer and flag state.
        $display("");
        $display("Final FIFO state:");

        repeat (5) begin
            @(posedge rclk);
            #1;

            $display(
                "DEBUG t=%0t rbin=%0d rgray=%b wbin=%0d wgray=%b wgray_sync_r=%b r_empty=%b r_accept=%b r_en=%b",
                $time,
                dut.rbin,
                dut.rgray,
                dut.wbin,
                dut.wgray,
                dut.wgray_sync_r,
                r_empty,
                r_accept,
                r_en
            );
        end

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO not empty after simultaneous test.");
            $display(
                "DEBUG FINAL: rbin=%0d rgray=%b wbin=%0d wgray=%b wgray_sync_r=%b",
                dut.rbin,
                dut.rgray,
                dut.wbin,
                dut.wgray,
                dut.wgray_sync_r
            );
            errors = errors + 1;
        end

        // 12. Final result.
        $display("");
        $display("==========================================");

        if (errors == 0)
            $display("PASS: All boundary tests passed.");
        else
            $display("FAIL: %0d boundary-test error(s).", errors);

        $display("==========================================");
        $finish;
    end

    // Global simulation timeout.
    initial begin
        #100000;
        $display("ERROR: Global simulation timeout.");
        $finish;
    end

endmodule
