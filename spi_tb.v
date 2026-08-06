
module spi_tb;

    parameter DATA_WIDTH = 8;
    parameter CLK_DIV    = 50;
    parameter CNT_WIDTH  = 6;

    // Clock period: 100MHz system clock => 10ns period
    parameter CLK_PERIOD = 10;

    // Testbench Signals
    reg                   clk;
    reg                   rst_n;
    reg                   start;
    reg  [DATA_WIDTH-1:0] tx_data;
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  busy;
    wire                  done;

    // SPI Interface Signals
    wire                  sclk;
    wire                  mosi;
    reg                   miso;
    wire                  cs_n;

    // Simulated Peripheral Internal Registers
    reg [DATA_WIDTH-1:0] slave_tx_data;
    reg [DATA_WIDTH-1:0] slave_rx_data;
  

    // Instantiate the Unit Under Test
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV),
        .CNT_WIDTH(CNT_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );


    initial begin
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_tb);
    end


    // System Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Simulated Peripheral Behavior (SPI Mode 0)

    // Load default byte to send back to master when selected
    always @(negedge cs_n) begin
        slave_tx_data <= 8'h3C;
        miso          <= 8'h3C >> 7;   // Drive MSB immediately
    end

    // Sample MOSI from Master on Rising Edge
    always @(posedge sclk) begin
        if (!cs_n) begin
            slave_rx_data <= {slave_rx_data[6:0], mosi};
        end
    end

    // Shift MISO out on Falling Edge
    always @(negedge sclk) begin
        if (!cs_n) begin
            slave_tx_data <= {slave_tx_data[6:0], 1'b0};
            miso          <= slave_tx_data[6];
        end
    end
  

    // Test Sequence
    initial begin

        // Initialize Inputs
        rst_n         = 1'b0;
        start         = 1'b0;
        tx_data       = 8'h00;
        miso          = 1'b0;
        slave_tx_data = 8'h00;
        slave_rx_data = 8'h00;

        // Apply Reset
        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

      
        // Test Transaction 1
   
        $display("[%0t ns] Starting SPI Transfer #1: TX = 0xA5", $time);

        tx_data = 8'hA5;
        start   = 1'b1;
        #(CLK_PERIOD);
        start   = 1'b0;

        // Wait until transfer completes
        wait(done);

        $display("[%0t ns] Transfer #1 Complete!", $time);
        $display("Master Sent     : 0xA5");
        $display("Slave Received  : 0x%02X", slave_rx_data);
        $display("Slave Sent      : 0x3C");
        $display("Master Received : 0x%02X", rx_data);

        #(CLK_PERIOD * 20);

        // End Simulation
        $display("[%0t ns] Simulation Finished.", $time);
        $finish;
    end

endmodule
