`timescale 1ns / 1ps

module locksolution(
    input  wire clk_50mhz,        // Referentieklok (clk_master50)
    input  wire bclk_is_missing,  // Signaal direct van de watchdog
    output reg  clean_missing,    // De gefilterde status (voor je Multiplexer)
    output reg  pll_reset_out     // De 10ms resetpuls (voor je PLL)
);

    // Registers voor de timers
    reg [23:0] debounce_timer = 0;
    reg [18:0] pll_rst_timer  = 0;
    reg        is_shocking     = 0; // Interne status voor de reset-puls

    always @(posedge clk_50mhz) begin
        
        // --- 1. De Ruis-Filter (Debounce) ---
        if (bclk_is_missing != clean_missing) begin
            if (debounce_timer < 24'd500000) begin // 10ms filter
                debounce_timer <= debounce_timer + 1;
            end else begin
                // Status wordt pas na 10ms stabiele verandering doorgegeven
                clean_missing <= bclk_is_missing; 
                
                // Activeer de PLL reset schok
                is_shocking   <= 1'b1;
                pll_rst_timer <= 0;
            end
        end else begin
            debounce_timer <= 0; 
        end

        // --- 2. De eenmalige PLL Reset Puls (10 ms) ---
        if (is_shocking) begin
            if (pll_rst_timer < 19'd500000) begin
                pll_rst_timer <= pll_rst_timer + 1;
                pll_reset_out <= 1'b1; // Reset actief
            end else begin
                is_shocking   <= 1'b0;
                pll_reset_out <= 1'b0; // Reset klaar
            end
        end else begin
            pll_reset_out <= 1'b0;
        end
    end

endmodule
