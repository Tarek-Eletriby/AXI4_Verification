timeunit 1ns; timeprecision 1ps;
module axi4_tb(axi4_if.tb_mp axi_if);
`include "axi4_transaction.sv"

  axi4_transaction stim_array[];
  logic [31:0] sim_output[$];
  logic [31:0] expected_output[$];

  // Functional coverage for basic AXI activity and ranges
  covergroup cg_axi @(posedge axi_if.ACLK);
    option.per_instance = 1;

    // Write address coverage
    coverpoint axi_if.AWVALID iff (axi_if.AWREADY) { bins aw = {1}; }
    coverpoint axi_if.AWLEN { bins short_len[] = {[0:3]}; bins med_len[] = {[4:7]}; bins long_len[] = {[8:15]}; }
    coverpoint axi_if.AWSIZE { bins size = {3'd2}; }

    // Read address coverage
    coverpoint axi_if.ARVALID iff (axi_if.ARREADY) { bins ar = {1}; }
    coverpoint axi_if.ARLEN { bins short_len[] = {[0:3]}; bins med_len[] = {[4:7]}; bins long_len[] = {[8:15]}; }
    coverpoint axi_if.ARSIZE { bins size = {3'd2}; }

    // Data channel
    coverpoint axi_if.WVALID iff (axi_if.WREADY) { bins w = {1}; }
    coverpoint axi_if.WLAST { bins last0 = {0}; bins last1 = {1}; }

    // Read data
    coverpoint axi_if.RVALID iff (axi_if.RREADY) { bins r = {1}; }
    coverpoint axi_if.RLAST { bins last0 = {0}; bins last1 = {1}; }

    // Response
    coverpoint axi_if.BVALID iff (axi_if.BREADY) { bins b = {1}; }
    coverpoint axi_if.BRESP { bins okay = {2'b00}; bins err = {2'b10}; }
    coverpoint axi_if.RRESP { bins okay = {2'b00}; bins err = {2'b10}; }

    // Cross coverage for burst length vs last
    cross axi_if.AWLEN, axi_if.WLAST;
    cross axi_if.ARLEN, axi_if.RLAST;
  endgroup

  cg_axi cov = new();

  function void configure_stim_storage(int n);
    stim_array = new[n];
    sim_output.delete();
    expected_output.delete();
  endfunction

  task automatic generate_stimulus();
    foreach (stim_array[i]) begin
      stim_array[i] = new();
      assert(stim_array[i].randomize());
      stim_array[i].wdata = new[stim_array[i].awlen + 1];
      foreach (stim_array[i].wdata[j]) begin
        stim_array[i].wdata[j] = $urandom();
      end
    end
  endtask

  task automatic drive_stim();
    foreach (stim_array[i]) begin
      // Write Address
      @(negedge axi_if.ACLK);
      axi_if.AWADDR  = stim_array[i].awaddr;
      axi_if.AWLEN   = stim_array[i].awlen;
      axi_if.AWSIZE  = stim_array[i].awsize;
      axi_if.AWVALID = 1;
      wait (axi_if.AWREADY);
      @(negedge axi_if.ACLK);
      axi_if.AWVALID = 0;

      // Write Data
      for (int j = 0; j <= stim_array[i].awlen; j++) begin
        axi_if.WDATA  = stim_array[i].wdata[j];
        axi_if.WVALID = 1;
        axi_if.WLAST  = (j == stim_array[i].awlen);
        wait (axi_if.WREADY);
        @(negedge axi_if.ACLK);
        axi_if.WVALID = 0;
        axi_if.WLAST  = 0;
      end

      // Write Response
      wait (axi_if.BVALID);
      @(negedge axi_if.ACLK);
      axi_if.BREADY = 1;
      @(negedge axi_if.ACLK);
      axi_if.BREADY = 0;

      // Read Address (use same address)
      @(negedge axi_if.ACLK);
      axi_if.ARADDR  = stim_array[i].araddr; // mirror constraint ensures same as awaddr
      axi_if.ARLEN   = stim_array[i].arlen;
      axi_if.ARSIZE  = stim_array[i].arsize;
      axi_if.ARVALID = 1;
      wait (axi_if.ARREADY);
      @(negedge axi_if.ACLK);
      axi_if.ARVALID = 0;

      // Read Data
      for (int j = 0; j <= stim_array[i].arlen; j++) begin
        wait (axi_if.RVALID);
        sim_output.push_back(axi_if.RDATA);
        axi_if.RREADY = 1;
        @(negedge axi_if.ACLK);
        axi_if.RREADY = 0;
      end
    end
  endtask

  // Directed illegal stimuli to hit error coverage bins (not checked by scoreboard)
  task automatic drive_illegal_stim();
    // Illegal write: out-of-range address
    @(negedge axi_if.ACLK);
    axi_if.AWADDR  = 16'hF000;
    axi_if.AWLEN   = 8'd1;
    axi_if.AWSIZE  = 3'd2;
    axi_if.AWVALID = 1;
    wait (axi_if.AWREADY);
    @(negedge axi_if.ACLK);
    axi_if.AWVALID = 0;

    for (int j = 0; j <= 1; j++) begin
      axi_if.WDATA  = $urandom();
      axi_if.WVALID = 1;
      axi_if.WLAST  = (j == 1);
      wait (axi_if.WREADY);
      @(negedge axi_if.ACLK);
      axi_if.WVALID = 0;
      axi_if.WLAST  = 0;
    end

    wait (axi_if.BVALID);
    @(negedge axi_if.ACLK);
    axi_if.BREADY = 1;
    @(negedge axi_if.ACLK);
    axi_if.BREADY = 0;

    // Illegal write: 4KB boundary crossing
    @(negedge axi_if.ACLK);
    axi_if.AWADDR  = 16'h0FF0; // 16 bytes before 0x1000 boundary
    axi_if.AWLEN   = 8'd4;     // 5 beats -> 20 bytes, crosses
    axi_if.AWSIZE  = 3'd2;
    axi_if.AWVALID = 1;
    wait (axi_if.AWREADY);
    @(negedge axi_if.ACLK);
    axi_if.AWVALID = 0;

    for (int k = 0; k <= 4; k++) begin
      axi_if.WDATA  = $urandom();
      axi_if.WVALID = 1;
      axi_if.WLAST  = (k == 4);
      wait (axi_if.WREADY);
      @(negedge axi_if.ACLK);
      axi_if.WVALID = 0;
      axi_if.WLAST  = 0;
    end

    wait (axi_if.BVALID);
    @(negedge axi_if.ACLK);
    axi_if.BREADY = 1;
    @(negedge axi_if.ACLK);
    axi_if.BREADY = 0;

    // Illegal read: out-of-range address
    @(negedge axi_if.ACLK);
    axi_if.ARADDR  = 16'hF000;
    axi_if.ARLEN   = 8'd1;
    axi_if.ARSIZE  = 3'd2;
    axi_if.ARVALID = 1;
    wait (axi_if.ARREADY);
    @(negedge axi_if.ACLK);
    axi_if.ARVALID = 0;

    for (int j = 0; j <= 1; j++) begin
      wait (axi_if.RVALID);
      axi_if.RREADY = 1;
      @(negedge axi_if.ACLK);
      axi_if.RREADY = 0;
    end

    // Illegal read: 4KB boundary crossing
    @(negedge axi_if.ACLK);
    axi_if.ARADDR  = 16'h0FF0;
    axi_if.ARLEN   = 8'd4;
    axi_if.ARSIZE  = 3'd2;
    axi_if.ARVALID = 1;
    wait (axi_if.ARREADY);
    @(negedge axi_if.ACLK);
    axi_if.ARVALID = 0;

    for (int m = 0; m <= 4; m++) begin
      wait (axi_if.RVALID);
      axi_if.RREADY = 1;
      @(negedge axi_if.ACLK);
      axi_if.RREADY = 0;
    end
  endtask

  task automatic golden_model();
    foreach (stim_array[i]) begin
      foreach (stim_array[i].wdata[j]) begin
        expected_output.push_back(stim_array[i].wdata[j]);
      end
    end
  endtask

  task check_results();
    automatic int errors = 0;
    for (int i = 0; i < sim_output.size(); i++) begin
      if (sim_output[i] !== expected_output[i]) begin
        $error("[MISMATCH] sim = %h, expected = %h", sim_output[i], expected_output[i]);
        errors++;
      end else begin
        $display("[MATCH] sim = %h", sim_output[i]);
      end
    end
    if (errors == 0) $display("\nAll checks passed!\n");
    else $display("\nTotal mismatches: %0d\n", errors);
  endtask

  initial begin
    $timeformat(-9, 0, " ns", 10);
    $display("[TB] Start at %0t", $time);

    // Init TB-driven signals
    axi_if.AWADDR  = '0;
    axi_if.AWLEN   = '0;
    axi_if.AWSIZE  = '0;
    axi_if.AWVALID = 0;
    axi_if.WDATA   = '0;
    axi_if.WVALID  = 0;
    axi_if.WLAST   = 0;
    axi_if.BREADY  = 0;
    axi_if.ARADDR  = '0;
    axi_if.ARLEN   = '0;
    axi_if.ARSIZE  = '0;
    axi_if.ARVALID = 0;
    axi_if.RREADY  = 0;

    axi_if.ARESETn = 0;
    repeat (4) @(negedge axi_if.ACLK);
    axi_if.ARESETn = 1;

    configure_stim_storage(20);
    generate_stimulus();
    drive_stim();
    golden_model();
    check_results();

    // Error coverage samples (not checked against expected_output)
    drive_illegal_stim();

    // Display functional coverage summary
    $display("Functional coverage: %0.2f%%", cov.get_inst_coverage());

    $display("[TB] Finish at %0t", $time);
    $finish;
  end

  // Watchdog to ensure log output even if stalled
  initial begin
    #100000ns;
    $display("[TB][TIMEOUT] No completion by %0t", $time);
    $finish;
  end
endmodule

