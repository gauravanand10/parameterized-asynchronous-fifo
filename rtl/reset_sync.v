
`timescale 1ns / 1ps

module reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire srst_n
);

    // Two-stage reset synchronizer.
    // ASYNC_REG helps Vivado identify these registers.
    (* ASYNC_REG = "TRUE" *)
    reg [1:0] reset_pipe;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            reset_pipe <= 2'b00;
        else
            reset_pipe <= {reset_pipe[0], 1'b1};
    end

    // Active-low synchronized reset output.
    assign srst_n = reset_pipe[1];

endmodule
