`timescale 1ns/10ps
`define CYCLE      12.5         	  // Modify your clock period here (do not larger than 25)
`define End_CYCLE  200000000          // Modify cycle times once your design need more cycle times!

// `define gray_image     "../../dat_grad/gray_image.txt"                 // Open in Quartus
// `define L0_EXP0        "../../dat_grad/relu_image.txt"					
// `define weight         "../../dat_grad/random_weight.txt"           
// `define L1_EXP0        "../../dat_grad/pooled_image.txt"      
// `define L2_EXP         "../../dat_grad/result_leaky_relu.txt"  

`define gray_image     "./dat_grad/gray_image.txt"                  // Open in ModelSim 
`define L0_EXP0        "./dat_grad/relu_image.txt"					
`define weight         "./dat_grad/random_weight.txt"           
`define L1_EXP0        "./dat_grad/pooled_image.txt"      
`define L2_EXP         "./dat_grad/result_leaky_relu.txt"  

module testfixture;

logic		check0=1, check1=1, check2=1;   ////you can only modify this line

logic	[11:0]	L0_EXP0	[0:16383];  
logic	[11:0]	L1_EXP0	[0:4095];
logic	[31:0]	L2_EXP	[0:99];


logic		reset = 0;
logic		clk = 0;
logic		ready = 0;

//define input and output
logic			busy;			
logic 	[13:0]	iaddr;
logic	[7:0]	idata;	
logic			ioe;
//weight mem
logic			oe_weight;
logic 	[15:0]	addr_weight;
logic	[7:0] 	r_data_weight;
//L0 mem
logic			wen_L0;
logic			oe_L0;
logic 	[13:0]	addr_L0;
logic 	[11:0]	w_data_L0;
logic	[11:0]	r_data_L0;
//L1 mem
logic 			wen_L1;
logic			oe_L1;
logic 	[11:0]	addr_L1;
logic 	[11:0]	w_data_L1;
logic	[11:0]	r_data_L1;
//L2 mem
logic			wen_L2;
logic 	[3:0]	addr_L2;
logic	[31:0]	w_data_L2;



integer		p0, p1, p3, p4, p2, pass0=0, pass1=0, pass2=0,RTL_score =0,SYN_score =0;
integer		err00, err10, err2;

integer		pat_num;



CONV u_CONV(
	.clk(clk),
	.reset(reset),
	.busy(busy),	
	.ready(ready),	
	//gray_image mem
	.iaddr(iaddr),
	.idata(idata),
	.ioe(ioe),
	//weight mem
	.oe_weight(oe_weight),
	.addr_weight(addr_weight),
	.r_data_weight(r_data_weight),
	//L0 mem
	.wen_L0(wen_L0),
	.oe_L0(oe_L0),
	.addr_L0(addr_L0),
	.w_data_L0(w_data_L0),
	.r_data_L0(r_data_L0),
	//L1 mem
	.wen_L1(wen_L1),
	.oe_L1(oe_L1),
	.addr_L1(addr_L1),
	.w_data_L1(w_data_L1),
	.r_data_L1(r_data_L1),
	//L2 mem
	.wen_L2(wen_L2),
	.addr_L2(addr_L2),
	.w_data_L2(w_data_L2)
	);
			

RAM_8 #(.depth(16384)) Grayscale_RAM(
  .CK(clk     ), 
  .A (iaddr ), 
  .WE(1'd0), 
  .OE(ioe), 
  .D (8'd0 ), 
  .Q (idata )
);

RAM_12 #(.depth(16384)) L0_RAM(
  .CK(clk     ), 
  .A (addr_L0 ), 
  .WE(wen_L0), 
  .OE(oe_L0), 
  .D (w_data_L0 ), 
  .Q (r_data_L0)
);

RAM_12 #(.depth(4096)) L1_RAM(
  .CK(clk     ), 
  .A (addr_L1 ), 
  .WE(wen_L1), 
  .OE(oe_L1), 
  .D (w_data_L1 ), 
  .Q (r_data_L1)
);

RAM_8 #(.depth(40960)) Weight_RAM(
  .CK(clk     ), 
  .A (addr_weight ), 
  .WE(1'b0), 
  .OE(oe_weight), 
  .D (), 
  .Q (r_data_weight)
);

RAM_32 #(.depth(10)) L2_RAM(
  .CK(clk     ), 
  .A (addr_L2 ), 
  .WE(wen_L2), 
  .OE(1'd0), 
  .D (w_data_L2 ), 
  .Q ()
);




always begin #(`CYCLE/2) clk = ~clk; end



initial begin  // global control
	$display("-----------------------------------------------------");
 	$display("START!!! Simulation Start .....");
 	$display("-----------------------------------------------------");
	@(negedge clk); #(`CYCLE/4); reset = 1'b1;  ready = 1'b1;
   	#(`CYCLE*3);  #(`CYCLE/4);   reset = 1'b0;  
   	wait(busy == 1); #(`CYCLE/4); ready = 1'b0;
