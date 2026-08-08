

`timescale 1ns / 1ps

module I2STX(
    input  wire        i2s_tx_bclk,   // DSP Bit Clock
    input  wire        reset,
    input  wire [31:0] tx_in_left,
    input  wire [31:0] tx_in_right,
    input  wire        tx_strobe,     // Trigger om nieuwe data te verwerken
    
    // Arduino SPI Interface
    input  wire        spi_le,
    input  wire        spi_clk,
    input  wire        spi_data,
    output reg         test_signal,
    
    // I2S Outputs
    output reg         i2s_tx_lrclk,
    output reg         i2s_out_data,
	
    // NIEUW: phase_adj is nu een uitgang, klaar om ergens anders voor te gebruiken!
    output reg [9:0]   phase_adj, 
	
    // debug pinnen
	output reg 			debug_pin3,
	output reg 			debug_pin4,
	output reg 			debug_pin5,
	output reg 			debug_pin6
);


    // --- Registers ---
    reg [63:0] tx_buf;
    reg [5:0]  cnt;
    
    // Arduino parameters
    reg [9:0]  offset_a, offset_b;  // phase_adj;
	reg [9:0]  balance; // balance waarde uit de arduino, die gebruikt wordt om de 
						// input van 1 kanaal (I of Q) harder/zachter te zetten
    reg [12:0] shift;
    reg [3:0]  bitcnt;
		
	
    // [VERANDERD 1] Sync registers voor SPI edge detectie (Double Flip-Flop voor 24MHz)
    reg [1:0] le_sync;
    reg [1:0] clk_sync;
    reg [1:0] data_sync;


	
    // Sync registers voor SPI edge detectie
//    reg le_d, clk_d, spi_data_d;
	
	
// --- Combinatoriale Wiskunde (Veel simpeler nu!) ---
    	
	
    // 1. OFFSETS VOORBEREIDEN
    //wire signed [31:0] off_a_ext = $signed({{3{offset_a[9]}}, offset_a, 19'b0});
	wire signed [31:0] off_a_ext = $signed(offset_a) <<< 18;
    // wire signed [31:0] off_b_ext = $signed({{3{offset_b[9]}}, offset_b, 19'b0});
	wire signed [31:0] off_b_ext = $signed(offset_b) <<< 18;

	// We moeten de balance (levels) tussen I en Q ook in kunnen stellen
	// Dat doen we met de balance (B) waarde die we in de Arduino instellen
	wire signed [15:0] balance_adj_s16 = $signed(balance)<<<2;
	wire signed [15:0] scale_q15 = 16'sd16384 + balance_adj_s16; // Q1.15
	wire signed [31:0] tx_in_right_wire = $signed(tx_in_right); // we lezen tx in right naar een wire zodat we ermee kunnen rekenen
	wire signed [47:0] tx_in_right_balanced = tx_in_right_wire * scale_q15; // Deze gaan we een klein beetje versterken of verzwakken
	

	
	// 2. VEILIG OPTELLEN (Rechts doet nu exact hetzelfde als Links!)
    wire signed [32:0] sum_left  = $signed(tx_in_left) + off_a_ext;
    wire signed [32:0] sum_right = (tx_in_right_balanced>>>14) + off_b_ext; //$signed(tx_in_right);
	

	
    wire [31:0] processed_left  = (sum_left > 33'sh0_7FFFFFFF)  ? 32'h7FFFFFFF : 
                                  (sum_left < -33'sh0_80000000) ? 32'h80000000 : 
                                  sum_left[31:0];

    wire [31:0] processed_right = (sum_right > 33'sh0_7FFFFFFF)  ? 32'h7FFFFFFF : 
                                  (sum_right < -33'sh0_80000000) ? 32'h80000000 : 
                                  sum_right[31:0];
	


    // --- Main Logic ---
    always @(negedge i2s_tx_bclk) begin
        if (reset) begin
		

		
            tx_buf       <= 64'b0;
            cnt          <= 6'd0;
            i2s_out_data <= 1'b0;
            i2s_tx_lrclk <= 1'b0;
            // SPI Reset
			
            //{offset_a, offset_b, phase_adj} <= 30'b0;
            offset_a     <= 10'b0;
            offset_b     <= 10'b0;
            phase_adj    <= 10'b0;	
			balance		 <= 10'b0;
            shift        <= 13'b0;
            bitcnt       <= 4'd0;
            test_signal  <= 1'b0;
			
			
			
            //{le_d, clk_d, spi_data_d}       <= 3'b0;
			            // [VERANDERD 4] Reset de nieuwe dubbele sync-registers
            le_sync      <= 2'd0;
            clk_sync     <= 2'd0;
            data_sync    <= 2'd0;
        end else begin
            
            // 1. I2S Bit Output & LRCLK
            i2s_out_data <= tx_buf[cnt];
            
            if (cnt > 0) cnt <= cnt - 6'd1;

            if (cnt == 0)  i2s_tx_lrclk <= 1'b0;  // Links Rechts klok laag
            if (cnt == 32) i2s_tx_lrclk <= 1'b1;

            // 2. Data laden op Strobe (Samenstellen van Left + Right)
            if (tx_strobe) begin
                //tx_buf <= { processed_left, processed_right };
				//tx_buf <= { tx_in_left[15:0], 16'd0, tx_in_right[15:0], 16'd0 };
				tx_buf <= { processed_left, processed_right};
                cnt    <= 6'd63;
            end
//----------------------------- Arduino ------------------------------------------------------
            // 3. SPI / Arduino Logic
            // spi_data_d <= spi_data;           // Sla de huidige status van de Arduino data-pin op (voor synchronisatie)
            // clk_d      <= spi_clk;            // Sla de huidige status van de Arduino klok-pin op (om straks een verandering te zien)
            // le_d       <= spi_le;             // Sla de huidige status van de Arduino LE (Latch Enable) pin op
            
			if (cnt == 32) begin 
				// // // [VERANDERD 6] SPI / Arduino Logic: Veilig inlezen voor hoge kloksnelheden
				le_sync   <= {le_sync[0], spi_le};
				clk_sync  <= {clk_sync[0], spi_clk};
				data_sync <= {data_sync[0], spi_data};

				debug_pin3 <= spi_le;
				debug_pin4 <= spi_clk;
				debug_pin5 <= spi_data;
				//debug_pin6 <= spi_data;
				debug_pin6 <= 1'b0;
				
				// Start van transactie       
				if (!le_sync[1] && le_sync[0]) begin        // Detecteer een "Rising Edge" van LE: was de pin net LAAG (!le_sync[1]) en is hij nu HOOG (le_sync[0])?
					bitcnt <= 4'd0;               // Ja? Dan begint er een nieuwe transactie: zet de teller voor ontvangen bits op 0
					shift  <= 13'b0;              // Maak ook het schuifregister helemaal leeg (alle 13 bits op 0)								
				end 
				// Data inklokken                                
				if (le_sync[0] && !clk_sync[1] && clk_sync[0]) begin      // Als de transactie bezig is (LE is hoog) EN de klok gaat van LAAG naar HOOG (Rising Edge)
					//debug_pin6 <= 1'b1;
					shift  <= {shift[11:0], data_sync[0]};         // Schuif de 12 oude bits één plek naar links en plak de nieuwe bit (spi_data_d) er helemaal rechts aan vast
					bitcnt <= bitcnt + 4'd1;                     // We hebben succesvol 1 bit binnengehaald, dus we hogen de bitteller met 1 op				 
				end

				// Adres-decodering als 13 bits binnen zijn
				if (bitcnt == 4'd13) begin                // Controleer of we exact 13 bits in het schuifregister hebben zitten
					debug_pin6 <= 1'b1;
								
					bitcnt <= 4'd0;                       // Reset de teller direct naar 0, zodat deze code niet per ongeluk de volgende kloktik wéér afgaat
					case (shift[12:10])                   // Kijk naar de bovenste 3 bits (bit 12, 11 en 10) van wat we net ontvangen hebben; dit is het "adres"
						3'd1: offset_b    <= shift[9:0];  // Is het adres 1? Sla dan de onderste 10 bits (de data) op in het register 'offset_b'
						3'd2: offset_a    <= shift[9:0];  // Is het adres 2? Sla dan de onderste 10 bits op in het register 'offset_a'
						3'd3: phase_adj   <= shift[9:0];  // Is het adres 3? Sla dan de onderste 10 bits op in het register 'phase_adj'
						3'd4: test_signal <= shift[0];    // Is het adres 4? Dat is alleen test mode aan of uit
						3'd5: balance     <= shift[9:0];  // Is het adres 5? Sla dan de onderste 10 bits op in het register 'balance'
						
	// Hier dwingen we alles naar NUL, wat er ook gestuurd wordt:
						//3'd1: offset_b    <= 10'd0; // Altijd 0
						//3'd2: offset_a    <= 10'd0; // Altijd 0
						//3'd3: phase_adj   <= 10'd0; // Geen fase aanpassing
						//3'd4: test_signal <= 1'b0;  // Test signaal uit
						//3'd5: balance     <= 10'd0; // Balans in het midden (0)
						
					endcase                               // Einde van het adres-keuzemenu
				end                                       
			end
//--------------------------------------------------------------------------------------------			
        end
    end

endmodule


