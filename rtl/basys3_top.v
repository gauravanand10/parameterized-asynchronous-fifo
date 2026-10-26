
module basys3_top #(
    parameter integer DATA_WIDTH = 12,
    parameter integer FIFO_DEPTH = 16
) (
    input  wire        CLK100MHZ,
    input  wire [15:0] SW,
    output wire [15:0] LED
);

    // --------------------------------------------------------
    // Derived parameters
    // --------------------------------------------------------
    localparam integer ADDR_WIDTH = $clog2(FIFO_DEPTH);
    localparam integer PTR_WIDTH  = ADDR_WIDTH + 1;

    // --------------------------------------------------------
    // Clocking Wizard
    // --------------------------------------------------------
    wire wclk;
    wire rclk;
    wire locked;

    // --------------------------------------------------------
    // Reset signals
    // --------------------------------------------------------
    wire arst_n;
    wire wrst_n;
    wire rrst_n;

    // --------------------------------------------------------
    // Synchronized switch inputs
    // --------------------------------------------------------
    wire [DATA_WIDTH-1:0] switch_data;
    wire [DATA_WIDTH-1:0] wdata_sync;

    wire wreq_sync;
    wire rreq_sync;
    wire view_sync;

    // --------------------------------------------------------
    // Request edge detection and arming
    // --------------------------------------------------------
    reg wreq_prev = 1'b0;
    reg rreq_prev = 1'b0;

    reg w_arm = 1'b0;
    reg r_arm = 1'b0;

    wire w_en;
    wire r_en;

    // --------------------------------------------------------
    // FIFO interface
    // --------------------------------------------------------
    wire [DATA_WIDTH-1:0] r_data;

    wire w_full;
    wire r_empty;

    wire w_accept;
    wire r_accept;

    // --------------------------------------------------------
    // LED data and operation indicators
    // --------------------------------------------------------
    reg [DATA_WIDTH-1:0] last_read_data;
    reg [DATA_WIDTH-1:0] display_data;

    reg write_toggle;
    reg read_toggle;

    genvar i;

    // --------------------------------------------------------
    // 1. Map physical data switches to configured data width
    // --------------------------------------------------------
    generate
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin : g_switch_data
            if (i < 12) begin : g_physical_switch
                assign switch_data[i] = SW[i];
            end
            else begin : g_zero_extend
                assign switch_data[i] = 1'b0;
            end
        end
    endgenerate

    // --------------------------------------------------------
    // 2. Combined active-low reset
    // Reset is active when SW15 is ON or MMCM is unlocked.
    // --------------------------------------------------------
    assign arst_n = ~(SW[15] | ~locked);

    // --------------------------------------------------------
    // 3. Clocking Wizard
    // Keep its reset LOW; SW15 resets the FIFO domains,
    // not the MMCM itself.
    // --------------------------------------------------------
    clk_wiz_0 u_clk_wiz (
        .clk_in1  (CLK100MHZ),
        .reset    (1'b0),
        .locked   (locked),
        .clk_out1 (wclk),
        .clk_out2 (rclk)
    );

    // --------------------------------------------------------
    // 4. Separate reset synchronizers for each clock domain
    // --------------------------------------------------------
    reset_sync u_reset_w (
        .clk    (wclk),
        .arst_n (arst_n),
        .srst_n (wrst_n)
    );

    reset_sync u_reset_r (
        .clk    (rclk),
        .arst_n (arst_n),
        .srst_n (rrst_n)
    );

    // --------------------------------------------------------
    // 5. Synchronize write request and data into write domain
    // --------------------------------------------------------
    sync_2ff #(
        .WIDTH(1),
        .STAGES(2),
        .HAS_RESET(0)
    ) u_sync_wreq (
        .clk      (wclk),
        .rst_n    (wrst_n),
        .async_in (SW[14]),
        .sync_out (wreq_sync)
    );

    sync_2ff #(
        .WIDTH(DATA_WIDTH),
        .STAGES(2),
        .HAS_RESET(0)
    ) u_sync_wdata (
        .clk      (wclk),
        .rst_n    (wrst_n),
        .async_in (switch_data),
        .sync_out (wdata_sync)
    );

    // --------------------------------------------------------
    // 6. Synchronize read request and view select into
    //    the read clock domain
    // --------------------------------------------------------
    sync_2ff #(
        .WIDTH(1),
        .STAGES(2),
        .HAS_RESET(0)
    ) u_sync_rreq (
        .clk      (rclk),
        .rst_n    (rrst_n),
        .async_in (SW[13]),
        .sync_out (rreq_sync)
    );

    sync_2ff #(
        .WIDTH(1),
        .STAGES(2),
        .HAS_RESET(0)
    ) u_sync_view (
        .clk      (rclk),
        .rst_n    (rrst_n),
        .async_in (SW[12]),
        .sync_out (view_sync)
    );

    // --------------------------------------------------------
    // 7. Write request arming and edge detection
    //
    // After reset release, first sample the synchronized
    // switch state. Do not generate a request on that cycle.
    // Subsequent transitions generate one-cycle requests.
    // --------------------------------------------------------
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wreq_prev <= 1'b0;
            w_arm     <= 1'b0;
        end
        else if (!w_arm) begin
            wreq_prev <= wreq_sync;
            w_arm     <= 1'b1;
        end
        else begin
            wreq_prev <= wreq_sync;
        end
    end

    assign w_en = wrst_n && w_arm &&
                  (wreq_sync ^ wreq_prev);

    // --------------------------------------------------------
    // 8. Read request arming and edge detection
    // --------------------------------------------------------
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rreq_prev <= 1'b0;
            r_arm     <= 1'b0;
        end
        else if (!r_arm) begin
            rreq_prev <= rreq_sync;
            r_arm     <= 1'b1;
        end
        else begin
            rreq_prev <= rreq_sync;
        end
    end

    assign r_en = rrst_n && r_arm &&
                  (rreq_sync ^ rreq_prev);

    // --------------------------------------------------------
    // 9. FIFO core
    // --------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_async_fifo (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .w_en     (w_en),
        .w_data   (wdata_sync),
        .w_full   (w_full),
        .w_accept (w_accept),

        .rclk     (rclk),
        .rrst_n   (rrst_n),
        .r_en     (r_en),
        .r_data   (r_data),
        .r_empty  (r_empty),
        .r_accept (r_accept)
    );

    // --------------------------------------------------------
    // 10. Write-accepted indicator
    // --------------------------------------------------------
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            write_toggle <= 1'b0;
        else if (w_accept)
            write_toggle <= ~write_toggle;
    end

    // --------------------------------------------------------
    // 11. Read-accepted indicator and last-read register
    // --------------------------------------------------------
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            last_read_data <= {DATA_WIDTH{1'b0}};
            read_toggle    <= 1'b0;
        end
        else if (r_accept) begin
            last_read_data <= r_data;
            read_toggle    <= ~read_toggle;
        end
    end

    // --------------------------------------------------------
    // 12. Registered data-view selection
    // SW12 = 0: last accepted read
    // SW12 = 1: peek at next word, or zero when empty
    // --------------------------------------------------------
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            display_data <= {DATA_WIDTH{1'b0}};
        end
        else if (view_sync) begin
            if (r_empty)
                display_data <= {DATA_WIDTH{1'b0}};
            else
                display_data <= r_data;
        end
        else begin
            display_data <= last_read_data;
        end
    end

    // --------------------------------------------------------
    // 13. Data LEDs LD0-LD11
    // Unused LEDs are zero for narrower DATA_WIDTH values.
    // --------------------------------------------------------
    generate
        for (i = 0; i < 12; i = i + 1) begin : g_data_leds
            if (i < DATA_WIDTH) begin : g_data_bit
                assign LED[i] = display_data[i];
            end
            else begin : g_zero_led
                assign LED[i] = 1'b0;
            end
        end
    endgenerate

    // --------------------------------------------------------
    // 14. Status LEDs
    // --------------------------------------------------------
    assign LED[12] = w_full;
    assign LED[13] = r_empty;
    assign LED[14] = write_toggle;
    assign LED[15] = read_toggle;

endmodule
