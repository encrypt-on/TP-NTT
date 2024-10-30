`include "dsp_def.vh"

module intmul_standard
   #(  
        parameter W_A     = 64,
        parameter W_B     = 64,
        parameter FF_IN   = 1 ,
        parameter FF_MUL  = 1 ,
        parameter FF_OUT  = 1 ,
        parameter USE_CSA = 1 ,
        parameter FF_CSA  = 1
    )
    (
        input                      clk,
        input                      rst,
        input wire  [W_A    -1:0]  A  ,
        input wire  [W_B    -1:0]  B  ,
        output wire [W_A+W_B-1:0]  C
    );

parameter LAT = FF_IN + FF_MUL + FF_OUT + (FF_CSA & USE_CSA);

localparam N_A = ((W_A - 1) / `DSP_A_U) + 1;
localparam N_B = ((W_B - 1) / `DSP_B_U) + 1;
localparam N_D = N_A + N_B - 1;
localparam CSA_OUT_W = W_A + W_B + $rtoi($ceil($clog2(N_D)));

integer i;

///////////////////////////// signals ///////////////////////////////////

wire [`DSP_A_U-1:0] A_i   [0:N_A-1];
reg  [`DSP_A_U-1:0] A_i_q [0:N_A-1];
wire [`DSP_A_U-1:0] A_i_mx[0:N_A-1];

wire [`DSP_B_U-1:0] B_i   [0:N_B-1];
reg  [`DSP_B_U-1:0] B_i_q [0:N_B-1];
wire [`DSP_B_U-1:0] B_i_mx[0:N_B-1];


wire [`DSP_M_U-1:0] P   [0:N_A-1][0:N_B-1];
reg  [`DSP_M_U-1:0] P_q [0:N_A-1][0:N_B-1];
wire [`DSP_M_U-1:0] P_mx[0:N_A-1][0:N_B-1];

reg  [W_A+W_B-1:0] D   [0:N_D-1];
for (genvar i = 0; i < N_D; i = i + 1) begin
    initial D[i] = 0;
end

reg  [W_A+W_B-1:0] S;
reg  [W_A+W_B-1:0] S_q;


wire [CSA_OUT_W-1:0] CSA_OUT    [0:1];
reg  [CSA_OUT_W-1:0] CSA_OUT_q  [0:1];
wire [CSA_OUT_W-1:0] CSA_OUT_mx [0:1];


/////////////////////////////////////////////////////////////////////////




///////////////////////////// partitioning //////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    if (i == (N_A - 1)) begin
        assign A_i[i] = A[W_A - 1 : `DSP_A_U*i];
    end
    else begin
        assign A_i[i] = A[`DSP_A_U*i +: `DSP_A_U];
    end
end

for (genvar i = 0; i < N_B; i = i + 1) begin
    if (i == (N_B - 1)) begin
        assign B_i[i] = B[W_B - 1 : `DSP_B_U*i];
    end
    else begin
        assign B_i[i] = B[`DSP_B_U*i +: `DSP_B_U];
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// pipeline steps ////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    assign A_i_mx[i] = (FF_IN) ? A_i_q[i] : A_i[i];
end

for (genvar i = 0; i < N_B; i = i + 1) begin
    assign B_i_mx[i] = (FF_IN) ? B_i_q[i] : B_i[i];
end

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        assign P_mx[i][j] = (FF_MUL) ? P_q[i][j] : P[i][j];
    end
end

for (genvar i = 0; i < 2; i = i + 1) begin
    assign CSA_OUT_mx[i] = (FF_CSA) ? CSA_OUT_q[i] : CSA_OUT[i];
end

assign C = (FF_OUT) ? S_q : S;

/////////////////////////////////////////////////////////////////////////




///////////////////////////// multiplication ////////////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        assign P[i][j] = A_i_mx[i] * B_i_mx[j];
    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// diagonal assignments //////////////////////

for (genvar i = 0; i < N_A; i = i + 1) begin
    for (genvar j = 0; j < N_B; j = j + 1) begin
        always @(*) begin
            if (((i*`DSP_A_U) + (j*`DSP_B_U) + `DSP_M_U) <= (W_A+W_B)) begin
                D[(i-j+N_D) % N_D][(i*`DSP_A_U) + (j*`DSP_B_U) +: `DSP_M_U] = P_mx[i][j];
            end
            else begin
                D[(i-j+N_D) % N_D][W_A + W_B - 1 : (i*`DSP_A_U) + (j*`DSP_B_U)] = P_mx[i][j];
            end
        end

    end
end

/////////////////////////////////////////////////////////////////////////




///////////////////////////// summation /////////////////////////////////



if (USE_CSA) begin

    csa_tree #(
        W_A + W_B,
        N_D
    ) CSA_TREE (
        D,
        CSA_OUT
    );

    always @(*) begin
        for (i = 0; i < N_D; i = i + 1) begin
            S = CSA_OUT_mx[0] + CSA_OUT_mx[1];
        end
    end

end 
else begin

    always @(*) begin
        S = 0;
        for (i = 0; i < N_D; i = i + 1) begin
            S = S + D[i];
        end
    end

end
/////////////////////////////////////////////////////////////////////////




///////////////////////////// sequential logic //////////////////////////

if (FF_IN) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        always @(posedge clk) begin
            A_i_q[i] <= A_i[i];
        end
    end
    for (genvar i = 0; i < N_B; i = i + 1) begin
        always @(posedge clk) begin
            B_i_q[i] <= B_i[i];
        end
    end
end

if (FF_MUL) begin
    for (genvar i = 0; i < N_A; i = i + 1) begin
        for (genvar j = 0; j < N_B; j = j + 1) begin
            always @(posedge clk) begin
                P_q[i][j] <= P[i][j];
            end
        end
    end
end

if (FF_CSA) begin
    for (genvar i = 0; i < 2; i = i + 1) begin
        always @(posedge clk) begin
            CSA_OUT_q[i] <= CSA_OUT[i];
        end
    end
end

if (FF_OUT) begin
    always @(posedge clk) begin
        S_q <= S;
    end
end

/////////////////////////////////////////////////////////////////////////


endmodule