end

initial begin // initial pattern and expected result
	wait(reset==1);
	wait ((ready==1) && (busy ==0) ) begin
		$readmemh(`gray_image, Grayscale_RAM.memory);
		$readmemh(`L0_EXP0, L0_EXP0);
		$readmemh(`L1_EXP0, L1_EXP0);
		$readmemh(`weight,  Weight_RAM.memory);
		$readmemh(`L2_EXP , L2_EXP);
	end
		
end


initial begin
 $dumpfile("CONV.vcd");
 $dumpvars(0,u_CONV);
end



//-------------------------------------------------------------------------------------------------------------------
initial begin  	// layer 0,  conv output
	  wait(reset== 1);
	  wait(reset== 0);
wait(busy==1); wait(busy==0);
if (check0 == 1) begin 
	err00 = 0;
	for (p0=0; p0<=16383; p0=p0+1) begin
		if (L0_RAM.memory[p0] == L0_EXP0[p0]) ;
		/*else if ( (L0_MEM0[p0]+20'h1) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]-20'h1) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]+20'h2) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]-20'h2) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]+20'h3) == L0_EXP0[p0]) ;
		else if ( (L0_MEM0[p0]-20'h3) == L0_EXP0[p0]) ;*/
		else begin
			err00 = err00 + 1;
			begin 
				$display("WRONG! Layer 0 (Convolutional Output) with Kernel 0 , Pixel %d is wrong!", p0);
				$display("               The output data is %h, but the expected data is %h ", L0_RAM.memory[p0], L0_EXP0[p0]);
			end
		end
	end
	if (err00 == 0) $display("Layer 0 (Convolutional Output) with Kernel 0 is correct !");
	else		 $display("Layer 0 (Convolutional Output) with Kernel 0 be found %d error !", err00);

end
end

//-------------------------------------------------------------------------------------------------------------------
initial begin  	// layer 1,  max-pooling output
	  wait(reset== 1);
	  wait(reset== 0);
wait(busy==1); wait(busy==0);
if(check1 == 1) begin
	err10 = 0;
	for (p1=0; p1<=4095; p1=p1+1) begin
		if (L1_RAM.memory[p1] == L1_EXP0[p1]) ;
		else begin
			err10 = err10 + 1;
			begin 
				$display("WRONG! Layer 1 (Max-pooling Output) with Kernel 0 , Pixel %d is wrong!", p1);
				$display("               The output data is %h, but the expected data is %h ", L1_RAM.memory[p1], L1_EXP0[p1]);
			end
		end
	end
	if (err10 == 0) $display("Layer 1 (Max-pooling Output) with Kernel 0 is correct!");
	else		 $display("Layer 1 (Max-pooling Output) with Kernel 0 be found %d error !", err10);

end
end


//-------------------------------------------------------------------------------------------------------------------
initial begin  	// layer 2,  flatten output
	  wait(reset== 1);
	  wait(reset== 0);
wait(busy==1); wait(busy==0);
if (check2 == 1) begin
	err2 = 0;
	for (p2=0; p2<=9; p2=p2+1) begin
		if (L2_RAM.memory[p2] == L2_EXP[p2]) ;
		else begin
			err2 = err2 + 1;
			begin 
				$display("WRONG! Layer 2 (Flatten  Output), Pixel %d is wrong!", p2);
				$display("               The output data is %h, but the expected data is %h ", L2_RAM.memory[p2], L2_EXP[p2]);
			end
		end
	end
	if (err2 == 0) $display("Layer 2 (Flatten  Output) is correct!");
	else 		$display("Layer 2 (Flatten  Output) be found %d error !", err2);
end
end

//-------------------------------------------------------------------------------------------------------------------
initial  begin
 #(`End_CYCLE*`CYCLE) ;
 	$display("-----------------------------------------------------\n");
 	$display("Error!!! The simulation can't be terminated under normal operation!\n");
 	$display("-------------------------FAIL------------------------\n");
 	$display("-----------------------------------------------------\n");
 	$finish;
end

initial begin
	  wait(reset== 1);
	  wait(reset== 0);
      wait(busy == 1);
      wait(busy == 0);      
	$display("--------------------- S U M M A R Y -----------------\n");
	if( (check0==1)&(err00==0) ) begin
		$display("Congratulations! Layer 0 data have been generated successfully! The result is PASS!!\n");
		pass0 = 1;
		end
		else if (check0 == 0) $display("Layer 0 output was fail! \n");
		else $display("FAIL!!!  There are %d errors! in Layer 0 \n", err00);
	if( (check1==1)&(err10==0) ) begin
		$display("Congratulations! Layer 1 data have been generated successfully! The result is PASS!!\n");
		pass1 = 1;
		end
		else if (check1 == 0) $display("Layer 1 output was fail! \n");
		else $display("FAIL!!!  There are %d errors! in Layer 1 \n", err10);
	if( (check2==1)&(err2==0)) begin
		$display("Congratulations! Layer 2 data have been generated successfully! The result is PASS!!\n");
		pass2 = 1;
		end
		else if (check2 == 0) $display("Layer 2 output was fail! \n");
		else $display("FAIL!!!  There are %d errors! in Layer 2 \n", err2);
	if ((check0|check1|check2) == 0) $display("FAIL!!! No output data was found!! \n");
	
	if(err00==1'd0 && err10==1'd0 && err2==1'd0 && check0 && check1 && check2) begin
			$display(" ****************************               ");
			$display(" **                        **       |\__||  ");
			$display(" **  Congratulations !!    **      / O.O  | ");
			$display(" **                        **    /_____   | ");
			$display(" **  Pattern   All Pass    **   /^ ^ ^ \\  |");
			$display(" **                        **  |^ ^ ^ ^ |w| ");
			$display(" ****************************   \\m___m__|_|");
		end
		else begin
			 $display(" ****************************               ");
			 $display(" **                        **       |\__||  ");
			 $display(" **  OOPS!!                **      / X,X  | ");
			 $display(" **                        **    /_____   | ");
			 $display(" **  Pattern   Failed      **   /^ ^ ^ \\  |");
			 $display(" **                        **  |^ ^ ^ ^ |w| ");
			 $display(" ****************************   \\m___m__|_|");
		end
			$display("\n");
			
		if(pass0==1) begin
			if(pass1==1) begin
				if(pass2==1) begin
					 RTL_score =30;
					 SYN_score =60;
				end 
				else begin
				 RTL_score =20;
				 SYN_score =50;
				end
		end else begin
			 RTL_score =10;
			 SYN_score =40;
			 end
	end else begin
		 RTL_score =0;
		 SYN_score =30;
	end
		$display("Your score in     RTL    Simulation = %1d",RTL_score);
		$display("Your score in Gate-Level Simulation = %1d",SYN_score);
		
	$display("-----------------------------------------------------");
      #(`CYCLE/2); $finish;
	end

