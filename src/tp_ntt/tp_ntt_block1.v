module tp_ntt_block1#(
        parameter iter_choice   = 1,
        parameter N             = 128,
        parameter n1            = 8,
        parameter n2            = 2,
        parameter size0         = 16,
        parameter TP            = 8,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8,
        parameter no_read_write = 0,
        parameter which_block   = 0
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQ-1:0]              Q_in,
        input   [TP*LOGQ-1:0]           NTT_INPUT,
        input   [(TP-1)*LOGQ-1:0]       TWIDDLE_INPUT,
        output reg [TP*LOGQ-1:0]           NTT_OUTPUT
    );

    localparam log_n1 = $rtoi($ceil($clog2(n1)));
    localparam log_n2 = $rtoi($ceil($clog2(n2)));
    localparam log_TP = $rtoi($ceil($clog2(TP)));
    localparam log_N = $rtoi($ceil($clog2(N)));
    localparam log_n1_over_n2 = $rtoi($ceil($clog2(n1/n2)));
    localparam log_TP_over_n2 = $rtoi($ceil($clog2(TP/n2)));
    localparam n1_over_n2 = $rtoi($ceil((n1/n2)));
    localparam size0_over_tp = $rtoi($ceil((n1*n2/TP)));
    localparam log_size0_over_tp = $rtoi($ceil($clog2((n1*n2)/TP)));
    localparam N_over_TP_log2 = $rtoi($ceil($clog2(N/TP)));
    localparam LOG_LOG_Q = $rtoi($ceil($clog2(LOGQ)));
    localparam depth         =  $rtoi($ceil(N/TP));
    localparam depth_log         =  $rtoi($ceil($clog2(N/TP)));

    localparam reg_ctr = $clog2(size0_over_tp);
    localparam bram_reg_size =  (TP/n1)*(n1-1);

    localparam shift_len = no_read_write ? 2 : size0_over_tp+4;
    localparam iter_part_num_tot = iter_choice == 0 ? 2 : (iter_choice == 1 ? 3 : 4);

    localparam extra_wait = (which_block == 2 || which_block == 3) ? 2 : 0;




    reg start_addr_gen;
    wire start_addr_gen_shifted, start_addr_gen_shifted_v2, start_addr_gen_shifted_v3;

    wire [(size0_over_tp+1)*TP-1:0] read_addr_res;
    wire [(size0_over_tp+1)*TP-1:0] write_addr_res;

    localparam OP_IDLE                  = 2'd0;
    localparam OP_TWIDDLE_LOAD          = 2'd1;
    localparam OP_STARTED               = 2'd2;
    localparam OP_Q_LOAD                = 2'd3;

    reg [1:0] OP_TYPE;

    reg [1:0] curr_state, next_state;


    reg [LOGQ-1:0]                  di00     [1*(TP)-1:0];
    wire[LOGQ-1:0]                  do00     [1*(TP)-1:0];
    reg [(reg_ctr+1)-1:0]           dw00     [1*(TP)-1:0];
    reg [(reg_ctr+1)-1:0]           dr00     [1*(TP)-1:0];
    reg                             de00     [1*(TP)-1:0];

    
    
    reg [LOGQ-1:0]              bi0     [1*(bram_reg_size)-1:0];
    wire[LOGQ-1:0]              bo0     [1*(bram_reg_size)-1:0];
    reg [N_over_TP_log2-1:0]    bw0     [1*(bram_reg_size)-1:0];
    reg [N_over_TP_log2-1:0]    br0     [1*(bram_reg_size)-1:0];
    reg                         be0     [1*(bram_reg_size)-1:0];
    
    
    


    reg [depth_log+1:0] twid_ctr;
    reg [reg_ctr:0] ctr;
    wire [reg_ctr:0] ctr_shifted;

    reg        CT00         [(TP>>1)-1:0];
    reg        MT00         [(TP>>1)-1:0];
    reg [LOGQ-1:0] A00      [(TP>>1)-1:0];
    reg [LOGQ-1:0] B00      [(TP>>1)-1:0];
    reg [LOGQ-1:0] PSI00    [(TP>>1)-1:0];
    reg [LOGQ-1:0] Q00      [(TP>>1)-1:0];
    reg [5:0] K100          [(TP>>1)-1:0];
    reg [5:0] K200          [(TP>>1)-1:0];
    reg [5:0] M00           [(TP>>1)-1:0];
    wire[LOGQ-1:0] E00      [(TP>>1)-1:0];
    wire[LOGQ-1:0] O00      [(TP>>1)-1:0];
    wire[LOGQ-1:0] MUL00    [(TP>>1)-1:0];
    wire[LOGQ-1:0] M3200    [(TP>>1)-1:0];
    wire[LOGQ-1:0] ADD00    [(TP>>1)-1:0];
    wire[LOGQ-1:0] SUB00    [(TP>>1)-1:0];

    reg [TP*LOGQ-1:0] NTT_param_in, NTT_param_out_reg;
    wire [TP*LOGQ-1:0] NTT_param_out;
    reg [(bram_reg_size)*LOGQ-1:0] W_param_in;
    reg [LOGQ-1:0] q_param_in;

    wire [TP*LOGQ-1:0] NTT_param_out_shift_d2;
    
    

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start_addr_gen <= 1'b0;
        end else begin
            case (curr_state)
                OP_STARTED: 
                    start_addr_gen <= 1'b1; 
                default: begin
                    start_addr_gen <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            twid_ctr <= 0;
        end else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    twid_ctr <= twid_ctr + 1;
                end 
                OP_STARTED: begin
                    twid_ctr <= twid_ctr + 1;
                end
                default: begin
                    twid_ctr <= 0;
                end
                
            endcase
            
        end
    end

    always @(posedge clk) 
    begin
        if(rst)
            curr_state <= OP_IDLE;
        else
            curr_state <= next_state;
    end

    // New Next State Logic
    always @(*) begin
        next_state = curr_state;
        case (curr_state)
            OP_IDLE: begin
                case (OP_TYPE_INPUT)
                    2'd0: begin
                        if (START_NTT) begin
                            next_state = OP_STARTED;
                        end else begin
                            next_state = OP_IDLE;
                        end
                        
                    end 
                    2'd1: begin
                        next_state = OP_TWIDDLE_LOAD;
                    end
                    2'd2: begin
                        next_state = OP_STARTED;
                    end
                    2'd3: begin
                        next_state = OP_Q_LOAD;
                    end
                    default: begin
                        next_state = OP_IDLE;
                    end
                endcase
            end 
            OP_TWIDDLE_LOAD: begin
                next_state = (twid_ctr == (iter_part_num_tot)*depth-1) ? OP_IDLE : OP_TWIDDLE_LOAD;
            end
            OP_STARTED: begin
                next_state =  OP_STARTED;
            end
            OP_Q_LOAD: begin
                next_state = (ctr == 1) ? OP_IDLE : OP_Q_LOAD;
            end
            
           
            default: begin
                next_state = OP_IDLE;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ctr <= 0;
        end else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    ctr <= ctr + 1;
                end 
                OP_STARTED: begin
                    if (start_addr_gen_shifted) begin
                        ctr <= ctr + 1;
                    end else begin
                        ctr <= ctr;
                    end
                end
                OP_Q_LOAD: begin
                    ctr <= ctr + 1;
                end
                default: begin
                    ctr <= 0;
                end
                
            endcase
            
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q_param_in <= 0;
        end else begin
            case (curr_state)
                OP_Q_LOAD: begin
                    q_param_in <= Q_in;
                end 

                default: begin
                    q_param_in <= q_param_in;
                end
                
            endcase
        end
    end


    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < TP-1  ; i = i+1 ) begin
                bi0[i]       <= 0;
                br0[i]       <= 0;
                bw0[i]       <= 0;
                be0[i]       <= 0;
            end
        end else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    for (i = 0; i < bram_reg_size  ; i = i+1 ) begin
                        if(twid_ctr >= (which_block<<depth_log) && twid_ctr < (which_block+1)<<depth_log) begin
                            bi0[i]       <= TWIDDLE_INPUT[(TP-1-i)*LOGQ-1-:LOGQ];
                            br0[i]       <= 0;
                            bw0[i]       <= (twid_ctr & (depth-1));
                            be0[i]       <= 1'b1;
                        end
                        else begin
                            bi0[i]       <= 0;
                            br0[i]       <= 0;
                            bw0[i]       <= 0;
                            be0[i]       <= 0;
                        end
                        
                    end
                end
                OP_STARTED: begin
                    for (i = 0; i < bram_reg_size  ; i = i+1 ) begin
                        br0[i]       <= (twid_ctr & (depth-1));
                    end
                end
                default: begin
                    for (i = 0; i < bram_reg_size  ; i = i+1 ) begin
                        bi0[i]       <= 0;
                        br0[i]       <= 0;
                        bw0[i]       <= 0;
                        be0[i]       <= 0;
                    end
                end
            endcase
        end
    end

    integer k;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (k = 0; k < TP  ; k = k+1 ) begin
                di00[k]       <= 0;
                dr00[k]       <= 0;
                dw00[k]       <= 0;
                de00[k]       <= 0;
            end
        end else begin
            case (curr_state)
                OP_STARTED: begin
                    for (k = 0; k < TP  ; k = k+1 ) begin
                        if(start_addr_gen_shifted_v2) begin
                            di00[k]       <= NTT_param_out_shift_d2[(TP-k)*LOGQ-1-:LOGQ];
                            dr00[k]       <= read_addr_res[(TP-k)*(reg_ctr+1)-1-:reg_ctr+1];
                            dw00[k]       <= write_addr_res[(TP-k)*(reg_ctr+1)-1-:reg_ctr+1];
                            de00[k]       <= 1'b1;
                        end
                        else begin
                            di00[k]       <=    0;
                            dr00[k]       <=    0;
                            dw00[k]       <=    0;
                            de00[k]       <=    0;
                        end
                    end
                end
                default: begin
                    for (k = 0; k < TP  ; k = k+1 ) begin
                        di00[k]       <=    0;
                        dr00[k]       <=    0;
                        dw00[k]       <=    0;
                        de00[k]       <=    0;
                    end
                end
            endcase
        end
    end


    integer j1, j2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            NTT_param_in    <= 0;
            W_param_in      <= 0;
        end else begin
            case (curr_state)
                OP_STARTED: begin
                    for (j2 = 0; j2 < bram_reg_size ; j2 = j2 + 1 ) begin
                        W_param_in[(bram_reg_size-j2)*LOGQ-1-:LOGQ]      <= bo0[j2];
                    end
                    for (j1 = 0; j1 < TP ; j1 = j1 + 1 ) begin
                        if (no_read_write) begin
                            NTT_param_in[( TP - (( (j1 & (n1/2-1))*2 + (j1 & (n1-1))/(n1/2) + (j1/n1)*n1) & (TP-1)) )*LOGQ-1-:LOGQ]    <= NTT_INPUT[(TP-j1)*LOGQ-1-:LOGQ];
                        end else begin
                            NTT_param_in[( TP - (( ((j1 & (n2-1))*n1) + (j1/(TP>>1)) + ((j1 & ((TP>>1)-1))/(TP/n1))*2) & (TP-1)) )*LOGQ-1-:LOGQ]    <= NTT_INPUT[(TP-j1)*LOGQ-1-:LOGQ];
                        end
                    end
                end 
                default: begin
                    NTT_param_in    <= 0;
                    W_param_in      <= 0;
                end
            endcase
            
        end
    end

    integer rot;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            NTT_param_out_reg <= 0;
        end
        else begin
            for (rot = 0; rot < TP ; rot = rot + 1 ) begin
                NTT_param_out_reg[(TP-((rot/(TP/n2) + (rot&(TP/n2-1))*n2 + (ctr&(size0/TP-1)) )&(TP-1)))*LOGQ-1-:LOGQ] <= NTT_param_out[(TP-rot)*LOGQ-1-:LOGQ];
            end
        end
    end

    


    generate
        // If this is last block
        if (no_read_write == 1'b0) begin
            addr_gen_small #(N, n1, n2, n1*n2 ,TP, LOGQ, BTF_LAT) small_addr_gen_sm_unit (clk, rst, start_addr_gen_shifted, read_addr_res, write_addr_res);
        end 
    endgenerate

    generate

        genvar c2, b2;
        // If this is last block
        if (no_read_write == 1'b0) begin
            for(c2=0; c2<TP ;c2=c2+1) begin: BRAM_GEN_BLOCK_NTT0 // BRAM for NTT
                BRAM #(LOGQ, $rtoi($ceil(2*size0_over_tp)), $rtoi($ceil($clog2(2*size0_over_tp)))) bm000(clk,de00[1*c2+0],dw00[1*c2+0],di00[1*c2+0],dr00[1*c2+0],do00[1*c2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
            end
        end 
        
        for(b2=0; b2<bram_reg_size ;b2=b2+1) begin: BRAM_GEN_BLOCK_TWIDDLE // BRAM for TWIDDLE
            BRAM #(LOGQ, $rtoi($ceil(N>>log_TP)), $rtoi($ceil($clog2((N>>log_TP))))) bt000(clk,be0[1*b2+0],bw0[1*b2+0],bi0[1*b2+0],br0[1*b2+0],bo0[1*b2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
        end
        

    endgenerate
    
    generate

        genvar ntt_idx;
        for (ntt_idx = 0; ntt_idx < (TP>>log_n1) ; ntt_idx = ntt_idx + 1) begin
            iterative_tp_param #(n1, LOGQ, BTF_LAT) NTT_units_pipelined(clk,rst, q_param_in ,NTT_param_in[(TP-n1*ntt_idx)*LOGQ-1-:n1*LOGQ], W_param_in[(bram_reg_size-(n1-1)*ntt_idx)*LOGQ-1-:(n1-1)*LOGQ], NTT_param_out[(TP-n1*ntt_idx)*LOGQ-1-:n1*LOGQ]);
        end 

    endgenerate

    

    shiftreg #(.SHIFT(log_n1*BTF_LAT + extra_wait),.DATA(1)) sre100(clk,rst,start_addr_gen,start_addr_gen_shifted);

    shiftreg #(.SHIFT(log_n1*BTF_LAT+2 + extra_wait),.DATA(1)) sre102(clk,rst,start_addr_gen,start_addr_gen_shifted_v2);

    shiftreg #(.SHIFT(1),.DATA(TP*LOGQ)) sre101(clk,rst,NTT_param_out_reg,NTT_param_out_shift_d2);

    shiftreg #(.SHIFT(shift_len),.DATA(reg_ctr+1)) sre104(clk,rst,ctr,ctr_shifted);
    

    integer final_int;
    // Output ROtaion for Next Block
    always @(posedge clk or posedge rst) begin
        if(rst) begin 
           for (final_int = 0; final_int < TP ; final_int = final_int + 1 ) begin
                NTT_OUTPUT[(TP-final_int)*LOGQ-1-:LOGQ] <= 0;
            end     
        end
        else begin
            for (final_int = 0; final_int < TP ; final_int = final_int + 1 ) begin
                if (no_read_write) begin
                    NTT_OUTPUT[(TP-final_int)*LOGQ-1-:LOGQ] <= NTT_param_out[(TP-final_int)*LOGQ-1-:LOGQ];
                end else begin
                    //NTT_OUTPUT[(TP-final_int)*LOGQ-1-:LOGQ] <= do00[(final_int+(ctr_shifted&(n2-1)))&(TP-1)];
                    //NTT_OUTPUT[(TP-final_int)*LOGQ-1-:LOGQ] <= do00[(((final_int>>log_n2)<<(log_n2)) + (((final_int&(n2-1))&(1'd1))<<(log_n2-1)) + ((final_int&(n2-1))>>1) + (ctr_shifted&(n2-1)))&(TP-1)];
                    NTT_OUTPUT[(TP-final_int)*LOGQ-1-:LOGQ] <= do00[(final_int + (ctr_shifted&(size0_over_tp-1)))&(TP-1)];
                end
                
            end
        end
        
        
    end
    
    

endmodule
