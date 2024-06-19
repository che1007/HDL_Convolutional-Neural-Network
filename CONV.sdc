# operating conditions and boundary conditions #

set cycle 12.5  
create_clock -name clk  -period $cycle   [get_ports  clk] 


#Don't touch the basic env setting as below
set_input_delay  5.0   -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 5.0    -clock clk [all_outputs] 

                     


