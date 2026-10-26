
`timescale 1ns / 1ps

module async_fifo_pointer_tb;

    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH);
    parameter PTR_WIDTH = ADDR_WIDTH + 1;

    reg wclk = 1'b0;
    reg rclk = 1'b0;
    reg wrst_n = 1'b0;
    reg rrst_n = 1'b0;

    reg w_en = 1'b0;
    reg [DATA_WIDTH-1:0] w_data = 0;
    wire w_full, w_accept;

    reg r_en = 1'b0;
    wire [DATA_WIDTH-1:0] r_data;
    wire r_empty, r_accept;

    integer errors = 0;
    integer i, phase;
    integer sequence_number = 0;
    reg test_done = 1'b0;

    reg [DATA_WIDTH-1:0] expected_data;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .SYNC_STAGES(2)
    ) dut (
        .wclk(wclk), .wrst_n(wrst_n),
        .w_en(w_en), .w_data(w_data),
        .w_full(w_full), .w_accept(w_accept),
        .rclk(rclk), .rrst_n(rrst_n),
        .r_en(r_en), .r_data(r_data),
        .r_empty(r_empty), .r_accept(r_accept)
    );

    always #5 wclk = ~wclk;
    always #7 rclk = ~rclk;

    function integer bit_count;
        input [PTR_WIDTH-1:0] value;
        integer k;
        begin
            bit_count = 0;
            for (k = 0; k < PTR_WIDTH; k = k + 1)
                bit_count = bit_count + value[k];
        end
    endfunction

    task check_write_pointer;
        input [PTR_WIDTH-1:0] old_bin;
        input [PTR_WIDTH-1:0] old_gray;
        reg [PTR_WIDTH-1:0] expected_bin;
        reg [PTR_WIDTH-1:0] expected_gray;
        reg [PTR_WIDTH-1:0] gray_delta;
        begin
            expected_bin = old_bin + 1'b1;
            expected_gray = (expected_bin >> 1) ^ expected_bin;

            if (dut.wbin !== expected_bin) begin
                $display("ERROR: wbin=%0d expected=%0d",
                         dut.wbin, expected_bin);
                errors = errors + 1;
            end

            if (dut.wgray !== expected_gray) begin
                $display("ERROR: wgray=%b expected=%b",
                         dut.wgray, expected_gray);
                errors = errors + 1;
            end

            gray_delta = old_gray ^ dut.wgray;
            if (bit_count(gray_delta) != 1) begin
                $display("ERROR: Write Gray pointer changed %0d bits.",
                         bit_count(gray_delta));
                errors = errors + 1;
            end

            if (old_bin == {PTR_WIDTH{1'b1}} &&
                dut.wbin !== {PTR_WIDTH{1'b0}}) begin
                $display("ERROR: Write binary pointer failed to wrap.");
                errors = errors + 1;
            end
        end
    endtask

    task check_read_pointer;
        input [PTR_WIDTH-1:0] old_bin;
        input [PTR_WIDTH-1:0] old_gray;
        reg [PTR_WIDTH-1:0] expected_bin;
        reg [PTR_WIDTH-1:0] expected_gray;
        reg [PTR_WIDTH-1:0] gray_delta;
        begin
            expected_bin = old_bin + 1'b1;
            expected_gray = (expected_bin >> 1) ^ expected_bin;

            if (dut.rbin !== expected_bin) begin
                $display("ERROR: rbin=%0d expected=%0d",
                         dut.rbin, expected_bin);
                errors = errors + 1;
            end

            if (dut.rgray !== expected_gray) begin
                $display("ERROR: rgray=%b expected=%b",
                         dut.rgray, expected_gray);
                errors = errors + 1;
            end

            gray_delta = old_gray ^ dut.rgray;
            if (bit_count(gray_delta) != 1) begin
                $display("ERROR: Read Gray pointer changed %0d bits.",
                         bit_count(gray_delta));
                errors = errors + 1;
            end

            if (old_bin == {PTR_WIDTH{1'b1}} &&
                dut.rbin !== {PTR_WIDTH{1'b0}}) begin
                $display("ERROR: Read binary pointer failed to wrap.");
                errors = errors + 1;
            end
        end
    endtask

    task write_checked;
        input [DATA_WIDTH-1:0] value;
        reg [PTR_WIDTH-1:0] old_bin;
        reg [PTR_WIDTH-1:0] old_gray;
        begin
            @(negedge wclk);
            w_data = value;
            w_en = 1'b1;
            #1;

            if (w_accept !== 1'b1) begin
                $display("ERROR: Expected write acceptance for %h.", value);
                errors = errors + 1;
                w_en = 1'b0;
            end
            else begin
                old_bin = dut.wbin;
                old_gray = dut.wgray;

                @(posedge wclk);
                #1;
                check_write_pointer(old_bin, old_gray);

                @(negedge wclk);
                w_en = 1'b0;
            end
        end
    endtask

    task read_checked;
        input [DATA_WIDTH-1:0] expected;
        integer timeout_count;
        reg [PTR_WIDTH-1:0] old_bin;
        reg [PTR_WIDTH-1:0] old_gray;
        begin
            timeout_count = 0;

            while ((r_empty !== 1'b0) && (timeout_count < 40)) begin
                @(posedge rclk);
                #1;
                timeout_count = timeout_count + 1;
            end

            if (r_empty !== 1'b0) begin
                $display("ERROR: Timed out waiting for read data.");
                errors = errors + 1;
            end
            else begin
                @(negedge rclk);
                r_en = 1'b1;
                #1;

                if (r_accept !== 1'b1) begin
                    $display("ERROR: Expected read acceptance.");
                    errors = errors + 1;
                    r_en = 1'b0;
                end
                else begin
                    if (r_data !== expected) begin
                        $display("ERROR: Data=%h expected=%h",
                                 r_data, expected);
                        errors = errors + 1;
                    end

                    old_bin = dut.rbin;
                    old_gray = dut.rgray;

                    @(posedge rclk);
                    #1;
                    check_read_pointer(old_bin, old_gray);

                    @(negedge rclk);
                    r_en = 1'b0;
                end
            end
        end
    endtask

    initial begin
        $display("Starting async_fifo_pointer_tb");

        repeat (4) @(posedge wclk);
        @(negedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;

        repeat (6) @(posedge wclk);
        repeat (6) @(posedge rclk);
        #1;

        if (dut.wbin !== 0 || dut.wgray !== 0 ||
            dut.rbin !== 0 || dut.rgray !== 0) begin
            $display("ERROR: Pointers did not initialize to zero.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Binary and Gray pointers initialize to zero.");
        end

        // Three complete fill/drain cycles exercise multiple wraps.
        for (phase = 0; phase < 3; phase = phase + 1) begin
            $display("Pointer rollover phase %0d", phase + 1);

            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                expected_data = sequence_number;
                write_checked(expected_data);
                sequence_number = sequence_number + 1;
            end

            // Allow full flag to settle.
            @(posedge wclk);
            #1;
            if (w_full !== 1'b1) begin
                $display("ERROR: FIFO should be full after filling.");
                errors = errors + 1;
            end

            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                read_checked(i + phase * FIFO_DEPTH);
            end

            @(posedge rclk);
            #1;
            if (r_empty !== 1'b1) begin
                $display("ERROR: FIFO should be empty after draining.");
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: Pointer, Gray-code and rollover checks passed.");
        else
            $display("FAIL: %0d pointer-test error(s).", errors);

        test_done = 1'b1;
        $finish;
    end

    initial begin
        #100000;
        if (test_done !== 1'b1) begin
            $display("ERROR: Pointer test watchdog timeout.");
            $finish;
        end
    end

endmodule
