// ------------------------------------------------------------    
    // Upsampler (192 kHz -> 384 kHz)
    // ------------------------------------------------------------
    wire [31:0] up_sample;     
    wire strobe_384;           

    Upsampler u_Upsampler(
        .clk_49152  (clk_49152),
        .reset      (reset),
        .sample_in  (rx_sample),
        .strobe_192 (strobe_w1),
        
        .sample_out (up_sample),
        .strobe_384 (strobe_384)
    );    
        
    // ------------------------------------------------------------
    // NIEUW: FIR Filter (Na Upsampler)
    // ------------------------------------------------------------
    wire [31:0] filtered_sample; 
    wire strobe_filtered;

    FIR_Filter u_FIR (
        .clk_49152  (clk_49152),
        .reset      (reset),
        .sample_in  (up_sample),    // Komt van de Upsampler
        .strobe_in  (strobe_384),   // Komt van de Upsampler
        
        .sample_out (filtered_sample),
        .strobe_out (strobe_filtered)
    );
        
    // ------------------------------------------------------------
    // Phase accumulator
    // ------------------------------------------------------------    
    PHASEACCUMULATOR phase_acc(    
         // NIEUW: Gebruikt nu de output van het FIR filter!
         .sample_in      (filtered_sample[31-:16]), 
         .test_signal    (test_signal),
         .reset          (reset),
         .i2s_in_bclk    (clk_49152),
         
         // NIEUW: Gebruikt nu de strobe van het FIR filter (die aangeeft dat de berekening klaar is)
         .strobe_in      (strobe_filtered),
        
         .strobe_out     (strobe_w2),
         .phase_out      (phase_w)
    );