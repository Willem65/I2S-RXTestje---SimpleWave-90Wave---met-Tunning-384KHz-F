

// 1  Werkt

// /*

`timescale 1ns / 1ps

module TopView(
        input  wire clk_master50,   // P55   //50 MHz
        // External I2S input from DSP (DSP is master)
        input  wire i2s_in_bclk,    // P85        //12,288 MHz from I2S source
        input  wire i2s_in_lrclk,   // P87        //192kHz from I2S source
        input  wire i2s_in_data,    // P84 GCLK   //Stereo channels from source
        input  wire btn_reset_n,    // Reset druk knopje voor de fpga
        
        // I2S output to PCM5102 (FPGA is slave)

        // Arduino ------------------------------
        input wire spi_data,
        input wire spi_clk,
        input wire spi_le,
        //---------------------------------------    
    
        output wire i2s_out_bclk,   // P78
        output wire i2s_out_data,   // P79
        output wire i2s_out_lrclk,  // P80 

        // LED pinnen (Toegevoegd bovenaan)
        output wire led1,            // P56
        // output wire led2,         // P57
        // output wire led3,         // P58
        // output wire led4,         // P59
        
        output wire debug_pin3,    // P97
        output wire debug_pin4,    // P98
        output wire debug_pin5,    // P99
        output wire debug_pin6     // P82            
    );
	
	

	  

	wire bclk_is_missing; 
	// ------------------------------------------------------------
	// De Deadlock Oplossing module
	// ------------------------------------------------------------
    locksolution u_lock_fix (
        .clk_50mhz      (clk_master50),
        .bclk_is_missing(bclk_is_missing), // Van de watchdog
        .clean_missing  (clean_dsp_weg),    // NAAR je Multiplexer!
        .pll_reset_out  (pll_shock)        // NAAR de PLL reset!
    );
	
	
	
	
    // ------------------------------------------------------------
    // 1. Reset & Watchdog (De Bewaker)
    // ------------------------------------------------------------
    wire reset;     
    wire reset_o;
    wire manual_reset = ~btn_reset_n;
    

    // De power-on reset manager
    Reset u_reset_manager (
        .clk_master50    (clk_master50),
        .reset_out       (reset_o)
		//.pll_needs_reset (pll_needs_reset)
    );






    // De Watchdog houdt ALTIJD de originele DSP pin in de gaten!
    watchdog u_watchdog (
        .clk_50mhz     (clk_master50),  
        .signal_to_mon (i2s_in_bclk),   // Monitor de fysieke pin!
		//.signal_to_mon (i2s_in_lrclk),   // Monitor de fysieke pin!
        .led1          (led1),          
        .status_lost   (bclk_is_missing)
    );
	
	
	
	 
	 
	 
	 

    // ------------------------------------------------------------
    // 2. Noodklokken Generatie (Draaien altijd op de achtergrond)
    // ------------------------------------------------------------    
    wire emg_12288;
    
    emg_clock12288 u_12288KHz (
        .CLK_IN1    (clk_master50),
        .CLK_OUT1   (emg_12288),
        .RESET      (reset_o),
        .LOCKED     ()
    );
    
	
	
	
    // ------------------------------------------------------------
    // Noodklokken Generatie Nood 192 kHz generator (Draaien altijd op de achtergrond)
    // ------------------------------------------------------------    	
	wire emg_192k;

    // Roep de nieuwe noodklok module aan
    Emergency_clocks u_192KHz (
        .clk_12mhz  (emg_12288), // Koppel de 12MHz IP core aan de ingang
        .reset      (reset_o),   // Koppel de opstart-reset
        .clk_192k   (emg_192k)   // Hier komt jouw 192kHz uit!
    );
	
	

    
    // ------------------------------------------------------------
    // 3. DE MULTIPLEXER (De automatische omschakelaar)
    // ------------------------------------------------------------
    // Als de DSP klok weg is, pakken we de noodklokken. Anders de DSP klokken.
    // wire active_bclk  = (bclk_is_missing) ? emg_12288 : i2s_in_bclk;
    // wire active_lrclk = (bclk_is_missing) ? emg_192k  : i2s_in_lrclk;
	
	// --- De Multiplexer gebruikt nu de CLEAN status ---
    wire active_bclk  = (clean_dsp_weg) ? emg_12288 : i2s_in_bclk;
    wire active_lrclk = (clean_dsp_weg) ? emg_192k  : i2s_in_lrclk;	

    // ------------------------------------------------------------
    // 4. PLL & Hoofd Reset Logica
    // ------------------------------------------------------------
    wire clk_24576;   // BUFG clock
    wire clk_49152;   // BUFG clock
    wire lockedA;  

    // De PLL krijgt nu de 'active_bclk' gevoed. Hij merkt dus amper dat de bron verandert!
    clock_doublerA u_clock_doublerA (
        .CLK_IN1   (active_bclk),  // <--- Hier gaat de geschakelde klok in!
        .CLK_OUT1  (clk_24576),   
        .CLK_OUT2  (clk_49152),
        //.RESET     (pll_needs_reset),
		//.RESET  (pll_shock | reset_o), // Gecombineerd met opstart-reset
		.RESET  (pll_shock), // Gecombineerd met opstart-reset
        .LOCKED    (lockedA)
    );

    // DE MAGISCHE REGEL: De FPGA gaat in reset als je op de knop drukt,
    // bij opstarten, OF als de PLL zijn ritme kwijt is (tijdens het schakelen).
    // Let op: 'bclk_is_missing' is hier weggehaald, anders zou hij voor altijd slapen!
    
	//assign reset = reset_o | manual_reset | ~lockedA;   

    assign reset = reset_o; 	
    
	assign debug_pin6 = reset;
	
	
	
	
	
    // ------------------------------------------------------------
    // 5. I2S Ingang
    // ------------------------------------------------------------    
    wire strobe_w1;
    wire strobe_w2;          
    wire test_signal;
    wire [31:0] rx_sample;
    
    I2SRX i2s_ingang(
         .i2s_in_bclk    (active_bclk),  // Krijgt de actieve klok
         .reset          (reset),
         .i2s_in_lrclk   (active_lrclk), // Krijgt de actieve klok
         .i2s_in_data    (i2s_in_data),
         
         .i2s_rx_strobe  (strobe_w1),    
         .rx_sample      (rx_sample)     
    );
    
    // ------------------------------------------------------------    
    // 6. Upsampler (192 kHz -> 384 kHz)
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
    // 7. FIR Filter (Na Upsampler)
    // ------------------------------------------------------------
    wire [31:0] filtered_sample; 
    wire strobe_filtered;

    FIR_Filter u_FIR (
        .clk_49152  (clk_49152), 
        .reset      (reset),
        .sample_in  (up_sample),    
        .strobe_in  (strobe_384),   
        .bypass     (1'b0),        // 1 = Filter UIT, 0 = Filter AAN
        
        .sample_out (filtered_sample),
        .strobe_out (strobe_filtered)
    );    
        
    // ------------------------------------------------------------
    // 8. Phase accumulator
    // ------------------------------------------------------------    
    //wire [10:0] phase_w; 
	wire [15:0] phase_w;
        
    PHASEACCUMULATOR phase_acc(    
         .sample_in      (filtered_sample[31-:16]), 
         .test_signal    (test_signal),
		 //.test_signal    (1'b0),
         .reset          (reset),
         .clk_49152      (clk_49152),
         .strobe_in      (strobe_filtered),
        
         .strobe_out     (strobe_w2),
         .phase_out      (phase_w)
    );
   
    // // ------------------------------------------------------------
    // // 9. Phase -> IQ using 360-wave LUT 
    // // ------------------------------------------------------------
    wire signed [31:0] I16;
    wire signed [31:0] Q16;
    
    wire signed [31:0] I_data = I16;
    wire signed [31:0] Q_data = Q16;    
    wire [9:0] phase_adj;
    
    // LUT lut(
        // .clk_49152   (clk_49152), 
        // .phase_in    (phase_w),     
        // .phase_adj   (phase_adj),
        
        // .I           (I16), // In-phase sinus
        // .Q           (Q16)  // Quadrature sinus
    // );
	
	
	
	
	
	
	
	
	
	
	
	
	
// ------------------------------------------------------------
    // 9. Phase -> IQ met de nieuwe Integrated Quarter-wave LUT 90 degrees 
    // ------------------------------------------------------------
    //wire signed [15:0] I16_new;  // Nieuwe 16-bit draden
    //wire signed [15:0] Q16_new;
    wire iq_valid_new;

    // We breiden je 11-bit phase_w uit naar 16-bit voor de nieuwe module
    // We zetten de 11 bits bovenin, en vullen aan met nullen.
    //wire [15:0] phase_16bit = {phase_w, 5'b00000}; 


    LUT90 u_LUT90 (
        .clk         (clk_49152),
        .rst         (reset),
        .ce_fs       (strobe_w2),
        .phase       (phase_w),
		.phase_adj   (phase_adj),
        .I           (I16),
        .Q           (Q16),
        .iq_valid    (iq_valid_new)
    );

    // Omdat de rest van je code (FIR_IQ) 32-bit verwacht, 
    // vullen we de 16-bit waarden aan.
    // wire signed [31:0] I_data = {I16_new, 16'd0};
    // wire signed [31:0] Q_data = {Q16_new, 16'd0};	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
    
    Oddr2F u_Oddr2F(
        .in        (clk_24576),
        .uit       (i2s_out_bclk)
    );
    
    // ============================================================
    // 10. DE WACHTKAMER OPLOSSING (Perfecte I2S Frame Uitlijning)
    // ============================================================
    wire [31:0] I_filtered;
    wire [31:0] Q_filtered;
    wire        strobe_iq; 

    FIR_IQ filter_i (
        .clk_49152 (clk_49152),
        .reset     (reset),
        .sample_in (I_data),      
        .strobe_in (iq_valid_new),   
        .sample_out(I_filtered),
        .strobe_out(strobe_iq)    
    );

    FIR_IQ filter_q (
        .clk_49152 (clk_49152),
        .reset     (reset),
        .sample_in (Q_data),      
        .strobe_in (iq_valid_new),   
        .sample_out(Q_filtered),
        .strobe_out()             
    );    

    // Puls Oprekker 
    reg strobe_w2_delay;
    always @(posedge clk_49152) begin
        strobe_w2_delay <= strobe_w2;
    end
    
    wire safe_tx_strobe = strobe_w2 | strobe_w2_delay;
	

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

endmodule
// */
 
 
 
 
 
 
 //=========================================================================================================
 
 
 
 
// 2     Werkt niet

 /*
`timescale 1ns / 1ps

