`timescale 1ns / 1ps

module tbI2S_RXTestje;

	// Inputs
	reg clk_master50;
	reg i2s_in_bclk;
	reg i2s_in_lrclk;
	reg i2s_in_data;
	//reg reset;

	// Outputs
	wire i2s_out_bclk;
	wire i2s_out_data;
	wire i2s_out_lrclk;
	wire debug_pin;

	// Instantiate the Unit Under Test (UUT)
	TopView uut (
		.clk_master50(clk_master50), 
		//.reset(reset),
		.i2s_in_bclk(i2s_in_bclk), 
		.i2s_in_lrclk(i2s_in_lrclk), 
		.i2s_in_data(i2s_in_data), 
		.i2s_out_bclk(i2s_out_bclk), 
		.i2s_out_data(i2s_out_data), 
		.i2s_out_lrclk(i2s_out_lrclk), 
		.debug_pin(debug_pin)
	);

	initial begin
		// Initialize Inputs
		clk_master50 = 0;
		i2s_in_bclk = 0;
		i2s_in_lrclk = 0;
		i2s_in_data = 0;

		// Wait 100 ns for global reset to finish
		#100;        
		// // Add stimulus here
		// reset     = 1;
		// i2s_in_data = 0;
       // #200 
	   // reset = 0;
	   
	end
      
endmodule

