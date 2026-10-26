
`timescale 1ns / 1ps

module async_fifo_concurrent_tb;

    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 16;
    parameter TOTAL_ITEMS = 64;

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
    integer write_count;
    integer read_count;
    integer i;
    reg test_done;

    // FIFO under test
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

    // Write clock: 10 ns period
    initial begin
        wclk = 1'b0;
        forever #5 wclk = ~wclk;
    end

    // Read clock: 14 ns period
    initial begin
        rclk = 1'b0;
        forever #7 rclk = ~rclk;
    end

    // Write one word, waiting if FIFO is full
    task write_item;
        input [DATA_WIDTH-1:0] value;
        begin
            @(negedge wclk);

            while (w_full === 1'b1)
                @(negedge wclk);

            w_data = value;
            w_en = 1'b1;

            #1;
            if (w_accept !== 1'b1) begin
                $display("ERROR: Write not accepted, data=%h time=%0t",
                         value, $time);
                errors = errors + 1;
            end
            else begin
                write_count = write_count + 1;
            end

            @(posedge wclk);
            @(negedge wclk);
            w_en = 1'b0;
        end
    endtask

    // Read one word and check its expected value
    task read_item;
        input [DATA_WIDTH-1:0] expected;
        integer wait_cycles;
        begin
            wait_cycles = 0;

            // Wait until synchronized write-pointer information
            // indicates that the FIFO contains data.
            while ((r_empty === 1'b1) && (wait_cycles < 1000)) begin
                @(negedge rclk);
                wait_cycles = wait_cycles + 1;
            end

            if (r_empty !== 1'b0) begin
                $display("ERROR: Read timeout waiting for data at time %0t",
                         $time);
                errors = errors + 1;
            end
            else begin
                r_en = 1'b1;
                #1;

                if (r_accept !== 1'b1) begin
                    $display("ERROR: Read not accepted at time %0t", $time);
                    errors = errors + 1;
                end
                else begin
                    if (r_data !== expected) begin
                        $display(
                            "ERROR: Read index=%0d actual=%h expected=%h time=%0t",
                            read_count, r_data, expected, $time
                        );
                        errors = errors + 1;
                    end
                    else begin
                        $display("PASS: Read index=%0d data=%h",
                                 read_count, r_data);
                    end

                    read_count = read_count + 1;
                end

                @(posedge rclk);
                @(negedge rclk);
                r_en = 1'b0;
            end
        end
    endtask

    // Main test
    initial begin
        errors = 0;
        write_count = 0;
        read_count = 0;
        test_done = 1'b0;

        wrst_n = 1'b0;
        rrst_n = 1'b0;
        w_en = 1'b0;
        w_data = {DATA_WIDTH{1'b0}};
        r_en = 1'b0;

        $display("------------------------------------------");
        $display("Starting async_fifo_concurrent_tb");
        $display("DATA_WIDTH=%0d FIFO_DEPTH=%0d TOTAL_ITEMS=%0d",
                 DATA_WIDTH, FIFO_DEPTH, TOTAL_ITEMS);
        $display("------------------------------------------");

        // Reset both domains
        repeat (4) @(posedge wclk);
        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;

        // Allow reset release and pointer synchronizers to settle
        repeat (6) @(posedge wclk);
        repeat (6) @(posedge rclk);

        #1;

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO should initially be empty.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO starts empty.");
        end

        $display("Starting concurrent write and read traffic.");

        // Run producer and consumer concurrently
        fork
            begin : producer
                for (i = 0; i < TOTAL_ITEMS; i = i + 1)
                    write_item(i);
                $display("Producer finished: accepted count=%0d",
                         write_count);
            end

            begin : consumer
                integer j;
                for (j = 0; j < TOTAL_ITEMS; j = j + 1)
                    read_item(j);
                $display("Consumer finished: read count=%0d",
                         read_count);
            end
        join

        // Allow the read-side empty flag to settle
        repeat (6) @(posedge rclk);
        #1;

        if (write_count != TOTAL_ITEMS) begin
            $display("ERROR: Write count=%0d expected=%0d",
                     write_count, TOTAL_ITEMS);
            errors = errors + 1;
        end
        else begin
            $display("PASS: All %0d words accepted for writing.",
                     TOTAL_ITEMS);
        end

        if (read_count != TOTAL_ITEMS) begin
            $display("ERROR: Read count=%0d expected=%0d",
                     read_count, TOTAL_ITEMS);
            errors = errors + 1;
        end
        else begin
            $display("PASS: All %0d words read.", TOTAL_ITEMS);
        end

        if (r_empty !== 1'b1) begin
            $display("ERROR: FIFO should be empty after all reads.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO is empty after concurrent traffic.");
        end

        if (errors == 0)
            $display("PASS: All concurrent FIFO checks passed.");
        else
            $display("FAIL: %0d error(s) detected.", errors);

        test_done = 1'b1;
        $display("Test completed at %0t", $time);
        $finish;
    end

    // Watchdog
    initial begin
        #200000;
        if (test_done !== 1'b1) begin
            $display("ERROR: Watchdog timeout.");
            $finish;
        end
    end

endmodule
