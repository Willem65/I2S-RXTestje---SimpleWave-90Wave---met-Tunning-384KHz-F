
`timescale 1ns / 1ps

module LUT(
        input  wire clk_49152,
        // LET OP: Als je POINTS verandert (bijv. 4096), moet je hier handmatig [11:0] van maken!
        input  wire [10:0] phase_in,     // 11 bits voor 2048 punten
        input  wire [9:0]  phase_adj,   
        
        output reg signed [31:0] I,      // 32-bit output (Links uitgelijnd)
        output reg signed [31:0] Q       // 32-bit output (Links uitgelijnd)
    );

    // ============================================================
    // INSTELLINGEN (Local parameters)
    // ============================================================
    localparam POINTS   = 2048;                   // Aantal punten in je .mem file
    localparam Q_OFFSET = 10'd412;                // Jouw fase-verschuiving
    localparam MEM_FILE = "HeleSin2048.mem";      // Bestandsnaam van de tabel
	// ============================================================
	
	
	

    // ============================================================
    // Sinus tabel (Block RAM)
    // ============================================================
    (* ram_style = "block" *) 
    reg signed [15:0] sin_table [0:POINTS-1]; 

    initial begin
        $readmemh(MEM_FILE, sin_table);  
    end

    // Berekening van de Q-fase (90 graden verschuiving)
    // We gebruiken de localparam Q_OFFSET
    wire [10:0] phase_q = phase_in + Q_OFFSET + {1'b0, phase_adj}; 
    
    // ============================================================
    // Combinatorische lookup & Uitlijning
    // ============================================================
    always @(posedge clk_49152) begin  // BRAM generatie
    
        // FIX: Ik heb hier '<=' gebruikt in plaats van '='. 
        // Binnen een 'always @(posedge)' moet je in Verilog altijd '<=' gebruiken.
        // Doe je dit niet, dan kan de FPGA in de war raken bij het maken van het geheugen!
        
        I <= { sin_table[phase_in], 16'd0 };
        Q <= { sin_table[phase_q[10:0]], 16'd0 }; 
    end                                          

endmodule

/*

`timescale 1ns / 1ps

module LUT(
		input  wire clk_49152,
        input  wire [10:0] phase_in,     // 11 bits voor 2048 punten
        input  wire [9:0]  phase_adj,   
        
        output reg signed [31:0] I,      // 32-bit output (Links uitgelijnd)
        output reg signed [31:0] Q       // 32-bit output (Links uitgelijnd)
    );

    // ============================================================
    // 2048-puntensinus tabel (360 graden)
    // ============================================================
    (* ram_style = "block" *) 
    reg signed [15:0] sin_table [0:2047]; 

    initial begin
        $readmemh("HeleSin2048.mem", sin_table);  
    end



    // Berekening van de Q-fase (90 graden verschuiving)
    // We gebruiken 11 bits zodat de optelling netjes rond de 2048 rolt
    wire [10:0] phase_q = phase_in + 10'd412 + {1'b0, phase_adj}; 
	//wire [10:0] phase_q = phase_in + 11'd512 + phase_adj; 
	
	



    // ============================================================
    // Combinatorische lookup & Uitlijning
    // ============================================================
	//always @(*) begin
    always @(posedge clk_49152) begin  // Dit als je Bram wilt gebruiken
	
        // We pakken de 16-bit waarde en plakken er 16 nullen achter.
        // Hierdoor staat de audio op de "luide" plek voor de 32-bit DAC.
		
        I = { sin_table[phase_in], 16'd0 };
        Q = { sin_table[phase_q[10:0]], 16'd0 }; // kijkt naar de bits 0 tot en met 10 van die variabele
    end                                         // Het kan het gebeuren dat de uitkomst groter is dan 2047
	                                           // Door sin_table[phase_q[10:0]] te schrijven, zeg je tegen de FPGA-compiler:
                                              //"Gebruik alleen de onderste 11 bits als index voor de tabel. Negeer alles wat daarboven zit."

endmodule

*/

/*
module LUT(
		input  [11:0] phase_in,     // 12-bit phase_out van de accumulator
		output reg signed [15:0] I, // In-phase sinus
		output reg signed [15:0] Q  // Quadrature sinus (90 graden verschoven)
    );

    // ============================================================
    // 4096-puntensinus tabel 360 degrees
    // ============================================================
    reg signed [15:0] sin_table [0:4095];

    initial begin
        $readmemh("sin4096.mem", sin_table);  
        // Je kunt ook $readmemb gebruiken of de tabel hardcoden
    end

    // 90 graden verschuiving = 4096/4 = 1024
    wire [11:0] phase_q = phase_in + 12'd924 + phase_adj;

    // ============================================================
    // Combinatorische lookup
    // ============================================================
    always @(*) begin
        I = sin_table[phase_in];
        Q = sin_table[phase_q];
    end

endmodule


*/