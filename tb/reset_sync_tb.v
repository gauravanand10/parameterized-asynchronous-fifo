
`timescale 1ns / 1ps

module reset_sync_tb;

    // ---------------------------------------------------------
    // 1. Testbench signals
    // ---------------------------------------------------------
    reg clk;
    reg arst_n;
    wire srst_n;

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
    // 3. Device under test
    // ---------------------------------------------------------
    reset_sync dut (
        .clk    (clk),
        .arst_n (arst_n),
        .srst_n (srst_n)
    );

    // ---------------------------------------------------------
    // 4. Check task
    // ---------------------------------------------------------
    task check_reset;
        input expected;
        begin
            if (srst_n !== expected) begin
                $display(
                    "ERROR at %0t ns: srst_n=%b expected=%b",
                    $time, srst_n, expected
                );
                errors = errors + 1;
            end
        end
    endtask

    // ---------------------------------------------------------
    // 5. Main test sequence
    // ---------------------------------------------------------
    initial begin
        errors   = 0;
        test_done = 1'b0;

        arst_n = 1'b0;

        $display("----------------------------------------");
        $display("Starting reset_sync_tb at time zero");
        $display("----------------------------------------");

        // Asynchronous reset assertion
        #1;
        check_reset(1'b0);

        // Keep reset asserted across two clock edges
        repeat (2) @(posedge clk);
        #1;
        check_reset(1'b0);

        // Release reset away from the rising edge
        @(negedge clk);
        arst_n = 1'b1;

        // First rising edge: reset remains asserted
        @(posedge clk);
        #1;
        check_reset(1'b0);

        // Second rising edge: reset is released
        @(posedge clk);
        #1;
        check_reset(1'b1);

        // Test asynchronous assertion
        #2;
        arst_n = 1'b0;
        #1;
        check_reset(1'b0);

        // Release reset and test it again
        @(negedge clk);
        arst_n = 1'b1;

        // First rising edge
        @(posedge clk);
        #1;
        check_reset(1'b0);

        // Second rising edge
        @(posedge clk);
        #1;
        check_reset(1'b1);

        // Final asynchronous assertion
        #2;
        arst_n = 1'b0;
        #1;
        check_reset(1'b0);

        // -----------------------------------------------------
        // 6. Final result
        // -----------------------------------------------------
        if (errors == 0)
            $display("PASS: All reset_sync checks passed.");
        else
            $display("FAIL: %0d reset check(s) failed.", errors);

        $display("Test completed at %0t ns", $time);
        $display("----------------------------------------");

        test_done = 1'b1;
        $finish;
    end

    // ---------------------------------------------------------
    // 7. Watchdog
    // ---------------------------------------------------------
    initial begin
        #200;

        if (!test_done) begin
            $display("ERROR: Testbench timeout at %0t ns", $time);
            $finish;
        end
    end

endmodule
