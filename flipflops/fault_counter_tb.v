`timescale 1ns/1ps

module fault_counter_tb;

    localparam WIDTH   = 32;
    localparam THR_100 = 8;

    reg  clk = 0;
    reg  rst = 0;
    reg  fault = 0;
    wire trigger_rst;

    always #5 clk = ~clk;

    fault_counter #(.WIDTH(WIDTH), .THR_100(THR_100)) dut (
        .clk(clk), .rst(rst), .fault(fault),
        .count(), .trigger_rst(trigger_rst)
    );

    task do_reset;
        begin
            fault = 0; rst = 1;
            @(posedge clk); #1;
            rst = 0;
        end
    endtask

    initial begin
        do_reset;
        repeat(10) @(posedge clk); #1;
        if (trigger_rst === 0)
            $display("PASS [T1 no fault]");
        else
            $display("FAIL [T1 no fault]: trigger_rst=%b, expected 0", trigger_rst);

        do_reset;
        fault = 1; @(posedge clk); #1; fault = 0;
        repeat(20) @(posedge clk); #1;
        fault = 1; @(posedge clk); #1; fault = 0;
        repeat(20) @(posedge clk); #1;
        fault = 1; @(posedge clk); #1; fault = 0;
        repeat(10) @(posedge clk); #1;
        if (trigger_rst === 0)
            $display("PASS [T2 isolated faults < THR_100]");
        else
            $display("FAIL [T2 isolated faults < THR_100]: trigger_rst=%b, expected 0", trigger_rst);

        do_reset;
        fault = 1;
        repeat(7) @(posedge clk); #1; // running_total=7, not yet
        if (trigger_rst === 0)
            $display("PASS [T3a rolling: 7 < THR_100]");
        else
            $display("FAIL [T3a rolling: 7 < THR_100]: trigger_rst=%b, expected 0", trigger_rst);
        @(posedge clk); #1; // running_total=8 = THR_100, fires
        fault = 0;
        if (trigger_rst === 1)
            $display("PASS [T3b rolling: 8 >= THR_100]");
        else
            $display("FAIL [T3b rolling: 8 >= THR_100]: trigger_rst=%b, expected 1", trigger_rst);

        do_reset;
        fault = 1;
        repeat(8) @(posedge clk); // fill window with 8 fault cycles
        fault = 0;
        repeat(108) @(posedge clk); #1; // wait for all 8 to slide past window[99]
        if (trigger_rst === 0)
            $display("PASS [T4 window slide-out]");
        else
            $display("FAIL [T4 window slide-out]: trigger_rst=%b, expected 0 after old faults evicted", trigger_rst);

        do_reset;
        fault = 1;
        repeat(8) @(posedge clk); #1;
        $display("[T5] before reset: trigger_rst=%b (expected 1)", trigger_rst);
        fault = 0;
        rst = 1;
        @(posedge clk); #1;
        rst = 0;
        @(posedge clk); #1;
        if (trigger_rst === 0)
            $display("PASS [T5 reset clears trigger]");
        else
            $display("FAIL [T5 reset clears trigger]: trigger_rst=%b, expected 0", trigger_rst);

        $display("=== fault_counter_tb done ===");
        $finish;
    end

endmodule
