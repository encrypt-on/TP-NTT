`include "bu_def.vh"

// This unit can perform operations below:
// -- CT-based butterfly: 7(+1) cc latency
// -- GS-based butterfly: 7(+1) cc latency
// -- Modular add/sub   : 1 cc latency
// -- Modular mul       : 6 cc latency
// (more features will be added later ...)

module butterfly#(parameter LOGQ = 32)
                (
                 input clk,rst,
                 input CT,               // CT (1) or GS (0) structure
                 input MT,               // CT:0+MT:1--> a+b and (a+b)Psi
                 input [LOGQ-1:0] A,B,
                 input [LOGQ-1:0] PSI,
                 input [LOGQ-1:0] q,
                 output[LOGQ-1:0] E,O,       // butterfly outputs
                 output[LOGQ-1:0] MUL,       // modular mult output
                 output[LOGQ-1:0] M32,       // modular mult output (for m_tilde)
                 output[LOGQ-1:0] ADD,SUB);  // modular add/sub outputs

// CT:0 -> GS-based butterfly (take input from A,B,PSI -- output from E,O)
// CT:1 -> CT-based butterfly (take input from A,B,PSI -- output from E,O)
// CT:0 -> Mod Add/Sub (take input from A,B -- output from ADD/SUB)
// CT:1 -> Mod Mult (take input from B,PSI -- output from MUL)

localparam MODMUL_CC = (LOGQ == 32) ? `MODMUL_CC_32 : `MODMUL_CC_64;
localparam BTRFLY_CC = (LOGQ == 32) ? `BTRFLY_CC_32 : `BTRFLY_CC_64;

// Signals
wire [LOGQ-1:0] Ar6;
wire [LOGQ-1:0] w0,w1;
wire [LOGQ-1:0] w2,w3;
reg  [LOGQ-1:0] w2r1,w3r1;
wire [LOGQ-1:0] w3r2;
wire [LOGQ-1:0] w2r1d6;
wire [LOGQ-1:0] w4;
reg  [LOGQ-1:0] PSIr1;
wire [LOGQ-1:0] PSIw;
wire [LOGQ-1:0] w5,w5_2,w5_3;
wire [LOGQ-1:0] w6;
reg  [LOGQ-1:0] w6r1;
wire [LOGQ-1:0] w7;

// Registered control signals
wire [LOGQ-1:0] q_addsub;
wire [LOGQ-1:0] q_modmul;

wire [LOGQ-1:0] q_d1,q_d6;
wire        mt_d1,mt_d6;

wire        ct_d,ct_o;

shiftreg #(.SHIFT(BTRFLY_CC-1),.DATA(1))  sre04(clk,rst,CT,ct_d);

assign ct_o = ct_d | CT;

shiftreg #(.SHIFT(1),.DATA(LOGQ)) sre00(clk,rst,q,q_d1);
shiftreg #(.SHIFT(MODMUL_CC),.DATA(LOGQ)) sre01(clk,rst,q,q_d6);
shiftreg #(.SHIFT(1),.DATA(1))  sre02(clk,rst,MT,mt_d1);
shiftreg #(.SHIFT(MODMUL_CC),.DATA(1))  sre03(clk,rst,MT,mt_d6);

assign q_addsub = (ct_o) ? q_d6 : q   ;
assign q_modmul = (ct_o) ? q    : q_d1;

// Operations

shiftreg #(.SHIFT(MODMUL_CC),.DATA(LOGQ)) sre10(clk,rst,A,Ar6);

assign w0 = (ct_o) ? w5_3 : B;
assign w1 = (ct_o) ? Ar6  : A;

modadd#(.LOGQ(LOGQ), .Reduc_param(17)) ma0(w1,w0,q_addsub,w2);
modsub#(.LOGQ(LOGQ), .Reduc_param(17)) ms0(w1,w0,q_addsub,w3);

always @(posedge clk or posedge rst) begin
    if(rst)
        {w2r1,w3r1} <= 0;
    else
        {w2r1,w3r1} <= {w2,w3};
end

shiftreg #(.SHIFT(MODMUL_CC),.DATA(LOGQ)) sre20(clk,rst,w2r1,w2r1d6);

assign w7 = (ct_o) ? w2r1 : w2r1d6;

assign w3r2 = (mt_d1) ? w2r1 : w3r1;
assign w4   = (ct_o)    ? B : w3r2;

always @(posedge clk or posedge rst) begin
    if(rst)
        PSIr1 <= 0;
    else
        PSIr1 <= PSI;
end

assign PSIw = (ct_o) ? PSI : PSIr1;


modmul#(.LOGQ(LOGQ)) mm0(clk,rst,q_modmul,w4,PSIw,w5,w5_2);


assign w6 = (ct_o) ? w3r1 : w5;

assign w5_3 = (mt_d6) ? w5_2 : w5;

always @(posedge clk or posedge rst) begin
    if(rst)
        w6r1 <= 0;
    else
        w6r1 <= w6;
end

// ---------------------------------------- Final Outputs

assign E = w7;
assign O = w3r1;

assign MUL = w5;
assign M32 = w5_2;

assign ADD = w2r1;
assign SUB = w3r1;

endmodule




