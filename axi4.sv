timeunit 1ns; timeprecision 1ps;
module axi4 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter MEMORY_DEPTH = 1024
)(axi4_if.dut_mp axi_if);

    // Internal memory signals
    reg mem_en, mem_we;
    reg [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    reg [DATA_WIDTH-1:0] mem_wdata;
    wire [DATA_WIDTH-1:0] mem_rdata;

    // Address and burst management
    reg [ADDR_WIDTH-1:0] write_addr, read_addr;
    reg [7:0] write_burst_len, read_burst_len;
    reg [7:0] write_burst_cnt, read_burst_cnt;
    reg [2:0] write_size, read_size;
    
    wire [ADDR_WIDTH-1:0] write_addr_incr,read_addr_incr;
    
    // Added declarations for boundary and address validity checks
    reg write_boundary_cross_burst;
    reg read_boundary_cross_burst;
    wire write_addr_valid;
    wire read_addr_valid;
    
    
    
    // Address increment calculation
    assign  write_addr_incr = (1 << write_size);
    assign  read_addr_incr  = (1 << read_size);
    
    // Address boundary check (4KB boundary = 12 bits) - latched per burst at address handshake
    // The flags are computed once from the starting address and full burst length
    
    // Address range check
    assign write_addr_valid = (write_addr >> 2) < MEMORY_DEPTH;
    assign read_addr_valid = (read_addr >> 2) < MEMORY_DEPTH;

    // Memory instance
    axi4_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH($clog2(MEMORY_DEPTH)),
        .DEPTH(MEMORY_DEPTH)
    ) mem_inst (
        .clk(axi_if.ACLK),
        .rst_n(axi_if.ARESETn),
        .mem_en(mem_en),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata)
    );

    // FSM states
    reg [2:0] write_state;
    localparam W_IDLE = 3'd0,
               W_ADDR = 3'd1,
               W_DATA = 3'd2,
               W_RESP = 3'd3;

    reg [2:0] read_state;
    localparam R_IDLE = 3'd0,
               R_ADDR = 3'd1,
               R_DATA = 3'd2,
               R_WAIT = 3'd3, // wait one cycle for memory to see mem_en/address
               R_PIPE = 3'd4; // extra cycle to capture mem_rdata into register

    // Registered memory read data for timing
    reg [DATA_WIDTH-1:0] mem_rdata_reg;

    always @(posedge axi_if.ACLK or negedge axi_if.ARESETn) begin
        if (!axi_if.ARESETn) begin
            // Reset all outputs
            axi_if.AWREADY <= 1'b1;  // Ready to accept address
            axi_if.WREADY <= 1'b0;
            axi_if.BVALID <= 1'b0;
            axi_if.BRESP <= 2'b00;
            
            axi_if.ARREADY <= 1'b1;  // Ready to accept address
            axi_if.RVALID <= 1'b0;
            axi_if.RRESP <= 2'b00;
            axi_if.RDATA <= {DATA_WIDTH{1'b0}};
            axi_if.RLAST <= 1'b0;
            
            // Reset internal state
            write_state <= W_IDLE;
            read_state <= R_IDLE;
            mem_en <= 1'b0;
            mem_we <= 1'b0;
            mem_addr <= {$clog2(MEMORY_DEPTH){1'b0}};
            mem_wdata <= {DATA_WIDTH{1'b0}};
            
            // Reset address tracking
            write_addr <= {ADDR_WIDTH{1'b0}};
            read_addr <= {ADDR_WIDTH{1'b0}};
            write_burst_len <= 8'b0;
            read_burst_len <= 8'b0;
            write_burst_cnt <= 8'b0;
            read_burst_cnt <= 8'b0;
            write_size <= 3'b0;
            read_size <= 3'b0;
            
            mem_rdata_reg <= {DATA_WIDTH{1'b0}};
            
        end else begin
            // Default memory disable
            mem_en <= 1'b0;
            mem_we <= 1'b0;

            // --------------------------
            // Write Channel FSM
            // --------------------------
            case (write_state)
                W_IDLE: begin
                    axi_if.AWREADY <= 1'b1;
                    axi_if.WREADY <= 1'b0;
                    axi_if.BVALID <= 1'b0;
                    
                    if (axi_if.AWVALID && axi_if.AWREADY) begin
                        // Capture address phase information
                        write_addr <= axi_if.AWADDR;
                        write_burst_len <= axi_if.AWLEN;
                        write_burst_cnt <= axi_if.AWLEN;
                        write_size <= axi_if.AWSIZE;
                        // Latch boundary-cross status for the whole burst
                        write_boundary_cross_burst <= ((axi_if.AWADDR & 12'hFFF) + (axi_if.AWLEN << axi_if.AWSIZE)) > 12'hFFF;
                        
                        axi_if.AWREADY <= 1'b0;
                        write_state <= W_ADDR;
                    end
                end
                
                W_ADDR: begin
                    // Transition to data phase
                    axi_if.WREADY <= 1'b1;
                    write_state <= W_DATA;
                end
                
                W_DATA: begin
                    if (axi_if.WVALID && axi_if.WREADY) begin
                        // Check if address is valid
                        if (write_addr_valid && !write_boundary_cross_burst) begin
                            // Perform write operation
                            mem_en <= 1'b1;
                            mem_we <= 1'b1;
                            mem_addr <= write_addr >> 2;  // Convert to word address
                            mem_wdata <= axi_if.WDATA;
                        end
                        
                        // Check for last transfer
                        if (axi_if.WLAST || write_burst_cnt == 0) begin
                            axi_if.WREADY <= 1'b0;
                            write_state <= W_RESP;
                            
                            // Set response - delayed until write completion
                            if (!write_addr_valid || write_boundary_cross_burst) begin
                                axi_if.BRESP <= 2'b10;  // SLVERR
                            end else begin
                                axi_if.BRESP <= 2'b00;  // OKAY
                            end
                            axi_if.BVALID <= 1'b1;
                        end else begin
                            // Continue burst - increment address
                            write_addr <= write_addr + write_addr_incr;
                            write_burst_cnt <= write_burst_cnt - 1'b1;
                        end
                    end
                end
                
                W_RESP: begin
                    if (axi_if.BREADY && axi_if.BVALID) begin
                        axi_if.BVALID <= 1'b0;
                        axi_if.BRESP <= 2'b00;
                        write_state <= W_IDLE;
                    end
                end
                
                default: write_state <= W_IDLE;
            endcase

            // --------------------------
            // Read Channel FSM
            // --------------------------
            case (read_state)
                R_IDLE: begin
                    axi_if.ARREADY <= 1'b1;
                    axi_if.RVALID <= 1'b0;
                    axi_if.RLAST <= 1'b0;
                    
                    if (axi_if.ARVALID && axi_if.ARREADY) begin
                        // Capture address phase information
                        read_addr <= axi_if.ARADDR;
                        read_burst_len <= axi_if.ARLEN;
                        read_burst_cnt <= axi_if.ARLEN;
                        read_size <= axi_if.ARSIZE;
                        // Latch boundary-cross status for the whole burst
                        read_boundary_cross_burst <= ((axi_if.ARADDR & 12'hFFF) + (axi_if.ARLEN << axi_if.ARSIZE)) > 12'hFFF;
                        
                        axi_if.ARREADY <= 1'b0;
                        read_state <= R_ADDR;
                    end
                end
                
                R_ADDR: begin
                    // Prepare to issue memory read for first beat next cycle
                    // Wait for memory to latch enable/address (synchronous read)
                    read_state <= R_WAIT;
                end

                R_WAIT: begin
                    // Assert memory enable for one cycle with current read_addr
                    if (read_addr_valid && !read_boundary_cross_burst) begin
                        mem_en <= 1'b1;
                        mem_addr <= read_addr >> 2;  // Convert to word address
                    end
                    // Extra pipeline stage for synchronous memory to produce data
                    read_state <= R_PIPE;
                end

                R_PIPE: begin
                    // Capture memory output into a register for stable presentation
                    mem_rdata_reg <= mem_rdata;
                    read_state <= R_DATA;
                end
                
                R_DATA: begin
                    // Present read data from registered value
                    if (read_addr_valid && !read_boundary_cross_burst) begin
                        axi_if.RDATA <= mem_rdata_reg;
                        axi_if.RRESP <= 2'b00;  // OKAY
                    end else begin
                        axi_if.RDATA <= {DATA_WIDTH{1'b0}};
                        axi_if.RRESP <= 2'b10;  // SLVERR
                    end
                    
                    axi_if.RVALID <= 1'b1;
                    axi_if.RLAST <= (read_burst_cnt == 0);
                    
                    if (axi_if.RREADY && axi_if.RVALID) begin
                        axi_if.RVALID <= 1'b0;
                        
                        if (read_burst_cnt > 0) begin
                            // Continue burst: update address and count; mem_en will be asserted in R_WAIT next cycle
                            read_addr <= read_addr + read_addr_incr;
                            read_burst_cnt <= read_burst_cnt - 1'b1;
                            
                            // Wait for next data through pipeline
                            read_state <= R_WAIT;
                        end else begin
                            // End of burst
                            axi_if.RLAST <= 1'b0;
                            read_state <= R_IDLE;
                        end
                    end
                end
                
                default: read_state <= R_IDLE;
            endcase
        end
    end

endmodule