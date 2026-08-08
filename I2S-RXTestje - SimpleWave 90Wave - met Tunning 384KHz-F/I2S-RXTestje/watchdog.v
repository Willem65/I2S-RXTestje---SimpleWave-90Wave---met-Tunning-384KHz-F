`timescale 1ns / 1ps

module watchdog(
	// ------------------------------------------------------------
    // LED Clock Detection (BCLK Watchdog)
    // ------------------------------------------------------------	
	// BCLK Watchdog logica
		input  wire clk_50mhz,     // De stabiele 50MHz referentieklok
		input  wire signal_to_mon, // De klok die we in de gaten houden (BCLK)
		output wire led1,
		// output wire led2,
		// output wire led3,
		// output wire led4,
		output wire status_lost    // Optioneel: hoog als klok weg is (voor interne logica)
	);

    // Registers voor de watchdog
    reg [21:0] watchdog_cnt = 0;
    reg [24:0] blink_cnt = 0;
    reg sync_r1, sync_r2;
    reg is_lost;

    always @(posedge clk_50mhz) begin
        // Synchroniseer het te monitoren signaal naar het 50MHz domein
        sync_r1 <= signal_to_mon;
        sync_r2 <= sync_r1;

        // Detecteer een flank (edge) op het signaal
        if (sync_r1 != sync_r2) begin
            watchdog_cnt <= 22'd0;
            is_lost      <= 1'b0;
        end else begin
            // Geen activiteit: tel op tot ~10ms timeout
            if (watchdog_cnt < 22'd500_000) begin
                watchdog_cnt <= watchdog_cnt + 22'd1;
            end else begin
                is_lost <= 1'b1;
            end
        end
        
        // Teller voor het knipperen
        blink_cnt <= blink_cnt + 25'd1;
    end

    // LED aansturing
    // Als klok OK: LED2 aan, rest uit.
    // Als klok WEG: LED1 en LED2 knipperen.
    assign led1 = is_lost ? blink_cnt[23] : 1'b0;
    // assign led2 = is_lost ? blink_cnt[23] : 1'b1; 
    // assign led3 = 1'b0;
    // assign led4 = 1'b0;
    
    // Status naar buiten brengen
    assign status_lost = is_lost;

endmodule
