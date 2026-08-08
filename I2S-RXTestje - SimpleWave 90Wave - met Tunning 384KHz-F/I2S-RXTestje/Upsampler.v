`timescale 1ns / 1ps

module Upsampler(
	input  wire        clk_49152,    // Je nieuwe snelle master klok
    input  wire        reset,
    input  wire [31:0] sample_in,    // 192 kHz sample van I2SRX
    input  wire        strobe_192,   // Puls van I2SRX (1 clk breed op 12MHz)
    
    output reg  [31:0] sample_out,   // 384 kHz output (Echte sample -> 0 -> Echte sample)
    output reg         strobe_384    // Puls voor de Phase Accumulator
    );


reg [7:0] clk_cnt;
reg [31:0] latched_sample;
    
    // Synchroniseer de 192kHz strobe naar het snelle domein
    reg [2:0] strobe_sync;
    always @(posedge clk_49152) strobe_sync <= {strobe_sync[1:0], strobe_192};
    wire load_pulse = strobe_sync[1] & ~strobe_sync[2];

    always @(posedge clk_49152) begin
        if (reset) begin
            clk_cnt <= 8'd0;
            sample_out <= 32'd0;
            strobe_384 <= 1'b0;
        end else begin
            strobe_384 <= 1'b0;

            if (load_pulse) begin
                clk_cnt <= 8'd1;
                latched_sample <= sample_in;
                // Moment 1: De echte sample direct doorgeven
                sample_out <= sample_in;
                strobe_384 <= 1'b1;
            end else if (clk_cnt != 8'd0) begin
                clk_cnt <= clk_cnt + 8'd1;
                
                // Moment 2: Precies in het midden (na 128 tikken) de nul sturen
                if (clk_cnt == 8'd128) begin
                    sample_out <= 32'd0;
                    strobe_384 <= 1'b1;
                end
            end
        end
    end


endmodule
