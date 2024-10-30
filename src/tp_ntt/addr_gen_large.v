module addr_gen_large#(
        parameter N             = 128,
        parameter n2            = 2,
        parameter size0         = 16,
        parameter size1         = 16,    
        parameter TP            = 8,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8
    )
    (
        input                 clk,
        input                 rst,
        input                 start,
        output reg [($rtoi($ceil($clog2(N/TP)))+1)*TP-1:0]         read_addr,
        output reg [($rtoi($ceil($clog2(N/TP)))+1)*TP-1:0]         write_addr     
    );

    localparam log_n2 = $rtoi($ceil($clog2(n2)));


    localparam log_N = $rtoi($ceil($clog2(N)));
    localparam depth = $rtoi($ceil(N/TP));
    localparam log_depth = $rtoi($ceil($clog2(depth)));
    localparam log_size1 = $rtoi($ceil($clog2(size1)));

    localparam size1_over_tp_log2 = $rtoi($ceil($clog2(size1/TP)));

    localparam size0_over_tp = size0/TP;
    localparam size1_over_tp = size1/TP;





    reg [log_depth:0] ctr;

    localparam OP_IDLE          = 1'd0;
    localparam OP_STARTED       = 1'd1;

    reg OP_TYPE;

    reg curr_state, next_state;


    always @(posedge clk) 
    begin
        if(rst)
            curr_state <= OP_IDLE;
        else
            curr_state <= next_state;
    end

    always @(*) begin
        next_state = curr_state;
        if (start) begin
            next_state = OP_STARTED;
        end else begin
            next_state = OP_IDLE;
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ctr <= 0;
        end else begin
            case (curr_state)
                OP_STARTED: begin
                    ctr <= ctr + 1;
                end 
                default: begin
                    ctr <= ctr;
                end
            endcase
            
        end
    end

    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < TP  ; i = i+1 ) begin
                read_addr[((TP-i)*(log_depth+1))-1-:(log_depth+1)]       <= 0;
                write_addr[((TP-i)*(log_depth+1))-1-:(log_depth+1)]      <= 0;
            end
        end else begin
            case (curr_state)
                OP_STARTED: begin
                    for (i = 0; i < TP  ; i = i+1 ) begin
                        read_addr[((TP-((i+(ctr>>(size1_over_tp_log2)))&(TP-1)))*(log_depth+1))-1-:(log_depth+1)]       <= ((((size0_over_tp)<<(size1_over_tp_log2))*i + (size0_over_tp)*(ctr&(size1_over_tp-1)) + ((ctr&(depth-1))>>log_size1)) & (depth-1)) + ((ctr<depth)<<log_depth);
                        write_addr[((TP-i)*((log_depth+1)))-1-:(log_depth+1)]      <= ctr;
                    end
                end 
                default: begin
                    for (i = 0; i < TP  ; i = i+1 ) begin
                        read_addr[((TP-i)*((log_depth+1)))-1-:((log_depth+1))]       <= 0;
                        write_addr[((TP-i)*((log_depth+1)))-1-:((log_depth+1))]      <= 0;
                    end
                end
            endcase
        end
        
    end






endmodule