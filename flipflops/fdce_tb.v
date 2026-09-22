`timescale 1ns/1ps

module trm_fdce_tb;
    reg C=0, CE=1, CLR=0, D=0;
    wire Q;
    wire fault;
    wire trigger_rst;

    always #20 C = ~C;

    trm_fdce #(.INIT(1'b0)) dut (
        .Q(Q), .fault(fault),
        .C(C), .CE(CE), .CLR(CLR), .D(D)
    );

    fault_counter #(.THR_100(10)) u_counter (
        .clk(C), .rst(1'b0),
        .fault(fault), .count(), .trigger_rst(trigger_rst)
    );

    wire GSR = glbl.GSR;

    // toggle D on every negedge
    initial begin
        wait (GSR === 1'b0);
        #5;
        forever begin
            @(negedge C);
            D <= ~D;
        end
    end

    // CE test
    initial begin
        #180; CE = 0;
        #100; CE = 1;
    end

    // CLR test
    initial begin
        #260; CLR = 1;
        #80;  CLR = 0;
        #160; CLR = 1;
        #100; CLR = 0;
    end

    // fault injection: stuck-at-1 then stuck-at-0 on q_a
    initial begin
        wait (GSR === 1'b0);
        #700;
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
