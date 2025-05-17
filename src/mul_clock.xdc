## --- Clock Constraint----------
create_clock -name clk -period 3.333 [get_ports clk]

## --- Default IO Timing ----------
set_input_delay  0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]

## ---forbit DSP48 --------------------------
set_property DONT_TOUCH TRUE [get_cells -hier -regexp .*wallace.*]

set_false_path -to [get_ports {product* out_valid}]
