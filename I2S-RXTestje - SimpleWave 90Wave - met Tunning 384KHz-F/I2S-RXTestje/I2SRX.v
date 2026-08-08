`timescale 1ns / 1ps

module I2SRX (

    input  wire        i2s_in_bclk,
    input  wire        reset,
    input  wire        i2s_in_lrclk,
    input  wire        i2s_in_data,
	
	output reg         i2s_rx_strobe,
    output reg [31:0]  rx_sample
    );
	
reg [63:0] shift;      // 64-bit shiftregister
reg [1:0]   lrclk_pipe;    // 2-cycle delayline voor LRCLK	

always @(posedge i2s_in_bclk) begin     // L en R 64 PULSEN
//        ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ 
//        ┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └ 64
    if (reset) begin
        shift   <= 64'd0;
        lrclk_pipe <= 2'b00;
        i2s_rx_strobe <= 1'b0;
		rx_sample     <= 32'd0;
    end else begin
        i2s_rx_strobe <= 1'b0;  
		
        shift <= {shift[62:0], i2s_in_data};            // schuif nieuwe bit in, shift i2s_in_data de data komt eerder       
        lrclk_pipe <= {lrclk_pipe[0], i2s_in_lrclk};    // i2s_in_lrclk delay line (2 clocks)
		
		// detecteer falling edge van LRCLK (2'b10)
		if (lrclk_pipe == 2'b10) begin                      // strobe en data out komt later ( door de pipe )    
			i2s_rx_strobe <= 1'b1;
			rx_sample <= shift[63:32];				// Left
			//rx_sample <= shift[31:0];     // Right
		end
    end
end

endmodule

