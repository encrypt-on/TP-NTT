
module modred_64(input clk,rst,
            input [63:0] q,
            input [127:0] D,
            output reg [63:0] C
);



reg [46:0] q2, q3, q4, q5;

always @(posedge clk or posedge rst) begin
    if(rst)
        {q5,q4,q3,q2} <= 0;
    else
        {q5,q4,q3,q2} <= {q4,q3,q2,q[63:17]}; 
end


// Step#1
wire [111:0] D2;

wordred_64 #(111,112) step1(clk,rst,q[63:17],D[16:0],D[127:17],D2); //1_cc



// Step#2
wire [95:0] D3;

wordred_64 #(95,96) step2(clk,rst,q2,D2[16:0],D2[111:17],D3); //1_cc



// Step#3
wire [79:0] D4;

wordred_64 #(79,80) step3(clk,rst,q3,D3[16:0],D3[95:17],D4); //1_cc



// Step#4
wire [63:0] D5;

wordred_64 #(63,64) step4(clk,rst,q4,D4[16:0],D4[79:17],D5); //1_cc



wire signed [65:0] D6;

//assign D6 = D5[63:0]-{1'b0,q5,17'b1};
assign D6 = D5-{1'b0,q5,17'b1};

always @(posedge clk or posedge rst) begin //1_cc
    if(rst) begin
        C <= 0;
    end
    else begin
        case(D6[65])
        0: C <= D6[63:0];
        1: C <= D5[63:0];
        endcase
    end
end

endmodule

