`timescale 1ns / 1ps

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
    parameter SYNC_STAGES = 2
)(
    // Write clock domain
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  w_en,
    input  wire [DATA_WIDTH-1:0] w_data,
    output reg                   w_full,
    output wire                  w_accept,

    // Read clock domain
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  r_en,
    output wire [DATA_WIDTH-1:0] r_data,
    output reg                   r_empty,
    output wire                  r_accept
);

    // ---------------------------------------------------------
    // 1. FIFO parameters and pointer widths
    // ---------------------------------------------------------
    localparam ADDR_WIDTH = (FIFO_DEPTH >= 2)
                          ? $clog2(FIFO_DEPTH) : 1;

    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    // Invert the two most significant Gray-pointer bits
    // when comparing for the full condition.
    localparam [PTR_WIDTH-1:0] FULL_MASK =
        ({{(PTR_WIDTH-2){1'b0}}, 2'b11} << (PTR_WIDTH-2));

    // ---------------------------------------------------------
    // 2. FIFO memory
    // ---------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // ---------------------------------------------------------
    // 3. Binary and Gray pointers
    // ---------------------------------------------------------
    reg [PTR_WIDTH-1:0] wbin;
    reg [PTR_WIDTH-1:0] wgray;

    reg [PTR_WIDTH-1:0] rbin;
    reg [PTR_WIDTH-1:0] rgray;

    // Synchronized pointers in the opposite clock domains
    wire [PTR_WIDTH-1:0] rgray_sync_w;
    wire [PTR_WIDTH-1:0] wgray_sync_r;

    // ---------------------------------------------------------
    // 4. Accepted operations
    // ---------------------------------------------------------
    assign w_accept = w_en && !w_full;
    assign r_accept = r_en && !r_empty;

    // ---------------------------------------------------------
    // 5. Synchronize Gray pointers across clock domains
    // ---------------------------------------------------------
    sync_2ff #(
        .WIDTH(PTR_WIDTH),
        .STAGES(SYNC_STAGES),
        .HAS_RESET(1)
    ) sync_rgray_to_wclk (
        .clk      (wclk),
        .rst_n    (wrst_n),
        .async_in (rgray),
        .sync_out (rgray_sync_w)
    );

    sync_2ff #(
        .WIDTH(PTR_WIDTH),
        .STAGES(SYNC_STAGES),
        .HAS_RESET(1)
    ) sync_wgray_to_rclk (
        .clk      (rclk),
        .rst_n    (rrst_n),
        .async_in (wgray),
        .sync_out (wgray_sync_r)
    );

    // ---------------------------------------------------------
    // 6. Calculate next binary pointers
    // ---------------------------------------------------------
    wire [PTR_WIDTH-1:0] wbin_next;
    wire [PTR_WIDTH-1:0] rbin_next;

    assign wbin_next = wbin + w_accept;
    assign rbin_next = rbin + r_accept;

    // ---------------------------------------------------------
    // 7. Convert next binary pointers to Gray code
    // ---------------------------------------------------------
    wire [PTR_WIDTH-1:0] wgray_next;
    wire [PTR_WIDTH-1:0] rgray_next;

    assign wgray_next = (wbin_next >> 1) ^ wbin_next;
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    // ---------------------------------------------------------
    // 8. Calculate next full and empty flags
    // ---------------------------------------------------------
    wire w_full_next;
    wire r_empty_next;

    // FIFO is full when the next write Gray pointer equals
    // the synchronized read Gray pointer with its top two
    // bits inverted.
    assign w_full_next =
        (wgray_next == (rgray_sync_w ^ FULL_MASK));

    // FIFO is empty when the next read Gray pointer equals
    // the synchronized write Gray pointer.
    assign r_empty_next =
        (rgray_next == wgray_sync_r);

    // ---------------------------------------------------------
    // 9. Write-domain pointer and full-flag registers
    // ---------------------------------------------------------
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin   <= {PTR_WIDTH{1'b0}};
            wgray  <= {PTR_WIDTH{1'b0}};
            w_full <= 1'b0;
        end else begin
            wbin   <= wbin_next;
            wgray  <= wgray_next;
            w_full <= w_full_next;
        end
    end

    // Write memory only when a write is accepted.
    always @(posedge wclk) begin
        if (wrst_n && w_accept)
            mem[wbin[ADDR_WIDTH-1:0]] <= w_data;
    end

    // ---------------------------------------------------------
    // 10. Read-domain pointer and empty-flag registers
    // ---------------------------------------------------------
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= {PTR_WIDTH{1'b0}};
            rgray  <= {PTR_WIDTH{1'b0}};
            r_empty <= 1'b1;
        end else begin
            rbin   <= rbin_next;
            rgray  <= rgray_next;
            r_empty <= r_empty_next;
        end
    end

    // ---------------------------------------------------------
    // 11. Asynchronous read from FIFO memory
    // ---------------------------------------------------------
    // r_data is meaningful when the FIFO is not empty.
    assign r_data = mem[rbin[ADDR_WIDTH-1:0]];

    // ---------------------------------------------------------
    // 12. Elaboration-time parameter validation
    // ---------------------------------------------------------
    // Invalid configurations intentionally instantiate an
    // undefined module, causing elaboration to fail.
    generate
        if ((DATA_WIDTH < 1) ||
            (FIFO_DEPTH < 2) ||
            ((FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0) ||
            (SYNC_STAGES < 2)) begin : g_invalid_parameters

            ASYNC_FIFO_INVALID_PARAMETERS invalid_configuration();

        end
    endgenerate

endmodule
