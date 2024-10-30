
module wordred_64 #(parameter I_SIZE=0, O_SIZE=0)
                (input clk,rst,
                 input [46:0] qH,
                 input [16:0] CL,
                 input [I_SIZE-1:0] CH,
                 output [O_SIZE-1:0] T
                );


//(* use_dsp = "yes" *)reg [O_SIZE-1:0] DSPout;
(* use_dsp = "yes" *) reg [42:0] p0_0,p0_1;
(* use_dsp = "no" *) reg [O_SIZE-1:0] OUTPUT_RES;

wire [16:0] CLn;
wire        Cin;

reg [I_SIZE-1:0] CH_q;
reg  Cin_q;

assign CLn = -CL;
assign Cin = CL[16] | CLn[16];


always @(posedge clk or posedge rst) begin
    if(rst) begin
        p0_0 <= 0;
        p0_1 <= 0;

        OUTPUT_RES <= 0;
        Cin_q <= 0;
        CH_q <= 0;
    end
    else begin
        p0_0 <= CLn[16:0] * qH[25:0];
        p0_1 <= CLn[16:0] * qH[46:26];

        Cin_q <= Cin;
        CH_q <= CH;
        OUTPUT_RES <= {{21'b0,p0_0}} + {{p0_1,26'b0}} + CH_q + Cin_q;
    end
        
end

assign T = OUTPUT_RES;

endmodule

