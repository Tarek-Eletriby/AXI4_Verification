class axi4_transaction;
  rand logic [15:0] awaddr;
  rand logic [7:0]  awlen;
  rand logic [2:0]  awsize;
  rand logic [15:0] araddr;
  rand logic [7:0]  arlen;
  rand logic [2:0]  arsize;

  rand logic [31:0] wdata[]; 

  // Reasonable ranges and alignment
  constraint burst_length_c {
    awlen inside {[0:15]};
    arlen inside {[0:15]};
  }

  // Ensure addresses are word aligned when DATA_WIDTH=32 (AWSIZE=2)
  constraint word_align {
    awaddr[1:0] == 2'b00;
    araddr[1:0] == 2'b00;
  }

  // For this project, drive 32-bit beats and keep read to match write for simple checking
  constraint size_c {
    awsize == 3'd2; // 4 bytes per beat
    arsize == 3'd2;
  }

  // Keep generated transactions within memory and 4KB region boundaries
  // Memory depth is 1024 words => 4096 bytes
  constraint legal_addr_range_c {
    awaddr inside {[16'd0 : 16'd4092]};
    araddr inside {[16'd0 : 16'd4092]};
  }

  // Ensure total byte span stays within memory and does not cross 4KB boundary
  constraint no_overflow_no_4kb_cross_c {
    // stay within memory size
    (awaddr + (awlen << awsize)) <= 16'd4092;
    (araddr + (arlen << arsize)) <= 16'd4092;
    // do not cross 4KB boundary according to DUT's check
    ((awaddr & 16'h0FFF) + (awlen << awsize)) <= 16'h0FFF;
    ((araddr & 16'h0FFF) + (arlen << arsize)) <= 16'h0FFF;
  }

  // Use same address and burst length for readback as write
  constraint mirror_read_c {
    araddr == awaddr;
    arlen  == awlen;
  }

  function new();
    wdata = new[0];
  endfunction
endclass
