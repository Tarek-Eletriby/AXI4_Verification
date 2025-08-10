timeunit 1ns; timeprecision 1ps;
interface axi4_if #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16
)(
    input logic ACLK
);

    logic ARESETn;

    // Write address channel
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic [7:0]            AWLEN;
    logic [2:0]            AWSIZE;
    logic                  AWVALID;
    logic                  AWREADY;

    // Write data channel
    logic [DATA_WIDTH-1:0] WDATA;
    logic                  WVALID;
    logic                  WLAST;
    logic                  WREADY;

    // Write response channel
    logic [1:0]            BRESP;
    logic                  BVALID;
    logic                  BREADY;

    // Read address channel
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic [7:0]            ARLEN;
    logic [2:0]            ARSIZE;
    logic                  ARVALID;
    logic                  ARREADY;

    // Read data channel
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0]            RRESP;
    logic                  RVALID;
    logic                  RLAST;
    logic                  RREADY;

    // Modport for DUT
    modport dut_mp (
        input ACLK, ARESETn,
              AWADDR, AWLEN, AWSIZE, AWVALID,
              WDATA, WVALID, WLAST,
              BREADY,
              ARADDR, ARLEN, ARSIZE, ARVALID,
              RREADY,

        output AWREADY,
               WREADY,
               BRESP, BVALID,
               ARREADY,
               RDATA, RRESP, RVALID, RLAST
    );

    // Modport for TB
    modport tb_mp (
        input ACLK,
              AWREADY,
              WREADY,
              BRESP, BVALID,
              ARREADY,
              RDATA, RRESP, RVALID, RLAST,

        output ARESETn,
               AWADDR, AWLEN, AWSIZE, AWVALID,
               WDATA, WVALID, WLAST,
               BREADY,
               ARADDR, ARLEN, ARSIZE, ARVALID,
               RREADY
    );

endinterface
