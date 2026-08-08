
`timescale 1ns / 1ps

module FIR_Filter (
    input  wire        clk_49152,  
    input  wire        reset,
    input  wire        bypass,     // <--- NIEUW: 1 = Filter UIT, 0 = Filter AAN
    
    input  wire [31:0] sample_in,  
    input  wire        strobe_in,  
    
    output reg  [31:0] sample_out, 
    output reg         strobe_out  
);

    // ============================================================
    // 63-tap Interpolation FIR met BYPASS functie
    // ============================================================

    // Delay line: 0 t/m 62 = 63 plekjes
    reg signed [15:0] x [0:62];

    // ROM met coëfficiënten
    reg signed [15:0] H_val;
    reg [5:0] tap_index;

    always @(*) begin
        case(tap_index)
            8'd0  : H_val = 7;
            8'd1  : H_val = 29;
            8'd2  : H_val = 8;
            8'd3  : H_val = -33;
            8'd4  : H_val = -32;
            8'd5  : H_val = 28;
            8'd6  : H_val = 65;
            8'd7  : H_val = 0;
            8'd8  : H_val = -98;
            8'd9  : H_val = -61;
            8'd10 : H_val = 104;
            8'd11 : H_val = 152;
            8'd12 : H_val = -54;
            8'd13 : H_val = -246;
            8'd14 : H_val = -75;
            8'd15 : H_val = 291;
            8'd16 : H_val = 277;
            8'd17 : H_val = -227;
            8'd18 : H_val = -507;
            8'd19 : H_val = 0;
            8'd20 : H_val = 679;
            8'd21 : H_val = 408;
            8'd22 : H_val = -672;
            8'd23 : H_val = -966;
            8'd24 : H_val = 342;
            8'd25 : H_val = 1593;
            8'd26 : H_val = 508;
            8'd27 : H_val = -2171;
            8'd28 : H_val = -2404;
            8'd29 : H_val = 2580;
            8'd30 : H_val = 10039;
            8'd31 : H_val = 13637;
            8'd32 : H_val = 10039;
            8'd33 : H_val = 2580;
            8'd34 : H_val = -2404;
            8'd35 : H_val = -2171;
            8'd36 : H_val = 508;
            8'd37 : H_val = 1593;
            8'd38 : H_val = 342;
            8'd39 : H_val = -966;
            8'd40 : H_val = -672;
            8'd41 : H_val = 408;
            8'd42 : H_val = 679;
            8'd43 : H_val = 0;
            8'd44 : H_val = -507;
            8'd45 : H_val = -227;
            8'd46 : H_val = 277;
            8'd47 : H_val = 291;
            8'd48 : H_val = -75;
            8'd49 : H_val = -246;
            8'd50 : H_val = -54;
            8'd51 : H_val = 152;
            8'd52 : H_val = 104;
            8'd53 : H_val = -61;
            8'd54 : H_val = -98;
            8'd55 : H_val = 0;
            8'd56 : H_val = 65;
            8'd57 : H_val = 28;
            8'd58 : H_val = -32;
            8'd59 : H_val = -33;
            8'd60 : H_val = 8;
            8'd61 : H_val = 29;
            8'd62 : H_val = 7;
            default: H_val = 0;
        endcase
    end

    // Rekenmachine
    reg signed [35:0] acc;
    integer k;

    // Volume-compensatie voor zero-stuffing als het filter AAN staat
    wire signed [35:0] acc_shifted = acc >>> 14; 
    wire [15:0] clipped_out = (acc_shifted > 36'sd32767)  ? 16'h7FFF : 
                              (acc_shifted < -36'sd32768) ? 16'h8000 : 
                              acc_shifted[15:0];

    // Volume-compensatie voor als het filter UIT staat (x2 versterking)
    wire signed [15:0] bypassed_audio = $signed(sample_in[31:16]) <<< 1; 

    // Simpele State Machine
    localparam STATE_IDLE = 1'b0;
    localparam STATE_RUN  = 1'b1;
    reg state;

    always @(posedge clk_49152) begin
        if (reset) begin
            for (k = 0; k < 63; k = k + 1) x[k] <= 16'sd0;
            tap_index  <= 6'd0;
            acc        <= 36'sd0;
            state      <= STATE_IDLE;
            sample_out <= 32'd0;
            strobe_out <= 1'b0;
        end else begin
            strobe_out <= 1'b0; // Strobe is altijd maar 1 tikje hoog

            case (state)
                STATE_IDLE: begin
                    if (strobe_in) begin
                        
                        // --- DE BYPASS SCHAKELAAR ---
                        if (bypass) begin
                            // FILTER IS UIT: Geef het signaal (versterkt) direct door
                            sample_out <= { bypassed_audio, 16'd0 };
                            strobe_out <= 1'b1; // Vuur direct door naar Phase Acc
                        
                        end else begin
                            // FILTER IS AAN: Inladen en rekenen
                            // 1. Opschuiven
                            for (k = 62; k > 0; k = k - 1) x[k] <= x[k-1];
                            // 2. Nieuwe inladen
                            x[0] <= $signed(sample_in[31:16]);
                            
                            // 3. Start rekenen
                            tap_index <= 6'd0;
                            acc       <= 36'sd0;
                            state     <= STATE_RUN;
                        end
                        
                    end
                end

                STATE_RUN: begin
                    // Tel op
                    acc <= acc + ($signed(x[tap_index]) * H_val);
                    
                    if (tap_index == 6'd62) begin
                        // Laatste berekening is klaar!
                        sample_out <= { clipped_out, 16'd0 };
                        strobe_out <= 1'b1;  // Vuur de Phase Accumulator aan
                        state      <= STATE_IDLE; // Ga lekker slapen tot de volgende sample
                    end else begin
                        tap_index <= tap_index + 6'd1;
                    end
                end
            endcase
        end
    end
endmodule
