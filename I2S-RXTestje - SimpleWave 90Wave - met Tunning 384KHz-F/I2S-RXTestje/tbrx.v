`timescale 1ns / 1ps



module tbrx;

	// Inputs
    reg i2s_in_bclk   = 0;
    reg i2s_in_lrclk  = 0;
    reg i2s_in_data   = 0;
    reg reset         = 1;

	// Outputs
	wire i2s_rx_strobe;
	wire [31:0] i2s_rx_out_left;
	wire [31:0] i2s_rx_out_right;

	// Instantiate the Unit Under Test (UUT)
	I2SRX uut (
		.i2s_in_bclk(i2s_in_bclk), 
		.reset(reset), 
		.i2s_in_lrclk(i2s_in_lrclk), 
		.i2s_in_data(i2s_in_data), 
		.i2s_rx_strobe(i2s_rx_strobe), 
		.i2s_rx_out_left(i2s_rx_out_left), 
		.i2s_rx_out_right(i2s_rx_out_right)
	);

    // ------------------------------------------------------------
    // Clock generation
    // BCLK = 12.288 MHz → periode ≈ 81.38 ns
    // ------------------------------------------------------------
    always #40.69 i2s_in_bclk = ~i2s_in_bclk;

    // ------------------------------------------------------------
    // Test sample (24-bit)
    // Dit sample moet terechtkomen op bits [31:8]
    // ------------------------------------------------------------
    reg [23:0] test_sample = 24'hA5_1234;
	
	integer i, p, frame;

	initial begin
	
	    // Reset
        #200 
		reset = 0;
        #200;
		
        // --------------------------------------------------------
        // 3 COMPLETE FRAMES
        // --------------------------------------------------------
        for (frame = 0; frame < 3; frame = frame + 1) begin

            // ============================
            // LEFT CHANNEL (32 bits zero)
            // ============================
            i2s_in_lrclk = 0;

            for (p = 0; p < 32; p = p + 1) begin
                @(negedge i2s_in_bclk);
                i2s_in_data = 0;
            end

            // ============================
            // RIGHT CHANNEL (24-bit sample)
            // ============================
            i2s_in_lrclk = 1;

            // 24 bits data (MSB first)
            for (i = 23; i >= 0; i = i - 1) begin
                @(negedge i2s_in_bclk);
                i2s_in_data = test_sample[i];
            end

            // 8 bits padding
            for (p = 0; p < 8; p = p + 1) begin
                @(negedge i2s_in_bclk);
                i2s_in_data = 0;
            end
        end
		#100;
        
		// Add stimulus here

	end
      
endmodule

