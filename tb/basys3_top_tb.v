
`timescale 1ns / 1ps

module basys3_top_tb;

    // ---------------------------------------------------------
    // 1. Parameters and testbench signals
    // ---------------------------------------------------------

    localparam integer DATA_WIDTH = 12;
    localparam integer FIFO_DEPTH = 16;

    reg         CLK100MHZ;
    reg  [15:0] SW;
    wire [15:0] LED;

    integer errors;
    integer i;
    integer timeout_count;

    reg test_done;
    reg [15:0] led_before;
    reg [DATA_WIDTH-1:0] expected_data [0:FIFO_DEPTH-1];

    // ---------------------------------------------------------
    // 2. Device under test
    // ---------------------------------------------------------

    basys3_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .CLK100MHZ(CLK100MHZ),
        .SW        (SW),
        .LED       (LED)
    );

    // ---------------------------------------------------------
    // 3. 100 MHz input clock
    // ---------------------------------------------------------

    initial begin
        CLK100MHZ = 1'b0;
        forever #5 CLK100MHZ = ~CLK100MHZ;
    end

    // ---------------------------------------------------------
    // 4. Startup: wait for clock lock and reset release
    // ---------------------------------------------------------

    task wait_for_startup;
        begin
            timeout_count = 0;

            while ((dut.locked !== 1'b1) &&
                   (timeout_count < 20000)) begin
                @(posedge CLK100MHZ);
                timeout_count = timeout_count + 1;
            end

            if (dut.locked !== 1'b1) begin
                $display("ERROR: Clock Wizard did not lock.");
                errors = errors + 1;
            end
            else begin
                $display("PASS: Clock Wizard locked.");
            end

            timeout_count = 0;

            while (((dut.wrst_n !== 1'b1) ||
                    (dut.rrst_n !== 1'b1)) &&
                   (timeout_count < 20000)) begin
                @(posedge CLK100MHZ);
                timeout_count = timeout_count + 1;
            end

            if ((dut.wrst_n !== 1'b1) ||
                (dut.rrst_n !== 1'b1)) begin
                $display("ERROR: FIFO domain resets did not release.");
                errors = errors + 1;
            end
            else begin
                $display("PASS: Write and read resets released.");
            end

            // Allow switch synchronizers and arming logic to settle.
            repeat (10) @(posedge CLK100MHZ);
            #1;
        end
    endtask

    // ---------------------------------------------------------
    // 5. Write one word
    //
    // SW[14] is a toggle request.
    // Each transition, 0->1 OR 1->0, requests one write.
    // ---------------------------------------------------------

    task write_word;
        input [DATA_WIDTH-1:0] data_in;
        begin
            // Set data and allow it to settle before the request.
            SW[DATA_WIDTH-1:0] = data_in;
            repeat (120) @(posedge CLK100MHZ);

            led_before = LED;

            // Generate exactly one transition.
            SW[14] = ~SW[14];

            timeout_count = 0;

            while ((LED[14] === led_before[14]) &&
                   (timeout_count < 500)) begin
                @(posedge CLK100MHZ);
                timeout_count = timeout_count + 1;
            end

            if (LED[14] === led_before[14]) begin
                $display(
                    "ERROR: Write request timed out, data=%03h, full=%b",
                    data_in, LED[12]
                );
                errors = errors + 1;
            end
            else begin
                $display("PASS: Write accepted, data=%03h", data_in);
            end

            // Leave the switch in its current state.
            // The next call will toggle it again.
            repeat (10) @(posedge CLK100MHZ);
        end
    endtask

    // ---------------------------------------------------------
    // 6. Read one word
    //
    // SW[13] is a toggle request.
    // Each transition requests one read.
    // ---------------------------------------------------------

    task read_word;
        input [DATA_WIDTH-1:0] expected;
        begin
            led_before = LED;

            // Generate exactly one transition.
            SW[13] = ~SW[13];

            timeout_count = 0;

            while ((LED[15] === led_before[15]) &&
                   (timeout_count < 500)) begin
                @(posedge CLK100MHZ);
                timeout_count = timeout_count + 1;
            end

            if (LED[15] === led_before[15]) begin
                $display(
                    "ERROR: Read request timed out, expected=%03h, empty=%b",
                    expected, LED[13]
                );
                errors = errors + 1;
            end
            else begin
                // Allow last-read data to propagate to the LEDs.
                repeat (10) @(posedge CLK100MHZ);
                #1;

                if (LED[DATA_WIDTH-1:0] !== expected) begin
                    $display(
                        "ERROR: LED data=%03h, expected=%03h",
                        LED[DATA_WIDTH-1:0], expected
                    );
                    errors = errors + 1;
                end
                else begin
                    $display(
                        "PASS: Read data displayed correctly: %03h",
                        LED[DATA_WIDTH-1:0]
                    );
                end
            end

            // Do not reset SW[13] to zero here.
            // The next call creates the next transition.
            repeat (10) @(posedge CLK100MHZ);
        end
    endtask

    // ---------------------------------------------------------
    // 7. Main test sequence
    // ---------------------------------------------------------

    initial begin
        errors    = 0;
        test_done = 1'b0;

        CLK100MHZ = 1'b0;
        SW        = 16'h0000;

        $display("------------------------------------------");
        $display("Starting basys3_top_tb");
        $display("------------------------------------------");

        // Assert board reset.
        SW[15] = 1'b1;
        repeat (10) @(posedge CLK100MHZ);

        // Release board reset.
        SW[15] = 1'b0;

        wait_for_startup;

        // -----------------------------------------------------
        // Test 1: Initial FIFO status
        // -----------------------------------------------------

        $display("TEST 1: Initial FIFO status");

        if (LED[13] !== 1'b1) begin
            $display("ERROR: LED13 should indicate empty.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: LED13 indicates empty.");
        end

        if (LED[12] !== 1'b0) begin
            $display("ERROR: LED12 should indicate not full.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: LED12 indicates not full.");
        end

        // -----------------------------------------------------
        // Test 2: Write 16 unique words
        // -----------------------------------------------------

        $display("TEST 2: Write 16 words");

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            expected_data[i] = 12'h120 + i;
            write_word(expected_data[i]);
        end

        // Allow full flag synchronization/update.
        repeat (30) @(posedge CLK100MHZ);
        #1;

        if (LED[12] !== 1'b1) begin
            $display("ERROR: LED12 did not indicate FIFO full.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: LED12 indicates FIFO full.");
        end

        // -----------------------------------------------------
        // Test 3: Write request while full
        // -----------------------------------------------------

        $display("TEST 3: Write while full");

        led_before = LED;

        // Change data and toggle request exactly once.
        SW[DATA_WIDTH-1:0] = 12'hEEE;
        repeat (120) @(posedge CLK100MHZ);

        led_before = LED;
        SW[14] = ~SW[14];

        repeat (100) @(posedge CLK100MHZ);

        if (LED[14] !== led_before[14]) begin
            $display("ERROR: Write accepted while FIFO full.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Write rejected while full.");
        end

        // -----------------------------------------------------
        // Test 4: Read all 16 words in order
        // -----------------------------------------------------

        $display("TEST 4: Read 16 words in order");

        // Select last-read display mode.
        SW[12] = 1'b0;
        repeat (10) @(posedge CLK100MHZ);

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_word(expected_data[i]);
        end

        // Allow empty flag synchronization/update.
        repeat (30) @(posedge CLK100MHZ);
        #1;

        if (LED[13] !== 1'b1) begin
            $display("ERROR: LED13 did not indicate FIFO empty.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: LED13 indicates FIFO empty.");
        end

        if (LED[12] !== 1'b0) begin
            $display("ERROR: LED12 should indicate not full after draining.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: LED12 indicates not full after draining.");
        end

        // -----------------------------------------------------
        // Test 5: Read request while empty
        // -----------------------------------------------------

        $display("TEST 5: Read while empty");

        led_before = LED;
        SW[13] = ~SW[13];

        repeat (100) @(posedge CLK100MHZ);

        if (LED[15] !== led_before[15]) begin
            $display("ERROR: Read accepted while FIFO empty.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Read rejected while empty.");
        end

        // -----------------------------------------------------
        // Test 6: Peek mode while empty
        // -----------------------------------------------------

        $display("TEST 6: Peek mode while empty");

        SW[12] = 1'b1;
        repeat (30) @(posedge CLK100MHZ);
        #1;

        if (LED[DATA_WIDTH-1:0] !== {DATA_WIDTH{1'b0}}) begin
            $display(
                "ERROR: Peek mode should display zero when empty; got %03h",
                LED[DATA_WIDTH-1:0]
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: Peek mode displays zero when empty.");
        end

        // -----------------------------------------------------
        // 8. Final result
        // -----------------------------------------------------

        if (errors == 0) begin
            $display("------------------------------------------");
            $display("PASS: All basys3_top checks passed.");
            $display("------------------------------------------");
        end
        else begin
            $display("------------------------------------------");
            $display("FAIL: %0d error(s) detected.", errors);
            $display("------------------------------------------");
        end

        test_done = 1'b1;
        $display("Test completed at %0t ns", $time);
        $finish;
    end

    // ---------------------------------------------------------
    // 9. Watchdog
    // ---------------------------------------------------------

    initial begin
        #2000000;

        if (!test_done) begin
            $display("ERROR: basys3_top_tb watchdog timeout.");
            $finish;
        end
    end

endmodule
