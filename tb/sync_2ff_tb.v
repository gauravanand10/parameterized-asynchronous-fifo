
`timescale 1ns / 1ps

module sync_2ff_tb;

    // ---------------------------------------------------------
    // 1. Testbench signals
    // ---------------------------------------------------------
    reg clk;
    reg rst_n;

    reg async_in_reset;
    reg async_in_no_reset;

    wire sync_out_2;
    wire sync_out_3;
    wire sync_out_no_reset;

    integer errors;
    reg test_done;

    // ---------------------------------------------------------
    // 2. Clock generation: 10 ns period
    // ---------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------------------------------------------------
    // 3. Two-stage synchronizer with reset
    // ---------------------------------------------------------
    sync_2ff #(
        .WIDTH(1),
        .STAGES(2),
        .HAS_RESET(1)
    ) dut_2stage (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (async_in_reset),
        .sync_out (sync_out_2)
    );

    // ---------------------------------------------------------
    // 4. Three-stage synchronizer with reset
    // ---------------------------------------------------------
    sync_2ff #(
        .WIDTH(1),
        .STAGES(3),
        .HAS_RESET(1)
    ) dut_3stage (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (async_in_reset),
        .sync_out (sync_out_3)
    );

    // ---------------------------------------------------------
    // 5. Two-stage synchronizer without reset
    // ---------------------------------------------------------
    sync_2ff #(
        .WIDTH(1),
        .STAGES(2),
        .HAS_RESET(0)
    ) dut_no_reset (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (async_in_no_reset),
        .sync_out (sync_out_no_reset)
    );

    // ---------------------------------------------------------
    // 6. Check task
    // ---------------------------------------------------------
    task check_value;
        input expected_2;
        input expected_3;
        input expected_no_reset;

        begin
            if (sync_out_2 !== expected_2) begin
                $display(
                    "ERROR at %0t: 2-stage output=%b expected=%b",
                    $time, sync_out_2, expected_2
                );
                errors = errors + 1;
            end

            if (sync_out_3 !== expected_3) begin
                $display(
                    "ERROR at %0t: 3-stage output=%b expected=%b",
                    $time, sync_out_3, expected_3
                );
                errors = errors + 1;
            end

            if (sync_out_no_reset !== expected_no_reset) begin
                $display(
                    "ERROR at %0t: no-reset output=%b expected=%b",
                    $time, sync_out_no_reset, expected_no_reset
                );
                errors = errors + 1;
            end
        end
    endtask

    // ---------------------------------------------------------
    // 7. Main test sequence
    // ---------------------------------------------------------
    initial begin
        errors = 0;
        test_done = 1'b0;

        rst_n             = 1'b0;
        async_in_reset    = 1'b0;
        async_in_no_reset = 1'b0;

        $display("----------------------------------------");
        $display("Starting sync_2ff_tb");
        $display("----------------------------------------");

        // Apply reset and allow the clock to run.
        repeat (2) @(posedge clk);
        #1;

        check_value(1'b0, 1'b0, 1'b0);

        // Release reset and drive both inputs high.
        @(negedge clk);
        rst_n             = 1'b1;
        async_in_reset    = 1'b1;
        async_in_no_reset = 1'b1;

        // First rising edge: first stage samples high.
        @(posedge clk);
        #1;
        check_value(1'b0, 1'b0, 1'b0);

        // Second rising edge: two-stage outputs become high.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b0, 1'b1);

        // Third rising edge: three-stage output becomes high.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b1, 1'b1);

        // Confirm outputs remain high.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b1, 1'b1);

        // Drive both inputs low away from the rising edge.
        @(negedge clk);
        async_in_reset    = 1'b0;
        async_in_no_reset = 1'b0;

        // First rising edge after input changes.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b1, 1'b1);

        // Second rising edge: two-stage outputs become low.
        @(posedge clk);
        #1;
        check_value(1'b0, 1'b1, 1'b0);

        // Third rising edge: three-stage output becomes low.
        @(posedge clk);
        #1;
        check_value(1'b0, 1'b0, 1'b0);

        // -----------------------------------------------------
        // 8. Test asynchronous reset assertion
        // -----------------------------------------------------
        #2;
        rst_n = 1'b0;
        #1;

        check_value(1'b0, 1'b0, 1'b0);

        // The no-reset synchronizer is not cleared by reset.
        // Its output is already zero here because its input is zero.
        repeat (2) @(posedge clk);
        #1;

        check_value(1'b0, 1'b0, 1'b0);

        // -----------------------------------------------------
        // 9. Test reset release and propagation again
        // -----------------------------------------------------
        @(negedge clk);
        rst_n = 1'b1;
        async_in_reset = 1'b1;

        // Keep the no-reset input low during this test.
        async_in_no_reset = 1'b0;

        // First rising edge.
        @(posedge clk);
        #1;
        check_value(1'b0, 1'b0, 1'b0);

        // Second rising edge.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b0, 1'b0);

        // Third rising edge.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b1, 1'b0);

        // -----------------------------------------------------
        // 10. Independently test the no-reset synchronizer
        // -----------------------------------------------------
        @(negedge clk);
        async_in_no_reset = 1'b1;

        // First rising edge after its input goes high.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b1, 1'b0);

        // Second rising edge: no-reset output becomes high.
        @(posedge clk);
        #1;
        check_value(1'b1, 1'b1, 1'b1);

        // -----------------------------------------------------
        // 11. Final result
        // -----------------------------------------------------
        if (errors == 0)
            $display("PASS: All sync_2ff checks passed.");
        else
            $display("FAIL: %0d synchronizer check(s) failed.", errors);

        $display("----------------------------------------");

        test_done = 1'b1;
        $finish;
    end

    // ---------------------------------------------------------
    // 12. Watchdog
    // ---------------------------------------------------------
    initial begin
        #500;

        if (!test_done) begin
            $display("ERROR: Testbench timeout.");
            $finish;
        end
    end

endmodule
