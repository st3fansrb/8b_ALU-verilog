// Booth Radix-4 (Modified Booth) Multiplier
// Signed 8x8 -> 16-bit product
// Uses 4 iterations, each processing 2 bits of Q
// Internal arithmetic done in 10-bit sign-extended registers
// to avoid 2M overflow

module booth_r4_mult (
    input        clk,
    input        rst,
    input        start,
    input  [7:0] a_in,   // multiplicand (signed)
    input  [7:0] b_in,   // multiplier   (signed)
    output reg [15:0] product,
    output reg        done
);

    // ------------------------------------------------------------------
    // Internal registers
    // ------------------------------------------------------------------
    // P = {A[9:0], Q[7:0], q_m1}  total 19 bits
    reg  [9:0] A;          // accumulator (sign-extended to 10 bits)
    reg  [7:0] Q;          // current multiplier bits
    reg        q_m1;       // Q[-1]
    reg  [7:0] M;          // multiplicand (stored)
    reg  [1:0] cnt;        // iteration counter 0..3

    // States
    localparam S_IDLE = 2'd0,
               S_ITER = 2'd1,
               S_FIN  = 2'd2;
    reg [1:0] state;

    // ------------------------------------------------------------------
    // Booth Recoder: combinational
    // Input: {Q[1], Q[0], q_m1}
    // Outputs: op (0=+M, 1=+2M), sub (0=add, 1=subtract), nop
    // Table:
    //  000 -> nop
    //  001 -> +M
    //  010 -> +M
    //  011 -> +2M
    //  100 -> -2M
    //  101 -> -M
    //  110 -> -M
    //  111 -> nop
    // ------------------------------------------------------------------
    wire [2:0] booth_bits = {Q[1], Q[0], q_m1};
    reg        r_op;   // 0=M, 1=2M
    reg        r_sub;  // 0=add, 1=sub
    reg        r_nop;  // 1=no operation

    always @(*) begin
        case (booth_bits)
            3'b000: begin r_nop=1; r_op=0; r_sub=0; end
            3'b001: begin r_nop=0; r_op=0; r_sub=0; end  // +M
            3'b010: begin r_nop=0; r_op=0; r_sub=0; end  // +M
            3'b011: begin r_nop=0; r_op=1; r_sub=0; end  // +2M
            3'b100: begin r_nop=0; r_op=1; r_sub=1; end  // -2M
            3'b101: begin r_nop=0; r_op=0; r_sub=1; end  // -M
            3'b110: begin r_nop=0; r_op=0; r_sub=1; end  // -M
            3'b111: begin r_nop=1; r_op=0; r_sub=0; end
            default: begin r_nop=1; r_op=0; r_sub=0; end
        endcase
    end

    // ------------------------------------------------------------------
    // Sign-extend M to 10 bits, and 2M (10-bit, no overflow since 10 bits)
    // ------------------------------------------------------------------
    wire [9:0] M_se  = {{2{M[7]}}, M};
    wire [9:0] M2_se = {M[7], M, 1'b0};   // 2M in 10-bit signed (safe: range -256..254)

    // ------------------------------------------------------------------
    // Operand MUX: select M or 2M
    // ------------------------------------------------------------------
    wire [9:0] mux_out = r_op ? M2_se : M_se;

    // ------------------------------------------------------------------
    // 10-bit adder/subtractor (structural instance)
    // ------------------------------------------------------------------
    wire [9:0] add_result;
    wire       add_cout, add_ov;

    adder_sub #(.N(10)) adder10 (
        .a       (A),
        .b       (mux_out),
        .sub     (r_sub),
        .result  (add_result),
        .cout    (add_cout),
        .overflow(add_ov)
    );

    // ------------------------------------------------------------------
    // NOP MUX: if nop, keep A unchanged
    // ------------------------------------------------------------------
    wire [9:0] A_post = r_nop ? A : add_result;

    // ------------------------------------------------------------------
    // Arithmetic right shift by 2 on {A_post[9:0], Q[7:0], q_m1}
    // Result: new {A, Q, q_m1} = {A_post, Q, q_m1} >>> 2
    // Total 19 bits >>> 2  -> top 2 bits filled with sign (A_post[9])
    // ------------------------------------------------------------------
    wire [18:0] shift_in  = {A_post, Q, q_m1};
    wire [18:0] shift_out = {{2{A_post[9]}}, shift_in[18:2]};

    wire [9:0]  A_new   = shift_out[18:9];
    wire [7:0]  Q_new   = shift_out[8:1];
    wire        qm1_new = shift_out[0];

    // ------------------------------------------------------------------
    // FSM + datapath sequential logic
    // ------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= S_IDLE;
            done    <= 0;
            product <= 0;
            A       <= 0;
            Q       <= 0;
            q_m1    <= 0;
            M       <= 0;
            cnt     <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        M    <= a_in;
                        A    <= 10'd0;
                        Q    <= b_in;
                        q_m1 <= 1'b0;
                        cnt  <= 2'd0;
                        state <= S_ITER;
                    end
                end

                S_ITER: begin
                    // Execute one Booth R4 iteration
                    A    <= A_new;
                    Q    <= Q_new;
                    q_m1 <= qm1_new;
                    if (cnt == 2'd3)
                        state <= S_FIN;
                    else
                        cnt <= cnt + 1;
                end

                S_FIN: begin
                    // Product = {A[7:0], Q[7:0]}
                    // A[7:0] is the upper byte; sign bits A[9:8] should equal A[7]
                    product <= {A[7:0], Q};
                    done    <= 1;
                    state   <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
