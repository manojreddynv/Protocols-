// =====================================================================
// SPI Master - Mode 0 (CPOL = 0, CPHA = 0) - Plain Verilog (IEEE 1364)
//   - SCLK idles LOW
//   - Data sampled on RISING edge (MISO -> shift_in)
//   - Data shifted/changed on FALLING edge (shift_out -> MOSI)
//   - Full-duplex: TX and RX happen in the same clock cycle
//   - Default CLK_DIV=50 => 100MHz sys clk / (2*50) = 1MHz SCLK
// =====================================================================
module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIV    = 50,          // 100MHz / (2*50) = 1MHz SCLK
    parameter CNT_WIDTH  = 6            // >= clog2(CLK_DIV); widen if CLK_DIV grows
)(
    input  wire                   clk,        // 100 MHz system clock
    input  wire                   rst_n,
    input  wire                   start,
    input  wire [DATA_WIDTH-1:0]  tx_data,
    output reg  [DATA_WIDTH-1:0]  rx_data,
    output reg                    busy,
    output reg                    done,

    // SPI pins
    output reg                    sclk,       // idles LOW (CPOL=0)
    output reg                    mosi,
    input  wire                   miso,
    output reg                    cs_n
);

    // ---- FSM state encoding ----
    localparam IDLE     = 2'd0;
    localparam SHIFT    = 2'd1;
    localparam DONE_ST  = 2'd2;

    reg [1:0]              state;
    reg [$clog2(DATA_WIDTH):0] bit_cnt;
    reg [DATA_WIDTH-1:0]   shift_out;
    reg [DATA_WIDTH-1:0]   shift_in;
    reg [CNT_WIDTH-1:0]    clk_cnt;
    reg                    sclk_en, sclk_r;
    reg                    sclk_d;
    wire                   sclk_rise, sclk_fall;

    // Clock divider for SCLK (idles low -> CPOL=0)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            sclk_r  <= 1'b0;      // CPOL=0: idle low
        end else if (sclk_en) begin
            if (clk_cnt == CLK_DIV-1) begin
                clk_cnt <= 0;
                sclk_r  <= ~sclk_r;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end else begin
            clk_cnt <= 0;
            sclk_r  <= 1'b0;
        end
    end

    always @(*) sclk = sclk_r;

    // Registered edge detector
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sclk_d <= 1'b0;
        else
            sclk_d <= sclk_r;
    end

    assign sclk_rise = sclk_r & ~sclk_d;   // sclk_r just went 0 -> 1 (SAMPLE, CPHA=0)
    assign sclk_fall = ~sclk_r & sclk_d;   // sclk_r just went 1 -> 0 (SHIFT,  CPHA=0)

    // FSM ststes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            cs_n      <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
            sclk_en   <= 1'b0;
            bit_cnt   <= 0;
            shift_out <= 0;
            shift_in  <= 0;
            mosi      <= 1'b0;
            rx_data   <= 0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    cs_n <= 1'b1;
                    if (start) begin
                        shift_out <= tx_data;
                        bit_cnt   <= 0;
                        cs_n      <= 1'b0;
                        busy      <= 1'b1;
                        sclk_en   <= 1'b1;
                        mosi      <= tx_data[DATA_WIDTH-1]; // MSB first, set up before 1st rising edge
                        state     <= SHIFT;
                    end
                end

                SHIFT: begin
                    // CPHA=0: sample MISO on rising edge
                    if (sclk_rise) begin
                        shift_in <= {shift_in[DATA_WIDTH-2:0], miso};
                    end
                    // CPHA=0: shift out next bit on falling edge
                    if (sclk_fall) begin
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == DATA_WIDTH-1) begin
                            sclk_en <= 1'b0;
                            state   <= DONE_ST;
                        end else begin
                            shift_out <= {shift_out[DATA_WIDTH-2:0], 1'b0};
                            mosi      <= shift_out[DATA_WIDTH-2];
                        end
                    end
                end
                DONE_ST: begin
                    cs_n    <= 1'b1;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    rx_data <= shift_in;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

