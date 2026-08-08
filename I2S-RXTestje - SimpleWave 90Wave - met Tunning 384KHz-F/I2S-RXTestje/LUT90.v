`timescale 1ns / 1ps

module LUT90 #(
    parameter INIT_FILE = "sin_qtr2.mem",
    parameter [15:0] PHASE_OFFSET = 16'd0
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              ce_fs,     
    input  wire [15:0]       phase,     
    input  wire [15:0]       phase_adj, 
    output reg  signed [31:0] I,        
    output reg  signed [31:0] Q,        
    output reg               iq_valid
);

    // --- 1. Geheugen definitie ---
    (* ram_style = "block" *)
    reg signed [15:0] rom_mem [0:16383];

    initial begin
        $readmemh(INIT_FILE, rom_mem);
    end

    // --- 2. Interne signalen (Wires voor de berekening) ---
    // We berekenen de 'target' fase hier. De FPGA rekent dit uit tussen de klokflanken.
    wire [15:0] target_p_cos = phase + 16'd16133 + PHASE_OFFSET + phase_adj;

    reg [13:0] addr_sin, addr_cos;
    reg        sin_neg_r, cos_neg_r;
    reg        ce_d1, ce_d2;
    reg signed [15:0] lut_sin, lut_cos;

    // --- 3. Logica voor adres-berekening en Teken ---
    always @(posedge clk) begin
        if (rst) begin
            ce_d1      <= 1'b0;
            ce_d2      <= 1'b0;
            iq_valid   <= 1'b0;
            I          <= 32'sd0;
            Q          <= 32'sd0;
            addr_sin   <= 14'd0;
            addr_cos   <= 14'd0;
            sin_neg_r  <= 1'b0;
            cos_neg_r  <= 1'b0;
        end else begin
            ce_d1    <= ce_fs;
            ce_d2    <= ce_d1;
            iq_valid <= ce_d2;

            if (ce_fs) begin
                // Sinus Kwadrant Logica
                case (phase[15:14])
                    2'd0: begin addr_sin <= phase[13:0];                sin_neg_r <= 1'b0; end
                    2'd1: begin addr_sin <= 14'h3FFF - phase[13:0];     sin_neg_r <= 1'b0; end
                    2'd2: begin addr_sin <= phase[13:0];                sin_neg_r <= 1'b1; end
                    2'd3: begin addr_sin <= 14'h3FFF - phase[13:0];     sin_neg_r <= 1'b1; end
                endcase

                // Cosinus Kwadrant Logica (Gebruik de stabiele wire)
                case (target_p_cos[15:14])
                    2'd0: begin addr_cos <= target_p_cos[13:0];            cos_neg_r <= 1'b0; end
                    2'd1: begin addr_cos <= 14'h3FFF - target_p_cos[13:0]; cos_neg_r <= 1'b0; end
                    2'd2: begin addr_cos <= target_p_cos[13:0];            cos_neg_r <= 1'b1; end
                    2'd3: begin addr_cos <= 14'h3FFF - target_p_cos[13:0]; cos_neg_r <= 1'b1; end
                endcase
            end

            // --- 4. BRAM Read ---
            lut_sin <= rom_mem[addr_sin];
            lut_cos <= rom_mem[addr_cos];

            // --- 5. Output mapping ---
            if (ce_d2) begin
                Q <= { (sin_neg_r ? -lut_sin : lut_sin), 16'd0 };
                I <= { (cos_neg_r ? -lut_cos : lut_cos), 16'd0 };
            end
        end
    end

endmodule












// // // `timescale 1ns / 1ps

// // // module LUT90 #(
    // // // parameter INIT_FILE = "sin_qtr2.mem",
    // // // parameter [13:0] PHASE_OFFSET = 14'd0
