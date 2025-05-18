# ----- clocks -----
create_clock -name sys_clk -period 5.000 [get_ports clk]

# ----- input delay 0 -----
set_input_delay -clock sys_clk 0 [get_ports {in_a in_b in_valid rst_n}]
set_output_delay -clock sys_clk 2.5 [get_ports mac_out[*]]
# ----- ignore all output paths -----
set_false_path -to [get_ports out_valid]
set_false_path -to [get_ports -regexp {^out_sum\[.*\]$}]

set_false_path -to [get_ports -regexp {^mac_out\[.*\]$}]
set_false_path -to [get_ports out_valid]