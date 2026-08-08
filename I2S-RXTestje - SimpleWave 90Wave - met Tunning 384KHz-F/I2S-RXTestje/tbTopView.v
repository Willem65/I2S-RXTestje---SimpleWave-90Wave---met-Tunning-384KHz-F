`timescale 1ns / 1ps

`define SIM

module tbTopView;

	// Inputs
	reg clk_master50  = 0;
    reg i2s_in_bclk   = 0;
    reg i2s_in_lrclk  = 0;
    reg i2s_in_data   = 0;
	//reg reset         = 1;

	// Outputs
	wire i2s_out_bclk;
	wire i2s_out_data;
	wire i2s_out_lrclk;
	wire debug_pin;

	// Instantiate the Unit Under Test (UUT)
	TopView uut (
		.clk_master50(clk_master50), 
		.i2s_in_bclk(i2s_in_bclk), 
		.i2s_in_lrclk(i2s_in_lrclk), 
		.i2s_in_data(i2s_in_data), 
		.i2s_out_bclk(i2s_out_bclk), 
		.i2s_out_data(i2s_out_data), 
		.i2s_out_lrclk(i2s_out_lrclk), 
		.debug_pin(debug_pin)
	);
	
// ------------------------------------------------------------
// Clock generation, bitclock and lr clock
// ------------------------------------------------------------
// i2s_in_bclk = 12.288 MHz  → 81.38 ns period
    initial i2s_in_bclk = 0;
	initial clk_master50 = 0;
    initial i2s_in_lrclk = 0;
	integer lrclk_counter = 0;
	
    //------------------------------------------------------------
    // TASK: SEND 32-BIT I2S SAMPLE (MSB FIRST)
    //------------------------------------------------------------
    task send_sample(input [31:0] sample);
        integer i;
        begin
            for (i = 31; i >= 0; i = i - 1) begin
                @(negedge i2s_in_bclk);
				i2s_in_data = sample[i];
            end
        end
    endtask

	always #10.00 clk_master50 = ~clk_master50;   // *** nu echt 50 MHz (20 ns periode)
	always #40.69 i2s_in_bclk = ~i2s_in_bclk;
	
	always @(negedge i2s_in_bclk) begin
		lrclk_counter <= lrclk_counter + 1;
		if (lrclk_counter == 31) begin   // *** 32 BCLK-pulsen per half-frame i.p.v. 31 NEEHEE
			i2s_in_lrclk = ~i2s_in_lrclk;
			lrclk_counter <= 0;
		end
	end
	
	// LEFT CHANNEL
	always @(negedge i2s_in_lrclk) begin
		send_sample(32'hff0f_0000);
	end

	// RIGHT CHANNEL
	always @(posedge i2s_in_lrclk) begin
		send_sample(32'hff0f_0000);
	end	
	
	initial begin
		// Initialize Inputs
		clk_master50 = 0;
		i2s_in_bclk = 0;
		i2s_in_lrclk = 0;
		i2s_in_data = 0;  
		// reset = 1;
		//#10;
		// reset = 0;   
		// #100; 
		


    // #100 reset = 0; // Laat de FPGA starten
    // #100;

    // // STROBE TRIGGEREN:
    // @(negedge i2s_in_bclk); // Wacht op een klokslag
    // strobe_in = 1;          // Maak hem hoog
    // repeat (5) @(negedge i2s_in_bclk); // Houd hem 5 klokslagen hoog
    // strobe_in = 0;          // Maak hem weer laag		
	end	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	/*
    // ------------------------------------------------------------
    // Clock generation
    // clk_master50 = 50 MHz
    // ------------------------------------------------------------
    always #10 clk_master50 = ~clk_master50;
	
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
       // #200 
		//reset = 0;
        #200;
		
        // --------------------------------------------------------
        // 3 COMPLETE FRAMES
        // --------------------------------------------------------
        for (frame = 0; frame < 30000; frame = frame + 1) begin

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
     */ 
endmodule

