//

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.07.2026 14:42:59
// Design Name: 
// Module Name: spi_protocol
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


module spi_protocol(
        input clk,
        input rst,
        input start,
        input miso,
        input [7:0] tx_data,
    
        output reg mosi,
        output reg cs,
        output reg sclk,
        output reg done,
        output reg [7:0] rx_data
    );
    
        // FSM States
        parameter IDLE    = 2'd0;
        parameter SHIFT   = 2'd1;
        parameter DONE_ST = 2'd2;
    
        reg [1:0] state;
    
        // Registers
        reg [7:0] shift_out;
        reg [7:0] shift_in;
    
        reg [6:0] clk_cnt;
        reg [3:0] bit_cnt;
    
        reg sclk_en;
        reg sclk_r;
        reg sclk_d;
    
        wire sclk_rise;
        wire sclk_fall;
    
        //-------------------------------------------------------
        // SPI Clock Divider (100MHz -> 1MHz)
        //-------------------------------------------------------
    
        always @(posedge clk)
        begin
            if(rst)
            begin
                clk_cnt <= 0;
                sclk_r  <= 0;
            end
            else if(sclk_en)
            begin
                if(clk_cnt == 49)
                begin
                    clk_cnt <= 0;
                    sclk_r  <= ~sclk_r;
                end
                else
                    clk_cnt <= clk_cnt + 1;
            end
            else
            begin
                clk_cnt <= 0;
                sclk_r  <= 0;
            end
        end
    
        //-------------------------------------------------------
        // Output SPI Clock
        //-------------------------------------------------------
    
        always @(*)
            sclk = sclk_r;
    
        //-------------------------------------------------------
        // Edge Detection
        //-------------------------------------------------------
    
        always @(posedge clk)
        begin
            if(rst)
                sclk_d <= 0;
            else
                sclk_d <= sclk_r;
        end
    
        assign sclk_rise =  sclk_r & ~sclk_d;
        assign sclk_fall = ~sclk_r &  sclk_d;
    
        //-------------------------------------------------------
        // SPI FSM
        //-------------------------------------------------------
    
        always @(posedge clk)
        begin
            if(rst)
            begin
                state     <= IDLE;
                cs        <= 1'b1;
                done      <= 1'b0;
                sclk_en   <= 1'b0;
                bit_cnt   <= 0;
                shift_out <= 0;
                shift_in  <= 0;
                rx_data   <= 0;
                mosi      <= 0;
            end
            else
            begin
                done <= 1'b0;
    
                case(state)
    
                //-------------------------------------------------
                // IDLE
                //-------------------------------------------------
    
                IDLE:
                begin
                    cs <= 1'b1;
    
                    if(start)
                    begin
                        cs        <= 1'b0;
                        shift_out <= tx_data;
                        shift_in  <= 8'd0;
                        bit_cnt   <= 0;
                        sclk_en   <= 1'b1;
    
                        mosi <= tx_data[7];
    
                        state <= SHIFT;
                    end
                end
    
                //-------------------------------------------------
                // SHIFT
                //-------------------------------------------------
    
                SHIFT:
                begin
                    // Sample MISO on Rising Edge
                    if(sclk_rise)
                    begin
                        shift_in <= {shift_in[6:0], miso};
                    end
    
                    // Shift MOSI on Falling Edge
                    if(sclk_fall)
                    begin
                        if(bit_cnt == 7)
                        begin
                            sclk_en <= 1'b0;
                            state   <= DONE_ST;
                        end
                        else
                        begin
                            bit_cnt   <= bit_cnt + 1;
                            shift_out <= {shift_out[6:0],1'b0};
                            mosi      <= shift_out[6];
                        end
                    end
                end
    
                //-------------------------------------------------
                // DONE
                //-------------------------------------------------
    
                DONE_ST:
                begin
                    cs      <= 1'b1;
                    done    <= 1'b1;
                    rx_data <= shift_in;
    
                    state <= IDLE;
                end
    
                default:
                    state <= IDLE;
    
                endcase
            end
        end
    
endmodule
