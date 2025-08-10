module top;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;

    logic clk = 0;
    always #5ns clk = ~clk;

    // Instantiate interface and pass clock
    axi4_if #(DATA_WIDTH, ADDR_WIDTH)axi_if(clk);

    // DUT using DUT modport
    axi4 #(DATA_WIDTH, ADDR_WIDTH)axi4(.axi_if(axi_if));

    // TB using TB modport
    axi4_tb axi4_tb(.axi_if(axi_if));

endmodule
