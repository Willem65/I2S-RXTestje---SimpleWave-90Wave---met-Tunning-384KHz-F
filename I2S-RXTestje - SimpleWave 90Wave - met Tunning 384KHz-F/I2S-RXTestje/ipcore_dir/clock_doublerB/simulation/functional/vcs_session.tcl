gui_open_window Wave
gui_sg_create clock_doublerB_group
gui_list_add_group -id Wave.1 {clock_doublerB_group}
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.test_phase}
gui_set_radix -radix {ascii} -signals {clock_doublerB_tb.test_phase}
gui_sg_addsignal -group clock_doublerB_group {{Input_clocks}} -divider
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.CLK_IN1}
gui_sg_addsignal -group clock_doublerB_group {{Output_clocks}} -divider
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.dut.clk}
gui_list_expand -id Wave.1 clock_doublerB_tb.dut.clk
gui_sg_addsignal -group clock_doublerB_group {{Status_control}} -divider
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.RESET}
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.LOCKED}
gui_sg_addsignal -group clock_doublerB_group {{Counters}} -divider
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.COUNT}
gui_sg_addsignal -group clock_doublerB_group {clock_doublerB_tb.dut.counter}
gui_list_expand -id Wave.1 clock_doublerB_tb.dut.counter
gui_zoom -window Wave.1 -full
