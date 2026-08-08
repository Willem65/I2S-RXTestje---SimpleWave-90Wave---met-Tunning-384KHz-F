    // ------------------------------------------------------------
    // 11. I2S uitgang
    // ------------------------------------------------------------        
    I2STX i2s_uitgang(
        .i2s_tx_bclk    (clk_24576),              
        .reset          (reset),
        
        .tx_in_left     (I_filtered), 
        .tx_in_right    (Q_filtered), 
        
        .tx_strobe      (safe_tx_strobe), 

        // Arduino interface
        .spi_le         (spi_le),
        .spi_data       (spi_data),
        .spi_clk        (spi_clk),                    
        .test_signal    (test_signal),
        
        .i2s_tx_lrclk   (i2s_out_lrclk),
        .i2s_out_data   (i2s_out_data),
        .phase_adj      (phase_adj),        
        
        .debug_pin3     (debug_pin3),
        .debug_pin4     (debug_pin4),
        .debug_pin5     (debug_pin5)
        //.debug_pin6     (debug_pin6)
    );