// // // )(
    // // // input  wire              clk,
    // // // input  wire              rst,
    // // // input  wire              ce_fs,    // Sample rate enable
    // // // input  wire [15:0]       phase,    // Inkomende fase (0-65535)
	// // // input  wire	[15:0]		 phase_adj, //  (phase_adj)
    // // // output reg  signed [31:0] I,        // 32-bit output (Links uitgelijnd)
    // // // output reg  signed [31:0] Q,        // 32-bit output (Links uitgelijnd)
    // // // output reg               iq_valid
// // // );

    // // // // --- 1. Geheugen definitie (Block RAM) ---
    // // // (* ram_style = "block" *)
    // // // reg signed [15:0] rom_mem [0:16383];

    // // // initial begin
        // // // $readmemh(INIT_FILE, rom_mem);
    // // // end

    // // // // --- 2. Interne signalen en registers ---
    // // // wire [15:0] phase_sin = phase;
    // // // //wire [15:0] phase_cos = phase + 16'd16384 + {2'b00, PHASE_OFFSET};
	// // // wire [15:0] phase_cos = phase + 16'd16084 + phase_adj;

    // // // reg [13:0] addr_sin, addr_cos;
    // // // reg signed [15:0] lut_sin, lut_cos;
    // // // reg        sin_neg_r, cos_neg_r;
    // // // reg        ce_d1, ce_d2;

    // // // // --- 3. Logica voor adres-berekening en Teken ---
    // // // always @(posedge clk) begin
        // // // if (rst) begin
            // // // ce_d1    <= 1'b0;
            // // // ce_d2    <= 1'b0;
            // // // iq_valid <= 1'b0;
            // // // I        <= 32'sd0;
            // // // Q        <= 32'sd0;
            // // // addr_sin <= 14'd0;
            // // // addr_cos <= 14'd0;
            // // // sin_neg_r <= 1'b0;
            // // // cos_neg_r <= 1'b0;
        // // // end else begin
            // // // // Pipeline delay registers
            // // // ce_d1    <= ce_fs;
            // // // ce_d2    <= ce_d1;
            // // // iq_valid <= ce_d2;

            // // // if (ce_fs) begin
                // // // // Bepaal adres en teken voor Sinus (gebaseerd op kwadrant)
                // // // case (phase_sin[15:14])
                    // // // 2'd0: begin addr_sin <= phase_sin[13:0];          sin_neg_r <= 1'b0; end
                    // // // 2'd1: begin addr_sin <= 14'h3FFF - phase_sin[13:0]; sin_neg_r <= 1'b0; end
                    // // // 2'd2: begin addr_sin <= phase_sin[13:0];          sin_neg_r <= 1'b1; end
                    // // // 2'd3: begin addr_sin <= 14'h3FFF - phase_sin[13:0]; sin_neg_r <= 1'b1; end
                // // // endcase

                // // // // Bepaal adres en teken voor Cosinus (+90 graden fase)
                // // // case (phase_cos[15:14])
                    // // // 2'd0: begin addr_cos <= phase_cos[13:0];          cos_neg_r <= 1'b0; end
                    // // // 2'd1: begin addr_cos <= 14'h3FFF - phase_cos[13:0]; cos_neg_r <= 1'b0; end
                    // // // 2'd2: begin addr_cos <= phase_cos[13:0];          cos_neg_r <= 1'b1; end
                    // // // 2'd3: begin addr_cos <= 14'h3FFF - phase_cos[13:0]; cos_neg_r <= 1'b1; end
                // // // endcase
            // // // end

            // // // // --- 4. Dual-Port ROM Read (1 cycle latency) ---
            // // // lut_sin <= rom_mem[addr_sin];
            // // // lut_cos <= rom_mem[addr_cos];

            // // // // --- 5. Output mapping (2nd cycle latency) ---
            // // // if (ce_d2) begin
                // // // // We berekenen het 16-bit resultaat en schuiven het direct naar de MSB van de 32-bit output
                // // // Q <= { (sin_neg_r ? -lut_sin : lut_sin), 16'd0 };
                // // // I <= { (cos_neg_r ? -lut_cos : lut_cos), 16'd0 };
            // // // end
        // // // end
    // // // end

// // // endmodule