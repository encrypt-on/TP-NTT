
module wordred_32 #(parameter I_SIZE=0, O_SIZE=0)
                   (input clk,rst,
                    input [18:0] qH,
                    input [12:0] CL,
                    input [I_SIZE-1:0] CH,
                    output [O_SIZE-1:0] T
                   );

(* use_dsp = "yes" *) reg [O_SIZE-1:0] DSPout;

wire [12:0] CLn;
wire        Cin;

assign CLn = -CL;
assign Cin = CL[12] | CLn[12];

always @(posedge clk or posedge rst) begin
    if(rst)
        DSPout <= 0;
    else
        DSPout <= CLn*qH + CH + Cin;
end

assign T = DSPout;

endmodule
