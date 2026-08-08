`timescale 1ns / 1ps

module PHASEACCUMULATOR (
    sample_in,
    reset,
    clk_49152,
    strobe_in,
    test_signal,
    strobe_out,
    phase_out
);

    // ============================================================
    // INSTELLINGEN (Nu als localparam, veilig vastgezet in deze module)
    // ============================================================
	
	localparam PHASE_WIDTH = 16; // 
	
    //localparam PHASE_WIDTH = 14; // 14 = 16384 punten tabel  //
                                 // 12 = 4096 punten tabel
                                 // 11 = 2048 punten tabel  //
								 // 8 = 256 punten
								 // 6 = 64  punten
								 // 5 = 32
								 // 4 = 16
                                
    localparam signed [17:0] K_FM = 18'sd65535;  
	// ============================================================
	
	

    // ============================================================
    // Ingangen & Uitgangen (In de klassieke stijl, los eronder)
    // ============================================================
    input  signed [15:0]     sample_in;   // modulatie amplitude
    input                    reset;
    input                    clk_49152;   // ALTIJD de snelle klok!
    input                    strobe_in;
    input                    test_signal; // Arduino

    output reg               strobe_out;
    output reg [PHASE_WIDTH-1:0] phase_out; // Slaat automatisch op de juiste breedte

    // ============================================================
    // Registers
    // ============================================================
    reg signed [31:0] fm_prod;
    reg signed [31:0] phase_acc;
    reg signed [15:0] sample;

    // ============================================================
    // Phase accumulator logica
    // ============================================================
    always @(posedge clk_49152) begin
        if (reset) begin
            fm_prod    <= 32'sd0;
            phase_acc  <= 32'sd0;
            strobe_out <= 1'b0;
            sample     <= 16'sd0;
            phase_out  <= 0; // Reset naar 0, ongeacht de breedte
        end else begin
            strobe_out <= 1'b0;
            
            if (strobe_in) begin
                strobe_out <= 1'b1;

                // Kies bron (Test of I2S Audio)
                if (test_signal == 1'b1) begin
                    //sample <= 16'sd10000;
					//sample <= 16'sd4096;
					sample <= 16'sd2000;
                end else begin
                    sample <= sample_in;
                end    

                // FM vermenigvuldiging
                fm_prod <= $signed(sample * K_FM);

                // Accumulator update
                phase_acc <= phase_acc + fm_prod;

                // De Magische Formule: Pak automatisch de juiste bovenste bits!
                phase_out <= phase_acc[31 : 32 - PHASE_WIDTH]; 
            end
        end
    end
endmodule

/*
`timescale 1ns / 1ps


module PHASEACCUMULATOR (
    sample_in,
    reset,
    clk_49152,
    strobe_in,
    test_signal,
    strobe_out,
    phase_out
);

    // ============================================================
    // INSTELLINGEN (Pas deze aan in je TopView!)
    // ============================================================
    parameter PHASE_WIDTH = 11; // 14 = 16384 punten tabel
                                // 12 = 4096 punten tabel
                                // 11 = 2048 punten tabel
								
								

    // ============================================================
    // Ingangen & Uitgangen (Nu met de correcte parameter!)
    // ============================================================
    input  signed [15:0]     sample_in;   // modulatie amplitude
    input                    reset;
    input                    clk_49152;   // ALTIJD de snelle klok!
    input                    strobe_in;
    input                    test_signal; // Arduino

    output reg               strobe_out;
    output reg [PHASE_WIDTH-1:0] phase_out; // Slaat automatisch op de juiste breedte

    // ============================================================
    // Gevoeligheid van de accumulator (FM factor)
    // ============================================================
    localparam signed [17:0] K_FM = 18'sd65535;  

    // ============================================================
    // Registers
    // ============================================================
    reg signed [31:0] fm_prod;
    reg signed [31:0] phase_acc;
    reg signed [15:0] sample;

    // ============================================================
    // Phase accumulator
    // ============================================================
    always @(posedge clk_49152) begin
        if (reset) begin
            fm_prod     <= 32'sd0;
            phase_acc   <= 32'sd0;
            strobe_out  <= 1'b0;
            sample      <= 16'sd0;
            phase_out   <= 0; // Reset naar 0, ongeacht de breedte
        end else begin
            strobe_out <= 1'b0;
            
            if (strobe_in) begin
                strobe_out <= 1'b1;

                // Kies bron (Test of I2S Audio)
                if (test_signal == 1'b1) begin
                    sample <= 16'sd10000;
                end else begin
                    sample <= sample_in;
                end    

                // FM vermenigvuldiging
                fm_prod <= $signed(sample * K_FM);

                // Accumulator update
                phase_acc <= phase_acc + fm_prod;

                // De Magische Formule: Pak automatisch de juiste bovenste bits!
                phase_out <= phase_acc[31 : 32 - PHASE_WIDTH]; 
            end
        end
    end
endmodule
*/