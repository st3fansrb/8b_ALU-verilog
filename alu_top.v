// =============================================================
// ALU Top-Level  (8-bit, structural integration)
//
// op[1:0]:  00=ADD  01=SUB  10=MUL(Booth R4)  11=DIV(Non-Restoring)
//
// result[15:0]:
//   ADD/SUB -> sign-extended 8-bit result in [7:0], [15:8]=sign-ext
//   MUL     -> full 16-bit signed product
//   DIV     -> [15:8]=remainder, [7:0]=quotient
//
// Flags (valid only for ADD/SUB, latched on result_valid):
//   flag_z, flag_n, flag_v, flag_c
// =============================================================

`include "full_adder.v"
`include "adder_sub.v"
`include "booth_r4_mult.v"
`include "nr_divider.v"
`include "control_unit.v"

module alu_top (
    input        clk,
    input        rst,
    input        start,
    input  [1:0] op,
    input  [7:0] a,
    input  [7:0] b,
    output [15:0] result,
    output        done,
    output        flag_z,
    output        flag_n,
    output        flag_v,
    output        flag_c,
    output        div_by_zero
);

    // ---------------------------------------------------------------
    // Wires for control signals
    // ---------------------------------------------------------------
    wire        cu_start;
    wire [1:0]  cu_op;
    wire        result_valid;
    wire        mul_done, div_done;

    // ---------------------------------------------------------------
    // Control Unit
    // ---------------------------------------------------------------
    control_unit cu (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .op          (op),
        .mul_done    (mul_done),
        .div_done    (div_done),
        .alu_start   (cu_start),
        .alu_op      (cu_op),
        .result_valid(result_valid),
        .done        (done)
    );

    // ---------------------------------------------------------------
    // ADD / SUB (combinational, 8-bit)
    // ---------------------------------------------------------------
    wire [7:0] add_sub_result;
    wire       add_sub_cout, add_sub_ov;
    wire       do_sub = op[0];

    adder_sub #(.N(8)) addsub8 (
        .a       (a),
        .b       (b),
        .sub     (do_sub),
        .result  (add_sub_result),
        .cout    (add_sub_cout),
        .overflow(add_sub_ov)
    );

    wire [15:0] add_sub_16 = {{8{add_sub_result[7]}}, add_sub_result};

    // ---------------------------------------------------------------
    // Booth R4 Multiplier
    // ---------------------------------------------------------------
    wire [15:0] mul_result;

    booth_r4_mult mult (
        .clk    (clk),
        .rst    (rst),
        .start  (cu_start & (cu_op == 2'b10)),
        .a_in   (a),
        .b_in   (b),
        .product(mul_result),
        .done   (mul_done)
    );

    // ---------------------------------------------------------------
    // Non-Restoring Divider
    // ---------------------------------------------------------------
    wire [7:0] div_quotient, div_remainder;

    nr_divider divider (
        .clk        (clk),
        .rst        (rst),
        .start      (cu_start & (cu_op == 2'b11)),
        .dividend   (a),
        .divisor    (b),
        .quotient   (div_quotient),
        .remainder  (div_remainder),
        .done       (div_done),
        .div_by_zero(div_by_zero)
    );

    wire [15:0] div_result_16 = {div_remainder, div_quotient};

    // ---------------------------------------------------------------
    // Result latch — captures correct source based on latched_op
    // ---------------------------------------------------------------
    reg [15:0] result_reg;
    reg [1:0]  latched_op;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result_reg <= 16'd0;
            latched_op <= 2'd0;
        end else begin
            if (start)
                latched_op <= op;
            // Captureaza direct la done-ul fiecarui modul
            if (mul_done)
                result_reg <= mul_result;
            else if (div_done)
                result_reg <= div_result_16;
            else if (result_valid && (latched_op == 2'b00 || latched_op == 2'b01))
                result_reg <= add_sub_16;
        end
    end

    assign result = result_reg;

    // ---------------------------------------------------------------
    // Flag Generator (ADD/SUB only)
    // ---------------------------------------------------------------
    wire fg_z, fg_n, fg_v, fg_c;

    flag_gen fg (
        .result  (add_sub_result),
        .carry   (add_sub_cout),
        .overflow(add_sub_ov),
        .flag_z  (fg_z),
        .flag_n  (fg_n),
        .flag_v  (fg_v),
        .flag_c  (fg_c)
    );

    reg r_z, r_n, r_v, r_c;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_z <= 0; r_n <= 0; r_v <= 0; r_c <= 0;
        end else if (result_valid && (latched_op == 2'b00 || latched_op == 2'b01)) begin
            r_z <= fg_z; r_n <= fg_n; r_v <= fg_v; r_c <= fg_c;
        end
    end

    assign flag_z = r_z;
    assign flag_n = r_n;
    assign flag_v = r_v;
    assign flag_c = r_c;

endmodule


// ---------------------------------------------------------------
// Inline: mux_4to1_16 (pastrat pentru compatibilitate, neutilizat)
// ---------------------------------------------------------------
module mux_4to1_16 (
    input  [15:0] in0, in1, in2, in3,
    input  [1:0]  sel,
    output [15:0] out
);
    wire [15:0] lo = sel[0] ? in1 : in0;
    wire [15:0] hi = sel[0] ? in3 : in2;
    assign out = sel[1] ? hi : lo;
endmodule


// ---------------------------------------------------------------
// Inline: flag_gen
// ---------------------------------------------------------------
module flag_gen (
    input  [7:0] result,
    input        carry,
    input        overflow,
    output       flag_z,
    output       flag_n,
    output       flag_v,
    output       flag_c
);
    assign flag_z = (result == 8'd0);
    assign flag_n = result[7];
    assign flag_v = overflow;
    assign flag_c = carry;
endmodule