endmodule



module RAM_8 #(parameter depth=65536)(CK, A, WE, OE, D, Q);

  input                                  CK;
  input  [$clog2(depth)-1:0]              A;
  input                                  WE;
  input                                  OE;
  input  [7:0]                            D;
  output [7:0]                            Q;

  logic    [7:0]                            Q;
  logic    [$clog2(depth)-1:0]      latched_A;
  logic    [$clog2(depth)-1:0]  latched_A_neg;
  logic    [7:0] memory           [depth-1:0];

  always @(posedge CK) begin
    if (WE) begin
      memory[A] <= D;
    end
		latched_A <= A;
  end
  
   always@(negedge CK) begin
    latched_A_neg <= latched_A;
  end
  
  always @(*) begin
    if (OE) begin
      Q = memory[latched_A_neg];
    end
    else begin
      Q = 8'hzz;
    end
  end
  
endmodule



module RAM_12 #(parameter depth=65536)(CK, A, WE, OE, D, Q);

  input                                  CK;
  input  [$clog2(depth)-1:0]              A;
  input                                  WE;
  input                                  OE;
  input  [11:0]                            D;
  output [11:0]                            Q;

  logic    [11:0]                            Q;
  logic    [$clog2(depth)-1:0]      latched_A;
  logic    [$clog2(depth)-1:0]  latched_A_neg;
  logic    [11:0] memory           [depth-1:0];

  always @(posedge CK) begin
    if (WE) begin
      memory[A] <= D;
    end
		latched_A <= A;
  end
  
      always@(negedge CK) begin
    latched_A_neg <= latched_A;
  end
  
  always @(*) begin
    if (OE) begin
      Q = memory[latched_A_neg];
    end
    else begin
      Q = 12'hzzz;
    end
  end

endmodule


module RAM_32 #(parameter depth=65536)(CK, A, WE, OE, D, Q);

  input                                  CK;
  input  [$clog2(depth)-1:0]              A;
  input                                  WE;
  input                                  OE;
  input  [31:0]                            D;
  output [31:0]                            Q;

  logic    [31:0]                            Q;
  logic    [$clog2(depth)-1:0]      latched_A;
  logic    [$clog2(depth)-1:0]  latched_A_neg;
  logic    [31:0] memory           [depth-1:0];

  always @(posedge CK) begin
    if (WE) begin
      memory[A] <= D;
    end
		latched_A <= A;
  end
  
    always@(negedge CK) begin
    latched_A_neg <= latched_A;
  end
  
  always @(*) begin
    if (OE) begin
      Q = memory[latched_A_neg];
    end
    else begin
      Q = 32'hzzzzzzzz;
    end
  end

endmodule


