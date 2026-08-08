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
	output reg 			debug_pin5
	//output reg 			debug_pin6
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
	wire signed [31:0] off_a_ext = $signed(offset_a) <<< 17;
    // wire signed [31:0] off_b_ext = $signed({{3{offset_b[9]}}, offset_b, 19'b0});
	wire signed [31:0] off_b_ext = $signed(offset_b) <<< 17;

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

    // // wire [31:0] processed_right = (sum_right > 33'sh0_7FFFFFFF)  ? 32'h7FFFFFFF : 
                                  // // (sum_right < -33'sh0_80000000) ? 32'h80000000 : 
                                  // // sum_right[31:0];
	
    // VERANDERD: Maskering toegevoegd { ... [31:16], 16'd0 } om extra pulsen rechts te voorkomen
    wire [31:0] processed_right = (sum_right > 33'sh0_7FFFFFFF)  ? 32'h7FFFFFFF : 
                                  (sum_right < -33'sh0_80000000) ? 32'h80000000 : 
                                  {sum_right[31:16], 16'd0}; 



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
				//debug_pin6 <= 1'b0;
				
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
					//debug_pin6 <= 1'b1;
								
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





/*



// // // --- Combinatoriale Wiskunde (Wijsneus-logica) ---
    
    // // // Fase aanpassing: 10-bit naar 16-bit signed, optellen bij Q1.15 schaal (0.5 basis)
    // // wire signed [15:0] phase_adj_s16 = {{6{phase_adj[9]}}, phase_adj}; // Maak de 10-bit waarde 16-bits breed. Dit heet "Sign Extension": kopieer de hoogste bit 
	// // //                                                                   (de + of - indicator, bit 9) 6 keer extra aan de voorkant, zodat negatieve getallen ook als 16-bit negatief blijven kloppen.   
	// // wire signed [15:0] scale_q15     = 16'sd16384 + phase_adj_s16;     // Tel de aanpassing op bij 16384. In Q1.15 notatie staat 32768 voor "1.0", dus 16384 is exact "0.5". 
	// // //                                                                    Dit is de basis-vermenigvuldigingsfactor.
    

    // // // Vermenigvuldiging Right Channel
    // // wire signed [31:0] x             = $signed(tx_in_right);           // Vertel de compiler expliciet dat de 32-bit ruwe inkomende audio data een getal mét een min-teken kan zijn (signed), 
    // // //                                                                    anders doet hij de vermenigvuldiging straks verkeerd.
	// // //                  
    // // wire signed [47:0] tx_in_adj     = x * scale_q15;                  // Vermenigvuldig de 32-bit audio met de 16-bit factor 
	// // //                                                                   (0.5 + aanpassing). Dit levert wiskundig een gigantisch 48-bit getal op (32 bits + 16 bits = 48 bits).


    // // // // Offsets voorbereiden (32-bit breed maken voor optelling)
    // // // wire [31:0] off_a_ext = {{3{offset_a[9]}}, offset_a, 19'b0};       // Maak de 10-bit 'offset_a' passend voor 32-bit audio. We plakken 19 nullen aan de achterkant 
	// // // //                                                                    (dit vermenigvuldigt het getal gigantisch zodat het uitlijnt met de luide bits) en vullen de bovenste 3 bits aan met de min-teken bit (3+10+19 = 32).
    // // // wire [31:0] off_b_ext = {{3{offset_b[9]}}, offset_b, 19'b0};       // Doe exact hetzelfde trucje (uitlijnen en sign-extension) voor 'offset_b'.

	// // // --- NIEUWE CODE ---
	// // wire signed [31:0] off_a_ext = $signed({{6{offset_a[9]}}, offset_a, 16'b0});
	// // wire signed [31:0] off_b_ext = $signed({{6{offset_b[9]}}, offset_b, 16'b0});


    // // // De uiteindelijke kanalen na verwerking
    // // wire [31:0] processed_left  = tx_in_left + off_a_ext;              // Linker kanaal is makkelijk: neem de originele audio en tel de enorme 32-bit gemaakte offset erbij op (dit is een DC-offset).
    // // wire [31:0] processed_right = (tx_in_adj >>> 14) + off_b_ext;      // Rechter kanaal: Neem het grote 48-bit vermenigvuldigde getal en schuif alle bits 14 stappen naar rechts (>>>) 
	// // //                                                                    om de "komma" weer goed te zetten na de eerdere berekening. Tel daarna pas offset B erbij op.	



*/

/*
module I2STX(
    input  wire        i2s_tx_bclk,   // Bit Clock
    input  wire        reset,
    input  wire [31:0] tx_in_left,
    input  wire [31:0] tx_in_right,
    input  wire        tx_strobe,     // Signaal om nieuwe data te laden
    
    // Arduino SPI Control
    input  wire        spi_le,        // Latch Enable
    input  wire        spi_clk,       // SPI Clock
    input  wire        spi_data,      // SPI Data
    output reg         test_signal,   // Output via SPI (Address 4)
    
    // I2S Outputs
    output reg         i2s_tx_lrclk,  // Left/Right Clock
    output reg         i2s_out_data   // Seriële data uit
);

    // Registers voor audio
    reg [63:0] tx_buf;
    reg [5:0]  cnt;

    // Registers voor SPI (Arduino)
    reg [12:0] shift;
    reg [3:0]  bitcnt;
    reg        le_d;
    reg        clk_d;
    reg        spi_data_d;

    // I2S Logic & SPI Sampling
    always @(negedge i2s_tx_bclk) begin
        if (reset) begin
            tx_buf       <= 64'b0;
            cnt          <= 6'd0;
            i2s_out_data <= 1'b0;
            i2s_tx_lrclk <= 1'b0;
            // SPI Reset
            shift        <= 13'b0;
            bitcnt       <= 4'd0;
            test_signal  <= 1'b0;
            le_d         <= 1'b0;
            clk_d        <= 1'b0;
            spi_data_d   <= 1'b0;
        end else begin
            
            // --- 1. I2S Data Shifting ---
            i2s_out_data <= tx_buf[cnt];

            if (cnt > 0) begin
                cnt <= cnt - 6'd1;
            end

            // LRCLK generatie op basis van counter
            if (cnt == 0)  i2s_tx_lrclk <= 1'b0;
            if (cnt == 32) i2s_tx_lrclk <= 1'b1;
            
            // Nieuwe data laden
            if (tx_strobe) begin
                tx_buf <= {tx_in_right, tx_in_left};
                cnt    <= 6'd63;
            end

            // --- 2. SPI / Arduino Interface ---
            // Sample SPI signalen op de BCLK
            spi_data_d <= spi_data;
            clk_d      <= spi_clk;
            le_d       <= spi_le;

            // Detecteer rising edge op SPI Latch Enable (Start/Reset transactie)
            if (!le_d && spi_le) begin
                bitcnt <= 4'd0;
                shift  <= 13'b0;
            end 
            // Als Latch Enable hoog is, schuif data binnen op rising edge van SPI Clock
            else if (spi_le && !clk_d && spi_clk) begin
                shift  <= {shift[11:0], spi_data_d};
                bitcnt <= bitcnt + 4'd1;
            end

            // Verwerk data als alle 13 bits binnen zijn (3 adres + 10 data)
            if (bitcnt == 4'd13) begin
                bitcnt <= 4'd0; // Voorkom herhaalde activatie
                if (shift[12:10] == 3'd4) begin
                    test_signal <= shift[0];
                end
            end

        end
    end

endmodule

*/

/*

`timescale 1ns / 1ps


module I2STX(
    input  wire       	i2s_tx_bclk,     	 // DSP BCLK
    input  wire       	reset,
    input  wire [31:0]	tx_in_left,
    input  wire [31:0]	tx_in_right,
    input  wire       	tx_strobe,		   // from RX
	
// //--------------------- Arduino ---------------------------------------		
	input wire			spi_le,
	input wire			spi_clk,
	input wire			spi_data,
	output reg			test_signal,
// //--------------------- Arduino end -----------------------------------		
	
    output reg       	i2s_tx_lrclk,       // Make LRCLK for tx i2s
	//output reg			debugPin,
    output reg        	i2s_out_data
);



// // // // // // // // These registers hold the audio data and the shifting state
// // // // // // // reg [63:0] tx_buf;
// // // // // // // reg [5:0]  cnt;						// bit counter (0..63)

// // // // // // // always @(negedge i2s_tx_bclk) begin
    // // // // // // // if (reset) begin
		// // // // // // // //debugPin <= 0;
		// // // // // // // tx_buf <= 64'b0;        
        // // // // // // // i2s_out_data <= 0;
		// // // // // // // i2s_tx_lrclk <= 0;
		// // // // // // // cnt <= 6'd0;
    // // // // // // // end else begin
	
		// // // // // // // // Output data immediately
		// // // // // // // i2s_out_data <= tx_buf[cnt];

		// // // // // // // if (cnt > 0) begin
			// // // // // // // cnt <= cnt - 6'd1;
		// // // // // // // end

		// // // // // // // if (cnt == 0) begin
			// // // // // // // i2s_tx_lrclk <= 0;
		// // // // // // // end
		// // // // // // // if (cnt == 32) begin
			// // // // // // // i2s_tx_lrclk <= 1;
		// // // // // // // end
		
		// // // // // // // if (tx_strobe) begin
// // // // // // // //			tx_buf <= {tx_in_left, tx_in_right};
			// // // // // // // tx_buf <= {tx_in_right, tx_in_left};
			// // // // // // // cnt <= 6'd63; // want data komt verschoven tevoorschijn
			// // // // // // // //debugPin <= 1;
		// // // // // // // end else begin
			// // // // // // // //debugPin <= 0;
		// // // // // // // end
    // // // // // // // end
// // // // // // // end

// // // // // // // endmodule







// These registers hold the audio data and the shifting state
reg [63:0] tx_buf = 0;
reg [5:0]  cnt;						// bit counter (0..63)

// //--------------------- Arduino -----------------------------------	
 reg [12:0] shift; // 3 address bits [MSBs] and 10 databits [LSBs]
 reg [9:0] offset_a;
 reg [9:0] offset_b;
 reg [9:0] phase_adj;


reg [3:0] bitcnt;
 reg le_d;
 reg clk_d;
 reg le_d2;
 reg clk_d2;
 reg spi_data_d;
 reg spi_data_d2;

 // wire signed [15:0] phase_adj_s16 = {{6{phase_adj[9]}}, phase_adj}; // 10->16 signed
 // wire signed [15:0] scale_q15 = 16'sd16384 + phase_adj_s16; // Q1.15
 // wire signed [17:0] x = $signed({tx_in_right, 2'b0});
 // wire signed [33:0] tx_in_adj = x * scale_q15;
 
wire signed [15:0] phase_adj_s16 = {{6{phase_adj[9]}}, phase_adj}; // 10->16 signed
wire signed [15:0] scale_q15 = 16'sd16384 + phase_adj_s16; // Q1.15
wire signed [31:0] x = $signed(tx_in_right);
wire signed [47:0] tx_in_adj = x * scale_q15;





//------------------- wijsneuscode ------------------------------------------------------------

//------------------------------------------------------------------------------- 


// //--------------------- Arduino end -----------------------------------	

always @(negedge i2s_tx_bclk) begin
    if (reset) begin
		//debugPin <= 0;
		tx_buf <= 64'b0;
		cnt <= 6'd0;
        i2s_out_data <= 0;
		i2s_tx_lrclk <= 0;
		//data_delay <= 1'b0;   // <-- toegevoegd
// //--------------------- Arduino -----------------------------------		
		shift		<=	13'b0;
		offset_a	<=	10'b0;
		offset_b	<=	10'b0;
		phase_adj 	<= 	10'b0;
		 test_signal <=  10'b0;   // vreemd
		bitcnt		<=	4'd0;
		le_d		<=	1'b0;
		clk_d		<=  1'b0;
		test_signal <=  1'b0;	  // vreemd	
    end else begin    // < ------------ Dit niet vergeten natuurlijk
		
	    // Dit is de meest eenvoudige manier: 
        // Elke klokslag verandert de status van 0 naar 1 of 1 naar 0.
        //debugPin <= ~debugPin;
		
		// Read offsets from external SPI bus (Arduino)
		clk_d2 <= clk_d;
		clk_d <= spi_clk;	// Edge detection on spi_clk
		le_d2 <= le_d;
		le_d <= spi_le;		// Edge detection on spi_le
		//spi_data_d2 <= spi_data_d;
		spi_data_d <= spi_data;
		
		if (!le_d2 && spi_le) begin // rising edge spi_le, reset conditions
			//debugPin <= 1;
			bitcnt  <= 4'd0;
			shift <= 13'b0;
		end

		if (le_d) begin
			if (!clk_d2 && clk_d) begin
				shift <= {shift[11:0], spi_data_d};
				bitcnt <= bitcnt + 4'd1;
			end
		end
		//if (le_d2 && !spi_le) begin // falling edge spi_le, assume all bits are in
		// if (clk_d2 && !spi_clk) begin // falling clk
			// debugPin <= 0;
		// end

		if (bitcnt == 4'd13) begin // All bits are in
			//debugPin <= 0;
			if (shift[12:10] == 3'd1) begin //I
				offset_b <= shift[9:0];
			end
			else if (shift[12:10] == 3'd2) begin // Q
				offset_a <= shift[9:0];
			end
			else if (shift[12:10] == 3'd3) begin // P
				phase_adj <= shift[9:0];
			end
			else if (shift[12:10] == 3'd4) begin // Test on or off
				test_signal <= shift[0];
			end
		end
// //--------------------- Arduino end -----------------------------------		
	
		// Output data immediately
		i2s_out_data <= tx_buf[cnt];

		if (cnt > 0) begin
			cnt <= cnt - 6'd1;
		end

		if (cnt == 0) begin
			i2s_tx_lrclk <= 0;
		end
		if (cnt == 32) begin
			i2s_tx_lrclk <= 1;
		end
		
		

		
		if (tx_strobe) begin
		//	tx_buf <= {tx_in_right, tx_in_left};
			
		//	tx_buf <= { tx_in_right, (tx_in_adj + {{3{offset_b[9]}}, offset_b, 19'b0}), ({tx_in_left, 16'b0} + {{3{offset_a[9]}}, offset_a, 19'b0}) };
		
			tx_buf <= { tx_in_left,((tx_in_adj>>>14) + {{3{offset_b[9]}}, offset_b, 19'b0}), (tx_in_left + {{3{offset_a[9]}}, offset_a, 19'b0}) };
			
			//tx_buf <= { tx_in_left,((tx_in_adj>>>10) + {{3{offset_b[9]}}, offset_b, 19'b0}), (tx_in_left + {{3{offset_a[9]}}, offset_a, 19'b0}) };
			
			
		
			cnt <= 6'd63; // want data komt verschoven tevoorschijn
			//debugPin <= 1;
		end else begin
			//debugPin <= 0;
		end
    end
end

endmodule

*/