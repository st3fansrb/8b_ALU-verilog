// =============================================================
// Flag Generator
// =============================================================
// Generates Z, N, V, C flags from 8-bit result (ADD/SUB only)
module flag_gen (
    input  [7:0] result,
    input        carry,
    input        overflow,
    output       flag_z,    // Zero
    output       flag_n,    // Negative
    output       flag_v,    // Overflow
    output       flag_c     // Carry
);
    assign flag_z = (result == 8'd0);
    assign flag_n = result[7];
    assign flag_v = overflow;
    assign flag_c = carry;
endmodule


// =============================================================
// 4-to-1 MUX (16-bit), selects one of 4 result buses
// =============================================================
module mux_4to1_16 (
    input  [15:0] in0,
    input  [15:0] in1,
    input  [15:0] in2,
    input  [15:0] in3,
    input  [1:0]  sel,
    output [15:0] out
);
    wire [15:0] mux_lo, mux_hi;
    // 2-to-1 lower
    assign mux_lo = sel[0] ? in1 : in0;
    // 2-to-1 upper
    assign mux_hi = sel[0] ? in3 : in2;
    // Final select
    assign out    = sel[1] ? mux_hi : mux_lo;
endmodule


// =============================================================
// Control Unit FSM
// Emits control signals to sequence ALU operations
// op: 00=ADD, 01=SUB, 10=MUL, 11=DIV
// =============================================================
module control_unit (
    input        clk,
    input        rst,
    input        start,
    input  [1:0] op,
    input        mul_done,
    input        div_done,
    output reg        alu_start,   // pulse to start MUL or DIV unit
    output reg  [1:0] alu_op,      // forwarded operation
    output reg        result_valid, // strobe: result on output bus
    output reg        done
);

    localparam S_IDLE    = 3'd0,
               S_DECODE  = 3'd1,
               S_ADD_SUB = 3'd2,
               S_MUL     = 3'd3,
               S_DIV     = 3'd4,
               S_DONE    = 3'd5;

    reg [2:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_IDLE;
            alu_start    <= 0;
            alu_op       <= 0;
            result_valid <= 0;
            done         <= 0;
        end else begin
            // Default strobes
            alu_start    <= 0;
            result_valid <= 0;
            done         <= 0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        alu_op <= op;
                        state  <= S_DECODE;
                    end
                end

                S_DECODE: begin
                    case (op)
                        2'b00, 2'b01: state <= S_ADD_SUB;  // combinational, 1 cycle
                        2'b10:        begin alu_start <= 1; state <= S_MUL; end
                        2'b11:        begin alu_start <= 1; state <= S_DIV; end
                        default:      state <= S_IDLE;
                    endcase
                end

                S_ADD_SUB: begin
                    result_valid <= 1;
                    done         <= 1;
                    state        <= S_IDLE;
                end

                S_MUL: begin
                    if (mul_done) begin
                        result_valid <= 1;
                        done         <= 1;
                        state        <= S_IDLE;
                    end
                end

                S_DIV: begin
                    if (div_done) begin
                        result_valid <= 1;
                        done         <= 1;
                        state        <= S_IDLE;
                    end
                end

                S_DONE: begin
                    done  <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
