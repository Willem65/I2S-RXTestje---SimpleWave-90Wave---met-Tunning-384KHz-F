



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
    output reg [9:0]   phase_adj     
);

    // --- Registers ---
    reg [63:0] tx_buf;
    reg [5:0]  cnt;
    
    // Arduino parameters
    reg [9:0]  offset_a, offset_b;  
    reg [9:0]  balance; // balance waarde uit de arduino, die gebruikt wordt om de 
                        // input van 1 kanaal (I of Q) harder/zachter te zetten
    reg [12:0] shift;
    reg [3:0]  bitcnt;
    
    // [VERANDERD 1] Sync registers voor SPI edge detectie (Double Flip-Flop voor 24MHz)
    reg [1:0] le_sync;
    reg [1:0] clk_sync;
    reg [1:0] data_sync;
    
    
// --- Combinatoriale Wiskunde ---
    
    // 1. OFFSETS VOORBEREIDEN
    wire signed [31:0] off_a_ext = $signed(offset_a) <<< 19;
    wire signed [31:0] off_b_ext = $signed(offset_b) <<< 19;

    // We moeten de balance (levels) tussen I en Q ook in kunnen stellen
    wire signed [15:0] balance_adj_s16 = $signed(balance)<<<3;
    wire signed [15:0] scale_q15 = 16'sd16384 + balance_adj_s16; // Q1.15
    wire signed [31:0] tx_in_right_wire = $signed(tx_in_right); 
    wire signed [47:0] tx_in_right_balanced = tx_in_right_wire * scale_q15; 
    
   




   // [VERANDERD 2] Shift de 48-bit vermenigvuldiging weer terug naar 32-bits formaat
    wire signed [31:0] right_shifted = tx_in_right_balanced[45:14];

    // [VERANDERD 3] VEILIG OPTELLEN (Hier tellen we de offsets er wél weer bij op!)
    wire signed [32:0] sum_left  = $signed(tx_in_left) + off_a_ext;
    wire signed [32:0] sum_right = $signed(right_shifted) + off_b_ext;
    
  




  // DIGITALE STOOTBUMPER (Clipping)
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
            offset_a     <= 10'b0;
            offset_b     <= 10'b0;
            phase_adj    <= 10'b0;    
            balance      <= 10'b0;
            shift        <= 13'b0;
            bitcnt       <= 4'd0;
            test_signal  <= 1'b0;
            
            // [VERANDERD 4] Reset de nieuwe dubbele sync-registers
            le_sync      <= 2'b00;
            clk_sync     <= 2'b00;
            data_sync    <= 2'b00;
        end else begin
            
            // 1. I2S Bit Output & LRCLK
            i2s_out_data <= tx_buf[cnt];
            
            if (cnt > 0) cnt <= cnt - 6'd1;

            if (cnt == 0)  i2s_tx_lrclk <= 1'b0;  // Links Rechts klok laag
            if (cnt == 32) i2s_tx_lrclk <= 1'b1;

            // 2. Data laden op Strobe
            if (tx_strobe) begin
                // [VERANDERD 5] We laden nu weer de 'processed' wiskunde in, niet de ruwe onbewerkte data!
                tx_buf <= { processed_left, processed_right };
                cnt    <= 6'd63;
            end
            
//----------------------------- Arduino ------------------------------------------------------
            // [VERANDERD 6] SPI / Arduino Logic: Veilig inlezen voor hoge kloksnelheden
            le_sync   <= {le_sync[0], spi_le};
            clk_sync  <= {clk_sync[0], spi_clk};
            data_sync <= {data_sync[0], spi_data};
                                          
            // Start van transactie        
            if (!le_sync[1] && le_sync[0]) begin        
                bitcnt <= 4'd0;               
                shift  <= 13'b0;              
            end 
            // Data