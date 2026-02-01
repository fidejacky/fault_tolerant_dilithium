`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/04/2025 05:39:57 PM
// Design Name: 
// Module Name: UART_transmit
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

module UART_transmit(
    input clock,
    input write_en,
    input clock_en,
    input reset,
    input  [7:0] data_in,
    output busy,
    output reg tx
);

    reg [7:0] data;
    reg [2:0] index;

    parameter state_idle  = 2'b00;
    parameter state_start = 2'b01;
    parameter state_data  = 2'b10;
    parameter state_stop  = 2'b11;

    reg [1:0] state = state_idle;

    always @(posedge clock) begin
        if (reset) begin
            // synchroner Reset
            tx    <= 1'b1;       
            state <= state_idle;
            data  <= 8'b0;
            index <= 3'd0;
        end else begin
            case (state)
                state_idle: begin
                    tx    <= 1'b1;      
                    index <= 3'd0;      

                    if (write_en) begin
                        state <= state_start;
                        data  <= data_in;
                    end
                end

                state_start: begin
                    if (clock_en) begin
                        tx    <= 1'b0;      
                        state <= state_data;
                        index <= 3'd0;     
                    end
                end

                state_data: begin
                    if (clock_en) begin
                        tx <= data[index];

                        if (index == 3'd7) begin
                            state <= state_stop;
                        end else begin
                            index <= index + 3'd1;
                        end
                    end
                end

                state_stop: begin
                    if (clock_en) begin
                        tx    <= 1'b1;     
                        state <= state_idle;
                    end
                end

                default: begin
                    state <= state_idle;
                    tx    <= 1'b1;
                end
            endcase
        end
    end

    assign busy = (state != state_idle);

endmodule
