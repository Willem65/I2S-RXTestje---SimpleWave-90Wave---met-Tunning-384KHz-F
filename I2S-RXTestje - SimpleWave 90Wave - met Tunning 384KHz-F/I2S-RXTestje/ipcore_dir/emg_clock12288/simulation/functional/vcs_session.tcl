gui_open_window Wave
gui_sg_create emg_clock12288_group
gui_list_add_group -id Wave.1 {emg_clock12288_group}
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.test_phase}
gui_set_radix -radix {ascii} -signals {emg_clock12288_tb.test_phase}
gui_sg_addsignal -group emg_clock12288_group {{Input_clocks}} -divider
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.CLK_IN1}
gui_sg_addsignal -group emg_clock12288_group {{Output_clocks}} -divider
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.dut.clk}
gui_list_expand -id Wave.1 emg_clock12288_tb.dut.clk
gui_sg_addsignal -group emg_clock12288_group {{Status_control}} -divider
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.RESET}
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.LOCKED}
gui_sg_addsignal -group emg_clock12288_group {{Counters}} -divider
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.COUNT}
gui_sg_addsignal -group emg_clock12288_group {emg_clock12288_tb.dut.counter}
gui_list_expand -id Wave.1 emg_clock12288_tb.dut.counter
gui_zoom -window Wave.1 -full
