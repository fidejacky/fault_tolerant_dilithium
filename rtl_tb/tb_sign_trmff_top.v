/*
 * From our research paper "High-Performance Hardware Implementation of CRYSTALS-Dilithium"
 * by Luke Beckwith, Duc Tri Nguyen, Kris Gaj
 * at George Mason University, USA
 * https://eprint.iacr.org/2021/1451.pdf
 * =============================================================================
 * Copyright (c) 2021 by Cryptographic Engineering Research Group (CERG)
 * ECE Department, George Mason University
 * Fairfax, VA, U.S.A.
 * Author: Luke Beckwith
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * =============================================================================
 * @author   Luke Beckwith <lbeckwit@gmu.edu>
 */


`timescale 1ns / 1ps
`define P 10



module tb_sign_trmff_top;
    reg clk = 1,  rst = 1, start = 0;

    localparam [2:0] sec_lvl = 2;
    reg [1:0] mode = 2;

    localparam NUM_TV = 5;

    reg valid_i,  ready_o;
    wire ready_i, valid_o;
    reg  [63:0] data_i;
    wire [63:0] data_o;

    //delay simulation due to global reset
    reg tb_enable = 0;

    initial begin
        tb_enable = 0;
        #200;
        tb_enable = 1;
    end


    combined_top DUT (
        clk,
        rst,
        start,
        mode,
        sec_lvl,
        valid_i,
        ready_i,
        data_i,
        valid_o,
        ready_o,
        data_o
    );

  localparam
    START     = 4'd0,
    LOAD_RHO  = 4'd1,
    LOAD_MLEN = 4'd2,
    LOAD_TR   = 4'd3,
    LOAD_M    = 4'd4,
    LOAD_K    = 4'd5,
    LOAD_S1   = 4'd6,
    LOAD_S2   = 4'd7,
    LOAD_T0   = 4'd8,
    UNLOAD_Z  = 4'd9,
    UNLOAD_H  = 4'd10,
    UNLOAD_C  = 4'd11;

  reg [4:0] state;
  integer ctr, c = 0, start_time;

  reg [0:18431] z_2 [NUM_TV-1:0];
  reg [0:671]   h_2 [NUM_TV-1:0];
  reg [0:255]   c_2 [NUM_TV-1:0];

  reg [0:3300*8-1] m_2    [NUM_TV-1:0];
  reg [0:15]       mlen_2 [NUM_TV-1:0];
  reg [0:255]      k_2    [NUM_TV-1:0];
  reg [0:255]      tr_2   [NUM_TV-1:0];
  reg [0:255]      rho_2  [NUM_TV-1:0];
  reg [0:13311]    t0_2   [NUM_TV-1:0];
  reg [0:3071]     s1_2   [NUM_TV-1:0];
  reg [0:3071]     s2_2   [NUM_TV-1:0];

  initial begin
    $readmemh("C:/Jacky/bachely_jacky/KAT/zs_2.txt",   z_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/h_2.txt",    h_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/c_2.txt",    c_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/rho_2.txt",  rho_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/m_2.txt",    m_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/mlen_2.txt", mlen_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/k_2.txt",    k_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/tr_2.txt",   tr_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/t0_2.txt",   t0_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/s1_2.txt",   s1_2);
    $readmemh("C:/Jacky/bachely_jacky/KAT/s2_2.txt",   s2_2);

    ctr   = 0;
    state = START;
    start = 0;
  end

  always @(posedge clk) begin
    if (!tb_enable) begin
        data_i  <= 0;
        valid_i <= 0;
        ready_o <= 0;
        start   <= 0;
        rst     <= 1;
    end
    else begin
        rst     <= 0;
        data_i  <= 0;
        valid_i <= 0;
        ready_o <= 0;
        start   <= 0;

        case(state)
        START: begin
            start_time <= $time;

            if (ctr == 0) begin
                rst <= 1;
            end

            if (ctr < 2) begin
                ctr    <= ctr + 1;
            end else begin
                ctr <= 0;
                start <= 1;
                state  <= LOAD_RHO;
            end
        end
        LOAD_RHO: begin
            data_i  <= rho_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 3) begin
                    state  <= LOAD_MLEN;
                    ctr    <= 0;
                    data_i  <= {48'd0, mlen_2[c]};
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= rho_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_MLEN: begin
            data_i  <= {48'd0, mlen_2[c]};
            valid_i <= 1;

            if (ready_i) begin
                state  <= LOAD_TR;
                ctr    <= 0;
                data_i <= tr_2[c][(0)*64+:64];
            end
        end
        LOAD_TR: begin
            data_i  <= tr_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 3) begin
                    state  <= LOAD_M;
                    ctr    <= 0;
                    data_i <= m_2[c][(0)*64+:64];
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= tr_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_M: begin
            data_i  <= m_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if ((ctr+1)*8 >= mlen_2[c]) begin
                    state  <= LOAD_K;
                    ctr    <= 0;
                    data_i <= k_2[c][(0)*64+:64];
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= m_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_K: begin
            data_i  <= k_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 3) begin
                    state  <= LOAD_S1;
                    data_i <= s1_2[c][(0)*64+:64];
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= k_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_S1: begin
            data_i  <= s1_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 47) begin
                    state  <= LOAD_S2;
                    data_i <= s2_2[c][(0)*64+:64];
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= s1_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_S2: begin
            data_i  <= s2_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 47) begin
                    state  <= LOAD_T0;
                    data_i <= t0_2[c][(ctr+1)*64+:64];
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= s2_2[c][(ctr+1)*64+:64];
                end
            end
        end
        LOAD_T0: begin
            data_i  <= t0_2[c][ctr*64+:64];
            valid_i <= 1;

            if (ready_i) begin
                if (ctr == 207) begin
                    state  <= UNLOAD_Z;
                    ctr    <= 0;
                end else begin
                    ctr    <= ctr + 1;
                    data_i <= t0_2[c][(ctr+1)*64+:64];
                end
            end
        end
        UNLOAD_Z: begin
            ready_o <= 1;
            if (valid_o) begin
                if (data_o !== z_2[c][ctr*64+:64])
                    $display("[Z, %d] Error: Expected %h, received %h", ctr, z_2[c][ctr*64+:64], data_o);

                ctr <= ctr + 1;

                if (ctr == 288-1) begin
                    ctr <= 0;
                    state <= UNLOAD_H;
                end
            end
        end
        UNLOAD_H: begin
            ready_o <= 1;
            if (valid_o) begin
                if (data_o != h_2[c][ctr*64+:64])
                    $display("[H, %d] Error: Expected %h, received %h", ctr, h_2[c][ctr*64+:64], data_o);

                ctr <= ctr + 1;

                if (ctr == 10) begin
                    ctr <= 0;
                    state <= UNLOAD_C;
                end
            end
        end
        UNLOAD_C: begin
            ready_o <= 1;
            if (valid_o) begin
                if (data_o != c_2[c][ctr*64+:64])
                    $display("[C, %d] Error: Expected %h, received %h", ctr, c_2[c][ctr*64+:64], data_o);

                ctr <= ctr + 1;

                if (ctr == 3) begin
                    ctr <= 0;
                    state <= START;
                    c <= c + 1;
                    $display("SG2[%d] completed in %d clock cycles", c, ($time-start_time)/10);

                    if (c == NUM_TV-1) begin
                        $display("Testbench Done.");
                        $finish;
                    end
                end
            end
        end
        endcase
    end
  end

  always #(`P/2) clk = ~clk;

endmodule
`undef P
