
`timescale 1ns / 1ps

module Emergency_clocks(
        input  wire clk_12mhz, // Ingang: De 12.288 MHz klok (van je IP core)
        input  wire reset,     // Ingang: De algemene reset
        output reg  clk_192k   // Uitgang: De stabiele en jitter-vrije 192 kHz klok
    );

    reg [4:0] counter = 0;
    reg clk_192k_intern = 0;   // NIEUW: De onzichtbare interne klok

    // STAP 1: Al het rekenwerk en tellen doen we op de superstrakke opgaande flank
    always @(posedge clk_12mhz) begin
        if (reset) begin
            counter         <= 5'd0;
            clk_192k_intern <= 1'b0;
        end else begin
            if (counter == 5'd31) begin
                counter         <= 5'd0;              
                clk_192k_intern <= ~clk_192k_intern;   
            end else begin
                counter         <= counter + 5'd1;    
            end
        end
    end

    // STAP 2: Het doorgeefluikje! We schuiven het signaal exact een halve kloktik op.
    // Omdat hier niet geteld hoeft te worden, kost dit de FPGA geen moeite en ontstaat er nul jitter.
    always @(negedge clk_12mhz) begin
        clk_192k <= clk_192k_intern;
    end

endmodule


// // `timescale 1ns / 1ps

// // module Emergency_clocks(
		// // input  wire clk_12mhz, // Ingang: De 12.288 MHz klok (van je IP core)
		// // input  wire reset,     // Ingang: De algemene reset
		// // output reg  clk_192k   // Uitgang: De gegenereerde 192 kHz klok
	// // );

    // // reg [4:0] counter = 0;

    // // // Let op: we gebruiken nog steeds perfect de negedge!
    // // always @(negedge clk_12mhz) begin
        // // if (reset) begin
            // // counter  <= 5'd0;
            // // clk_192k <= 1'b0;
        // // end else begin
            // // if (counter == 5'd31) begin
                // // counter  <= 5'd0;             
                // // clk_192k <= ~clk_192k;   
            // // end else begin
                // // counter  <= counter + 5'd1;   
            // // end
        // // end
    // // end

// // endmodule
