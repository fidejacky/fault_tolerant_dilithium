`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/05/2025 09:37:57 AM
// Design Name: 
// Module Name: UART_transmit_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module UART_transmit_tb;
    reg write_en = 0;
    reg reset = 0;
    //reg write_en = 0 ;
    reg clock_en = 0;
    reg [7:0] data_in = 8'h00;
    wire busy;
    wire tx;
    reg clock = 0;
        
    UART_transmit dut (
        .clock(clock),
        .write_en(write_en),
        .clock_en(clock_en),
        .reset(reset),
        .data_in(data_in),
        .busy(busy),
        .tx(tx)
        );

    always #10 clock = ~clock;
    
    localparam integer BAUD_DIV = 16;
    integer baud_cnt = 0;
    
    always @(posedge clock) begin
        if(reset)
            begin
            baud_cnt <=0;
            clock_en<= 0;
            end
        else begin
            if(baud_cnt == BAUD_DIV-1)
                begin
                    baud_cnt<=0;
                    clock_en <=1'b1;
                end
                else begin
                    baud_cnt <= baud_cnt+1;
                    clock_en <=1'b0;
                end
        end
    end

    task wait_for_clock_en;
    begin
        @(posedge clock);
        while (clock_en==1'b0)begin
            @(posedge clock);
        end
        #1;
    end
    endtask

    task check_frame(input [7:0] byte_val, input [31*8-1:0] name);
        integer i;
        reg expected_bit;
    begin
        $display("\n--- Prüfe Frame für %s (0x%0h) @ time %0t ---", name, byte_val, $time);

        @(posedge clock);
        while (!busy) begin
            @(posedge clock);
        end

        for (i = 0; i < 10; i = i + 1) begin
            wait_for_clock_en(); 

            case (i)
                0: expected_bit = 1'b0;              
                1: expected_bit = byte_val[0];
                2: expected_bit = byte_val[1];
                3: expected_bit = byte_val[2];
                4: expected_bit = byte_val[3];
                5: expected_bit = byte_val[4];
                6: expected_bit = byte_val[5];
                7: expected_bit = byte_val[6];
                8: expected_bit = byte_val[7];
                9: expected_bit = 1'b1;              // Stopbit
                default: expected_bit = 1'bx;
            endcase

            if (tx !== expected_bit) begin
                $display("**FEHLER** Bit %0d für %s: tx=%b, erwartet=%b @ time %0t, ",
                         i, name, tx, expected_bit, $time);
            end else begin
                $display("OK: Bit %0d fuer %s: tx=%b @ time %0t",
                         i, name, tx, $time);
            end
        end

        repeat (5) @(posedge clock); //bleibt idle für die nächsten 15 Takten 
        if (tx !== 1'b1)
            $display("**FEHLER**: tx ist nach Stopbit nicht im Idle (1) für %s @ time %0t", name, $time);
    end
    endtask
    
    task send_byte(input [7:0] byte_val);
    begin
        @(posedge clock);
        while (busy) begin
            @(posedge clock);
        end

        data_in  <= byte_val;
        write_en <= 1'b1;
        @(posedge clock);
        write_en <= 1'b0;
    end
    endtask
    
    initial begin
        $dumpfile("UART_transmit_tb.vcd");
        $dumpvars(0, UART_transmit_tb);

        $display("Starte Simulation...");

        reset   = 1'b1;
        write_en= 1'b0;
        data_in = 8'h00;

        repeat (5) @(posedge clock);
        reset = 1'b0;
        $display("Reset deaktiviert @ time %0t", $time);

        repeat (20) @(posedge clock);

        send_byte(8'hA5);
        check_frame(8'hA5, "Test1_0xA5");

        send_byte(8'h00);
        check_frame(8'h00, "Test2_0x00");

        send_byte(8'hFF);
        check_frame(8'hFF, "Test3_0xFF");

        send_byte(8'h55);
        check_frame(8'h55, "Test4_0x55");

        send_byte(8'hAA);
        check_frame(8'hAA, "Test5_0xAA");

        repeat (50) @(posedge clock);

        $display("Simulation fertig @ time %0t", $time);
        $finish;
    end

endmodule
