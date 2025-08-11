timeunit 1ns; timeprecision 1ps;
// Assertions and cover properties for AXI4-lite subset behavior used here
module axi4_assert_bind (axi4_if.dut_mp dut_if);

  // Default clocking and reset
  default clocking cb @(posedge dut_if.ACLK); endclocking
  default disable iff (!dut_if.ARESETn);

  // Handshake stability: VALID must remain asserted until READY
  property p_valid_stable(valid, ready);
    valid |-> valid until_with ready;
  endproperty

  // Use it for all channels we drive
  aw_valid_stable: assert property (p_valid_stable(dut_if.AWVALID, dut_if.AWREADY));
  w_valid_stable:  assert property (p_valid_stable(dut_if.WVALID,  dut_if.WREADY));
  ar_valid_stable: assert property (p_valid_stable(dut_if.ARVALID, dut_if.ARREADY));
  r_valid_stable:  assert property (p_valid_stable(dut_if.RVALID,  dut_if.RREADY));
  b_valid_stable:  assert property (p_valid_stable(dut_if.BVALID,  dut_if.BREADY));

  // Write address must precede write data acceptance sequence start
  sequence s_aw_hs;
    dut_if.AWVALID && dut_if.AWREADY;
  endsequence

  sequence s_w_hs;
    dut_if.WVALID && dut_if.WREADY;
  endsequence

  // After AW handshake, W handshake must eventually occur
  aw_then_w: assert property (s_aw_hs |-> ##[1:$] s_w_hs);

  // After last write data is accepted, BVALID should eventually assert
  last_w_then_b: assert property ((dut_if.WVALID && dut_if.WREADY && dut_if.WLAST) |-> ##[1:10] dut_if.BVALID);

  // When RVALID asserted, RRESP is OKAY or SLVERR only
  rresp_legal: assert property (dut_if.RVALID |-> (dut_if.RRESP inside {2'b00,2'b10}));
  bresp_legal: assert property (dut_if.BVALID |-> (dut_if.BRESP inside {2'b00,2'b10}));

  // Cover: observe at least one full write burst and read burst
  cover_full_write: cover property (s_aw_hs ##[1:$] (s_w_hs [*1:$]) ##[1:10] (dut_if.BVALID && dut_if.BREADY));
  cover_full_read:  cover property ((dut_if.ARVALID && dut_if.ARREADY) ##[1:$] (dut_if.RVALID && dut_if.RREADY && dut_if.RLAST));

endmodule

// Bind it in top or TB context
bind axi4 axi4_assert_bind axi4_sva(.dut_if(axi_if));