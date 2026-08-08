/*
`timescale 1ns / 1ps

module FIR_IQ(
    input  wire        clk_49152,  
    input  wire        reset,
    input  wire [31:0] sample_in,  
    input  wire        strobe_in,  
    
    output reg  [31:0] sample_out, 
    output reg         strobe_out  
);

    // ============================================================
    // AAN/UIT SCHAKELAAR VOOR DIT FILTER
	//
	//
    // ============================================================
    localparam BYPASS = 1'b0; 
    
    //=============================================================
    // Aangepaste delay line naar 114 taps	
	//# Jouw FPGA Filter Specificaties
	//fs = 384000       # Sample rate (384 kHz)
	//cutoff = 100000    # Cutoff frequentie (100 kHz)
	//numtaps = 114     # Aantal taps 64 , 96 , 114		
    //=============================================================
    reg signed [15:0] x [0:113];

    // ROM met coëfficiënten (Aangepast naar 114)
    reg signed [15:0] H_val;
    reg [6:0] tap_index; // 7 bits is genoeg voor 0-113

    always @(*) begin
        case(tap_index)
            8'd0  : H_val = -14;
            8'd1  : H_val = 4;
            8'd2  : H_val = 15;
            8'd3  : H_val = -7;
            8'd4  : H_val = -16;
            8'd5  : H_val = 10;
            8'd6  : H_val = 18;
            8'd7  : H_val = -15;
            8'd8  : H_val = -20;
            8'd9  : H_val = 22;
            8'd10 : H_val = 21;
            8'd11 : H_val = -30;
            8'd12 : H_val = -22;
            8'd13 : H_val = 41;
            8'd14 : H_val = 22;
            8'd15 : H_val = -54;
            8'd16 : H_val = -19;
            8'd17 : H_val = 70;
            8'd18 : H_val = 13;
            8'd19 : H_val = -87;
            8'd20 : H_val = -3;
            8'd21 : H_val = 106;
            8'd22 : H_val = -11;
            8'd23 : H_val = -125;
            8'd24 : H_val = 32;
            8'd25 : H_val = 145;
            8'd26 : H_val = -58;
            8'd27 : H_val = -164;
            8'd28 : H_val = 92;
            8'd29 : H_val = 180;
            8'd30 : H_val = -134;
            8'd31 : H_val = -193;
            8'd32 : H_val = 185;
            8'd33 : H_val = 200;
            8'd34 : H_val = -245;
            8'd35 : H_val = -200;
            8'd36 : H_val = 316;
            8'd37 : H_val = 190;
            8'd38 : H_val = -399;
            8'd39 : H_val = -168;
            8'd40 : H_val = 496;
            8'd41 : H_val = 128;
            8'd42 : H_val = -609;
            8'd43 : H_val = -66;
            8'd44 : H_val = 745;
            8'd45 : H_val = -27;
            8'd46 : H_val = -914;
            8'd47 : H_val = 168;
            8'd48 : H_val = 1135;
            8'd49 : H_val = -388;
            8'd50 : H_val = -1458;
            8'd51 : H_val = 766;
            8'd52 : H_val = 2016;
            8'd53 : H_val = -1561;
            8'd54 : H_val = -3377;
            8'd55 : H_val = 4406;
            8'd56 : H_val = 15227;
            8'd57 : H_val = 15227;
            8'd58 : H_val = 4406;
            8'd59 : H_val = -3377;
            8'd60 : H_val = -1561;
            8'd61 : H_val = 2016;
            8'd62 : H_val = 766;
            8'd63 : H_val = -1458;
            8'd64 : H_val = -388;
            8'd65 : H_val = 1135;
            8'd66 : H_val = 168;
            8'd67 : H_val = -914;
            8'd68 : H_val = -27;
            8'd69 : H_val = 745;
            8'd70 : H_val = -66;
            8'd71 : H_val = -609;
            8'd72 : H_val = 128;
            8'd73 : H_val = 496;
            8'd74 : H_val = -168;
            8'd75 : H_val = -399;
            8'd76 : H_val = 190;
            8'd77 : H_val = 316;
            8'd78 : H_val = -200;
            8'd79 : H_val = -245;
            8'd80 : H_val = 200;
            8'd81 : H_val = 185;
            8'd82 : H_val = -193;
            8'd83 : H_val = -134;
            8'd84 : H_val = 180;
            8'd85 : H_val = 92;
            8'd86 : H_val = -164;
            8'd87 : H_val = -58;
            8'd88 : H_val = 145;
            8'd89 : H_val = 32;
            8'd90 : H_val = -125;
            8'd91 : H_val = -11;
            8'd92 : H_val = 106;
            8'd93 : H_val = -3;
            8'd94 : H_val = -87;
            8'd95 : H_val = 13;
            8'd96 : H_val = 70;
            8'd97 : H_val = -19;
            8'd98 : H_val = -54;
            8'd99 : H_val = 22;
            8'd100: H_val = 41;
            8'd101: H_val = -22;
            8'd102: H_val = -30;
            8'd103: H_val = 21;
            8'd104: H_val = 22;
            8'd105: H_val = -20;
            8'd106: H_val = -15;
            8'd107: H_val = 18;
            8'd108: H_val = 10;
            8'd109: H_val = -16;
            8'd110: H_val = -7;
            8'd111: H_val = 15;
            8'd112: H_val = 4;
            8'd113: H_val = -14;
            default: H_val = 0;
        endcase
    end

    // Rekenmachine en clipping
    reg signed [35:0] acc;
    integer k;

    wire signed [35:0] acc_shifted = acc >>> 15; 
    wire [15:0] clipped_out = (acc_shifted > 36'sd32767)  ? 16'h7FFF : 
                              (acc_shifted < -36'sd32768) ? 16'h8000 : 
                              acc_shifted[15:0];

    // State Machine
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;
    reg state;

    always @(posedge clk_49152) begin
        if (reset) begin
            for (k = 0; k < 114; k = k + 1) x[k] <= 16'sd0;
            tap_index  <= 7'd0;
            acc        <= 36'sd0;
            state      <= STATE_IDLE;
            sample_out <= 32'd0;
            strobe_out <= 1'b0;
        end else begin
            strobe_out <= 1'b0; 

            if (BYPASS) begin
			    // FILTER UIT: Geef het signaal onbewerkt door als er een strobe binnenkomt
                if (strobe_in) begin
                    sample_out <= sample_in;
                    strobe_out <= 1'b1;
                end
                state <= STATE_IDLE; 
            end else begin
			    // FILTER AAN: ORIGINELE LOGICA 
                case (state)
                    STATE_IDLE: begin
                        if (strobe_in) begin
                            // Shiften van de delay line (114 taps)
                            for (k = 113; k > 0; k = k - 1) x[k] <= x[k-1];
                            x[0] <= $signed(sample_in[31:16]);
                            
                            tap_index <= 7'd0;
                            acc       <= 36'sd0;
                            state     <= STATE_RUN;
                        end
                    end

                    STATE_RUN: begin
                        acc <= acc + ($signed(x[tap_index]) * H_val);
                        
                        // Check of we bij de laatste tap (113) zijn
                        if (tap_index == 7'd113) begin
                            sample_out <= { clipped_out, 16'd0 };
                            strobe_out <= 1'b1;  
                            state      <= STATE_IDLE; 
                        end else begin
                            tap_index <= tap_index + 7'd1;
                        end
                    end
                endcase
            end
        end
    end
endmodule
*/



