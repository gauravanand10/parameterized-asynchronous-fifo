
`timescale 1ns / 1ps

module async_fifo_stress_tb;

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
    integer phase;
    integer i;
    integer count;
    integer sequence_number;
    integer writes_total;
    integer reads_total;

    reg test_done;

    // Expected-data queue for ordering checks.
    reg [DATA_WIDTH-1:0] expected_data [0:1023];
    integer write_index;
    integer read_index;

    // ---------------------------------------------------------
    // 1. Independent clocks
    // ---------------------------------------------------------

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
    // 3. Write one item
    // ---------------------------------------------------------

    task write_item;
        input [DATA_WIDTH-1:0] data_in;
        begin
            @(negedge wclk);
            w_data = data_in;
            w_en = 1'b1;

            // Sample acceptance before the active edge.
            #1;
            if (w_accept !== 1'b1) begin
                $display(
                    "ERROR: Write rejected, data=%02h time=%0t",
                    data_in, $time
                );
                errors = errors + 1;
            end

            // Write is performed at the next rising edge.
            @(posedge wclk);

            // Store expected data in FIFO order.
            expected_data[write_index] = data_in;
            write_index = write_index + 1;
            writes_total = writes_total + 1;

            @(negedge wclk);
            w_en = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // 4. Read one item
    // ---------------------------------------------------------

    task read_item;
        reg [DATA_WIDTH-1:0] expected;
        begin
            // Wait for the read-domain empty flag to clear.
            wait (r_empty === 1'b0);

            @(negedge rclk);
            r_en = 1'b1;

            // For this asynchronous-read FIFO, check the
            // current address before the read pointer advances.
            #1;

            expected = expected_data[read_index];

            if (r_accept !== 1'b1) begin
                $display(
                    "ERROR: Read not accepted, time=%0t",
                    $time
                );
                errors = errors + 1;
            end

            if (r_data !== expected) begin
                $display(
                    "ERROR: Data mismatch: got=%02h expected=%02h time=%0t",
                    r_data, expected, $time
                );
                errors = errors + 1;
            end

            // The rising edge consumes the current word.
            @(posedge rclk);

            read_index = read_index + 1;
            reads_total = reads_total + 1;

            @(negedge rclk);
            r_en = 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // 5. Check that FIFO is full
    // ---------------------------------------------------------

    task check_full;
        begin
            repeat (5) @(posedge wclk);
            #1;

            if (w_full !== 1'b1) begin
                $display("ERROR: FIFO did not assert full.");
                errors = errors + 1;
            end
            else begin
                $display("PASS: FIFO full flag asserted.");
            end
        end
    endtask

    // ---------------------------------------------------------
    // 6. Check that FIFO is empty
    // ---------------------------------------------------------

    task check_empty;
        begin
            repeat (5) @(posedge rclk);
            #1;

            if (r_empty !== 1'b1) begin
                $display("ERROR: FIFO did not assert empty.");
                errors = errors + 1;
            end
            else begin
                $display("PASS: FIFO empty flag asserted.");
            end
        end
    endtask

    // ---------------------------------------------------------
    // 7. Main stress sequence
    // ---------------------------------------------------------

    initial begin
        errors = 0;
        test_done = 1'b0;

        write_index = 0;
        read_index = 0;
        sequence_number = 0;
        writes_total = 0;
        reads_total = 0;

        wrst_n = 1'b0;
        rrst_n = 1'b0;

        w_en = 1'b0;
        w_data = {DATA_WIDTH{1'b0}};
        r_en = 1'b0;

        $display("============================================");
        $display("Starting async_fifo_stress_tb");
        $display("DATA_WIDTH=%0d FIFO_DEPTH=%0d",
                 DATA_WIDTH, FIFO_DEPTH);
        $display("============================================");

        // -----------------------------------------------------
        // Reset and initialization
        // -----------------------------------------------------

        repeat (4) @(posedge wclk);

        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;

        // Allow both pointer synchronizers to settle.
        repeat (6) @(posedge wclk);
        repeat (6) @(posedge rclk);
        #1;

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO should start empty.");
            errors = errors + 1;
        end

        if (w_full !== 1'b0) begin
            $display("ERROR: FIFO should start not full.");
            errors = errors + 1;
        end

        // -----------------------------------------------------
        // Test 1: Fill FIFO completely
        // -----------------------------------------------------

        $display("TEST 1: Fill FIFO to capacity");

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            write_item(sequence_number);
            sequence_number = sequence_number + 1;
        end

        check_full;

        // Attempt an extra write while full.
        @(negedge wclk);
        w_data = 8'hEE;
        w_en = 1'b1;

        #1;
        if (w_accept !== 1'b0) begin
            $display("ERROR: Write accepted while full.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Write rejected while full.");
        end

        @(negedge wclk);
        w_en = 1'b0;

        // -----------------------------------------------------
        // Test 2: Drain FIFO completely
        // -----------------------------------------------------

        $display("TEST 2: Drain FIFO completely");

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_item;
        end

        check_empty;

        // Attempt an extra read while empty.
        @(negedge rclk);
        r_en = 1'b1;

        #1;
        if (r_accept !== 1'b0) begin
            $display("ERROR: Read accepted while empty.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Read rejected while empty.");
        end

        @(negedge rclk);
        r_en = 1'b0;

        // -----------------------------------------------------
        // Test 3: Repeated write/read bursts
        // -----------------------------------------------------

        $display("TEST 3: Repeated write/read bursts");

        for (phase = 0; phase < 10; phase = phase + 1) begin

            // Burst sizes vary from 1 to FIFO_DEPTH-1.
            count = (phase % (FIFO_DEPTH - 1)) + 1;

            $display(
                "Burst %0d: transferring %0d words",
                phase + 1, count
            );

            // Write this burst.
            for (i = 0; i < count; i = i + 1) begin
                write_item(sequence_number);
                sequence_number = sequence_number + 1;
            end

            // Allow write pointer to cross into read domain.
            repeat (5) @(posedge rclk);

            // Read the same number of words in FIFO order.
            for (i = 0; i < count; i = i + 1) begin
                read_item;
            end

            check_empty;
        end

        // -----------------------------------------------------
        // Test 4: Final consistency checks
        // -----------------------------------------------------

        $display("TEST 4: Final consistency");

        if (writes_total != reads_total) begin
            $display(
                "ERROR: Writes=%0d Reads=%0d",
                writes_total, reads_total
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "PASS: Total writes match total reads (%0d)",
                writes_total
            );
        end

        if (write_index != read_index) begin
            $display(
                "ERROR: Queue indexes differ: write=%0d read=%0d",
                write_index, read_index
            );
            errors = errors + 1;
        end
        else begin
            $display("PASS: All expected data entries were consumed.");
        end

        if (errors == 0) begin
            $display("============================================");
            $display("PASS: All stress checks passed.");
            $display("Total writes = %0d", writes_total);
            $display("Total reads  = %0d", reads_total);
            $display("============================================");
        end
        else begin
            $display("============================================");
            $display("FAIL: %0d error(s) detected.", errors);
            $display("Total writes = %0d", writes_total);
            $display("Total reads  = %0d", reads_total);
            $display("============================================");
        end

        test_done = 1'b1;
        $display("Test completed at %0t ns", $time);
        $finish;
    end

    // ---------------------------------------------------------
    // 8. Watchdog
    // ---------------------------------------------------------

    initial begin
        #1000000;

        if (!test_done) begin
            $display("ERROR: Stress test watchdog timeout.");
            $finish;
        end
    end

endmodule
