class axi4_transaction;
  rand logic [15:0] awaddr;
  rand logic [7:0]  awlen;
  rand logic [2:0]  awsize;
  rand logic [15:0] araddr;
  rand logic [7:0]  arlen;
  rand logic [2:0]  arsize;

  rand logic [31:0] wdata[]; // burst data array

  constraint burst_length_c {
    awlen inside {[0:15]};
    arlen inside {[0:15]};
  }

  constraint word_align {
    awaddr[1:0] == 2'b00;
    araddr[1:0] == 2'b00;
  }

  function new();
    wdata = new[0];
  endfunction
endclass