module TopView(
        input  wire clk_master50,   // P55   //50 MHz
        // External I2S input from DSP (DSP is master)
        input  wire i2s_in_bclk,    // P85        //12,288 MHz from I2S source
        input  wire i2s_in_lrclk,   // P87        //192kHz from I2S source
        input  wire i2s_in_data,    // P84 GCLK   //Stereo channels from source
		input  wire btn_reset_n,    // Reset druk knopje voor de fpga
        
        // I2S output to PCM5102 (FPGA is slave)

        // Arduino ------------------------------
        input wire spi_data,
        input wire spi_clk,
        input wire spi_le,
        //---------------------------------------    
    
        output wire i2s_out_bclk,   // P78
        output wire i2s_out_data,   // P79
        output wire i2s_out_lrclk,  // P80 

		// LED pinnen (Toegevoegd bovenaan)
        output wire led1,            // P56
        // output wire led2,         // P57
        // output wire led3,         // P58
        // output wire led4,         // P59
		
        output wire debug_pin3,    // P97
        output wire debug_pin4,    // P98
        output wire debug_pin5,    // P99
        output wire debug_pin6     // P82   		
    );
    
    //assign i2s_out_bclk  = i2s_in_bclk;
	assign debug_pin6 = 1'b0;
    // ------------------------------------------------------------
    // Proper 10 ms power-on reset 
    // ------------------------------------------------------------
    wire reset; 	
	wire reset_o;
    wire manual_reset = ~btn_reset_n;
    wire bclk_is_missing; // <--- HIER ALVAST DECLAREREN!

    // De power-on reset manager
    Reset u_reset_manager (
        .clk_master50    (clk_master50),
        .reset_out       (reset_o)
    );

    // DE MAGISCHE REGEL: De FPGA gaat in reset als je op de knop drukt,
    // bij het opstarten, OF als de DSP klok wegvalt!
    assign reset = reset_o | manual_reset | bclk_is_missing | ~lockedA;	
	
	
	 // ------------------------------------------------------------
    // Clock generation (49.152 MHz BUFG)
    // ------------------------------------------------------------
    wire clk_24576;   // BUFG clock
	wire clk_49152;   // BUFG clock
	wire lockedA;  // wordt nog niet gebruikt

    clock_doublerA u_clock_doublerA (
        .CLK_IN1   (i2s_in_bclk),
        .CLK_OUT1  (clk_24576),   // BUFG output
		.CLK_OUT2  (clk_49152),
		.RESET     (bclk_is_missing),
        .LOCKED    (lockedA)
    );
	
	// ------------------------------------------------------------
    // emergency_clock 12,288 MHZ 
    // ------------------------------------------------------------	
	wire emg_12288;
	
	emg_clock12288 emergency_clock (
		.CLK_IN1	(clk_master50),
		.CLK_OUT1	(emg_12288),
		.RESET		(reset_o),
		.LOCKED		()
	);
	
	// ------------------------------------------------------------
    // emergency_clock 192 KHz
    // ------------------------------------------------------------		
	// Een 5-bit teller is precies genoeg, want 2^5 = 32 (telt van 0 t/m 31)
    reg [4:0] counter = 0;
	reg  clk_out_192k;
	wire clk_in_12mhz;

    always @(posedge emg_12288) begin
        if (reset_o) begin
            counter      <= 5'd0;
            clk_out_192k <= 1'b0;
        end else begin
            // Als de teller bij 31 is (dat is de 32e tik, want we beginnen bij 0)
            if (counter == 5'd31) begin
                counter      <= 5'd0;             // Reset de teller
                clk_out_192k <= ~clk_out_192k;   // Klap de klok om (toggle)
            end else begin
                counter      <= counter + 5'd1;   // Tel gewoon verder
            end
        end
    end
	
	
	
	// ------------------------------------------------------------
    // I2S Clock Watchdog
    // ------------------------------------------------------------
    //wire bclk_is_missing; // Optionele draad als je intern wilt weten of de klok weg is

    watchdog u_watchdog (
        .clk_50mhz     (clk_master50),  // Referentie
        .signal_to_mon (i2s_in_bclk),   // Te bewaken klok
        .led1          (led1),          // Naar de fysieke pinnen
        // .led2         (led2),
        // .led3         (led3),
        // .led4         (led4),
        .status_lost   (bclk_is_missing)
    );
    
    // ------------------------------------------------------------
    // Bedrading (Wires) declareren
    // ------------------------------------------------------------
    wire strobe_w1;
    wire strobe_w2;          // FIX: Ontbrak! Nu netjes gedeclareerd
    wire test_signal;
    
    wire [31:0] rx_sample;
    
    // ------------------------------------------------------------
    // I2S ingang
    // ------------------------------------------------------------    
    I2SRX i2s_ingang(
         .i2s_in_bclk    (i2s_in_bclk),
         .reset          (reset),
         .i2s_in_lrclk   (i2s_in_lrclk),
         .i2s_in_data    (i2s_in_data),
         
         .i2s_rx_strobe  (strobe_w1),    // output
         .rx_sample      (rx_sample)     // output
    );
	
	
	// ------------------------------------------------------------	
	// Upsampler (192 kHz -> 384 kHz)
	// ------------------------------------------------------------
    wire [31:0] up_sample;     // 384 kHz
    wire strobe_384;           // Nieuwe clock voor de accumulator
    //wire clk_49152;            // Je klok uit de PLL/DCM

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
		.bypass      (1'b0),       // <--- NIEUW: 1 = Filter UIT, 0 = Filter AAN
        
        .sample_out (filtered_sample),
        .strobe_out (strobe_filtered)
    );	
		
	
	wire [10:0] phase_w;     // FIX: Was [11:0] 4096, aangepast naar [10:0] voor 2048-puntentabel
        
    // ------------------------------------------------------------
    // Phase accumulator
    // ------------------------------------------------------------    
    PHASEACCUMULATOR phase_acc(    
         //.sample_in      (rx_sample[31-:16]), // Neemt bits 31 t/m 16, perfect!
		 .sample_in      (filtered_sample[31-:16]), // Neemt bits 31 t/m 16, perfect!
         .test_signal    (test_signal),
		 //.test_signal    (1'b1),
         .reset          (reset),
         .clk_49152      (clk_49152),
         //.strobe_in      (strobe_w1),
		 .strobe_in      (strobe_filtered),
        
         .strobe_out     (strobe_w2),
         .phase_out      (phase_w)
    );
   
   
    // ------------------------------------------------------------
    // Phase -> IQ using 90-wave LUT 
    // ------------------------------------------------------------
    wire signed [31:0] I16;
    wire signed [31:0] Q16;
    
    // wire signed [31:0] I_data = {I16, 16'd0};
    // wire signed [31:0] Q_data = {Q16, 16'd0};
    wire signed [31:0] I_data = I16;
    wire signed [31:0] Q_data = Q16;	
	//wire unsigned [9:0] phase_adj;
	wire [9:0] phase_adj;
    
    LUT lut(
		.clk_49152   (clk_49152),
        .phase_in    (phase_w),     // 11-bit phase_out van de accumulator
		.phase_adj	 (phase_adj),
        
        .I           (I16), // In-phase sinus
        .Q           (Q16)  // Quadrature sinus (90 graden verschoven)
    );
	

    Oddr2F u_Oddr2F(
		.in        (clk_24576),
		.uit       (i2s_out_bclk)
    );
	
// ============================================================
    // DE WACHTKAMER OPLOSSING (Perfecte I2S Frame Uitlijning)
    // ============================================================
    
    wire [31:0] I_filtered;
    wire [31:0] Q_filtered;
    wire        strobe_iq; 

    // --- De Filters ---
    FIR_IQ filter_i (
        .clk_49152 (clk_49152),
        .reset     (reset),
        .sample_in (I_data),      
        .strobe_in (strobe_w2),   // Start met rekenen bij start van frame
        .sample_out(I_filtered),
        .strobe_out(strobe_iq)    // Gaat hoog na 34 kloktikken
    );

    FIR_IQ filter_q (
        .clk_49152 (clk_49152),
        .reset     (reset),
        .sample_in (Q_data),      
        .strobe_in (strobe_w2),   
        .sample_out(Q_filtered),
        .strobe_out()             
    );    



// Jouw originele Puls Oprekker (zorgt voor exact 2 kloktikken op 49MHz)
    reg strobe_w2_delay;
    always @(posedge clk_49152) begin
        strobe_w2_delay <= strobe_w2;
    end
    
    // We gebruiken NIET strobe_iq, maar direct de stabiele strobe_w2!
    wire safe_tx_strobe = strobe_w2 | strobe_w2_delay;

    // ------------------------------------------------------------
    // I2S uitgang
    // ------------------------------------------------------------        
    I2STX i2s_uitgang(
        .i2s_tx_bclk    (clk_24576),              
        .reset          (reset),
        
        .tx_in_left     (I_filtered), // Direct uit de 63-tap filter
        .tx_in_right    (Q_filtered), // Direct uit de 63-tap filter
        
        // Start de I2S zender op hetzelfde moment als je Phase Acc
        // Zo dwing je de frame-uitlijning perfect af, precies zoals bij de bypass.
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


    
endmodule

 */







//=========================================================================================================




// 3

 /*

`timescale 1ns / 1ps

module TopView(
        input  wire clk_master50,   // P55   //50 MHz
        // External I2S input from DSP (DSP is master)
        input  wire i2s_in_bclk,    // P85        //12,288 MHz from I2S source
        input  wire i2s_in_lrclk,   // P87        //192kHz from I2S source
        input  wire i2s_in_data,    // P84 GCLK   //Stereo channels from source
        input  wire btn_reset_n,    // Reset druk knopje voor de fpga
		
        // Arduino ------------------------------
        input wire spi_data,
        input wire spi_clk,
        input wire spi_le,
        //---------------------------------------   
		
		// I2S output to PCM5102 (FPGA is slave)
        output wire i2s_out_bclk,   // P78
        output wire i2s_out_data,   // P79
        output wire i2s_out_lrclk,  // P80 

		// LED pinnen (Toegevoegd bovenaan)
        output wire led1,            // P56
        // output wire led2,         // P57
        // output wire led3,         // P58
        // output wire led4,         // P59
		
        output wire debug_pin3,    // P97
        output wire debug_pin4,    // P98
        output wire debug_pin5,    // P99
        output wire debug_pin6     // P82   		
    );
    
    // ------------------------------------------------------------
    // 1. Reset & Noodklok Generatie (Altijd actief via 50MHz)
    // ------------------------------------------------------------
    wire reset; 
    wire reset_o;
    wire emg_bclk, emg_lrclk, emg_25;
    wire manual_reset = ~btn_reset_n;

    Reset u_reset_manager (
        .clk_master50    (clk_master50),
        .reset_out       (reset_o),
		.emergency_clk25 (emg_25),
        .emergency_bclk  (emg_bclk),  // ~12.5 MHz
        .emergency_lrclk (emg_lrclk)  // ~390 kHz
    );

    assign reset = reset_o | manual_reset;
	
    // ------------------------------------------------------------
    // 2. PLL clock_doubler Generatie (Afhankelijk van DSP klok)
    // ------------------------------------------------------------
    // Interne klok-bussen die alle modules voeden
    wire clk_24; // Voor I2STX en BCLK output
    wire clk_49; // Voor Upsampler, Filters en Accumulator	
	wire pll_24, pll_49, lockedA;
	
    clock_doublerA u_pll (
        .CLK_IN1   (i2s_in_bclk),
        .CLK_OUT1  (pll_24),   
        .CLK_OUT2  (pll_49),
        .LOCKED    (lockedA)
    );	
	
    // ------------------------------------------------------------
    // 3. Watchdog & INTERNE Klok Selectie
    // ------------------------------------------------------------
    wire bclk_is_missing;

    watchdog u_watchdog (
        .clk_50mhz     (clk_master50),
        .signal_to_mon (i2s_in_bclk),
        .led1          (led1),
        .status_lost   (bclk_is_missing)
    );

	//wire i2s_in_lrclk_w, i2s_in_bclk_w;

    // // HIER maken we de beslissing voor de HELE FPGA
	// assign clk_24 = (bclk_is_missing) ? emg_bclk : pll_24;
    // assign clk_49 = (bclk_is_missing) ? emg_25 : pll_49;

    // // Voor de ingang (RX) gebruiken we ook de noodklokken om de module levend te houden
    // wire i2s_in_bclk_w = (bclk_is_missing) ? emg_bclk : i2s_in_bclk;
    // wire i2s_in_lrclk_w = (bclk_is_missing) ? emg_lrclk : i2s_in_lrclk;
	
    // HIER maken we de beslissing voor de HELE FPGA // test
	assign clk_24 =  pll_24;                         // test
    assign clk_49 =  pll_49;                         // test

    // Voor de ingang (RX) gebruiken we ook de noodklokken om de module levend te houden // test
    wire i2s_in_bclk_w = i2s_in_bclk;                                                    // test
    wire i2s_in_lrclk_w = i2s_in_lrclk;	                                                 // test

    // ------------------------------------------------------------
    // 4. Uitgangs-Bedrading naar DAC
    // ------------------------------------------------------------
    //wire i2s_out_lrclk_fpga;
	//wire i2s_out_lrclk_intern;
    
    // // De uitgangspinnen volgen de interne geschakelde klokken
    // assign i2s_out_lrclk_intern = (bclk_is_missing) ? emg_lrclk : i2s_out_lrclk_fpga;
	
	// Oddr2F u_Oddr2F_lrclk_out(
        // .in   (i2s_out_lrclk_intern),
        // .uit  (i2s_out_lrclk)
    // );

    Oddr2F u_Oddr2F_bclk_out(
        .in   (i2s_in_bclk_w),
        .uit  (i2s_out_bclk)
    );

    // ------------------------------------------------------------
    // 5. Audio Processing Keten (Draait nu ALTIJD op clk_24/clk_49)
    // ------------------------------------------------------------
    wire strobe_w1, strobe_w2, strobe_filtered, strobe_iq, strobe_384;
    wire [31:0] rx_sample, up_sample, filtered_sample, I_filtered, Q_filtered;
    wire [10:0] phase_w;
    wire [9:0]  phase_adj;
    wire test_signal;
    
    // ------------------------------------------------------------
    // I2S ingang
    // ------------------------------------------------------------    
    I2SRX i2s_ingang(
         .i2s_in_bclk    (i2s_in_bclk_w),
         .reset          (reset | bclk_is_missing),
         .i2s_in_lrclk   (i2s_in_lrclk_w),
         .i2s_in_data    (i2s_in_data),
         
         .i2s_rx_strobe  (strobe_w1),    // output
         .rx_sample      (rx_sample)     // output
    );
	
	
	// ------------------------------------------------------------	
	// Upsampler (192 kHz -> 384 kHz)
	// ------------------------------------------------------------
    // wire [31:0] up_sample;     // 384 kHz
    // wire strobe_384;           // Nieuwe clock voor de accumulator
    // //wire clk_49152;            // Je klok uit de PLL/DCM

    Upsampler u_Upsampler(
        .clk_49152  (clk_49),
        .reset      (reset),
        .sample_in  (rx_sample),
        .strobe_192 (strobe_w1),
		
        .sample_out (up_sample),
        .strobe_384 (strobe_384)
    );	
	
	
	
 // ------------------------------------------------------------
    // NIEUW: FIR Filter (Na Upsampler)
    // ------------------------------------------------------------
   // wire [31:0] filtered_sample; 
   // wire strobe_filtered;

     FIR_Filter u_FIR (
        .clk_49152  (clk_49), // INTERNE GESCHAKELDE KLOK
        .reset      (reset),
        .sample_in  (up_sample),
        .strobe_in  (strobe_384),
        .bypass     (1'b1),
        .sample_out (filtered_sample),
        .strobe_out (strobe_filtered)
    );	
		
	
	//wire [10:0] phase_w;     // FIX: Was [11:0] 4096, aangepast naar [10:0] voor 2048-puntentabel
        
    // ------------------------------------------------------------
    // Phase accumulator
    // ------------------------------------------------------------    
    PHASEACCUMULATOR phase_acc(    
         //.sample_in      (rx_sample[31-:16]), // Neemt bits 31 t/m 16, perfect!
		 .sample_in      (filtered_sample[31-:16]), // Neemt bits 31 t/m 16, perfect!
         .test_signal    (test_signal),
         .reset          (reset),
         .clk_49152      (clk_49),
         //.strobe_in      (strobe_w1),
		 .strobe_in      (strobe_filtered),
        
         .strobe_out     (strobe_w2),
         .phase_out      (phase_w)
    );
   
   
    // ------------------------------------------------------------
    // Phase -> IQ using 90-wave LUT 
    // ------------------------------------------------------------
    //wire signed [31:0] I16;
    //wire signed [31:0] Q16;
    
    //wire signed [31:0] I_data = {I16, 16'd0};
    //wire signed [31:0] Q_data = {Q16, 16'd0};
    wire signed [31:0] I_data;
    wire signed [31:0] Q_data;	
	// //wire unsigned [9:0] phase_adj;
	// wire [9:0] phase_adj;
    
    LUT lut(
        .clk_49152   (clk_49), // INTERNE GESCHAKELDE KLOK
        .phase_in    (phase_w),
        .phase_adj     (phase_adj),
        
        .I           (I_data), // In-phase sinus
        .Q           (Q_data)  // Quadrature sinus (90 graden verschoven)
    );
	

    // Oddr2F u_Oddr2F(
		// .in        (clk_24576),
		// .uit       (i2s_out_bclk)
    // );
	
// ============================================================
    // DE WACHTKAMER OPLOSSING (Perfecte I2S Frame Uitlijning)
    // ============================================================
    
    //wire [31:0] I_filtered;
    //wire [31:0] Q_filtered;
    //wire        strobe_iq; 

    // --- De Filters ---
    FIR_IQ filter_i (
        .clk_49152 (clk_49),
        .reset     (reset),
        .sample_in (I_data),      
        .strobe_in (strobe_w2),   // Start met rekenen bij start van frame
        .sample_out(I_filtered),
        .strobe_out(strobe_iq)    // Gaat hoog na 34 kloktikken
    );

    FIR_IQ filter_q (
        .clk_49152 (clk_49),
        .reset     (reset),
        .sample_in (Q_data),      
        .strobe_in (strobe_w2),   
        .sample_out(Q_filtered),
        .strobe_out()             
    );    



// Jouw originele Puls Oprekker (zorgt voor exact 2 kloktikken op 49MHz)
    reg strobe_w2_delay;
    always @(posedge clk_49) begin
        strobe_w2_delay <= strobe_w2;
    end
    
    // We gebruiken NIET strobe_iq, maar direct de stabiele strobe_w2!
    wire safe_tx_strobe = strobe_w2 | strobe_w2_delay;

    // ------------------------------------------------------------
    // I2S uitgang (Draait nu ALTIJD op clk_24)
    // ------------------------------------------------------------        
    I2STX i2s_uitgang(
        .i2s_tx_bclk    (clk_24),              
        .reset          (reset),
        
        .tx_in_left     (I_filtered), // Direct uit de 63-tap filter
        .tx_in_right    (Q_filtered), // Direct uit de 63-tap filter
        
        // Start de I2S zender op hetzelfde moment als je Phase Acc
        // Zo dwing je de frame-uitlijning perfect af, precies zoals bij de bypass.
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
        .debug_pin5     (debug_pin5),
        .debug_pin6     (debug_pin6)
    );

    
endmodule

 */



//=========================================================================================================




// 4  Werkt goed

/*

`timescale 1ns / 1ps

module TopView(
        input  wire clk_master50,   // P55   //50 MHz
        // External I2S input from DSP (DSP is master)
        input  wire i2s_in_bclk,    // P85        //12,288 MHz from I2S source
        input  wire i2s_in_lrclk,   // P87        //192kHz from I2S source
        input  wire i2s_in_data,    // P84 GCLK   //Stereo channels from source
        
        // I2S output to PCM5102 (FPGA is slave)

        // Arduino ------------------------------
        input wire spi_data,
        input wire spi_clk,
        input wire spi_le,
        //---------------------------------------    
    
        output wire i2s_out_bclk,   // P78
        output wire i2s_out_data,   // P79
        output wire i2s_out_lrclk,  // P80 

		// LED pinnen (Toegevoegd bovenaan)
        output wire led1,            // P56
        // output wire led2,         // P57
        // output wire led3,         // P58
        // output wire led4,         // P59
		
        output wire debug_pin3,    // P97
        output wire debug_pin4,    // P98
        output wire debug_pin5,    // P99
        output wire debug_pin6     // P82   		
    );
    
    

    // ------------------------------------------------------------
    // Proper 10 ms power-on reset 
    // ------------------------------------------------------------
    wire reset; 
        
    `ifdef SIM
        assign reset = 0;   // direct uit reset in simulatie
    `else
        Reset u_pow_reset(
            .clk_master50    (clk_master50),
            .reset_out       (reset)
        );
    `endif
	
	 // ------------------------------------------------------------
    // Clock generation (49.152 MHz BUFG)
    // ------------------------------------------------------------
    wire clk_24576;   // BUFG clock
	wire clk_49152;   // BUFG clock
	wire lockedA, lockedB;  // wordt nog niet gebruikt

    clock_doublerA u_clock_doublerA (
        .CLK_IN1   (i2s_in_bclk),
        .CLK_OUT1  (clk_24576),   // BUFG output
		.CLK_OUT2  (clk_49152),
		.RESET	   (reset),
        .LOCKED    (lockedA)
    );
	
    // clock_doublerB u_clock_doublerB (
        // .CLK_IN1   (clk_24576),
        // .CLK_OUT1  (clk_49152),   // BUFG output
		// .RESET 	   (reset),
        // .LOCKED    (lockedB)
    // );
	
	// ------------------------------------------------------------
    // I2S Clock Watchdog
    // ------------------------------------------------------------
    wire bclk_is_missing; // Optionele draad als je intern wilt weten of de klok weg is

    watchdog u_watchdog (
        .clk_50mhz    (clk_master50),  // Referentie
        .signal_to_mon(i2s_in_bclk),   // Te bewaken klok
        .led1         (led1),          // Naar de fysieke pinnen
        // .led2         (led2),
        // .led3         (led3),
        // .led4         (led4),
        .status_lost  (bclk_is_missing)
    );
    
    // ------------------------------------------------------------
    // Bedrading (Wires) declareren
    // ------------------------------------------------------------
    wire strobe_w1;
    wire strobe_w2;          // FIX: Ontbrak! Nu netjes gedeclareerd
    wire test_signal;
    
    wire [31:0] rx_sample;
    
    // ------------------------------------------------------------
    // I2S ingang
    // ------------------------------------------------------------    
    I2SRX i2s_ingang(
         .i2s_in_bclk    (i2s_in_bclk),
         .reset          (reset),
         .i2s_in_lrclk   (i2s_in_lrclk),
         .i2s_in_data    (i2s_in_data),
         
         .i2s_rx_strobe  (strobe_w1),    // output
         .rx_sample      (rx_sample)     // output
    );
	
	
	// ------------------------------------------------------------	
	// Upsampler (192 kHz -> 384 kHz)
	// ------------------------------------------------------------
    wire [31:0] up_sample;     // 384 kHz
    wire strobe_384;           // Nieuwe clock voor de accumulator
    //wire clk_49152;            // Je klok uit de PLL/DCM

    Upsampler u_Upsampler(
        .clk_49152  (clk_49152),
        .reset      (reset),
        .sample_in  (rx_sample),
        .strobe_192 (strobe_w1),
		
        .sample_out (up_sample),
        .strobe_384 (strobe_384)
    );	
	
	
	assign debug_pin6  = strobe_384;
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
		.bypass      (1'b0),       // <--- NIEUW: 1 = Filter UIT, 0 = Filter AAN
        
        .sample_out (filtered_sample),
        .strobe_out (strobe_filtered)
    );	
		
	
	wire [10:0] phase_w;     // FIX: Was [11:0] 4096, aangepast naar [10:0] voor 2048-puntentabel
        
    // ------------------------------------------------------------
    // Phase accumulator
    // ------------------------------------------------------------    
    PHASEACCUMULATOR phase_acc(    
         //.sample_in      (rx_sample[31-:16]), // Neemt bits 31 t/m 16, perfect!
		 .sample_in      (filtered_sample[31-:16]), // Neemt bits 31 t/m 16, perfect!
         .test_signal    (test_signal),
         .reset          (reset),
         .clk_49152      (clk_49152),
         //.strobe_in      (strobe_w1),
		 .strobe_in      (strobe_filtered),
        
         .strobe_out     (strobe_w2),
         .phase_out      (phase_w)
    );
   
   
    // ------------------------------------------------------------
    // Phase -> IQ using 90-wave LUT 
    // ------------------------------------------------------------
    wire signed [31:0] I16;
    wire signed [31:0] Q16;
    
    // wire signed [31:0] I_data = {I16, 16'd0};
    // wire signed [31:0] Q_data = {Q16, 16'd0};
    wire signed [31:0] I_data = I16;
    wire signed [31:0] Q_data = Q16;	
	//wire unsigned [9:0] phase_adj;
	wire [9:0] phase_adj;
    
    LUT lut(
		.clk_49152   (clk_49152),
        .phase_in    (phase_w),     // 11-bit phase_out van de accumulator
		.phase_adj	 (phase_adj),
        
        .I           (I16), // In-phase sinus
        .Q           (Q16)  // Quadrature sinus (90 graden verschoven)
    );
	

    Oddr2F u_Oddr2F(
		.in        (clk_24576),
		.uit       (i2s_out_bclk)
    );
	
// ============================================================
    // DE WACHTKAMER OPLOSSING (Perfecte I2S Frame Uitlijning)
    // ============================================================
    
    wire [31:0] I_filtered;
    wire [31:0] Q_filtered;
    wire        strobe_iq; 

    // --- De Filters ---
    FIR_IQ filter_i (
        .clk_49152 (clk_49152),
        .reset     (reset),
        .sample_in (I_data),      
        .strobe_in (strobe_w2),   // Start met rekenen bij start van frame
        .sample_out(I_filtered),
        .strobe_out(strobe_iq)    // Gaat hoog na 34 kloktikken
    );

    FIR_IQ filter_q (
        .clk_49152 (clk_49152),
        .reset     (reset),
        .sample_in (Q_data),      
        .strobe_in (strobe_w2),   
        .sample_out(Q_filtered),
        .strobe_out()             
    );    



// Jouw originele Puls Oprekker (zorgt voor exact 2 kloktikken op 49MHz)
    reg strobe_w2_delay;
    always @(posedge clk_49152) begin
        strobe_w2_delay <= strobe_w2;
    end
    
    // We gebruiken NIET strobe_iq, maar direct de stabiele strobe_w2!
    wire safe_tx_strobe = strobe_w2 | strobe_w2_delay;

    // ------------------------------------------------------------
    // I2S uitgang
    // ------------------------------------------------------------        
    I2STX i2s_uitgang(
        .i2s_tx_bclk    (clk_24576),              
        .reset          (reset),
        
        .tx_in_left     (I_filtered), // Direct uit de 63-tap filter
        .tx_in_right    (Q_filtered), // Direct uit de 63-tap filter
        
        // Start de I2S zender op hetzelfde moment als je Phase Acc
        // Zo dwing je de frame-uitlijning perfect af, precies zoals bij de bypass.
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


    
endmodule


*/
















