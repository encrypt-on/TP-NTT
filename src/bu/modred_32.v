
module modred_32(input clk,rst,
                 input [31:0] q,
                 input [63:0] D,
                 output reg [31:0] C
                );

// q registers
reg [18:0] q2,q3,q4;

always @(posedge clk or posedge rst) begin
    if(rst)
        {q4,q3,q2} <= 0;
    else
        {q4,q3,q2} <= {q3,q2,q[31:13]};
end

// Step#1
wire [46:0] D2;
reg  [4:0]  T2;

wordred_32 #(46,47) step1(clk,rst,q[31:13],D[12:0],D[58:13],D2);

always @(posedge clk or posedge rst) begin
    if(rst)
        T2 <= 0;
    else
        T2 <= D[63:59];
end

// Step#2
wire [39:0] D3;
wire [5:0]  T3;

assign T3 = T2+D2[46];

wordred_32 #(39,40) step2(clk,rst,q2,D2[12:0],{T3,D2[45:13]},D3);

// Step#3
wire [32:0] D4;

wordred_32 #(27,33) step3(clk,rst,q3,D3[12:0],D3[39:13],D4);

// Final correction
wire signed [33:0] D5;

assign D5 = D4-{1'b0,q4,13'b1};

always @(posedge clk or posedge rst) begin
    if(rst) begin
        C <= 0;
    end
    else begin
        case(D5[33])
        0: C <= D5[31:0];
        1: C <= D4[31:0];
        endcase
    end
end

endmodule
