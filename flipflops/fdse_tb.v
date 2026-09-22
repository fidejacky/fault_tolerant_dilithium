`timescale 1ns/1ps

module trm_fdse_tb;
    reg C=0, CE=1, S=0, D=0;
    wire Q;
    wire fault;
    wire trigger_rst;

    always #20 C = ~C;

    trm_fdse #(.INIT(1'b0)) dut (
        .Q(Q), .fault(fault),
        .C(C), .CE(CE), .D(D), .S(S)
    );

    fault_counter #(.THR_100(10)) u_counter (
        .clk(C), .rst(1'b0),
        .fault(fault), .count(), .trigger_rst(trigger_rst)
    );

    wire GSR = glbl.GSR;

    // toggle D on every negedge
    initial begin
        wait (GSR == 1'b0);
        forever begin
            @(negedge C);
            D <= ~D;
        end
    end

    // CE test
    initial begin
        #200; CE = 0;
        #100; CE = 1;
    end

    // S (set) test
    initial begin
        #260; S = 1;
        #40;  S = 0;
        #50;  S = 1;
        #50;  S = 0;
    end

    // fault injection: stuck-at-1 then stuck-at-0 on q_a
    initial begin
        wait (GSR == 1'b0);
        #400;
        $display("[%0t] injecting stuck-at-1 on q_a | trigger_rst = %0b", $time, trigger_rst);
        force dut.q_a = 1'b1;
        #100;
        $display("[%0t] switching to stuck-at-0 on q_a  | trigger_rst = %0b", $time, trigger_rst);
        force dut.q_a = 1'b0;
        #100;
        release dut.q_a;
        $display("[%0t] fault released                  | trigger_rst = %0b", $time, trigger_rst);
    end

    initial begin
        #5000;
        $display("[%0t] === final trigger_rst: %0b ===", $time, trigger_rst);
        $finish;
    end
endmodule
