`timescale 1ns/10ps

module  CONV(
	input				clk,
	input				reset,
	output logic		busy,	
	input				ready,	
	//gray-image mem
	output logic [13:0]	iaddr,
	input  		 [7:0]	idata,	
	output logic		ioe,
	//L0 mem
	output logic		wen_L0,
	output logic		oe_L0,
	output logic [13:0]	addr_L0,
	output logic [11:0] w_data_L0,
	input  		 [11:0] r_data_L0,
	//L1 mem
	output logic 		wen_L1,
	output logic		oe_L1,
	output logic [11:0]	addr_L1,
	output logic [11:0]	w_data_L1,
	input  		 [11:0]	r_data_L1,
	//weight mem
	output logic		oe_weight,
	output logic [15:0]	addr_weight,
	input  logic signed  [7:0]  r_data_weight,
	//L2 mem
	output logic		wen_L2,
	output logic [3:0]	addr_L2,
	output logic [31:0]	w_data_L2
	);

localparam IDLE = 3'd0;
localparam LAYER0 = 3'd1;
localparam LAYER1 = 3'd2;
localparam LAYER2 = 3'd3;
localparam W0 = 3'd4;
localparam W1 = 3'd5;
localparam W2 = 3'd6;
localparam FINISH = 3'd7;

reg [2:0] currentState, nextState;
reg [13:0] center;
reg [3:0] counter;
reg last_zeropad;

reg max_counter;
reg [5:0] max_addr_col, max_addr_row;
reg max_col, max_row;

reg signed [31:0] fc_temp, fc_temp2;
reg [12:0] fc_cnt;
reg [15:0] weight_addr;
reg [1:0] x,y;

reg signed [10:0] col1, col2, col3;
reg signed [12:0] convSum1, convSum2, convSum3;

wire signed [31:0] mul_result;
multiply u0(.clk(clk), .reset(reset), .a(r_data_weight), .b(r_data_L1), .ans(mul_result));

always @(posedge clk or posedge reset) begin
	if (reset) currentState <= IDLE;
	else currentState <= nextState;
end

always @(*) begin
	case (currentState)
		IDLE: nextState = (ready)? LAYER0 : IDLE;
		LAYER0: nextState = (counter == 4'd10)? W0 : LAYER0;
		W0: nextState = LAYER1;
		LAYER1: nextState = (max_counter)? W1 : LAYER1;
		W1: nextState = (center == 14'd16383)? LAYER2 : LAYER0;
		LAYER2: nextState = (fc_cnt == 13'd4102)? W2 : LAYER2;
		W2: nextState = (counter == 4'd9)? FINISH : LAYER2;
		FINISH: nextState = FINISH;
		default: nextState = IDLE;
	endcase
end

always @(*) begin
    case (y)
        0: begin
            col1 = ~(idata<<1)+1;
            col2 = 0;
            col3 = idata;
        end
        1: begin
            col1 = 0;
            col2 = idata;
            col3 = idata<<1;
        end
        2: begin
            col1 = idata;
            col2 = idata<<1;
            col3 = ~((idata<<1) + idata)+1;
        end
        default: begin
            col1 = 0;
            col2 = 0;
            col3 = 0;
        end
    endcase
end


always @(posedge clk or posedge reset) begin
	if (reset) begin
		busy <= 0;
		
		ioe <= 0;
		iaddr <= 0;

		wen_L0 <= 0;
		oe_L0 <= 0;
		addr_L0 <= 0;
		w_data_L0 <= 0;

		wen_L1 <= 0;
		oe_L1 <= 0;
		addr_L1 <= 0;
		w_data_L1 <= 0;

		oe_weight <= 0;
		addr_weight <= 0;

		wen_L2 <= 0 ;
		addr_L2 <= 0;
		w_data_L2 <= 0;

		center <= {7'd0, 7'd0};
		last_zeropad <= 0;
		counter <= 0;
		max_counter <= 0;
		max_col <= 0;
		max_row <= 0;
		max_addr_col <= 0;
		max_addr_row <= 0;
		fc_temp <= 0;
		fc_temp2 <= 0;
		fc_cnt <= 0;
		weight_addr <= 0;
        x <= 3;
        y <= 0;
        convSum1 <= 0;
        convSum2 <= 0;
        convSum3 <= 0; 
	end

	else begin
		case (currentState)

			LAYER0: begin
				busy <= 1;
				counter <= counter + 4'd1;
				ioe <= 1;

				wen_L0 <= 0;
				wen_L1 <= 0;
				
                case (counter)
                    2,3,5,6,8,9: y <= y + 1; 
                    1,4,7,10: begin
                        y <= 0;
                        x <= (center[6:0] != 0)? 2 : x + 1; 
                    end
                endcase
                
                
                case (x)
                    0: convSum1 <= (last_zeropad)? convSum1 : convSum1 + col1; 
                    1: begin
                        convSum1 <= (last_zeropad)? convSum1 : convSum1 + col2;
                        convSum2 <= (last_zeropad)? convSum2 : convSum2 + col1;
                    end
                    2: begin
                        convSum1 <= (last_zeropad)? convSum1 : convSum1 + col3;
                        convSum2 <= (last_zeropad)? convSum2 : convSum2 + col2;
                        convSum3 <= (last_zeropad)? convSum3 : convSum3 + col1;
                    end
                endcase

				case (counter)
					4'd1: last_zeropad <= (center[13:7]==7'd0 | center[6:0]==7'd0)? 1'd1 : 1'd0;
					4'd2: last_zeropad <= (center[6:0]==7'd0)? 1'd1: 1'd0;
					4'd3: last_zeropad <= (center[13:7]==7'd127 | center[6:0]==7'd0)? 1'd1 : 1'd0;
					4'd4: last_zeropad <= (center[13:7]==7'd0)? 1'd1: 1'd0 ;
					4'd5: last_zeropad <= 1'd0;
					4'd6: last_zeropad <= (center[13:7]==7'd127)? 1'd1 : 1'd0;
					4'd7: last_zeropad <= (center[13:7]==7'd0 | center[6:0]==7'd127)? 1'd1 : 1'd0;
					4'd8: last_zeropad <= (center[6:0]==7'd127)? 1'd1 : 1'd0;
					4'd9: last_zeropad <= (center[13:7]==7'd127 | center[6:0]==7'd127)? 1'd1 : 1'd0;
				endcase

				case (counter)
                    0,1,2: iaddr[6:0] <= center[6:0] - 7'd1;
                    3,4,5: iaddr[6:0] <= center[6:0];
                    6,7,8: iaddr[6:0] <= center[6:0] + 7'd1;
                endcase

                case (counter)
                    0,3,6: iaddr[13:7] <= center[13:7] - 7'd1;
                    1,4,7: iaddr[13:7] <= center[13:7];
                    2,5,8: iaddr[13:7] <= center[13:7] + 7'd1;
                endcase
			end

			W0: begin
				addr_L0 <= center;
				wen_L0 <= 1;
				w_data_L0 <= (convSum1[12])? 12'd0 : convSum1[11:0];			
			end

			LAYER1: begin
				oe_L0 <= 1;
				addr_L0 <= center;
				max_counter <= ~max_counter;

				if (max_row | max_col) begin
					oe_L1 <= 1;
					addr_L1 <= {max_addr_row, max_addr_col};
				end
			end

			W1: begin
				oe_L0 <= 0;
				oe_L1 <= 0;
				center <= center + 14'd1;
                x <= 3;
                convSum3 <= 0;
				if (center[6:0] == 7'd127) begin
					counter <= 0;
					max_row <= ~max_row;
                    convSum1 <= 0;
                    convSum2 <= 0; 
				end
				else begin
					counter <= 4'd6;
                    convSum1 <= convSum2;
                    convSum2 <= convSum3;
				end

				wen_L1 <= 1;
				addr_L1 <= {max_addr_row, max_addr_col};
				w_data_L1 <= (max_row | max_col)? (r_data_L0 > r_data_L1)? r_data_L0 : r_data_L1 : r_data_L0;

				max_col <= ~max_col;
				max_addr_col <= (max_col)? max_addr_col + 6'd1 : max_addr_col;
				max_addr_row <= (max_row && center[6:0] == 7'd127)? max_addr_row + 6'd1 : max_addr_row;
			end

			LAYER2: begin
				wen_L1 <= 0;
				fc_cnt <= fc_cnt + 13'd1;
				weight_addr <= weight_addr + 16'd1;
				oe_weight <= 1;
				oe_L1 <= 1;
				addr_L1 <= weight_addr[11:0];
				addr_weight <= weight_addr;

				if (fc_cnt > 6) begin
					fc_temp <= fc_temp + mul_result;
				end
			end

			W2: begin
				oe_weight <= 0;
				oe_L1 <= 0;
				wen_L2 <= 1;
				addr_L2 <= counter;
				w_data_L2 <= (fc_temp[31])? fc_temp>>>16 : fc_temp;

				fc_cnt <= 0;
				weight_addr <= weight_addr - 16'd7;
				counter <= counter + 4'd1;
				fc_temp <= 0;
			end

			FINISH: begin
				busy <= 0;
			end 
		endcase
	end
end

endmodule

module multiply (
	clk,
	reset,
	a,
	b,
	ans
);
parameter  MUL_WIDTH  = 13;
parameter  MUL_RESULT= 25;

input         clk;
input       reset;
input [7:0]     a;
input [11:0]    b;

output [31:0] ans;


wire [23:0] inv_add;
wire [6:0] inv_a;

reg                             msb;
reg                       msb_reg_0;
reg                       msb_reg_1;
reg                       msb_reg_2;
reg [MUL_WIDTH-1:0]       mul_a_reg,mul_a_reg1,mul_a_reg2,mul_a_reg3,mul_a_reg4;
reg [MUL_WIDTH-1:0]       mul_b_reg,mul_b_reg1,mul_b_reg2,mul_b_reg3,mul_b_reg4;

reg [MUL_RESULT-2:0]   stored0;
reg [MUL_RESULT-2:0]   stored1;
reg [MUL_RESULT-2:0]   stored2;
reg [MUL_RESULT-2:0]   stored3;
reg [MUL_RESULT-2:0]   stored4;
reg [MUL_RESULT-2:0]   stored5;
reg [MUL_RESULT-2:0]   stored6;
reg [MUL_RESULT-2:0]   stored7;
reg [MUL_RESULT-2:0]   stored8;
reg [MUL_RESULT-2:0]   stored9;
reg [MUL_RESULT-2:0]   stored10;
reg [MUL_RESULT-2:0]   stored11;
reg [MUL_RESULT-2:0]   out1,out2,out3;
reg [MUL_RESULT-2:0]   add1,add2,add3,add4,add5,add6;
reg [MUL_RESULT-2:0]   add;

assign inv_a = ~a[6:0] + 1;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		stored0 <= 0;
		stored1 <= 0;
		stored2 <= 0;
		stored3 <= 0;
		stored4 <= 0;
		stored5 <= 0;
		stored6 <= 0;
		stored7 <= 0;
		stored8 <= 0;
		stored9 <= 0;
		stored10 <= 0;
		stored11 <= 0;
		mul_a_reg<=0;
		mul_a_reg1 <= 0;
		mul_a_reg2 <= 0;
		mul_a_reg3 <= 0;
		mul_a_reg4 <= 0;
		mul_b_reg<=0;
		mul_b_reg1 <= 0;
		mul_b_reg2 <= 0;
		mul_b_reg3 <= 0;
		mul_b_reg4 <= 0;

		// msb<=0;
		// msb_reg_0<=0;
		// msb_reg_1<=0;
		// msb_reg_2<=0;
		add<=0;
		add1 <= 0;
		add2 <= 0;
		add3 <= 0;
		add4 <= 0;
		add5 <= 0;
		add6 <= 0;
		out1 <= 0;
		out2 <= 0;
		out3 <= 0; 
		
	end

	else begin
		mul_a_reg <= (a[7] == 0)? {5'b0,a} : {1'b1, {5'b0, inv_a}};
		mul_b_reg <= {1'b0, b};

		mul_a_reg1 <= mul_a_reg;
		mul_a_reg2 <= mul_a_reg1;
		mul_a_reg3 <= mul_a_reg2;
		mul_a_reg4 <= mul_a_reg3;

		mul_b_reg1 <= mul_b_reg;
		mul_b_reg2 <= mul_b_reg1;
		mul_b_reg3 <= mul_b_reg2;
		mul_b_reg4 <= mul_b_reg3;

		// msb_reg_0 <= mul_a_reg[12] ^ mul_b_reg[12];
		// msb_reg_1 <= msb_reg_0;
		// msb_reg_2 <= msb_reg_1;
		// msb <= msb_reg_2;

		stored0 <= mul_b_reg[0]? {12'b0, mul_a_reg[11:0]} : 24'b0;
		stored1 <= mul_b_reg[1]? {11'b0, mul_a_reg[11:0], 1'b0} : 24'b0;
		stored2 <= mul_b_reg[2]? {10'b0, mul_a_reg[11:0], 2'b0} : 24'b0;
		stored3 <= mul_b_reg[3]? {9'b0, mul_a_reg[11:0], 3'b0} : 24'b0;
		stored4 <= mul_b_reg[4]? {8'b0, mul_a_reg[11:0], 4'b0} : 24'b0;
		stored5 <= mul_b_reg[5]? {7'b0, mul_a_reg[11:0], 5'b0} : 24'b0;
		stored6 <= mul_b_reg[6]? {6'b0, mul_a_reg[11:0], 6'b0} : 24'b0;
		stored7 <= mul_b_reg[7]? {5'b0, mul_a_reg[11:0], 7'b0} : 24'b0;
		stored8 <= mul_b_reg[8]? {4'b0, mul_a_reg[11:0], 8'b0} : 24'b0;
		stored9 <= mul_b_reg[9]? {3'b0, mul_a_reg[11:0], 9'b0} : 24'b0;
		stored10 <= mul_b_reg[10]? {2'b0, mul_a_reg[11:0], 10'b0} : 24'b0;
		stored11 <= mul_b_reg[11]? {1'b0, mul_a_reg[11:0], 11'b0} : 24'b0;

		add1 <= stored1 + stored0;
		add2 <= stored3 + stored2;
		add3 <= stored5 + stored4;
		add4 <= stored7 + stored6;
		add5 <= stored9 + stored8;
		add6 <= stored11 + stored10;
		out1 <= add1 + add2;
		out2 <= add3 + add4;
		out3 <= add5 + add6;
		add <= out1 + out2 + out3;
	end
	
end

assign inv_add = ~add+1;
assign ans = (mul_a_reg4==0 || mul_b_reg4==0)? 0 : (mul_a_reg4[12]==0)? {8'b0, add} : {{8{1'b1}}, inv_add};


endmodule