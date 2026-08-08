
`timescale 1ns / 1ps

module Reset(
	//input  wire	bclk_is_missing,
    input  wire clk_master50,  
    output reg  reset_out
	//output 		pll_needs_reset
);


	// ------------------------------------------------------------
    // DE normale Reset
    // ------------------------------------------------------------    
    // 23-bit register is groot genoeg om tot 5 miljoen te tellen (max ~8.3 miljoen)
    reg [22:0] reset_cnt = 0;  
    
    always @(posedge clk_master50) begin
        // --- Power-on Reset Logica (100ms wachten bij opstarten) ---
        // 5.000.000 tikken op 50MHz is exact 100 milliseconden
        if (reset_cnt < 23'd5000000) begin 
            reset_cnt <= reset_cnt + 1;
            reset_out <= 1'b1;   // Houd de hele FPGA netjes in reset
        end else begin
            reset_out <= 1'b0;   // Klaar! Start de FPGA op.
        end
    end
	
	
	
	// // ------------------------------------------------------------
    // // DE "ZWEVENDE-PIN" FILTER & PLL (Oplossing voor de Deadlock)
    // // ------------------------------------------------------------	
    // reg clean_bclk_missing = 0;      
    // reg [23:0] debounce_timer = 0;
    
    // reg pll_needs_reset = 0;
    // reg [18:0] pll_rst_timer = 0;		
	
    // always @(posedge clk_master50) begin
        // // --- 1. De Ruis-Filter ---
        // if (bclk_is_missing != clean_bclk_missing) begin
            // debounce_timer <= debounce_timer + 1;
            
            // // HIER IS DE AANPASSING: Verlaagd van 5.000.000 (100ms) naar 500.000 (10ms)!
            // if (debounce_timer == 24'd500000) begin 
                // clean_bclk_missing <= bclk_is_missing; // Schakelaar omzetten!
                
                // // Geef de PLL de 10 milliseconde reset
                // pll_needs_reset <= 1'b1;
                // pll_rst_timer   <= 0;
            // end
        // end else begin
            // debounce_timer <= 0; // Twijfel? Reset de timer direct.
        // end

        // // --- 2. De eenmalige PLL Reset Timer (10 ms) ---
        // if (pll_needs_reset) begin
            // if (pll_rst_timer < 19'd500000) begin // 500.000 = 10ms
                // pll_rst_timer <= pll_rst_timer + 1;
            // end else begin
                // pll_needs_reset <= 1'b0; 
            // end
        // end
    // end	
	   
endmodule























