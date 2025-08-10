module axi4_tb(axi4_if.tb_mp axi_if);
`include "axi4_transaction.sv"

  axi4_transaction stim_array[];
  logic [31:0] sim_output[$];
  logic [31:0] expected_output[$];

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
      axi_if.ARADDR  = stim_array[i].awaddr;
      axi_if.ARLEN   = stim_array[i].awlen;
      axi_if.ARSIZE  = stim_array[i].awsize;
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
    axi_if.ARESETn = 0;
    #20ns;
    axi_if.ARESETn = 1;

    configure_stim_storage(10);
    generate_stimulus();
    drive_stim();
    golden_model();
    check_results();

    $finish;
  end
endmodule

