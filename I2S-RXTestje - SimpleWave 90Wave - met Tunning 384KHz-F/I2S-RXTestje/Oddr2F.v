`timescale 1ns / 1ps

module Oddr2F(
		input wire in,
		output wire uit
    );
	
	// ------------------------------------------------------------	
	// Voor de debugpin
	// ------------------------------------------------------------
	ODDR2 #(
		.DDR_ALIGNMENT("NONE"),
		.INIT(1'b0),
		.SRTYPE("SYNC")
	) oddr2_bck (
		.Q  (uit),
		.C0 (in),
		.C1 (~in),    // bijvoorbeeld (~i2s_rx_right[18]),
		.CE (1'b1),
		.D0 (1'b1),
		.D1 (1'b0),
		.R  (1'b0),
		.S  (1'b0)
    );


endmodule
