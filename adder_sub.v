// N-bit Ripple-Carry Adder/Subtractor (structural, N=parameter)
// sub=0: result = a + b
// sub=1: result = a - b  (a + ~b + 1, i.e. cin=1 and b XOR'd)
module adder_sub #(parameter N = 8) (
    input  [N-1:0] a,
    input  [N-1:0] b,
    input          sub,       // 0=add, 1=subtract
    output [N-1:0] result,
    output         cout,
    output         overflow
);
    wire [N-1:0] b_xor;
    wire [N:0]   carry;

    // XOR each b bit with sub (invert b when subtracting)
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : xor_b
            xor gx (b_xor[i], b[i], sub);
        end
    endgenerate

    // cin = sub (for two's complement negation)
    assign carry[0] = sub;

    // Chain of full adders
    generate
        for (i = 0; i < N; i = i + 1) begin : fa_chain
            full_adder fa (
                .a   (a[i]),
                .b   (b_xor[i]),
                .cin (carry[i]),
                .sum (result[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate

    assign cout     = carry[N];
    // Overflow: carry in to MSB differs from carry out of MSB
    assign overflow = carry[N] ^ carry[N-1];
endmodule
