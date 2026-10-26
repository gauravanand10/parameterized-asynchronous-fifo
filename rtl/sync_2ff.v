
`timescale 1ns / 1ps

module sync_2ff #(
    parameter WIDTH     = 1,
    parameter STAGES    = 2,
    parameter HAS_RESET = 1
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [WIDTH-1:0]     async_in,
    output wire [WIDTH-1:0]     sync_out
);

    // All synchronizer stages stored in one flat vector.
    // ASYNC_REG helps Vivado recognize synchronizer registers.
    (* ASYNC_REG = "TRUE" *)
    reg [WIDTH*STAGES-1:0] sync_pipe;

    genvar k;

    generate
        // -----------------------------------------------------
        // Option 1: Synchronizer with asynchronous active-low reset
        // -----------------------------------------------------
        if (HAS_RESET == 1) begin : g_with_reset

            for (k = 0; k < STAGES; k = k + 1) begin : g_stage

                if (k == 0) begin : g_first_stage

                    always @(posedge clk or negedge rst_n) begin
                        if (!rst_n)
                            sync_pipe[WIDTH-1:0] <= {WIDTH{1'b0}};
                        else
                            sync_pipe[WIDTH-1:0] <= async_in;
                    end

                end else begin : g_later_stages

                    always @(posedge clk or negedge rst_n) begin
                        if (!rst_n)
                            sync_pipe[(k+1)*WIDTH-1:k*WIDTH]
                                <= {WIDTH{1'b0}};
                        else
                            sync_pipe[(k+1)*WIDTH-1:k*WIDTH]
                                <= sync_pipe[k*WIDTH-1:(k-1)*WIDTH];
                    end

                end
            end

        end else begin : g_without_reset

            // -------------------------------------------------
            // Option 2: Free-running synchronizer without reset
            // Used for switch-input synchronization.
            // rst_n is intentionally unused in this branch.
            // -------------------------------------------------
            for (k = 0; k < STAGES; k = k + 1) begin : g_stage

                if (k == 0) begin : g_first_stage

                    always @(posedge clk) begin
                        sync_pipe[WIDTH-1:0] <= async_in;
                    end

                end else begin : g_later_stages

                    always @(posedge clk) begin
                        sync_pipe[(k+1)*WIDTH-1:k*WIDTH]
                            <= sync_pipe[k*WIDTH-1:(k-1)*WIDTH];
                    end

                end
            end

        end
    endgenerate

    // Output comes from the final synchronizer stage.
    assign sync_out =
        sync_pipe[WIDTH*STAGES-1:WIDTH*(STAGES-1)];

    // Elaboration-time parameter check.
    // An invalid configuration intentionally causes elaboration to fail.
    generate
        if ((WIDTH < 1) || (STAGES < 2)) begin : g_invalid_parameters
            SYNC_2FF_INVALID_PARAMETERS invalid_configuration();
        end
    endgenerate

endmodule
