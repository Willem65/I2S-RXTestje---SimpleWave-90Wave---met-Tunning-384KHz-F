always @(posedge clk_49152) begin
        if (reset) begin
            // ... je reset logica ...
            strobe_cnt <= 4'd0;
            strobe_out <= 1'b0;
        end else begin
            // Standaard gedrag: tel af als de teller boven 0 is
            if (strobe_cnt > 0) begin
                strobe_cnt <= strobe_cnt - 4'd1;
                strobe_out <= 1'b1;
            end else begin
                strobe_out <= 1'b0;
            end

            if (BYPASS) begin
                if (strobe_in) begin
                    sample_out <= sample_in;
                    strobe_cnt <= 4'd15; // Start de opgerekte puls (16 tikken)
                end
            end else begin
                case (state)
                    STATE_IDLE: begin
                        if (strobe_in) begin
                            // ... samples schuiven ...
                            state <= STATE_RUN;
                        end
                    end

                    STATE_RUN: begin
                        // ... berekening ...
                        if (tap_index == 7'd95) begin
                            sample_out <= { clipped_out, 16'd0 };
                            strobe_cnt <= 4'd15; // Start de opgerekte puls (16 tikken)
                            state      <= STATE_IDLE; 
                        end else begin
                            tap_index <= tap_index + 7'd1;
                        end
                    end
                endcase
            end
        end
    end