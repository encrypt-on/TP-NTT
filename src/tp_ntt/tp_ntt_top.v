`include "bu_def.vh"

module tp_ntt_top#(
        parameter N             = 1<<16,
        parameter n1            = 1<<6,
        parameter n2            = 1<<4,
        parameter n3            = 1<<6,
        parameter n4            = 1<<0,
        parameter TP            = 1<<6,
        parameter LOGQ          = 32
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input       [            1:0]   OP_TYPE_INPUT,
        input       [LOGQ       -1:0]   Q_in,
        input       [TP*LOGQ    -1:0]   NTT_INPUT,
        input       [(TP-1)*LOGQ-1:0]   TWIDDLE_INPUT,
        output reg  [TP*LOGQ    -1:0]   NTT_OUTPUT
    );

    localparam BTF_LAT = (LOGQ == 32) ? `BTRFLY_CC_32 : `BTRFLY_CC_64;
    localparam DIM   = (n4 != 1) ? 2 : ((n3 != 1) ? 1 : 0);
    localparam log_n1 = $rtoi($ceil($clog2(n1)));
    localparam log_n2 = $rtoi($ceil($clog2(n2)));
    localparam log_n3 = $rtoi($ceil($clog2(n3)));
    localparam log_n4 = $rtoi($ceil($clog2(n4)));
    localparam depth         =  $rtoi($ceil(N/TP));
    localparam size0_over_tp =  $rtoi($ceil(n1*n2/TP));
    localparam size1_over_tp =  $rtoi($ceil(n3*n4/TP));

    wire START_NTT_2, START_NTT_3, START_NTT_4;
    wire [TP*LOGQ-1:0] NTT_READ_STAGE0, NTT_READ_STAGE1, NTT_READ_STAGE2, NTT_READ_STAGE3;

    generate
        if(DIM == 0) begin // 2D
            tp_ntt_block1#(DIM, N, n1, n2, n1*n2, TP, LOGQ, BTF_LAT, 0, 0) unit_super1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, Q_in, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
            tp_ntt_block2#(DIM, N, n2, n1*n2, 1, TP, LOGQ, BTF_LAT, 1)    unit_super_v2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
        end
        else if(DIM == 1) begin // 3D
            tp_ntt_block1#(DIM, N, n1, n2, n1*n2, TP, LOGQ, BTF_LAT, 0, 0) unit_super1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, Q_in, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
            tp_ntt_block2#(DIM, N, n2, n1*n2, n3, TP, LOGQ, BTF_LAT, 0)   unit_super_v2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
            tp_ntt_block1#(DIM, N, n3, 1, n3*1, TP, LOGQ, BTF_LAT, 1, 2)   unit_super2 (clk, rst, START_NTT_3 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE1, TWIDDLE_INPUT, NTT_READ_STAGE2);

        end
        else begin // 4D
            tp_ntt_block1#(DIM, N, n1, n2, n1*n2, TP, LOGQ, BTF_LAT, 0, 0)  unit_super1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, Q_in, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
            tp_ntt_block2#(DIM, N, n2, n1*n2, n3*n4, TP, LOGQ, BTF_LAT, 0) unit_super_v2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
            tp_ntt_block1#(DIM, N, n3, n4, n3*n4, TP, LOGQ, BTF_LAT, 0, 2)  unit_super2 (clk, rst, START_NTT_3 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE1, TWIDDLE_INPUT, NTT_READ_STAGE2);
            tp_ntt_block1#(DIM, N, n4, n3, n3*n4, TP, LOGQ, BTF_LAT, 1, 3)  unit_super3 (clk, rst, START_NTT_4 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE2, TWIDDLE_INPUT, NTT_READ_STAGE3);
        end
    endgenerate


    shiftreg #(.SHIFT(BTF_LAT*log_n1+size0_over_tp+4),.DATA(1)) sre101(clk,rst,START_NTT_ALL,START_NTT_2);
    shiftreg #(.SHIFT(BTF_LAT*log_n2+6+depth),.DATA(1)) sre102(clk,rst,START_NTT_2,START_NTT_3);
    shiftreg #(.SHIFT(BTF_LAT*log_n3+size1_over_tp+6),.DATA(1)) sre103(clk,rst,START_NTT_3,START_NTT_4);


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            NTT_OUTPUT <= 0;
        end else begin
            if(DIM == 0) begin
                NTT_OUTPUT <= NTT_READ_STAGE1;
            end
            else if(DIM == 1) begin
                NTT_OUTPUT <= NTT_READ_STAGE2;
            end
            else begin
                NTT_OUTPUT <= NTT_READ_STAGE3;
            end
            
        end    
    end


endmodule