`timescale 1ns / 1ps

module FIR_IQ(
    input  wire        clk_49152,  
    input  wire        reset,
    input  wire [31:0] sample_in,  
    input  wire        strobe_in,  
    
    output reg  [31:0] sample_out, 
    output reg         strobe_out  
);

    // ============================================================
    // AAN/UIT SCHAKELAAR VOOR DIT FILTER
    // 0 = Filter AAN (normale werking)
    // 1 = Filter UIT (Bypass, signaal gaat er onbewerkt doorheen)
    // ============================================================
    localparam BYPASS = 1'b0; 
	//=============================================================
    // Jouw vertrouwde 96-tap delay line
    reg signed [15:0] x [0:95];

    // ROM met jouw coëfficiënten
    reg signed [15:0] H_val;
    reg [6:0] tap_index;

    always @(*) begin
        case(tap_index)
// --- FIR Coefficienten (60 kHz Cutoff, 384 kHz Fs) ---
            8'd0  : H_val = 13;
            8'd1  : H_val = 12;
            8'd2  : H_val = -16;
            8'd3  : H_val = -11;
            8'd4  : H_val = 20;
            8'd5  : H_val = 11;
            8'd6  : H_val = -27;
            8'd7  : H_val = -10;
            8'd8  : H_val = 37;
            8'd9  : H_val = 7;
            8'd10 : H_val = -49;
            8'd11 : H_val = -2;
            8'd12 : H_val = 64;
            8'd13 : H_val = -7;
            8'd14 : H_val = -81;
            8'd15 : H_val = 21;
            8'd16 : H_val = 100;
            8'd17 : H_val = -41;
            8'd18 : H_val = -119;
            8'd19 : H_val = 69;
            8'd20 : H_val = 137;
            8'd21 : H_val = -105;
            8'd22 : H_val = -154;
            8'd23 : H_val = 150;
            8'd24 : H_val = 166;
            8'd25 : H_val = -207;
            8'd26 : H_val = -172;
            8'd27 : H_val = 276;
            8'd28 : H_val = 168;
            8'd29 : H_val = -357;
            8'd30 : H_val = -152;
            8'd31 : H_val = 455;
            8'd32 : H_val = 119;
            8'd33 : H_val = -570;
            8'd34 : H_val = -63;
            8'd35 : H_val = 710;
            8'd36 : H_val = -26;
            8'd37 : H_val = -883;
            8'd38 : H_val = 163;
            8'd39 : H_val = 1110;
            8'd40 : H_val = -381;
            8'd41 : H_val = -1438;
            8'd42 : H_val = 759;
            8'd43 : H_val = 2001;
            8'd44 : H_val = -1553;
            8'd45 : H_val = -3368;
            8'd46 : H_val = 4398;
            8'd47 : H_val = 15210;
            8'd48 : H_val = 15210;
            8'd49 : H_val = 4398;
            8'd50 : H_val = -3368;
            8'd51 : H_val = -1553;
            8'd52 : H_val = 2001;
            8'd53 : H_val = 759;
            8'd54 : H_val = -1438;
            8'd55 : H_val = -381;
            8'd56 : H_val = 1110;
            8'd57 : H_val = 163;
            8'd58 : H_val = -883;
            8'd59 : H_val = -26;
            8'd60 : H_val = 710;
            8'd61 : H_val = -63;
            8'd62 : H_val = -570;
            8'd63 : H_val = 119;
            8'd64 : H_val = 455;
            8'd65 : H_val = -152;
            8'd66 : H_val = -357;
            8'd67 : H_val = 168;
            8'd68 : H_val = 276;
            8'd69 : H_val = -172;
            8'd70 : H_val = -207;
            8'd71 : H_val = 166;
            8'd72 : H_val = 150;
            8'd73 : H_val = -154;
            8'd74 : H_val = -105;
            8'd75 : H_val = 137;
            8'd76 : H_val = 69;
            8'd77 : H_val = -119;
            8'd78 : H_val = -41;
            8'd79 : H_val = 100;
            8'd80 : H_val = 21;
            8'd81 : H_val = -81;
            8'd82 : H_val = -7;
            8'd83 : H_val = 64;
            8'd84 : H_val = -2;
            8'd85 : H_val = -49;
            8'd86 : H_val = 7;
            8'd87 : H_val = 37;
            8'd88 : H_val = -10;
            8'd89 : H_val = -27;
            8'd90 : H_val = 11;
            8'd91 : H_val = 20;
            8'd92 : H_val = -11;
            8'd93 : H_val = -16;
            8'd94 : H_val = 12;
            8'd95 : H_val = 13;
            default: H_val = 0;
        endcase
    end

    // Jouw exacte Rekenmachine en clipping
    reg signed [35:0] acc;
    integer k;

    wire signed [35:0] acc_shifted = acc >>> 15; 
    wire [15:0] clipped_out = (acc_shifted > 36'sd32767)  ? 16'h7FFF : 
                              (acc_shifted < -36'sd32768) ? 16'h8000 : 
                              acc_shifted[15:0];

    // Jouw Simpele State Machine
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;
    reg state;

    always @(posedge clk_49152) begin
        if (reset) begin
            for (k = 0; k < 96; k = k + 1) x[k] <= 16'sd0;
            tap_index  <= 7'd0;
            acc        <= 36'sd0;
            state      <= STATE_IDLE;
            sample_out <= 32'd0;
            strobe_out <= 1'b0;
        end else begin
            strobe_out <= 1'b0; 

            // --- De logica kijkt nu naar de localparam BYPASS ---
            if (BYPASS) begin
                // FILTER UIT: Geef het signaal onbewerkt door als er een strobe binnenkomt
                if (strobe_in) begin
                    sample_out <= sample_in;
                    strobe_out <= 1'b1;
                end
                state <= STATE_IDLE; 
            end else begin
                // FILTER AAN: ORIGINELE LOGICA 
                case (state)
                    STATE_IDLE: begin
                        if (strobe_in) begin
                            for (k = 95; k > 0; k = k - 1) x[k] <= x[k-1];
                            x[0] <= $signed(sample_in[31:16]);
                            
                            tap_index <= 7'd0;
                            acc       <= 36'sd0;
                            state     <= STATE_RUN;
                        end
                    end

                    STATE_RUN: begin
                        acc <= acc + ($signed(x[tap_index]) * H_val);
                        
                        if (tap_index == 7'd95) begin
                            sample_out <= { clipped_out, 16'd0 };
                            strobe_out <= 1'b1;  
                            state      <= STATE_IDLE; 
                        end else begin
                            tap_index <= tap_index + 7'd1;
                        end
                    end
                endcase
            end
        end
    end
endmodule



/*

`timescale 1ns / 1ps

