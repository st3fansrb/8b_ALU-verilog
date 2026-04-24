`timescale 1ns/1ps

module alu_tb;

    reg        clk, rst, start;
    reg  [1:0] op;
    reg  [7:0] a, b;
    wire [15:0] result;
    wire        done, flag_z, flag_n, flag_v, flag_c, div_by_zero;

    // Semnal auxiliar doar pentru wave — arata ce test ruleaza
    reg [127:0] test_label;

    alu_top dut (
        .clk(clk), .rst(rst), .start(start),
        .op(op), .a(a), .b(b),
        .result(result), .done(done),
        .flag_z(flag_z), .flag_n(flag_n),
        .flag_v(flag_v), .flag_c(flag_c),
        .div_by_zero(div_by_zero)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Task: aplica operatia, asteapta done, afiseaza rezultat
    // ---------------------------------------------------------------
    task run_op;
        input [1:0]  t_op;
        input [7:0]  t_a, t_b;
        input [15:0] t_expected;
        input [127:0] t_label;
        begin
            // Seteaza label-ul vizibil in wave
            test_label = t_label;

            @(negedge clk);
            op = t_op; a = t_a; b = t_b; start = 1;
            @(negedge clk);
            start = 0;

            // Asteapta done max 30 cicli
            repeat(30) begin
                if (!done) @(posedge clk);
            end
            @(negedge clk);

            // Afiseaza cu timestamp
            if (result === t_expected)
                $display("[%0t ns] PASS | %-16s | a=%4d b=%4d | result=0x%04h", 
                          $time, t_label, $signed(t_a), $signed(t_b), result);
            else
                $display("[%0t ns] FAIL | %-16s | a=%4d b=%4d | expected=0x%04h got=0x%04h",
                          $time, t_label, $signed(t_a), $signed(t_b), t_expected, result);

            // Pauza intre teste — vizibila in wave ca spatiu
            repeat(4) @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------------
    // Stimuli
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        test_label = "RESET";
        rst = 1; start = 0; op = 0; a = 0; b = 0;
        repeat(4) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        $display("====================================================");
        $display("  ALU TESTBENCH START  |  time=%0t", $time);
        $display("====================================================");

        // ----- ADD -----
        test_label = "-- ADD --";
        repeat(2) @(posedge clk);

        run_op(2'b00, 8'd5,   8'd3,   16'h0008, "ADD 5+3");
        run_op(2'b00, 8'd0,   8'd0,   16'h0000, "ADD 0+0");
        run_op(2'b00, 8'd127, 8'd0,   16'h007F, "ADD 127+0");
        run_op(2'b00, 8'hFF,  8'h01,  16'h0000, "ADD -1+1");
        run_op(2'b00, 8'd100, 8'd28,  16'h0080, "ADD 100+28 OV");

        // ----- SUB -----
        test_label = "-- SUB --";
        repeat(2) @(posedge clk);

        run_op(2'b01, 8'd10,  8'd3,   16'h0007, "SUB 10-3");
        run_op(2'b01, 8'd3,   8'd10,  16'hFFF9, "SUB 3-10");
        run_op(2'b01, 8'd0,   8'd0,   16'h0000, "SUB 0-0");
        run_op(2'b01, 8'h80,  8'd1,   16'hFF7F, "SUB -128-1 OV");

        // ----- MUL -----
        test_label = "-- MUL --";
        repeat(2) @(posedge clk);

        run_op(2'b10, 8'd3,   8'd5,   16'h000F, "MUL 3x5");
        run_op(2'b10, 8'd12,  8'd12,  16'h0090, "MUL 12x12");
        run_op(2'b10, 8'hFE,  8'd3,   16'hFFFA, "MUL -2x3");
        run_op(2'b10, 8'hFE,  8'hFE,  16'h0004, "MUL -2x-2");
        run_op(2'b10, 8'd0,   8'd255, 16'h0000, "MUL 0x255");
        run_op(2'b10, 8'd127, 8'd127, 16'h3F01, "MUL 127x127");
        run_op(2'b10, 8'h80,  8'h80,  16'h4000, "MUL -128x-128");

        // ----- DIV -----
        test_label = "-- DIV --";
        repeat(2) @(posedge clk);

        run_op(2'b11, 8'd10,  8'd3,  {8'd1,  8'd3},  "DIV 10/3");
        run_op(2'b11, 8'd20,  8'd4,  {8'd0,  8'd5},  "DIV 20/4");
        run_op(2'b11, 8'd7,   8'd7,  {8'd0,  8'd1},  "DIV 7/7");
        run_op(2'b11, 8'd0,   8'd5,  {8'd0,  8'd0},  "DIV 0/5");
        run_op(2'b11, 8'd255, 8'd16, {8'd15, 8'd15}, "DIV 255/16");
        run_op(2'b11, 8'd100, 8'd10, {8'd0,  8'd10}, "DIV 100/10");

        // ----- DIV by zero -----
        test_label = "DIV/0 TEST";
        repeat(2) @(posedge clk);
        @(negedge clk);
        op = 2'b11; a = 8'd5; b = 8'd0; start = 1;
        @(negedge clk); start = 0;
        repeat(5) @(posedge clk);
        if (div_by_zero)
            $display("[%0t ns] PASS | DIV by zero flag OK", $time);
        else
            $display("[%0t ns] FAIL | DIV by zero not asserted", $time);

        repeat(4) @(posedge clk);
        test_label = "DONE";

        $display("====================================================");
        $display("  TESTBENCH COMPLETE  |  time=%0t", $time);
        $display("====================================================");
        $stop;
    end

endmodule