

module modadd#(
            parameter LOGQ                  =       64,
            parameter Reduc_param           =       17
        )
        (
            input [LOGQ-1:0] A,B,
            input [LOGQ-1:0] q,
            output[LOGQ-1:0] C
        );

wire [LOGQ:0] R;
wire [LOGQ:0] Rq;

assign R = A + B;
//assign Rq= R - {1'b0,q[31:13],13'b1};
assign Rq= R - {1'b0,q[LOGQ-1:Reduc_param],{Reduc_param-1{1'b0}},q[0]};
//assign Rq = R - q;

assign C = (Rq[LOGQ] == 0) ? Rq[LOGQ-1:0] : R[LOGQ-1:0];

endmodule
