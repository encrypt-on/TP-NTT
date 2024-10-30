

`include "bu_def.vh"

module modmul#
            (
                parameter LOGQ = 32
            )
            (
                input        clk,rst,
                input [LOGQ-1:0] q,
                input [LOGQ-1:0] A,
                input [LOGQ-1:0] B,
                output[LOGQ-1:0] C,
                output[LOGQ-1:0] C_32
             );

localparam K = 2*LOGQ;
localparam MODRED_CC = (LOGQ == 32) ? `MODRED_CC_32 : `MODRED_CC_64;
// q registers
reg [LOGQ-1:0] qred,qint;

`ifdef USE_DFF_MODMUL
always @(posedge clk or posedge rst) begin
    if(rst)
        begin
            {qred,qint} <= 0;
        end
    else
        begin
            {qred,qint} <= {qint,q};
        end
end
`else
always @(posedge clk or posedge rst) begin
    if(rst)
        begin
            qred <= 0;
        end
    else
        begin
            qred <= q;
        end
end
`endif

// connections
wire [K-1:0] D;
reg  [K-1:0] D2;

intmul_standard#(.W_A(LOGQ), .W_B(LOGQ)) im(clk, rst, A, B, D);

// connection
`ifdef USE_DFF_MODMUL
always @(posedge clk or posedge rst) begin
    if(rst)
        D2 <= 0;
    else
        D2 <= D;
end
`else
always @(*) begin
    D2 = D;
end
`endif

// modular reduction
if (LOGQ == 32) begin
    modred_32 mr(clk,rst,qred,D2,C);
end else begin
    modred_64 mr(clk,rst,qred,D2,C);
end



// final LOGQ-bit
shiftreg #(.SHIFT(MODRED_CC),.DATA(LOGQ)) sre00(clk,rst,D2[LOGQ-1:0],C_32);

endmodule