module FIR_IQ(
    input  wire        clk_49152,  
    input  wire        reset,
    input  wire [31:0] sample_in,  
    input  wire        strobe_in,  
    
    output reg  [31:0] sample_out, 
    output reg         strobe_out  
);

    // Jouw vertrouwde 96-tap delay line
    reg signed [15:0] x [0:95];

    // ROM met jouw coëfficiënten
    reg signed [15:0] H_val;
    reg [6:0] tap_index;

    always @(*) begin
        case(tap_index)
// --- FIR Coefficienten (60 kHz Cutoff, 384 kHz Fs) ---
            8'd0  : H_val = 13;
            8'd1  : H_val = 12;
            8'd2  : H_val = -16;
            8'd3  : H_val = -11;
            8'd4  : H_val = 20;
            8'd5  : H_val = 11;
            8'd6  : H_val = -27;
            8'd7  : H_val = -10;
            8'd8  : H_val = 37;
            8'd9  : H_val = 7;
            8'd10 : H_val = -49;
            8'd11 : H_val = -2;
            8'd12 : H_val = 64;
            8'd13 : H_val = -7;
            8'd14 : H_val = -81;
            8'd15 : H_val = 21;
            8'd16 : H_val = 100;
            8'd17 : H_val = -41;
            8'd18 : H_val = -119;
            8'd19 : H_val = 69;
            8'd20 : H_val = 137;
            8'd21 : H_val = -105;
            8'd22 : H_val = -154;
            8'd23 : H_val = 150;
            8'd24 : H_val = 166;
            8'd25 : H_val = -207;
            8'd26 : H_val = -172;
            8'd27 : H_val = 276;
            8'd28 : H_val = 168;
            8'd29 : H_val = -357;
            8'd30 : H_val = -152;
            8'd31 : H_val = 455;
            8'd32 : H_val = 119;
            8'd33 : H_val = -570;
            8'd34 : H_val = -63;
            8'd35 : H_val = 710;
            8'd36 : H_val = -26;
            8'd37 : H_val = -883;
            8'd38 : H_val = 163;
            8'd39 : H_val = 1110;
            8'd40 : H_val = -381;
            8'd41 : H_val = -1438;
            8'd42 : H_val = 759;
            8'd43 : H_val = 2001;
            8'd44 : H_val = -1553;
            8'd45 : H_val = -3368;
            8'd46 : H_val = 4398;
            8'd47 : H_val = 15210;
            8'd48 : H_val = 15210;
            8'd49 : H_val = 4398;
            8'd50 : H_val = -3368;
            8'd51 : H_val = -1553;
            8'd52 : H_val = 2001;
            8'd53 : H_val = 759;
            8'd54 : H_val = -1438;
            8'd55 : H_val = -381;
            8'd56 : H_val = 1110;
            8'd57 : H_val = 163;
            8'd58 : H_val = -883;
            8'd59 : H_val = -26;
            8'd60 : H_val = 710;
            8'd61 : H_val = -63;
            8'd62 : H_val = -570;
            8'd63 : H_val = 119;
            8'd64 : H_val = 455;
            8'd65 : H_val = -152;
            8'd66 : H_val = -357;
            8'd67 : H_val = 168;
            8'd68 : H_val = 276;
            8'd69 : H_val = -172;
            8'd70 : H_val = -207;
            8'd71 : H_val = 166;
            8'd72 : H_val = 150;
            8'd73 : H_val = -154;
            8'd74 : H_val = -105;
            8'd75 : H_val = 137;
            8'd76 : H_val = 69;
            8'd77 : H_val = -119;
            8'd78 : H_val = -41;
            8'd79 : H_val = 100;
            8'd80 : H_val = 21;
            8'd81 : H_val = -81;
            8'd82 : H_val = -7;
            8'd83 : H_val = 64;
            8'd84 : H_val = -2;
            8'd85 : H_val = -49;
            8'd86 : H_val = 7;
            8'd87 : H_val = 37;
            8'd88 : H_val = -10;
            8'd89 : H_val = -27;
            8'd90 : H_val = 11;
            8'd91 : H_val = 20;
            8'd92 : H_val = -11;
            8'd93 : H_val = -16;
            8'd94 : H_val = 12;
            8'd95 : H_val = 13;
            default: H_val = 0;
        endcase
    end

    // Jouw exacte Rekenmachine en clipping
    reg signed [35:0] acc;
    integer k;

    wire signed [35:0] acc_shifted = acc >>> 15; 
    wire [15:0] clipped_out = (acc_shifted > 36'sd32767)  ? 16'h7FFF : 
                              (acc_shifted < -36'sd32768) ? 16'h8000 : 
                              acc_shifted[15:0];

    // Jouw Simpele State Machine
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;
    reg state;

    always @(posedge clk_49152) begin
        if (reset) begin
            for (k = 0; k < 96; k = k + 1) x[k] <= 16'sd0;
            tap_index  <= 7'd0;
            acc        <= 36'sd0;
            state      <= STATE_IDLE;
            sample_out <= 32'd0;
            strobe_out <= 1'b0;
        end else begin
            strobe_out <= 1'b0; 

            case (state)
                STATE_IDLE: begin
                    if (strobe_in) begin
                        for (k = 95; k > 0; k = k - 1) x[k] <= x[k-1];
                        x[0] <= $signed(sample_in[31:16]);
                        
                        tap_index <= 6'd0;
                        acc       <= 36'sd0;
                        state     <= STATE_RUN;
                    end
                end

                STATE_RUN: begin
                    acc <= acc + ($signed(x[tap_index]) * H_val);
                    
                    if (tap_index == 7'd95) begin
                        sample_out <= { clipped_out, 16'd0 };
                        strobe_out <= 1'b1;  
                        state      <= STATE_IDLE; 
                    end else begin
                        tap_index <= tap_index + 7'd1;
                    end
                end
            endcase
        end
    end
endmodule

*/