module iterative_tp_param #(
    parameter TP           = 32,
    parameter LOGQ         = 32,
    parameter BTF_LAT      = 8
)(
    input clk, 
    input rst,
    input wire [LOGQ-1:0] q_in,
    input wire [LOGQ*TP-1:0] NTT_in,
    input wire [LOGQ*(TP-1)-1:0] W_in,
    output wire [LOGQ*TP-1:0] NTT_out
);

    localparam stage_nums =  $rtoi($ceil($clog2(TP)));

    wire [LOGQ-1:0] NTT_results [stage_nums-1:0][TP-1:0];
    wire [LOGQ-1:0] NTT_results_after [stage_nums-1:0][TP-1:0];

    reg        CT00 [stage_nums-1:0][(TP>>1)-1:0];
    reg        MT00 [stage_nums-1:0][(TP>>1)-1:0];
    reg [LOGQ-1:0] A00  [stage_nums-1:0][(TP>>1)-1:0];
    reg [LOGQ-1:0] B00  [stage_nums-1:0][(TP>>1)-1:0];
    reg [LOGQ-1:0] PSI00[stage_nums-1:0][(TP>>1)-1:0];
    reg [LOGQ-1:0] Q00  [stage_nums-1:0][(TP>>1)-1:0];
    wire[LOGQ-1:0] E00  [stage_nums-1:0][(TP>>1)-1:0];
    wire[LOGQ-1:0] O00  [stage_nums-1:0][(TP>>1)-1:0];
    wire[LOGQ-1:0] MUL00[stage_nums-1:0][(TP>>1)-1:0];
    wire[LOGQ-1:0] M3200[stage_nums-1:0][(TP>>1)-1:0];
    wire[LOGQ-1:0] ADD00[stage_nums-1:0][(TP>>1)-1:0];
    wire[LOGQ-1:0] SUB00[stage_nums-1:0][(TP>>1)-1:0];

    wire [LOGQ*(TP-1)-1:0] W_in_shifted [stage_nums-1:0] ;
    
        for (genvar i = 0; i < TP>>1 ; i = i + 1 ) begin
            always @(posedge clk or posedge rst) begin
                if(rst) begin
                    {A00[0][i],B00[0][i],PSI00[0][i],CT00[0][i],MT00[0][i],Q00[0][i]} <= 0;
                end
                else begin
                    {A00[0][i],B00[0][i],PSI00[0][i],CT00[0][i],MT00[0][i],Q00[0][i]} <= {NTT_in[(TP-2*i)*LOGQ-1-:LOGQ],NTT_in[(TP-(2*i+1))*LOGQ-1-:LOGQ],W_in[((TP-1)*LOGQ)-1-:LOGQ],1'b1,1'b0, q_in};
                end
            end
            
        end

        for (genvar i = 0; i < stage_nums; i = i + 1) begin 
            for (genvar j = 0; j < TP>>1 ; j = j + 1) begin
                assign NTT_results[i][2*j] = E00[i][j];
                assign NTT_results[i][2*j+1] = O00[i][j];

            end
        end

        for (genvar j = 0; j < stage_nums-1; j = j + 1) begin 
            for (genvar i = 0; i < TP>>1 ; i = i + 1) begin
                assign NTT_results_after[j+1][(((2*i)&((TP>>j)-1))/(TP>>(j+1))) + ((2*i) & ((TP>>(j+1))-1)) + (((2*i)/(TP>>(j)))*(TP>>(j)))] = NTT_results[j][2*i];
                assign NTT_results_after[j+1][(((2*i)&((TP>>j)-1))/(TP>>(j+1))) + ((2*i) & ((TP>>(j+1))-1)) + (((2*i)/(TP>>(j)))*(TP>>(j))) + ((TP>>(j+1))*1)] = NTT_results[j][2*i+1];
            end

        end

        for (genvar j = 1; j < stage_nums; j = j + 1) begin // For every stage
            for (genvar i = 0; i < (TP>>1); i = i + 1) begin // For every butterfly
                always @(posedge clk or posedge rst) begin
                    if(rst) begin
                        {A00[j][i],B00[j][i],PSI00[j][i],CT00[j][i],MT00[j][i],Q00[j][i]} <= 0;
                    end
                    else begin
                        {A00[j][i],B00[j][i],PSI00[j][i],CT00[j][i],MT00[j][i],Q00[j][i]} <= {NTT_results_after[j][2*i],NTT_results_after[j][2*i+1],W_in_shifted[j][((TP-1-(((1<<j)-1)+i/(TP>>(j+1))))*LOGQ)-1-:LOGQ],1'b1,1'b0,q_in};
                    end
                        
                end
            end
        end
        
    

    generate
	genvar m, k;	
        for (k = 0; k < stage_nums ; k = k + 1) begin
            for(m=0; m<(TP>>1) ;m=m+1) begin: BTF_GEN_BLOCK
                butterfly #(.LOGQ(LOGQ)) btfu00(clk,rst,CT00[k][m],MT00[k][m],A00[k][m],B00[k][m],PSI00[k][m],Q00[k][m],E00[k][m],O00[k][m],MUL00[k][m],M3200[k][m],ADD00[k][m],SUB00[k][m]);
            end
        end
        

    endgenerate



    for ( genvar i = 0; i < TP; i = i + 1) begin // For every stage
        assign NTT_out[(TP-(i))*LOGQ-1-:LOGQ] = {NTT_results[stage_nums-1][i]};
    end


    generate
        genvar b;
        for (b = 1; b < stage_nums ; b = b + 1 ) begin
            shiftreg #(.SHIFT(b*BTF_LAT),.DATA((TP-1)*LOGQ)) sre100(clk,rst,W_in,W_in_shifted[b]);
        end
    endgenerate






endmodule
