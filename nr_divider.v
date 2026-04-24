// Non-Restoring Division
// Unsigned 8-bit dividend / 8-bit divisor -> 8-bit quotient, 8-bit remainder
// Algorithm: 8 iterations
//   If remainder >= 0: shift left, subtract divisor  -> q_bit = 1
//   If remainder < 0: shift left, add divisor        -> q_bit = 0
// Final correction: if remainder < 0, add divisor back

module nr_divider (
    input        clk,
    input        rst,
    input        start,
    input  [7:0] dividend,
    input  [7:0] divisor,
    output reg [7:0] quotient,
    output reg [7:0] remainder,
    output reg       done,
    output reg       div_by_zero
);

    localparam S_IDLE  = 2'd0,
               S_ITER  = 2'd1,
               S_FIN   = 2'd2,
               S_DONE  = 2'd3;

    reg [1:0] state;

    reg signed [8:0] R;
    reg        [7:0] Qreg;
    reg        [7:0] D;
    reg        [3:0] cnt;

    wire signed [9:0] R_shifted = {R, 1'b0};

    wire        do_sub = ~R[8];
    wire signed [9:0] D_se      = {1'b0, D};
    wire signed [9:0] R_new_sub = R_shifted - $signed(D_se);
    wire signed [9:0] R_new_add = R_shifted + $signed(D_se);
    wire signed [9:0] R_new     = do_sub ? R_new_sub : R_new_add;

    wire q_bit = ~R_new[9];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= S_IDLE;
            done        <= 0;
            div_by_zero <= 0;
            quotient    <= 0;
            remainder   <= 0;
            R           <= 0;
            Qreg        <= 0;
            D           <= 0;
            cnt         <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done        <= 0;
                    div_by_zero <= 0;
                    if (start) begin
                        if (divisor == 8'd0) begin
                            div_by_zero <= 1;
                            done        <= 1;
                        end else begin
                            D     <= divisor;
                            R     <= 9'd0;
                            Qreg  <= dividend;
                            cnt   <= 4'd0;
                            state <= S_ITER;
                        end
                    end
                end

                S_ITER: begin
                    R    <= R_new[8:0];
                    Qreg <= {Qreg[6:0], q_bit};
                    if (cnt == 4'd7)
                        state <= S_FIN;
                    else
                        cnt <= cnt + 1;
                end

                S_FIN: begin
                    // Scrie rezultatele in registre, done vine in ciclul urmator
                    if (R[8])
                        remainder <= R[7:0] + D;
                    else
                        remainder <= R[7:0];
                    quotient <= Qreg;
                    state    <= S_DONE;
                end

                S_DONE: begin
                    // Acum registrele sunt stabile, ridicam done
                    done  <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule