`timescale 1ns/1ps
`default_nettype none
`include "params.vh"
`include "graph.vh"


module tb_npu_axi_each;
  // ============================================================================
  // TB Overview
  // ============================================================================
  // Main flow selection:
  //   main initial
  //   |- ALL_NPU_TESTS: select one isolated flow with +NPU_TEST_CASE
  //   |- NPU_FSM_CTRL_TB: run_npu_fsm_ctrl_test() from npu_fsm_ctrl_test.svh
  //   |- METADATA_TB: run_metadata_test()
  //   |  |- read_metadata_file()
  //   |  |- metadata_run_auto_issue_job()
  //   |  |  |- metadata_write_desc_to_dram()
  //   |  |  |- metadata_write_inst_to_dram()
  //   |  |  |- metadata_write_tensor_payloads_to_dram()
  //   |  |  |- pulse_npu_start()
  //   |  |  `- wait(done)
  //   |  |- build_metadata_sram_golden()
  //   |  `- check_metadata_result()
  //   `- default: run_metadata_test()
  //
  // Major helper groups:
  //   common timing/job/DRAM helpers -> payload builders -> golden helpers
  //   -> metadata parser/descriptor packers -> metadata job/auto-issue
  //   -> metadata shadow SRAM golden -> reset/main.
  // ============================================================================
  localparam real CLK_PERIOD = 1.0; // ns
  localparam real TB_DRIVE_DELAY = 0.001; // ns, 1ps: avoid delta race without wasting setup budget
`ifdef GATE
  localparam real CLOCK_START_DELAY = 20.0; // ns, let SDF/gate signals settle before first clock edge
`else
  localparam real CLOCK_START_DELAY = CLK_PERIOD;
`endif
  string npu_test_case;


  // ============================================================================
  // Clock and Basic Configuration
  // ============================================================================

  // ----------------------------------------------------------------------------
  // Clock / reset signals
  // ----------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    #(CLOCK_START_DELAY);
    forever #(CLK_PERIOD/2.0) clk = ~clk;
  end


  // ----------------------------------------------------------------------------
  // PE / max bounds
  // ----------------------------------------------------------------------------
  localparam int LANES = `LANES;
  localparam int PE_SIZE = LANES;

  localparam int MAX_M = 4096;
  localparam int MAX_K = 4096;
  localparam int MAX_N = 4096;

  // ----------------------------------------------------------------------------
  // LSU / DRAM address map
  // ----------------------------------------------------------------------------
  localparam logic [3:0] LSU_BANK_DATA   = 4'd0;
  localparam logic [3:0] LSU_BANK_WEIGHT = 4'd1;
  localparam logic [3:0] LSU_BANK_RESULT = 4'd3;
  localparam logic [3:0] LSU_BANK_LUT    = 4'd8;
  localparam logic [3:0] LSU_BANK_QDESC  = 4'd9;
  localparam logic [3:0] LSU_BANK_INST   = 4'd10;

  // localparam int unsigned A_DRAM_BASE   = 0;
  localparam int unsigned PROFILE_DRAM_BASE = 0;
  localparam int unsigned B_DRAM_BASE   = 1_000_000;
  localparam int unsigned LUT_DRAM_BASE = 2_000_000;
  localparam int unsigned OUT_DRAM_BASE = 3_000_000;
  localparam int unsigned EW_IN2_DRAM_BASE = 4_000_000;
  localparam int unsigned EW_IN1_DRAM_BASE = 4_500_000;
  localparam int unsigned INST_DRAM_BASE = 5_000_000;
  localparam int unsigned JOB_DRAM_BASE = 6_000_000;
  localparam int unsigned DESC_DRAM_BASE = 7_000_000;
  localparam int unsigned TENSOR_DMA_TABLE_DRAM_BASE = 7_100_000;
  localparam int unsigned TENSOR_PAYLOAD_DRAM_BASE = 7_200_000;
  localparam int INST_BITS = `INST_BITS;
  localparam int INST_PER_WORD = (`SRAM_WIDTH_O / INST_BITS);
  localparam int DESC_SLOT_BITS = `DESC_SLOT_BITS;
  localparam int DESC_PACKET_BITS = `DESC_PACKET_BITS;
  localparam int DESC_WORDS_PER_PACKET =
      (DESC_PACKET_BITS + (`SRAM_WIDTH_O) - 1) / (`SRAM_WIDTH_O);
  localparam int DESC_STORAGE_BITS = DESC_WORDS_PER_PACKET * `SRAM_WIDTH_O;
  localparam int DESC_LOC_BITS = 3 + `SRAM_ADDR_WIDTH;
  localparam logic [7:0] DESC_VERSION = 8'd1;
  localparam int EW_IS_NONE   = 0; // non-EW op
  localparam int EW_IS_UNARY  = 1; // unary EW op, src0 only
  localparam int EW_IS_BINARY = 2; // binary EW op, src0 + src1/input2

  // Bit offsets inside the job header word. The TB writes the values here;
  // the NPU LOAD_JOB state only unpacks them.
  localparam int JOB_DESC_WORD_LEN_LSB = 16;
  localparam int JOB_TENSOR_DMA_COUNT_LSB = 32;
  //Added Job header layout to track info across multiple job headers
  localparam int JOB_IS_LAST_LSB          = 47; // Bit 47
  localparam int JOB_RESULT_BASE_LSB      = 48; 
  localparam int JOB_INST_OFFSET_LSB      = 80; 
  localparam int JOB_DESC_OFFSET_LSB      = 96; // Hex 0x60 aligned
  localparam int JOB_DMA_OFFSET_LSB       = 112; // Hex 0x70 aligned
  

  localparam int TENSOR_DMA_SLOT_BITS = 32;
  localparam bit TENSOR_DMA_REPLAY_IN_GOLDEN = 1'b0;
  localparam bit TENSOR_DMA_MIRROR_NOW       = 1'b1;

  // ----------------------------------------------------------------------------
  // LUT preload layout
  // ----------------------------------------------------------------------------
  localparam int EXP_LUT_BASE_ADDR = 0;
  localparam int RCP_LUT_BASE_ADDR = 256;
  localparam int LUT_ENTRY_NUM     = 513;
  localparam int LUT_ENTRIES_PER_WORD = (`SRAM_WIDTH_O / `INT16_SIZE);
  localparam int LUT_WORD_NUM         = (LUT_ENTRY_NUM + LUT_ENTRIES_PER_WORD - 1) / LUT_ENTRIES_PER_WORD;

  logic [`INT16_SIZE-1:0] exp_lut [0:LUT_ENTRY_NUM-1];
  logic [`INT16_SIZE-1:0] rcp_lut [0:LUT_ENTRY_NUM-1];


  initial begin
    $dumpfile("waveform_axi_each.fst");
    $dumpvars(0, tb_npu_axi_each);
    `ifdef RTL
      // $fsdbDumpfile("verdi.fsdb");
      // $fsdbDumpvars(0, tb_npu_int16.dut.u_ew, "+all");
      // $fsdbDumpMDA();
    `endif

    `ifdef GATE
      // $sdf_annotate("../02_SYN/Netlist/SystolicArray_OS_INT8_REQUANT_SRAM_SYN.sdf", dut.u_sa);
      // $sdf_annotate("../02_SYN/Netlist/element_wise_LUT_SYN.sdf", dut.u_ew);
      $sdf_annotate("../02_SYN/Netlist/npu_int16_SYN.sdf", dut);

      // $fsdbDumpfile("verdi_SYN.fsdb");
      // $fsdbDumpvars(0, tb_npu_int16.dut.u_ew, "+all");
      // $fsdbDumpMDA();
    `endif
  end

  // ============================================================================
  // DUT Interface Signals
  // ============================================================================
  logic npu_start_i;
  wire done;


  // ----------------------------------------------------------------------------
  // DRAM model handshake
  // ----------------------------------------------------------------------------
  wire                        dram_rd_valid;
  logic                       dram_rd_ready;
  wire [`DRAM_ADDR_WIDTH-1:0]  dram_rd_addr;

  logic                       dram_rd_data_valid;
  logic [`SRAM_WIDTH_O-1:0]   dram_rd_data;

  wire                        dram_wr_valid;
  logic                       dram_wr_ready;
  wire [`DRAM_ADDR_WIDTH-1:0]  dram_wr_addr;
  wire [`SRAM_WIDTH_O-1:0]    dram_wr_data;

  // Sparse DRAM model.
  // This avoids allocating a huge packed memory.
  // logic [`SRAM_WIDTH_O-1:0] dram_mem [int unsigned];

  // Byte addressed dram
  logic [7:0] dram_mem [int unsigned];


  logic signed [`INT32_SIZE-1:0] conv_input_requant_multiplier, conv_input_requant_shift, conv_input_requant_offset;
  logic signed [`INT32_SIZE-1:0] conv_weight_requant_multiplier, conv_weight_requant_shift, conv_weight_requant_offset;
  logic signed [`INT32_SIZE-1:0] conv_input_activation_min, conv_input_activation_max;
  logic signed [`INT32_SIZE-1:0] conv_weight_activation_min, conv_weight_activation_max;

  logic signed [`INT32_SIZE-1:0] conv_qm;
  logic signed [`INT32_SIZE-1:0] shift;
  logic signed [`INT32_SIZE-1:0] conv_out_offset;
  logic signed [`INT32_SIZE-1:0] conv_act_min;
  logic signed [`INT32_SIZE-1:0] conv_act_max;

  // sub quant params
  logic signed [`INT32_SIZE-1:0] sub_input1_offset;
  logic signed [`INT32_SIZE-1:0] sub_input2_offset;
  logic signed [`INT32_SIZE-1:0] sub_left_shift;
  logic        [`INT32_SIZE-1:0] sub_input1_multiplier;
  logic        [`INT32_SIZE-1:0] sub_input2_multiplier;
  logic signed [`INT32_SIZE-1:0] sub_input1_shift;
  logic signed [`INT32_SIZE-1:0] sub_input2_shift;
  logic        [`INT32_SIZE-1:0] sub_output_multiplier;
  logic signed [`INT32_SIZE-1:0] sub_output_shift;
  logic signed [`INT32_SIZE-1:0] sub_output_offset;
  logic signed [`INT32_SIZE-1:0] sub_act_min;
  logic signed [`INT32_SIZE-1:0] sub_act_max;

  // add quant params
  logic signed [`INT32_SIZE-1:0] add_input1_offset;
  logic signed [`INT32_SIZE-1:0] add_input2_offset;
  logic signed [`INT32_SIZE-1:0] add_left_shift;
  logic        [`INT32_SIZE-1:0] add_input1_multiplier;
  logic        [`INT32_SIZE-1:0] add_input2_multiplier;
  logic signed [`INT32_SIZE-1:0] add_input1_shift;
  logic signed [`INT32_SIZE-1:0] add_input2_shift;
  logic        [`INT32_SIZE-1:0] add_output_multiplier;
  logic signed [`INT32_SIZE-1:0] add_output_shift;
  logic signed [`INT32_SIZE-1:0] add_output_offset;
  logic signed [`INT32_SIZE-1:0] add_act_min;
  logic signed [`INT32_SIZE-1:0] add_act_max;

  // mul quant params
  logic signed [`INT32_SIZE-1:0] mul_in1_multiplier; // for mul input reqaunt
  logic signed [`INT32_SIZE-1:0] mul_in1_shift;
  logic signed [`INT32_SIZE-1:0] mul_in1_offset;
  logic signed [`INT32_SIZE-1:0] mul_in1_act_min;
  logic signed [`INT32_SIZE-1:0] mul_in1_act_max;
  logic signed [`INT32_SIZE-1:0] mul_in2_multiplier;
  logic signed [`INT32_SIZE-1:0] mul_in2_shift;
  logic signed [`INT32_SIZE-1:0] mul_in2_offset;
  logic signed [`INT32_SIZE-1:0] mul_in2_act_min;
  logic signed [`INT32_SIZE-1:0] mul_in2_act_max;
  logic signed [`INT32_SIZE-1:0] mul_input1_offset; // for mul calculation
  logic signed [`INT32_SIZE-1:0] mul_input2_offset;
  logic        [`INT32_SIZE-1:0] mul_output_multiplier;
  logic signed [`INT32_SIZE-1:0] mul_output_shift;
  logic signed [`INT32_SIZE-1:0] mul_output_offset;
  logic signed [`INT32_SIZE-1:0] mul_act_min;
  logic signed [`INT32_SIZE-1:0] mul_act_max;

  // exp params
  logic signed [`INT32_SIZE-1:0] exp_deq_input_range_radius;
  logic signed [`INT32_SIZE-1:0] exp_deq_input_zero_point;
  logic signed [`INT32_SIZE-1:0] exp_deq_input_left_shift;
  logic        [`INT32_SIZE-1:0] exp_deq_input_multiplier;
  logic signed [`INT32_SIZE-1:0] exp_req_input_quantized_multiplier;
  logic signed [`INT32_SIZE-1:0] exp_req_input_shift;
  logic signed [`INT32_SIZE-1:0] exp_req_input_offset;

  // reciprocal params
  logic signed [`INT32_SIZE-1:0] reciprocal_deq_input_zero_point;
  logic signed [`INT32_SIZE-1:0] reciprocal_deq_input_range_radius;
  logic signed [`INT32_SIZE-1:0] reciprocal_deq_input_left_shift;
  logic        [`INT32_SIZE-1:0] reciprocal_deq_input_multiplier;
  logic signed [`INT32_SIZE-1:0] reciprocal_req_input_quantized_multiplier;
  logic signed [`INT32_SIZE-1:0] reciprocal_req_input_shift;
  logic signed [`INT32_SIZE-1:0] reciprocal_req_input_offset;

  wire busy;


   // ============================================================================
  // AXI4-Full Signals for FPGA Wrapper
  // ============================================================================
  wire [`DRAM_ADDR_WIDTH-1:0] m_axi_araddr, m_axi_awaddr;
  wire [7:0]                  m_axi_arlen, m_axi_awlen;
  wire [2:0]                  m_axi_arsize, m_axi_awsize;
  wire [1:0]                  m_axi_arburst, m_axi_awburst;
  wire                        m_axi_arvalid, m_axi_awvalid;
  logic                       m_axi_arready, m_axi_awready;

  wire [`SRAM_WIDTH_O-1:0]    m_axi_wdata;
  wire [(`SRAM_WIDTH_O/8)-1:0] m_axi_wstrb;
  wire                        m_axi_wlast, m_axi_wvalid;
  logic                       m_axi_wready;

  logic [`SRAM_WIDTH_O-1:0]   m_axi_rdata;
  logic                       m_axi_rvalid, m_axi_rlast;
  wire                        m_axi_rready;
  logic [1:0]                 m_axi_rresp;

  logic [1:0]                 m_axi_bresp;
  logic                       m_axi_bvalid;
  wire                        m_axi_bready;
  // // ============================================================================
  // // Behavioral AXI4-Full Sparse DRAM Slave Model
  // // ============================================================================
  // localparam int ADDR_SHIFT = $clog2(`SRAM_WIDTH_O / 8); // Must match wrapper: 16 bytes = 128 bits

  // // 1. AXI Read Channel Slave Handshake
  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) begin
  //     m_axi_arready <= 1'b1; // Always ready to accept read requests
  //     m_axi_rvalid  <= 1'b0;
  //     m_axi_rlast   <= 1'b0;
  //     m_axi_rresp   <= 2'b00; // OKAY response
  //     m_axi_rdata   <= '0;
  //   end else begin
  //     // Default auto-clear after master accepts data
  //     if (m_axi_rvalid && m_axi_rready) begin
  //       m_axi_rvalid <= 1'b0;
  //       m_axi_rlast  <= 1'b0;
  //     end

  //     // When Master requests a read and we are ready
  //     if (m_axi_arvalid && m_axi_arready) begin
  //       // Shift byte address back to word address for dram_mem lookup
  //       // m_axi_rdata  <= dram_mem[m_axi_araddr >> ADDR_SHIFT]; //word addressed dram


  //       //byte addressed dram
  //       logic [`SRAM_WIDTH_O-1:0] assembled_data;
  //       int i;
        
  //       assembled_data = '0;
  //       // Fetch 16 consecutive bytes to build the 128-bit read word
  //       for (i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
  //         if (dram_mem.exists(m_axi_araddr + i)) begin
  //           assembled_data[i*8 +: 8] = dram_mem[m_axi_araddr + i];
  //         end else begin
  //           assembled_data[i*8 +: 8] = 8'h00;
  //         end
  //       end
  //       m_axi_rdata  <= assembled_data;

  //       m_axi_rvalid <= 1'b1;
  //       // Since your wrapper sets arlen=0 (single-beat burst), every beat is the last
  //       m_axi_rlast  <= 1'b1; 
  //     end
  //   end
  // end

  // // 2. AXI Write Channel Slave Handshake (Handles AW, W, and B channels)
  // logic [`DRAM_ADDR_WIDTH-1:0] active_awaddr;
  // logic                       aw_latched, w_latched;

  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) begin
  //     m_axi_awready <= 1'b1;
  //     m_axi_wready  <= 1'b1;
  //     m_axi_bvalid  <= 1'b0;
  //     m_axi_bresp   <= 2'b00; // OKAY response
  //     aw_latched    <= 1'b0;
  //     w_latched     <= 1'b0;
  //     active_awaddr <= '0;
  //   end else begin
  //     // Latch Address when AW handshake occurs
  //     if (m_axi_awvalid && m_axi_awready) begin
  //       active_awaddr <= m_axi_awaddr;
  //       aw_latched    <= 1'b1;
  //     end

  //     // Latch Data and Write to Memory when W handshake occurs
  //     if (m_axi_wvalid && m_axi_wready) begin
  //       // If AW arrived on the same cycle or earlier, use active/current address
  //       logic [`DRAM_ADDR_WIDTH-1:0] target_addr;
  //       int i;
  //       target_addr = (m_axi_awvalid && m_axi_awready) ? m_axi_awaddr : active_awaddr;
        
  //       // dram_mem[target_addr >> ADDR_SHIFT] = m_axi_wdata; //word addressed

  //       //byte addressed
  //       // Deconstruct the 128-bit write word into 16 bytes, respecting the strobe
  //       for (i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
  //         if (m_axi_wstrb[i]) begin
  //           dram_mem[target_addr + i] = m_axi_wdata[i*8 +: 8];
  //         end
  //       end
      
  //       w_latched <= 1'b1;
  //     end

  //     // When both Address and Data have been captured, fire BVALID (Write Response)
  //     if ((aw_latched || (m_axi_awvalid && m_axi_awready)) && 
  //         (w_latched  || (m_axi_wvalid  && m_axi_wready))) begin
  //       m_axi_bvalid <= 1'b1;
  //       aw_latched   <= 1'b0;
  //       w_latched    <= 1'b0;
  //     end

  //     // Clear BVALID once the NPU wrapper acknowledges the write response
  //     if (m_axi_bvalid && m_axi_bready) begin
  //       m_axi_bvalid <= 1'b0;
  //     end
  //   end
  // end

  // ============================================================================
  // Behavioral AXI4-Full Sparse DRAM Slave Model (Burst Capable)
  // ============================================================================
  localparam int ADDR_SHIFT = $clog2(`SRAM_WIDTH_O / 8); 
  localparam int BYTES_PER_BEAT = 1 << ADDR_SHIFT;

  // ----------------------------------------------------------------------------
  // 1. AXI Read Channel Slave Handshake
  // ----------------------------------------------------------------------------
  logic r_burst_active;
  logic [7:0] r_beat_cnt;
  logic [7:0] r_len_reg;
  logic [`DRAM_ADDR_WIDTH-1:0] r_addr_reg;

  // Accept new read addresses only when not actively processing a burst
  assign m_axi_arready = !r_burst_active;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_burst_active <= 1'b0;
      m_axi_rvalid   <= 1'b0;
      m_axi_rlast    <= 1'b0;
      m_axi_rresp    <= 2'b00;
      r_beat_cnt     <= '0;
    end else begin
      
      // When Master requests a read and we are ready
      if (m_axi_arvalid && m_axi_arready) begin
        //4k boundary check
        logic [`DRAM_ADDR_WIDTH-1:0] ar_start_addr;
        logic [`DRAM_ADDR_WIDTH-1:0] ar_end_addr;
        ar_start_addr = m_axi_araddr;
        ar_end_addr   = m_axi_araddr + (m_axi_arlen * BYTES_PER_BEAT);

        if ((ar_start_addr >> 12) != (ar_end_addr >> 12)) begin
          $display("\n\033[31m[AXI SLAVE FATAL] 4KB Boundary Violation on AR Channel!\033[0m");
          $display("  Start Addr: 0x%08h (Page 0x%05h)", ar_start_addr, ar_start_addr >> 12);
          $display("  End Addr:   0x%08h (Page 0x%05h)", ar_end_addr, ar_end_addr >> 12);
          $display("  ARLEN:      %0d beats (%0d bytes)", m_axi_arlen + 1, (m_axi_arlen + 1) * BYTES_PER_BEAT);
          $finish;
        end


        r_burst_active <= 1'b1;
        r_addr_reg     <= m_axi_araddr;
        r_len_reg      <= m_axi_arlen;
        r_beat_cnt     <= 8'd0;
        
        m_axi_rvalid   <= 1'b1;
        m_axi_rlast    <= (m_axi_arlen == 8'd0) ? 1'b1 : 1'b0;
      end

      // When Master accepts read data during an active burst
      if (m_axi_rvalid && m_axi_rready) begin
        if (m_axi_rlast) begin
          // Burst finished
          m_axi_rvalid   <= 1'b0;
          m_axi_rlast    <= 1'b0;
          r_burst_active <= 1'b0;
        end else begin
          // Move to the next beat in the burst
          r_addr_reg <= r_addr_reg + BYTES_PER_BEAT;
          r_beat_cnt <= r_beat_cnt + 1;
          
          // If the next beat is the last one, assert RLAST
          if (r_beat_cnt + 1 == r_len_reg) begin
            m_axi_rlast <= 1'b1;
          end
        end
      end
    end
  end

  // Combinational logic to fetch bytes from sparse array based on current address
  always_comb begin
    logic [`SRAM_WIDTH_O-1:0] assembled_data;
    assembled_data = '0;
    if (m_axi_rvalid) begin
      for (int i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
        if (dram_mem.exists(r_addr_reg + i)) begin
          assembled_data[i*8 +: 8] = dram_mem[r_addr_reg + i];
        end else begin
          assembled_data[i*8 +: 8] = 8'h00;
        end
      end
    end
    m_axi_rdata = assembled_data;
  end


  // // ----------------------------------------------------------------------------
  // // 2. AXI Write Channel Slave Handshake (Handles AW, W, and B channels)
  // // ----------------------------------------------------------------------------
  // logic aw_active;
  // logic [`DRAM_ADDR_WIDTH-1:0] w_addr_reg;

  // // Accept AW if not currently writing and not waiting to send B response
  // assign m_axi_awready = !aw_active && !m_axi_bvalid; 
  // // Ready to receive W data once AW phase is captured
  // assign m_axi_wready  = aw_active;

  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) begin
  //     aw_active    <= 1'b0;
  //     m_axi_bvalid <= 1'b0;
  //     m_axi_bresp  <= 2'b00; 
  //     w_addr_reg   <= '0;
  //   end else begin
      
  //     // Latch Address when AW handshake occurs
  //     if (m_axi_awvalid && m_axi_awready) begin
  //       logic [`DRAM_ADDR_WIDTH-1:0] aw_start_addr;
  //       logic [`DRAM_ADDR_WIDTH-1:0] aw_end_addr;
        
  //       aw_start_addr = m_axi_awaddr;
  //       aw_end_addr   = m_axi_awaddr + (m_axi_awlen * BYTES_PER_BEAT);

  //       if ((aw_start_addr >> 12) != (aw_end_addr >> 12)) begin
  //         $display("\n\033[31m[AXI SLAVE FATAL] 4KB Boundary Violation on AW Channel!\033[0m");
  //         $display("  Start Addr: 0x%08h (Page 0x%05h)", aw_start_addr, aw_start_addr >> 12);
  //         $display("  End Addr:   0x%08h (Page 0x%05h)", aw_end_addr, aw_end_addr >> 12);
  //         $display("  AWLEN:      %0d beats (%0d bytes)", m_axi_awlen + 1, (m_axi_awlen + 1) * BYTES_PER_BEAT);
  //         $finish;
  //       end
  //       aw_active  <= 1'b1;
  //       w_addr_reg <= m_axi_awaddr;
  //     end

  //     // Process Write Data Beats
  //     if (m_axi_wvalid && m_axi_wready) begin
  //       // 1. Write current beat into memory
  //       for (int i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
  //         if (m_axi_wstrb[i]) begin
  //           dram_mem[w_addr_reg + i] = m_axi_wdata[i*8 +: 8];
  //         end
  //       end
        
  //       // 2. Increment address for the next beat in the burst
  //       w_addr_reg <= w_addr_reg + BYTES_PER_BEAT;

  //       // 3. If this is the last beat, end AW phase and trigger B response
  //       if (m_axi_wlast) begin
  //         aw_active    <= 1'b0;
  //         m_axi_bvalid <= 1'b1; 
  //       end
  //     end

  //     // Clear BVALID once the Master acknowledges the write response
  //     if (m_axi_bvalid && m_axi_bready) begin
  //       m_axi_bvalid <= 1'b0;
  //     end
  //   end
  // end
  // ----------------------------------------------------------------------------
  // 2. AXI Write Channel Slave Handshake (Handles AW, W, and B channels)
  // ----------------------------------------------------------------------------
  logic aw_active;
  logic [`DRAM_ADDR_WIDTH-1:0] w_addr_reg;
  
  // New Registers for simulating AXI Backpressure
  logic [7:0] w_beat_cnt;
  logic       stall_wready;
  logic       has_stalled_this_txn;
  logic [1:0] stall_cnt; 


  // Accept AW if not currently writing and not waiting to send B response
  assign m_axi_awready = !aw_active && !m_axi_bvalid; 
  
  // Ready to receive W data ONLY if active AND we are not artificially stalling
  assign m_axi_wready  = aw_active && !stall_wready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_active            <= 1'b0;
      m_axi_bvalid         <= 1'b0;
      m_axi_bresp          <= 2'b00; 
      w_addr_reg           <= '0;
      w_beat_cnt           <= '0;
      stall_wready         <= 1'b0;
      has_stalled_this_txn <= 1'b0;
      stall_cnt <= '0;
    end else begin
      
      // Latch Address when AW handshake occurs
      if (m_axi_awvalid && m_axi_awready) begin
        logic [`DRAM_ADDR_WIDTH-1:0] aw_start_addr;
        logic [`DRAM_ADDR_WIDTH-1:0] aw_end_addr;
        
        aw_start_addr = m_axi_awaddr;
        aw_end_addr   = m_axi_awaddr + (m_axi_awlen * BYTES_PER_BEAT);

        if ((aw_start_addr >> 12) != (aw_end_addr >> 12)) begin
          $display("\n\033[31m[AXI SLAVE FATAL] 4KB Boundary Violation on AW Channel!\033[0m");
          $display("  Start Addr: 0x%08h (Page 0x%05h)", aw_start_addr, aw_start_addr >> 12);
          $display("  End Addr:   0x%08h (Page 0x%05h)", aw_end_addr, aw_end_addr >> 12);
          $display("  AWLEN:      %0d beats (%0d bytes)", m_axi_awlen + 1, (m_axi_awlen + 1) * BYTES_PER_BEAT);
          $finish;
        end
        aw_active            <= 1'b1;
        w_addr_reg           <= m_axi_awaddr;
        w_beat_cnt           <= '0;      // Reset beat count for new burst
        stall_wready         <= 1'b0;
        has_stalled_this_txn <= 1'b0;    // Reset stall tracking
      end

      // --------------------------------------------------------------------
      // ARTIFICIAL BACKPRESSURE LOGIC
      // --------------------------------------------------------------------
      // If we have successfully received 10 beats, and haven't stalled yet, 
      // trigger a 1-cycle dip on m_axi_wready.
      // if (aw_active && w_beat_cnt == 10 && !has_stalled_this_txn) begin
      //   stall_wready         <= 1'b1;
      //   has_stalled_this_txn <= 1'b1; // Mark that we did our 1-cycle dip
      // end else begin
      //   stall_wready         <= 1'b0; // Release the stall on the next cycle
      // end
      // --------------------------------------------------------------------
      // --------------------------------------------------------------------
      // --------------------------------------------------------------------
      // ARTIFICIAL BACKPRESSURE LOGIC (2-cycle stall)
      // --------------------------------------------------------------------
      // Requires: logic [1:0] stall_cnt; (Initialize to 0 on reset)

      if (aw_active && w_beat_cnt == 10 && !has_stalled_this_txn && (stall_cnt == 0)) begin
        stall_wready         <= 1'b1;
        stall_cnt            <= 2'd2; // Trigger 2 stall cycles
        has_stalled_this_txn <= 1'b1;
      end else if (stall_cnt > 0) begin
        // Keep stall_wready high while count is 2 or 1
        stall_wready         <= (stall_cnt > 2'd1); 
        stall_cnt            <= stall_cnt - 1'b1;
      end else begin
        stall_wready         <= 1'b0;
      end
      // --------------------------------------------------------------------


      // Process Write Data Beats
      if (m_axi_wvalid && m_axi_wready) begin
        
        // Count successful handshakes
        w_beat_cnt <= w_beat_cnt + 1;

        // 1. Write current beat into memory
        for (int i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
          if (m_axi_wstrb[i]) begin
            dram_mem[w_addr_reg + i] = m_axi_wdata[i*8 +: 8];
          end
        end
        
        // 2. Increment address for the next beat in the burst
        w_addr_reg <= w_addr_reg + BYTES_PER_BEAT;

        // 3. If this is the last beat, end AW phase and trigger B response
        if (m_axi_wlast) begin
          aw_active    <= 1'b0;
          m_axi_bvalid <= 1'b1; 
        end
      end

      // Clear BVALID once the Master acknowledges the write response
      if (m_axi_bvalid && m_axi_bready) begin
        m_axi_bvalid <= 1'b0;
      end
    end
  end

  // ============================================================================
  // DUT Instance
  // ============================================================================
  // ============================================================================
  // DUT Instance (AXI Wrapper)
  // ============================================================================
  npu_axi_full_burst #(
      .DATA_WIDTH(`SRAM_WIDTH_O),
      .DRAM_ADDR_WIDTH(`DRAM_ADDR_WIDTH)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .start_i(npu_start_i),
      .busy_o(busy),
      .done_o(done),

      // AXI Read Address Channel
      .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen), .m_axi_arsize(m_axi_arsize),
      .m_axi_arburst(m_axi_arburst), .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
      // AXI Read Data Channel
      .m_axi_rdata(m_axi_rdata), .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready),
      .m_axi_rlast(m_axi_rlast), .m_axi_rresp(m_axi_rresp),
      // AXI Write Address Channel
      .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen), .m_axi_awsize(m_axi_awsize),
      .m_axi_awburst(m_axi_awburst), .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
      // AXI Write Data Channel
      .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wlast(m_axi_wlast),
      .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
      // AXI Write Response Channel
      .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready)
  );

  // // ============================================================================
  // // DUT Instance
  // // ============================================================================
  // npu_int16 dut (
  //   .clk(clk),
  //   .rst_n(rst_n),
  //   .start_i(npu_start_i),
  //   .done_o(done),
  //   // DRAM interface
  //   .dram_rd_valid(dram_rd_valid),
  //   .dram_rd_ready(dram_rd_ready),
  //   .dram_rd_addr(dram_rd_addr),

  //   .dram_rd_data_valid(dram_rd_data_valid),
  //   .dram_rd_data(dram_rd_data),

  //   .dram_wr_valid(dram_wr_valid),
  //   .dram_wr_ready(dram_wr_ready),
  //   .dram_wr_addr(dram_wr_addr),
  //   .dram_wr_data(dram_wr_data),

  //   .busy_o(busy)
  // );

  // ============================================================================
  // Runtime State and Metadata Storage
  // ============================================================================
  int IMG_H, IMG_W, IN_C;
  int K_H, K_W, STRIDE;
  int OUT_H, OUT_W, OUT_C;
  int M_DIM, K_DIM, N_DIM;
  int TOTAL_WORDS;

  // A_mat [M][K], B_mat [K][N]
  logic signed [`INT8_SIZE-1:0]  A_mat8 [0:MAX_M-1][0:MAX_K-1];
  logic signed [`INT8_SIZE-1:0]  B_mat8 [0:MAX_K-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0] A_mat16 [0:MAX_M-1][0:MAX_K-1];
  logic signed [`INT16_SIZE-1:0] B_mat16 [0:MAX_K-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0] EW_input1_mat16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0] EW_input2_mat16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT8_SIZE-1:0]  MUL_input2_8 [0:MAX_M-1][0:MAX_N-1];

  logic signed [`INT16_SIZE-1:0]  C_golden16  [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT32_SIZE-1:0]  C_golden32 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0]   SUB_golden16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0]   ADD_golden16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT8_SIZE-1:0]    MUL_input8 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0]   MUL_golden16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0]   EXP_golden16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0]   RCP_golden16 [0:MAX_M-1][0:MAX_N-1];
  logic signed [`INT16_SIZE-1:0]  SRAM_OUTPUT_got16 [0:MAX_M-1][0:MAX_N-1];

  int errors;

  typedef struct {
    int conv_requant_multiplier, conv_requant_shift, conv_requant_output_offset;
    int conv_output_activation_min, conv_output_activation_max;
    int conv_input_requant_multiplier, conv_input_requant_shift, conv_input_requant_offset;
    int conv_input_activation_min, conv_input_activation_max;
    int conv_weight_requant_multiplier, conv_weight_requant_shift, conv_weight_requant_offset;
    int conv_weight_activation_min, conv_weight_activation_max;
    int exp_deq_input_range_radius, exp_deq_input_zero_point, exp_deq_input_multiplier;
    int exp_deq_input_left_shift, exp_req_input_quantized_multiplier, exp_req_input_shift, exp_req_input_offset;
    int reciprocal_deq_input_range_radius, reciprocal_deq_input_zero_point, reciprocal_deq_input_multiplier;
    int reciprocal_deq_input_left_shift, reciprocal_req_input_quantized_multiplier, reciprocal_req_input_shift, reciprocal_req_input_offset;
    int add_input1_offset, add_input2_offset, add_left_shift;
    int add_input1_multiplier, add_input2_multiplier, add_input1_shift, add_input2_shift;
    int add_output_multiplier, add_output_shift, add_output_offset;
    int add_quantized_activation_min, add_quantized_activation_max;
    int sub_input1_offset, sub_input2_offset, sub_left_shift;
    int sub_input1_multiplier, sub_input2_multiplier, sub_input1_shift, sub_input2_shift;
    int sub_output_multiplier, sub_output_shift, sub_output_offset;
    int sub_quantized_activation_min, sub_quantized_activation_max;
    int mul_input1_offset, mul_input2_offset, mul_output_multiplier, mul_output_shift, mul_output_offset;
    int mul_quantized_activation_min, mul_quantized_activation_max;
    int mul_in1_requant_multiplier, mul_in1_requant_shift, mul_in1_requant_offset;
    int mul_in1_activation_min, mul_in1_activation_max;
    int mul_in2_requant_multiplier, mul_in2_requant_shift, mul_in2_requant_offset;
    int mul_in2_activation_min, mul_in2_activation_max;
  } metadata_quant_t;

  typedef struct {
    logic [15:0] op;
    int weight_num, store_sram_idx;
    int op0_weight_idx0, op0_weight_idx1, op1_weight_idx0, op2_weight_idx0, op3_weight_idx0;
    int op0_broadcast, op1_broadcast, op2_broadcast, op3_broadcast;
    int op0_data_counts, op1_data_counts, op2_data_counts, op3_data_counts;
    int op0_input_data_total_counts, op0_weight_total_counts;
    int op1_weight_total_counts, op2_weight_total_counts, op3_weight_total_counts;
    int stride_h, stride_w, padding;
    int batch, img_row, img_col, in_channel;
    int out_channel, ker_row, ker_col;
    metadata_quant_t op_quant [0:3];
  } metadata_t;

  metadata_t metadata [0:9999];
  int metadata_num_ops;
  logic [INST_BITS-1:0] metadata_inst64 [0:9999];
  logic [`SRAM_WIDTH_O-1:0] metadata_inst_words [0:1023];
  int metadata_inst_word_count;
  logic [`SRAM_WIDTH_O-1:0] metadata_desc_words [0:9999];
  logic [24:0] metadata_inst_dsc_idx [0:9999];
  int metadata_desc_word_count;
  logic [`SRAM_WIDTH_O-1:0] metadata_tensor_expected [0:7][0:(1<<`SRAM_ADDR_WIDTH)-1];
  bit [(1<<`SRAM_ADDR_WIDTH)-1:0] metadata_tensor_word_valid [0:7];
  int metadata_tensor_dma_count;
  int metadata_tensor_payload_next;
  int metadata_tensor_bank_words [0:7];
  int metadata_tensor_producer_words [0:7];
  // Tensor DMA entries are recorded once when the DRAM table is built.
  // Metadata golden can replay them later at the per-instruction load point.
  int metadata_tensor_entry_bank [0:(1<<`SRAM_ADDR_WIDTH)-1];
  int unsigned metadata_tensor_entry_dram_base [0:(1<<`SRAM_ADDR_WIDTH)-1];
  int unsigned metadata_tensor_entry_word_len [0:(1<<`SRAM_ADDR_WIDTH)-1];
  logic [2:0] tensor_readback_bank_force;
  logic [`SRAM_ADDR_WIDTH-1:0] tensor_readback_addr_force;

  // Global variables to keep track of job queue
  int global_job_idx = 0;
  int global_inst_offset = 0;
  int global_desc_offset = 0;
  int global_dma_offset = 0;
  int global_tensor_payload_next = TENSOR_PAYLOAD_DRAM_BASE;
  int unsigned current_result_base = OUT_DRAM_BASE;

  // ----------------------------------------------------------------------------
  // Default signal initialization
  // ----------------------------------------------------------------------------
  initial begin
    rst_n = 1'b0;
    npu_start_i = 1'b0;
    dram_rd_ready = 1'b1;
    dram_wr_ready = 1'b1;
  end

  // Helper function for random
  function automatic int next_prng(inout integer state);
  begin
    state = state * 69069 + 1;
    next_prng = state;
  end
  endfunction

  // Helper function to generate .bin files for FPGA testing
  // ----------------------------------------------------------------------------
  // DRAM .bin File Dumper
  // ----------------------------------------------------------------------------
  task automatic dump_dram_to_bin(
    input string filename,
    input int unsigned start_word_addr,
    input int unsigned num_words
  );
    int fd;
    int w, b;
    int unsigned byte_addr;
    logic [7:0] byte_val;
    begin
      if (num_words == 0) return; // Skip if nothing to dump
      
      fd = $fopen(filename, "wb");
      if (fd) begin
        for (w = 0; w < num_words; w++) begin
          byte_addr = (start_word_addr + w) << ADDR_SHIFT;
          
          // Write out the 128-bit word byte-by-byte (Little-Endian)
          for (b = 0; b < (`SRAM_WIDTH_O / 8); b = b + 1) begin
            if (dram_mem.exists(byte_addr + b)) begin
              byte_val = dram_mem[byte_addr + b];
            end else begin
              byte_val = 8'h00; // Pad unwritten memory with zeros
            end
            $fwrite(fd, "%c", byte_val);
          end
        end
        $fclose(fd);
        $display("[SV_DRAM_DUMP] Wrote %0d words (%0d bytes) to %s", num_words, num_words * (`SRAM_WIDTH_O / 8), filename);
      end else begin
        $display("[SV_DRAM_DUMP] FATAL ERROR: Could not open %s for writing.", filename);
      end
    end
  endtask


  // ============================================================================
  // Reference Math and Saturation Helpers
  // ============================================================================
  // Match TFLite rounding divide-by-power-of-two behavior.
  function automatic int signed ref_rounding_divide_by_pot(int signed x, int right_shift);
    int signed mask;
    int signed remainder;
    int signed threshold;
    int signed result;
    begin
      if (right_shift <= 0) begin
        ref_rounding_divide_by_pot = x;
      end else begin
        mask = (1 <<< right_shift) - 1;
        remainder = x & mask;
        threshold = (mask >>> 1) + ((x < 0) ? 1 : 0);
        result = (x >>> right_shift) + ((remainder > threshold) ? 1 : 0);
        ref_rounding_divide_by_pot = result;
      end
    end
  endfunction

  // Match TFLite saturating rounding doubling high multiply.
  function automatic int signed ref_srdh_mul(int signed a, int signed b);
    longint signed ab_64;
    longint signed nudge;
    int signed res;
    begin
      ab_64 = longint'(a) * longint'(b);
      nudge = (ab_64 >= 0) ? (64'sd1 <<< 30) : (64'sd1 - (64'sd1 <<< 30));
      res = int'((ab_64 + nudge) >>> (`INT32_SIZE-1));
      ref_srdh_mul = res;
    end
  endfunction

  // Apply quantized multiplier and signed shift used by CONV/EW golden paths.
  function automatic int signed ref_multiply_by_conv_qm(int signed x, int signed qm, int signed sh);
    int left_shift;
    int right_shift;
    int signed x_ls;
    int signed mul;
    begin
      if (sh > 0) begin
        left_shift  = sh;
        right_shift = 0;
      end else begin
        left_shift  = 0;
        right_shift = -sh;
      end

      x_ls = (left_shift > 0) ? (x <<< left_shift) : x;
      mul  = ref_srdh_mul(x_ls, qm);
      ref_multiply_by_conv_qm = ref_rounding_divide_by_pot(mul, right_shift);
    end
  endfunction

  function automatic logic signed [`INT8_SIZE-1:0] sat_int8(input int signed x);
    if (x > 127)  sat_int8 = 127;
    else if (x < -128) sat_int8 = -128;
    else          sat_int8 = x[`INT8_SIZE-1:0];
  endfunction

  // Round real values with TensorFlow-style half-away-from-zero behavior.
  function automatic integer tf_round(input real x);
    real ax;
    integer q;
    begin
      if (x >= 0.0) begin
        tf_round = $rtoi(x + 0.5);
      end else begin
        ax = -x;
        q  = $rtoi(ax + 0.5);
        tf_round = -q;
      end
    end
  endfunction

  function automatic shortint sat_int16(input integer x);
    begin
      if (x > 32767)
        sat_int16 = `INT16_SIZE'sd32767;
      else if (x < -32768)
        sat_int16 = -`INT16_SIZE'sd32768;
      else
        sat_int16 = shortint'(x);
    end
  endfunction

  // ============================================================================
  // Common Timing, Job, and LSU Helpers
  // ============================================================================

  // ----------------------------------------------------------------------------
  // Timing and launch pulses
  // ----------------------------------------------------------------------------
  // Drive TB-controlled signals just after a posedge to avoid delta races.
  task automatic tb_drive_after_posedge();
    begin
      @(posedge clk);
      #(TB_DRIVE_DELAY);
    end
  endtask

  // Issue one clean start_i pulse using the TB drive timing rule.
  task automatic pulse_npu_start();
    begin
      tb_drive_after_posedge();
      npu_start_i = 1'b1;
      tb_drive_after_posedge();
      npu_start_i = 1'b0;
    end
  endtask

  // ----------------------------------------------------------------------------
  // DRAM/job stream writers
  // ----------------------------------------------------------------------------
  task automatic write_dram_word(
    input int unsigned addr,
    input logic [`SRAM_WIDTH_O-1:0] data
  );
    int unsigned byte_addr;
    int i;
    begin
      //word addressed dram
      // dram_mem[addr] = data;

      //byte addressed dram
      byte_addr = addr << ADDR_SHIFT; //for 8x8 npu
      for (i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
        dram_mem[byte_addr + i] = data[i*8 +: 8];
      end
    end
  endtask


  // Pack LOAD_JOB header fields into the first job DRAM word.
  task automatic write_job_header(
    input int inst_count,
    input int desc_word_len,
    input int tensor_dma_count,
    // Variables to keep track of job queue
    input int job_idx,
    input bit is_last,
    input int unsigned result_base, //32 bit dram address
    input int inst_offset,
    input int desc_offset,
    input int dma_offset
  );
    logic [`SRAM_WIDTH_O-1:0] header;
    begin
      header = '0;
      header[`SRAM_ADDR_WIDTH+3:0] = inst_count[`SRAM_ADDR_WIDTH+3:0];
      // Values are packed at fixed bit offsets; the *_LSB constants are not counters.
      header[JOB_DESC_WORD_LEN_LSB +: `SRAM_ADDR_WIDTH] = desc_word_len[`SRAM_ADDR_WIDTH-1:0];
      header[JOB_TENSOR_DMA_COUNT_LSB +: `SRAM_ADDR_WIDTH] = tensor_dma_count[`SRAM_ADDR_WIDTH-1:0];

      // Variables to keep track of job queue
      header[JOB_IS_LAST_LSB] = is_last;
      header[JOB_RESULT_BASE_LSB +: 32] = result_base;
      header[JOB_INST_OFFSET_LSB +: 16] = inst_offset[15:0];
      header[JOB_DESC_OFFSET_LSB +: 16] = desc_offset[15:0];
      header[JOB_DMA_OFFSET_LSB +: 16]  = dma_offset[15:0];


      write_dram_word(JOB_DRAM_BASE + job_idx, header);
      $display("[JOB HEADER %0d] is_last=%b result_base (word address)=%0d, header:%h", job_idx, is_last, result_base, header);
    end
  endtask

  // Pack 64-bit instruction entries into SRAM-width DRAM words.
  task automatic write_inst_stream(
    input logic [INST_BITS-1:0] inst_words [],
    input int inst_count
  );
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    int i;
    int word_idx;
    int slot_idx;
    begin
      packed_word = '0;
      for (i = 0; i < inst_count; i = i + 1) begin
        word_idx = i / INST_PER_WORD;
        slot_idx = i % INST_PER_WORD;
        if (slot_idx == 0) packed_word = '0;
        packed_word[slot_idx*INST_BITS +: INST_BITS] = inst_words[i];
        if ((slot_idx == (INST_PER_WORD - 1)) || (i == (inst_count - 1))) begin
          write_dram_word(INST_DRAM_BASE + word_idx, packed_word);
        end
      end
    end
  endtask


  // ============================================================================
  // Tensor Payload Builders
  // ============================================================================

  // ----------------------------------------------------------------------------
  // A matrix DRAM pack
  // ----------------------------------------------------------------------------
  // DRAM: A_DRAM_BASE + tile_m*K_DIM + k_col.
  // SRAM: data[tile_m*K_DIM + k_col].
  task automatic write_A_matrix_to_dram(
    input int unsigned dram_base
  );
    integer tile_m, k_col, lane;
    integer m_row;
    integer data_addr_linear;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    integer num_m_tiles;
    begin
      num_m_tiles = (M_DIM + PE_SIZE - 1) / PE_SIZE;

      for (tile_m = 0; tile_m < num_m_tiles; tile_m = tile_m + 1) begin
        for (k_col = 0; k_col < K_DIM; k_col = k_col + 1) begin
          packed_word = `SRAM_WIDTH_O'd0;

          for (lane = 0; lane < PE_SIZE; lane = lane + 1) begin
            m_row = tile_m*PE_SIZE + lane;

            if (m_row < M_DIM && k_col < K_DIM)
              packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] = A_mat16[m_row][k_col];
            else
              packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] = `INT16_SIZE'sd0;
          end

          data_addr_linear = tile_m*K_DIM + k_col;
          write_dram_word(dram_base + data_addr_linear, packed_word);
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // B matrix DRAM pack
  // ----------------------------------------------------------------------------
  // DRAM: B_DRAM_BASE + k_row*num_n_tiles + tile_n.
  // SRAM: weight[k_row*num_n_tiles + tile_n].
  task automatic write_B_matrix_to_dram(
    input int unsigned dram_base
  );
    integer k_row, tile_n, lane;
    integer n_col;
    integer weight_addr_linear;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    integer num_n_tiles;
    begin
      num_n_tiles = (N_DIM + PE_SIZE - 1) / PE_SIZE;

      for (k_row = 0; k_row < K_DIM; k_row = k_row + 1) begin
        for (tile_n = 0; tile_n < num_n_tiles; tile_n = tile_n + 1) begin
          packed_word = `SRAM_WIDTH_O'd0;

          for (lane = 0; lane < PE_SIZE; lane = lane + 1) begin
            n_col = tile_n*PE_SIZE + lane;

            if (k_row < K_DIM && n_col < N_DIM)
              packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] = B_mat16[k_row][n_col];
            else
              packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] = `INT16_SIZE'sd0;
          end

          weight_addr_linear = k_row*num_n_tiles + tile_n;
          write_dram_word(dram_base + weight_addr_linear, packed_word);
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // EW input pattern builders
  // ----------------------------------------------------------------------------
  function automatic logic signed [`INT16_SIZE-1:0] ew_input2_pattern(
    input logic [3:0] op_code,
    input int unsigned idx,
    input int unsigned count
  );
    int signed base;
    int signed delta;
    begin
      case (op_code)
        `OP_MUL: base = 16;
        default: base = 3;
      endcase
      if (count <= 1) begin
        delta = 0;
      end else if (op_code == `OP_MUL) begin
        delta = (idx % 3) - 1;
      end else begin
        delta = (idx % 5) - 2;
      end
      ew_input2_pattern = sat_int16(base + delta);
    end
  endfunction

  function automatic logic signed [`INT16_SIZE-1:0] ew_input1_pattern(input int unsigned idx);
    int signed base;
    begin
      base = (idx % 31) - 15;
      ew_input1_pattern = sat_int16(base);
    end
  endfunction

  // Build a deterministic EW src0/data tensor for preload and golden use.
  task automatic build_EW_input1_matrix(
    ref logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_N-1],
    input bit broadcast,
    input int unsigned total_count
  );
    int m, n;
    int unsigned src_idx;
    int unsigned logical_idx;
    begin
      for (m = 0; m < MAX_M; m = m + 1) begin
        for (n = 0; n < MAX_N; n = n + 1) begin
          out_mat[m][n] = '0;
        end
      end

      for (m = 0; m < M_DIM; m = m + 1) begin
        for (n = 0; n < N_DIM; n = n + 1) begin
          if (broadcast) begin
            src_idx = (total_count <= 1) ? 0 : (n % total_count);
            out_mat[m][n] = ew_input1_pattern(src_idx);
          end else begin
            logical_idx = (m * N_DIM) + n;
            if ((total_count == 0) || (logical_idx < total_count)) begin
              out_mat[m][n] = ew_input1_pattern(logical_idx);
            end
          end
        end
      end
    end
  endtask

  // Build EW src1/weight, including broadcast-vector cases.
  task automatic build_EW_input2_matrix(
    ref logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_N-1],
    input logic [3:0] op_code,
    input bit broadcast,
    input int unsigned broadcast_count
  );
    int m, n;
    int unsigned src_idx;
    int unsigned logical_idx;
    begin
      for (m = 0; m < MAX_M; m = m + 1) begin
        for (n = 0; n < MAX_N; n = n + 1) begin
          out_mat[m][n] = '0;
        end
      end

      for (m = 0; m < M_DIM; m = m + 1) begin
        for (n = 0; n < N_DIM; n = n + 1) begin
          if (broadcast) begin
            src_idx = (broadcast_count <= 1) ? 0 : (n % broadcast_count);
            out_mat[m][n] = ew_input2_pattern(op_code, src_idx, broadcast_count);
          end else begin
            logical_idx = (m * N_DIM) + n;
            out_mat[m][n] = ew_input2_pattern(op_code, logical_idx, broadcast_count);
          end
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // EW tensor DRAM pack
  // ----------------------------------------------------------------------------
  // Pack EW tensors into the physical SRAM word/lane layout expected by RTL.
  // A broadcast payload stores only row 0; RTL expands it at runtime.
  task automatic write_ew_tensor_to_dram(
    input int unsigned dram_base,
    input logic signed [`INT16_SIZE-1:0] tensor_mat [0:MAX_M-1][0:MAX_N-1],
    input logic [3:0] op_code,
    input bit broadcast,
    input int unsigned broadcast_count
  );
    int m_idx, tile_n, lane;
    int n_idx;
    int words_per_row;
    int broadcast_words;
    int broadcast_idx;
    int addr;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    begin
      words_per_row = (N_DIM + PE_SIZE - 1) / PE_SIZE;
      if (broadcast) begin
        broadcast_words = metadata_ceil_div((broadcast_count <= 0) ? 1 : broadcast_count,
                                            PE_SIZE);
        for (tile_n = 0; tile_n < broadcast_words; tile_n = tile_n + 1) begin
          packed_word = '0;
          for (lane = 0; lane < PE_SIZE; lane = lane + 1) begin
            broadcast_idx = tile_n*PE_SIZE + lane;
            if (broadcast_idx < broadcast_count) begin
              packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] =
                tensor_mat[0][broadcast_idx];
            end
          end
          write_dram_word(dram_base + tile_n, packed_word);
        end
      end else begin
        for (m_idx = 0; m_idx < M_DIM; m_idx = m_idx + 1) begin
          for (tile_n = 0; tile_n < words_per_row; tile_n = tile_n + 1) begin
            packed_word = '0;
            for (lane = 0; lane < PE_SIZE; lane = lane + 1) begin
              n_idx = tile_n*PE_SIZE + lane;
              if (n_idx < N_DIM) begin
                packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] = tensor_mat[m_idx][n_idx];
              end
            end
            addr = m_idx*words_per_row + tile_n;
            write_dram_word(dram_base + addr, packed_word);
          end
        end
      end
    end
  endtask


  // ============================================================================
  // LUT Payload and Reference Helpers
  // ============================================================================

  // ----------------------------------------------------------------------------
  // EXP LUT builder
  // ----------------------------------------------------------------------------
  // Generate the EXP LUT contents used by both RTL preload and golden lookup.
  task automatic build_exp_lut_tflite();
    real input_scale, output_scale;
    integer input_zp, output_zp;
    real input_min, input_max;
    real output_min, output_max;
    integer nb_steps;
    real step, half_step;
    real output_scaling_inv;
    integer i;
    real val, val_mid, val_next;
    integer sample_val, midpoint_interp_val, midpoint_val;
    integer midpoint_err, bias;
    begin
      input_scale  = 10.0 / 65535.0;
      input_zp     = 32767;
      output_scale = 1.0 / 32768.0;
      output_zp    = 0;

      input_min  = input_scale  * ((-32768) - input_zp);
      input_max  = input_scale  * (( 32767) - input_zp);
      output_min = output_scale * ((-32768) - output_zp);
      output_max = output_scale * (( 32767) - output_zp);

      nb_steps = 512;
      step     = (input_max - input_min) / nb_steps;
      half_step = step / 2.0;

      output_scaling_inv =
        ((32767 - (-32768) + 1) * 1.0) / (output_max - output_min);

      for (i = 0; i < nb_steps; i = i + 1) begin
        val      = $exp(input_min + i*step);
        val_mid  = $exp(input_min + i*step + half_step);
        val_next = $exp(input_min + (i+1)*step);

        sample_val = tf_round(val * output_scaling_inv);
        midpoint_interp_val =
          tf_round((val_next * output_scaling_inv + tf_round(val * output_scaling_inv)) / 2.0);
        midpoint_val = tf_round(val_mid * output_scaling_inv);
        midpoint_err = midpoint_interp_val - midpoint_val;
        bias         = tf_round(midpoint_err / 2.0);

        exp_lut[i] = sat_int16(sample_val - bias);
      end

      exp_lut[nb_steps] = sat_int16(tf_round($exp(input_max) * output_scaling_inv));
    end
  endtask

  // ----------------------------------------------------------------------------
  // RCP LUT builder
  // ----------------------------------------------------------------------------
  // Generate the reciprocal LUT contents used by both RTL preload and golden lookup.
  task automatic build_one_over_one_plus_x_lut_tflite();
    real input_scale, output_scale;
    integer input_zp, output_zp;
    real input_min, input_max;
    real output_min, output_max;
    integer nb_steps;
    real step, half_step;
    real output_scaling_inv;
    integer i;
    real x0, xmid, x1;
    real val, val_mid, val_next;
    integer sample_val, midpoint_interp_val, midpoint_val;
    integer midpoint_err, bias;
    begin
      input_scale  = 1.0 / 65536.0;
      input_zp     = -32768;
      output_scale = 1.0 / 32768.0;
      output_zp    = 0;

      input_min  = input_scale  * ((-32768) - input_zp); // 0
      input_max  = input_scale  * (( 32767) - input_zp); // ~1
      output_min = output_scale * ((-32768) - output_zp);
      output_max = output_scale * (( 32767) - output_zp);

      nb_steps = 512;
      step     = (input_max - input_min) / nb_steps;
      half_step = step / 2.0;

      output_scaling_inv =
        ((32767 - (-32768) + 1) * 1.0) / (output_max - output_min);

      for (i = 0; i < nb_steps; i = i + 1) begin
        x0   = input_min + i*step;
        xmid = x0 + half_step;
        x1   = input_min + (i+1)*step;

        val      = 1.0 / (1.0 + x0);
        val_mid  = 1.0 / (1.0 + xmid);
        val_next = 1.0 / (1.0 + x1);

        sample_val = tf_round(val * output_scaling_inv);
        midpoint_interp_val =
          tf_round((val_next * output_scaling_inv + tf_round(val * output_scaling_inv)) / 2.0);
        midpoint_val = tf_round(val_mid * output_scaling_inv);
        midpoint_err = midpoint_interp_val - midpoint_val;
        bias         = tf_round(midpoint_err / 2.0);

        rcp_lut[i] = sat_int16(sample_val - bias);
      end

      rcp_lut[nb_steps] =
        sat_int16(tf_round((1.0 / (1.0 + input_max)) * output_scaling_inv));
    end
  endtask

  // ----------------------------------------------------------------------------
  // LUT DRAM pack
  // ----------------------------------------------------------------------------
  // DRAM: LUT_DRAM_BASE + base_addr + w.
  // SRAM: base_addr + w.
  task automatic write_lut_array_to_dram(
    input int unsigned dram_base,
    input integer base_addr,
    input [`INT16_SIZE-1:0] lut_arr [0:LUT_ENTRY_NUM-1]
  );
    integer w, b, idx;
    integer entries_per_word;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    begin
      entries_per_word = (`SRAM_WIDTH_O / `INT16_SIZE);

      for (w = 0; w < LUT_WORD_NUM; w = w + 1) begin
        packed_word = `SRAM_WIDTH_O'd0;

        for (b = 0; b < entries_per_word; b = b + 1) begin
          idx = w*entries_per_word + b;

          if (idx < LUT_ENTRY_NUM)
            packed_word[b*`INT16_SIZE +: `INT16_SIZE] = lut_arr[idx][`INT16_SIZE-1:0];
        end

        write_dram_word(dram_base + base_addr + w, packed_word);
      end
    end
  endtask

  // Build both LUTs and place them at the LUT DRAM preload base.
  task automatic write_exp_rcp_lut_to_dram();
    begin
        build_exp_lut_tflite();
        build_one_over_one_plus_x_lut_tflite();

        write_lut_array_to_dram(LUT_DRAM_BASE, EXP_LUT_BASE_ADDR, exp_lut);
        write_lut_array_to_dram(LUT_DRAM_BASE, RCP_LUT_BASE_ADDR, rcp_lut);
    end
  endtask


  // ============================================================================
  // Result Unpack and Golden Model Helpers
  // ============================================================================

  // ----------------------------------------------------------------------------
  // Result DRAM unpack
  // ----------------------------------------------------------------------------
  // Convert STORE_RESULT DRAM words back into SRAM_OUTPUT_got16[m][n].
  task automatic unpack_result_from_dram(
    input int unsigned dram_base
  );
    int addr;
    int lane;
    int words_per_row;
    int m_idx;
    int w_idx;
    int base_n;
    int n_idx;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    int unsigned byte_addr;
    int i;
    begin
      words_per_row = (N_DIM + PE_SIZE - 1) / PE_SIZE;

      for (addr = 0; addr < TOTAL_WORDS; addr = addr + 1) begin
        //word addressed dram
        // packed_word = dram_mem[dram_base + addr];

        //byte addressed dram
        byte_addr = (dram_base + addr) << ADDR_SHIFT;
        packed_word = '0;
        for (i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
          if (dram_mem.exists(byte_addr + i)) begin
            packed_word[i*8 +: 8] = dram_mem[byte_addr + i];
          end else begin
            packed_word[i*8 +: 8] = 8'h00;
          end
        end

        m_idx  = addr / words_per_row;
        w_idx  = addr % words_per_row;
        base_n = w_idx * PE_SIZE;

        for (lane = 0; lane < PE_SIZE; lane = lane + 1) begin
          n_idx = base_n + lane;

          if (m_idx < M_DIM && n_idx < N_DIM) begin
            SRAM_OUTPUT_got16[m_idx][n_idx] =
              packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE];
          end
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // LUT interpolation golden
  // ----------------------------------------------------------------------------
  function automatic logic signed [`INT16_SIZE-1:0] lut_lookup_ref_exp(input logic signed [`INT16_SIZE-1:0] v);
    integer index;
    integer offset;
    integer base;
    integer slope;
    integer delta;
    integer outv;
    begin
      index = 256 + ($signed(v) >>> 7);
      if (index < 0) index = 0;
      if (index > 511) index = 511;

      offset = v[6:0];

      base  = $signed(exp_lut[index]);
      slope = $signed(exp_lut[index+1]) - $signed(exp_lut[index]);
      delta = (slope * offset + 64) >>> 7;
      outv  = base + delta;

      lut_lookup_ref_exp = sat_int16(outv);
    end
  endfunction

  function automatic logic signed [`INT16_SIZE-1:0] lut_lookup_ref_rcp(input logic signed [`INT16_SIZE-1:0] v);
    integer index;
    integer offset;
    integer base;
    integer slope;
    integer delta;
    integer outv;
    begin
      index = 256 + ($signed(v) >>> 7);
      if (index < 0) index = 0;
      if (index > 511) index = 511;

      offset = v[6:0];

      base  = $signed(rcp_lut[index]);
      slope = $signed(rcp_lut[index+1]) - $signed(rcp_lut[index]);
      delta = (slope * offset + 64) >>> 7;
      outv  = base + delta;

      lut_lookup_ref_rcp = sat_int16(outv);
    end
  endfunction


  // ----------------------------------------------------------------------------
  // CONV/FC input case builder
  // ----------------------------------------------------------------------------
  // mode: 0=ramp, 1=small random, 2=large random, 3=hybrid.
  task automatic buid_case_AB(
      ref  logic signed [`INT16_SIZE-1:0] out1_mat16 [0:MAX_M-1][0:MAX_K-1],
      ref  logic signed [`INT16_SIZE-1:0] out2_mat16 [0:MAX_K-1][0:MAX_N-1],
      input int mode = 0,
      input int seed = 32'h1218
  );
      int m,k,n;
      int oh,ow,kh,kw,ic,oc;
      int m_idx,k_idx;
      int ih, iw;
      integer rand_state;
      int rand_val;

      rand_state = seed;

      for (m=0; m<MAX_M; m++)
        for (k=0; k<MAX_K; k++)
          out1_mat16[m][k] = '0;

      for (k=0; k<MAX_K; k++)
        for (n=0; n<MAX_N; n++)
          out2_mat16[k][n] = '0;

      // A = im2col
      m_idx = 0;
      for (oh=0; oh<OUT_H; oh++) begin
        for (ow=0; ow<OUT_W; ow++) begin
          k_idx = 0;
          for (kh=0; kh<K_H; kh++) begin
            for (kw=0; kw<K_W; kw++) begin
              for (ic=0; ic<IN_C; ic++) begin
                ih = oh*STRIDE + kh;
                iw = ow*STRIDE + kw;

                case (mode)
                  0: begin
                    // original ramp pattern
                    out1_mat16[m_idx][k_idx] = $signed((ih*IMG_W + iw + 1) + ic);
                  end

                  1: begin
                    // small-range random
                    // rand_val = $random(rand_state);
                    rand_val = next_prng(rand_state);
                    rand_val = int'($unsigned(rand_val) % 21) - 10;
                    out1_mat16[m_idx][k_idx] = $signed(rand_val); // [-10, 10]
                  end

                  2: begin
                    // large-range random
                    // rand_val = $random(rand_state);
                    rand_val = next_prng(rand_state);
                    out1_mat16[m_idx][k_idx] = $signed(rand_val[15:0]);
                  end

                  3: begin
                    // hybrid
                    if (((m_idx + k_idx) % 8) == 0) begin
                      // rand_val = $random(rand_state);
                      rand_val = next_prng(rand_state);
                      rand_val = int'($unsigned(rand_val) % 21) - 10;
                      out1_mat16[m_idx][k_idx] = $signed(rand_val);
                    end
                    else begin
                      out1_mat16[m_idx][k_idx] = $signed((ih*IMG_W + iw + 1) + ic);
                    end
                  end

                  default: begin
                    out1_mat16[m_idx][k_idx] = $signed((ih*IMG_W + iw + 1) + ic);
                  end
                endcase

                k_idx++;
              end
            end
          end
          m_idx++;
        end
      end

      // B = flatten kernels
      for (oc=0; oc<OUT_C; oc++) begin
        k_idx = 0;
        for (kh=0; kh<K_H; kh++) begin
          for (kw=0; kw<K_W; kw++) begin
            for (ic=0; ic<IN_C; ic++) begin

              case (mode)
                0: begin
                  // original ramp pattern：const per oc
                  out2_mat16[k_idx][oc] = $signed(oc + 1);
                end

                1: begin
                  // small-range random
                  // rand_val = $random(rand_state);
                  rand_val = next_prng(rand_state);
                  rand_val = int'($unsigned(rand_val) % 21) - 10;
                  out2_mat16[k_idx][oc] = $signed(rand_val); // [-10, 10]
                end

                2: begin
                  // large-range random
                  // rand_val = $random(rand_state);
                  rand_val = next_prng(rand_state);
                  out2_mat16[k_idx][oc] = $signed(rand_val[15:0]);
                end

                3: begin
                  // hybrid
                  if (((k_idx + oc) % 8) == 0) begin
                    // rand_val = $random(rand_state);
                    rand_val = next_prng(rand_state);
                    rand_val = int'($unsigned(rand_val) % 21) - 10;
                    out2_mat16[k_idx][oc] = $signed(rand_val);
                  end
                  else begin
                    out2_mat16[k_idx][oc] = $signed(oc + 1);
                  end
                end

                default: begin
                  out2_mat16[k_idx][oc] = $signed(oc + 1);
                end
              endcase

              k_idx++;
            end
          end
        end
      end
  endtask

  // ----------------------------------------------------------------------------
  // INT16-to-INT8 requant helpers
  // ----------------------------------------------------------------------------
  // Requantize one INT16 value into the signed INT8 range with activation clamp.
  function automatic logic signed [`INT8_SIZE-1:0] requant_to_int8(
    input int signed x,
    input int signed qm,
    input int signed sh,
    input int signed out_offset,
    input int signed act_min,
    input int signed act_max
  );
    int signed y;
    begin
      y = ref_multiply_by_conv_qm(x, qm, sh);
      y = y + out_offset;

      if (y > act_max) y = act_max;
      else if (y < act_min) y = act_min;

      requant_to_int8 = sat_int8(y);
    end
  endfunction

  // Requantize SA input/weight matrices before CONV/FC golden accumulation.
  task automatic build_sa_q8_from_q16(
    input  logic signed [`INT16_SIZE-1:0] in1_mat16 [0:MAX_M-1][0:MAX_K-1],
    input  logic signed [`INT16_SIZE-1:0] in2_mat16 [0:MAX_K-1][0:MAX_N-1],
    ref    logic signed [`INT8_SIZE-1:0]  out1_mat8 [0:MAX_M-1][0:MAX_K-1],
    ref    logic signed [`INT8_SIZE-1:0]  out2_mat8 [0:MAX_K-1][0:MAX_N-1]
  );
    int m, k, n;
    begin
      for (m = 0; m < M_DIM; m++) begin
        for (k = 0; k < K_DIM; k++) begin
          out1_mat8[m][k] = requant_to_int8(
            $signed(in1_mat16[m][k]),
            conv_input_requant_multiplier, conv_input_requant_shift, conv_input_requant_offset, conv_input_activation_min, conv_input_activation_max
          );
        end
      end

      for (k = 0; k < K_DIM; k++) begin
        for (n = 0; n < N_DIM; n++) begin
          out2_mat8[k][n] = requant_to_int8(
            $signed(in2_mat16[k][n]),
            conv_weight_requant_multiplier, conv_weight_requant_shift, conv_weight_requant_offset, conv_weight_activation_min, conv_weight_activation_max
          );
        end
      end
    end
  endtask

  // Requantize MUL input tensors before the MUL_Element golden calculation.
  task automatic build_mul_q8_from_q16(
    input int signed mul_in1_multiplier,
    input int signed mul_in1_shift,
    input int signed mul_in1_offset,
    input int signed mul_in1_act_max,
    input int signed mul_in1_act_min,
    input int signed mul_in2_multiplier,
    input int signed mul_in2_shift,
    input int signed mul_in2_offset,
    input int signed mul_in2_act_max,
    input int signed mul_in2_act_min,
    input  logic signed [`INT16_SIZE-1:0] in1_mat16 [0:MAX_M-1][0:MAX_N-1],
    input  logic signed [`INT16_SIZE-1:0] in2_mat16 [0:MAX_M-1][0:MAX_N-1],
    ref    logic signed [`INT8_SIZE-1:0] out1_mat8 [0:MAX_M-1][0:MAX_N-1],
    ref    logic signed [`INT8_SIZE-1:0] out2_mat8 [0:MAX_M-1][0:MAX_N-1]
  );
    int m, n;
    begin
      for (m = 0; m < M_DIM; m++) begin
        for (n = 0; n < N_DIM; n++) begin
          out1_mat8[m][n] = requant_to_int8(
            $signed(in1_mat16[m][n]),
            mul_in1_multiplier, mul_in1_shift, mul_in1_offset, mul_in1_act_min, mul_in1_act_max
          );
          out2_mat8[m][n] = requant_to_int8(
            $signed(in2_mat16[m][n]),
            mul_in2_multiplier, mul_in2_shift, mul_in2_offset, mul_in2_act_min, mul_in2_act_max
          );
        end
      end
    end
  endtask


  // ----------------------------------------------------------------------------
  // CONV/FC golden
  // ----------------------------------------------------------------------------
  // A/B are requantized to INT8 before the INT16 output golden.
  task automatic compute_CONV(
    input  logic signed [`INT16_SIZE-1:0] in1_mat16 [0:MAX_M-1][0:MAX_K-1],
    input  logic signed [`INT16_SIZE-1:0] in2_mat16 [0:MAX_K-1][0:MAX_N-1],
    ref    logic signed [`INT16_SIZE-1:0] out1_mat16[0:MAX_M-1][0:MAX_N-1]
  );
    int m,n,k;
    int signed acc;
    int signed y32;
    int signed y32_off;
    int signed y32_clamp;
    begin
      // $display(" CONV start.");
      build_sa_q8_from_q16(in1_mat16, in2_mat16, A_mat8, B_mat8);
      for (m=0; m<M_DIM; m++) begin
        for (n=0; n<N_DIM; n++) begin
          acc = 0;
          for (k=0; k<K_DIM; k++) begin
            acc += $signed(A_mat8[m][k]) * $signed(B_mat8[k][n]);
          end
          C_golden32[m][n] = acc;
          y32     = ref_multiply_by_conv_qm(C_golden32[m][n], conv_qm, shift);
          y32_off = y32 + conv_out_offset;

          if (y32_off > conv_act_max) y32_clamp = conv_act_max;
          else if (y32_off < conv_act_min) y32_clamp = conv_act_min;
          else y32_clamp = y32_off;

          out1_mat16[m][n] = sat_int16(y32_clamp);
        end
      end

    end
  endtask

  // ----------------------------------------------------------------------------
  // ADD/SUB golden
  // ----------------------------------------------------------------------------
  // Mirrors ADD_Element.v and SUB_Element.v.
  task automatic compute_ADD_SUB(
      input  logic [3:0] op_code,
      input  logic signed [`INT16_SIZE-1:0] in2_mat [0:MAX_M-1][0:MAX_N-1],
      input  logic signed [`INT16_SIZE-1:0] in1_mat [0:MAX_M-1][0:MAX_N-1],
      ref    logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_N-1]
  );
    int m,n;
    int signed input1_offset, input2_offset;
    int signed left_shift;
    int signed input1_multiplier, input2_multiplier;
    int signed input1_shift, input2_shift;
    int signed output_multiplier, output_shift, output_offset;
    int signed act_min, act_max;
    int signed x1, x2;
    int signed s1, s2;
    int signed acc;
    int signed req;
    int signed out32;
    bit is_sub;

    begin
      is_sub = (op_code == `OP_SUB);
      if ((op_code != `OP_ADD) && (op_code != `OP_SUB)) begin
        $display("[TB][FATAL] compute_ADD_SUB unsupported op=%04b", op_code);
        $finish;
      end

      if (is_sub) begin
        // $display(" SUB start.");
        input1_offset     = sub_input1_offset;
        input2_offset     = sub_input2_offset;
        left_shift        = sub_left_shift;
        input1_multiplier = sub_input1_multiplier;
        input2_multiplier = sub_input2_multiplier;
        input1_shift      = sub_input1_shift;
        input2_shift      = sub_input2_shift;
        output_multiplier = sub_output_multiplier;
        output_shift      = sub_output_shift;
        output_offset     = sub_output_offset;
        act_min           = sub_act_min;
        act_max           = sub_act_max;
      end else begin
        // $display(" ADD start.");
        input1_offset     = add_input1_offset;
        input2_offset     = add_input2_offset;
        left_shift        = add_left_shift;
        input1_multiplier = add_input1_multiplier;
        input2_multiplier = add_input2_multiplier;
        input1_shift      = add_input1_shift;
        input2_shift      = add_input2_shift;
        output_multiplier = add_output_multiplier;
        output_shift      = add_output_shift;
        output_offset     = add_output_offset;
        act_min           = add_act_min;
        act_max           = add_act_max;
      end

      for (m=0; m<M_DIM; m++) begin
        for (n=0; n<N_DIM; n++) begin
          x1 = ($signed(in1_mat[m][n]) + input1_offset) * (`INT32_SIZE'sd1 <<< left_shift);
          x2 = ($signed(in2_mat[m][n]) + input2_offset) * (`INT32_SIZE'sd1 <<< left_shift);
          s1 = ref_multiply_by_conv_qm(x1, input1_multiplier, input1_shift);
          s2 = ref_multiply_by_conv_qm(x2, input2_multiplier, input2_shift);

          acc = is_sub ? (s1 - s2) : (s1 + s2);
          req = ref_multiply_by_conv_qm(acc, output_multiplier, output_shift);
          out32 = req + output_offset;

          if (out32 > act_max) out32 = act_max;
          else if (out32 < act_min) out32 = act_min;

          out_mat[m][n] = sat_int16(out32);
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // MUL golden
  // ----------------------------------------------------------------------------
  // Mirrors MUL_Element.v with INT8 input requant.
  task automatic compute_MUL(
      input  logic signed [`INT16_SIZE-1:0] in2_mat16 [0:MAX_M-1][0:MAX_N-1],
      input  logic signed [`INT16_SIZE-1:0] in1_mat16 [0:MAX_M-1][0:MAX_N-1],
      ref    logic signed [`INT16_SIZE-1:0] out_mat16 [0:MAX_M-1][0:MAX_N-1]
  );
    int m, n;
    int signed in1_adj;
    int signed in2_adj;
    int signed prod32;
    longint signed prod64;

    begin
      // $display(" MUL start.");
      build_mul_q8_from_q16(
        mul_in1_multiplier, mul_in1_shift, mul_in1_offset, mul_in1_act_max, mul_in1_act_min,
        mul_in2_multiplier, mul_in2_shift, mul_in2_offset, mul_in2_act_max, mul_in2_act_min,
        in1_mat16, in2_mat16, MUL_input8, MUL_input2_8
      );

      for (m = 0; m < M_DIM; m++) begin
        for (n = 0; n < N_DIM; n++) begin
          in1_adj = ($signed(MUL_input8[m][n]) + mul_input1_offset);
          in2_adj = ($signed(MUL_input2_8[m][n]) + mul_input2_offset);
          prod64 = $signed(in1_adj) * $signed(in2_adj);
          prod32 = int'(prod64);
          out_mat16[m][n] = sat_int16(prod32);
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // EXP golden
  // ----------------------------------------------------------------------------
  // Mirrors element_wise_LUT.sv -> lut_vec_tflite.sv.
  task automatic compute_EXP(
      input  logic signed [`INT16_SIZE-1:0] in1_mat [0:MAX_M-1][0:MAX_N-1],
      ref    logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_N-1]
  );
    int m, n;
    int signed in16;
    int signed v_off;
    int signed v32;
    logic signed [`INT16_SIZE-1:0] v16;
    logic signed [`INT16_SIZE-1:0] exp_q15;
    begin
      // $display(" EXP start.");
      for (m = 0; m < M_DIM; m++) begin
        for (n = 0; n < N_DIM; n++) begin
          in16 = $signed(in1_mat[m][n]);

          v_off = ref_multiply_by_conv_qm(
                    in16 - exp_deq_input_zero_point,
                    exp_deq_input_multiplier,
                    exp_deq_input_left_shift
                  );

          v32 = 32767 + v_off;
          v16 = sat_int16(v32);

          exp_q15 = lut_lookup_ref_exp(v16);

          out_mat[m][n] = exp_q15;
        end
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // RCP golden
  // ----------------------------------------------------------------------------
  // Mirrors element_wise_LUT.sv -> lut_vec_tflite.sv.
  task automatic compute_RCP(
      input  logic signed [`INT16_SIZE-1:0] in1_mat [0:MAX_M-1][0:MAX_N-1],
      ref    logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_N-1]
  );
    int m, n;
    int signed in16;
    int signed sym32;
    logic signed [`INT16_SIZE-1:0] sym16;
    logic signed [`INT16_SIZE-1:0] rcp_q15;
    begin
      // $display(" RCP start.");
      for (m = 0; m < M_DIM; m++) begin
        for (n = 0; n < N_DIM; n++) begin
          in16 = $signed(in1_mat[m][n]);

          sym32 = ref_multiply_by_conv_qm(
                    in16 - reciprocal_deq_input_zero_point,
                    reciprocal_deq_input_multiplier,
                    reciprocal_deq_input_left_shift
                  );

          sym16 = sat_int16(sym32);

          rcp_q15 = lut_lookup_ref_rcp(sym16);

          out_mat[m][n] = rcp_q15;
        end
      end
    end
  endtask


  // ----------------------------------------------------------------------------
  // Output checker
  // ----------------------------------------------------------------------------
  // Compare SRAM_OUTPUT_got16[][] against the selected golden matrix.
  task automatic check_results(
      string case_name,
      input logic signed [`INT16_SIZE-1:0] expected16 [0:MAX_M-1][0:MAX_N-1]
  );
      int m, n;
      int case_errors;
      case_errors = 0;
      `ifdef METADATA_TB
            $display("[CHECK] %s", case_name);
      `else
      $display("========================================");
      $display("[CASE] %s", case_name);
      $display("  IMG=%0dx%0d IN_C=%0d  K=%0dx%0d STRIDE=%0d  OUT_C=%0d", IMG_H, IMG_W, IN_C, K_H, K_W, STRIDE, OUT_C);
      $display("  M_DIM=%0d  K_DIM=%0d  N_DIM=%0d", M_DIM, K_DIM, N_DIM);
      $display("  A=MxK=%0d, B=KxN=%0d, C=MxN=%0d", M_DIM*K_DIM, K_DIM*N_DIM, M_DIM*N_DIM);
      $display("  Input  address words needed = ceil(A_size / %0d) = %0d, addr width >= %0d bits",
                                                                    `LANES,
                                                                    (M_DIM*K_DIM + (`LANES-1)) / `LANES,
                                                                    $clog2((M_DIM*K_DIM + (`LANES-1)) / `LANES));
      $display("  Weight address words needed = ceil(B_size / %0d) = %0d, addr width >= %0d bits",
                                                                    `LANES,
                                                                    (K_DIM*N_DIM + (`LANES-1)) / `LANES,
                                                                    $clog2((K_DIM*N_DIM + (`LANES-1)) / `LANES));
      $display(". Output address words needed = ceil(C_size / %0d) = %0d, addr width >= %0d bits",
                                                                    `LANES,
                                                                    (M_DIM*N_DIM + (`LANES-1)) / `LANES,
                                                                    $clog2((M_DIM*N_DIM + (`LANES-1)) / `LANES));
      $display("  REQUANT: qm=%0d shift=%0d offset=%0d act=[%0d,%0d]", conv_qm, shift, conv_out_offset, conv_act_min, conv_act_max);
      $display("  SUB: in1_off=%0d in2_off=%0d left_shift=%0d in1_mul=%0d in2_mul=%0d in1_sh=%0d in2_sh=%0d out_mul=%0d out_sh=%0d out_off=%0d act=[%0d,%0d]",
               sub_input1_offset, sub_input2_offset, sub_left_shift,
               sub_input1_multiplier, sub_input2_multiplier, sub_input1_shift, sub_input2_shift,
               sub_output_multiplier, sub_output_shift, sub_output_offset,
               sub_act_min, sub_act_max);
      $display("  ADD: in1_off=%0d in2_off=%0d left_shift=%0d in1_mul=%0d in2_mul=%0d in1_sh=%0d in2_sh=%0d out_mul=%0d out_sh=%0d out_off=%0d act=[%0d,%0d]",
               add_input1_offset, add_input2_offset, add_left_shift,
               add_input1_multiplier, add_input2_multiplier, add_input1_shift, add_input2_shift,
               add_output_multiplier, add_output_shift, add_output_offset,
               add_act_min, add_act_max);
      $display("  MUL: in1_off=%0d in2_off=%0d out_mul=%0d out_sh=%0d out_off=%0d act=[%0d,%0d]",
               mul_input1_offset, mul_input2_offset,
               mul_output_multiplier, mul_output_shift, mul_output_offset,
               mul_act_min, mul_act_max);
      $display("========================================");
      `endif

      for (m = 0; m < M_DIM; m++) begin
        for (n = 0; n < N_DIM; n++) begin
          if ($isunknown(SRAM_OUTPUT_got16[m][n]) ||
              $isunknown(expected16[m][n])) begin
            $display("\033[31m[FAIL][X/Z]\033[0m (%0d,%0d): in1=%04h got=%04h exp=%04h",
                    m, n,
                    $signed(C_golden16[m][n]),
                    $signed(SRAM_OUTPUT_got16[m][n]),
                    $signed(expected16[m][n]));
            case_errors++;
            errors++;
          end
          else if (SRAM_OUTPUT_got16[m][n] != expected16[m][n]) begin
            $display("\033[31m[FAIL]\033[0m (%0d,%0d): in1= %04h got=%04h exp=%04h",
                    m, n,
                    $signed(C_golden16[m][n]),
                    $signed(SRAM_OUTPUT_got16[m][n]),
                    $signed(expected16[m][n]));
            case_errors++;
            errors++;
            // $finish;
          end
          else begin // DEBUG INFO
            // $display("\033[32m[PASS]\033[0m (%0d,%0d): got=%04h exp=%04h",
            //         m, n,
            //         $signed(SRAM_OUTPUT_got16[m][n]),
            //         $signed(expected16[m][n]));
          end
        end
      end

      if (case_errors == 0) $display("\033[32m[PASS]\033[0m %s: All INT16 sram outputs match golden.", case_name);
      else             $display("[DONE] %s: Total errors = %0d", case_name, case_errors);
  endtask

  // ============================================================================
  // Metadata Parser and Descriptor Helpers
  // ============================================================================

  // ----------------------------------------------------------------------------
  // metadata.txt line reader
  // ----------------------------------------------------------------------------
  function automatic string metadata_strip_newline(input string in_line);
    string out_line;
    int i;
    begin
      out_line = "";
      for (i = 0; i < in_line.len(); i++) begin
        if ((in_line[i] != "\n") && (in_line[i] != "\r")) out_line = {out_line, in_line[i]};
      end
      return out_line;
    end
  endfunction

  function automatic string metadata_read_next_line(input int file);
    string line;
    int r;
    begin
      while (1) begin
        r = $fgets(line, file);
        if (r == 0) return "";
        line = metadata_strip_newline(line);
        if (line.len() == 0) continue;
        if (line[0] == "#") continue;
        return line;
      end
    end
  endfunction

  // Fill metadata fields that older metadata.txt cases may omit.
  task automatic metadata_set_param_defaults(inout metadata_t meta);
    int op_idx;
    begin
      for (op_idx = 0; op_idx < 4; op_idx++) begin
        meta.op_quant[op_idx].conv_output_activation_min = -32768;
        meta.op_quant[op_idx].conv_output_activation_max = 32767;
        meta.op_quant[op_idx].conv_input_requant_multiplier = 1073741824;
        meta.op_quant[op_idx].conv_input_requant_shift = 0;
        meta.op_quant[op_idx].conv_input_requant_offset = 0;
        meta.op_quant[op_idx].conv_input_activation_min = -128;
        meta.op_quant[op_idx].conv_input_activation_max = 127;
        meta.op_quant[op_idx].conv_weight_requant_multiplier = 1073741824;
        meta.op_quant[op_idx].conv_weight_requant_shift = 0;
        meta.op_quant[op_idx].conv_weight_requant_offset = 0;
        meta.op_quant[op_idx].conv_weight_activation_min = -128;
        meta.op_quant[op_idx].conv_weight_activation_max = 127;
        meta.op_quant[op_idx].mul_in1_requant_multiplier = 1073741824;
        meta.op_quant[op_idx].mul_in1_requant_shift = 0;
        meta.op_quant[op_idx].mul_in1_requant_offset = 0;
        meta.op_quant[op_idx].mul_in1_activation_min = -128;
        meta.op_quant[op_idx].mul_in1_activation_max = 127;
        meta.op_quant[op_idx].mul_in2_requant_multiplier = 1073741824;
        meta.op_quant[op_idx].mul_in2_requant_shift = 0;
        meta.op_quant[op_idx].mul_in2_requant_offset = 0;
        meta.op_quant[op_idx].mul_in2_activation_min = -128;
        meta.op_quant[op_idx].mul_in2_activation_max = 127;
      end
    end
  endtask

  function automatic logic [3:0] metadata_get_op(input logic [15:0] op_word, input int op_idx);
    begin
      case (op_idx)
        0: metadata_get_op = op_word[3:0];
        1: metadata_get_op = op_word[7:4];
        2: metadata_get_op = op_word[11:8];
        3: metadata_get_op = op_word[15:12];
        default: metadata_get_op = `OP_IDLE;
      endcase
    end
  endfunction

  function automatic int metadata_get_first_active_op_idx(input metadata_t meta);
    int op_idx;
    begin
      metadata_get_first_active_op_idx = -1;
      for (op_idx = 0; op_idx < 4; op_idx++) begin
        if ((metadata_get_first_active_op_idx < 0) &&
            (metadata_get_op(meta.op, op_idx) != `OP_IDLE)) begin
          metadata_get_first_active_op_idx = op_idx;
        end
      end
    end
  endfunction

  function automatic string metadata_op_name(input logic [3:0] op_code);
    begin
      case (op_code)
        `OP_IDLE: metadata_op_name = "IDLE";
        `OP_CONV: metadata_op_name = "CONV";
        `OP_FC:   metadata_op_name = "FC";
        `OP_EXP:  metadata_op_name = "EXP";
        `OP_RCP:  metadata_op_name = "RCP";
        `OP_ADD:  metadata_op_name = "ADD";
        `OP_SUB:  metadata_op_name = "SUB";
        `OP_MUL:  metadata_op_name = "MUL";
        default: metadata_op_name = "UNKNOWN";
      endcase
    end
  endfunction

  function automatic int metadata_op_ew_type(input logic [3:0] op_code);
    begin
      case (op_code)
        `OP_EXP, `OP_RCP: metadata_op_ew_type = EW_IS_UNARY;
        `OP_ADD, `OP_SUB, `OP_MUL: metadata_op_ew_type = EW_IS_BINARY;
        default: metadata_op_ew_type = EW_IS_NONE;
      endcase
    end
  endfunction

  // Integer ceil division, used to turn element counts into lane-packed SRAM words.
  function automatic int metadata_ceil_div(input int numerator, input int denominator);
    begin
      if ((numerator <= 0) || (denominator <= 0)) begin
        metadata_ceil_div = 0;
      end else begin
        metadata_ceil_div = (numerator + denominator - 1) / denominator;
      end
    end
  endfunction

  // Print one parsed metadata entry in a human-readable debug format.
  task automatic metadata_print_entry(input metadata_t meta, input int entry_idx);
    int i;
    logic [3:0] op_code;
    begin
      $display("==============================================================================");
      $display("[ENTRY %0d] word=%016b  weight_num=%0d", entry_idx, meta.op, meta.weight_num);
      $display("  ops          : %-15s -> %-9s -> %-9s -> %-10s",
               metadata_op_name(metadata_get_op(meta.op, 0)),
               metadata_op_name(metadata_get_op(meta.op, 1)),
               metadata_op_name(metadata_get_op(meta.op, 2)),
               metadata_op_name(metadata_get_op(meta.op, 3)));
      $display("  banks        : %-15s %-12s %-12s %-12s store=%0d",
               $sformatf("op0_w=(%0d,%0d)", meta.op0_weight_idx0, meta.op0_weight_idx1),
               $sformatf("op1_w=%0d", meta.op1_weight_idx0),
               $sformatf("op2_w=%0d", meta.op2_weight_idx0),
               $sformatf("op3_w=%0d", meta.op3_weight_idx0),
               meta.store_sram_idx);
      $display("  broadcast    : %-15s %-12s %-12s %-12s",
               $sformatf("op0=%0d", meta.op0_broadcast),
               $sformatf("op1=%0d", meta.op1_broadcast),
               $sformatf("op2=%0d", meta.op2_broadcast),
               $sformatf("op3=%0d", meta.op3_broadcast));
      $display("  data_counts  : %-15s %-12s %-12s %-12s",
               $sformatf("op0=%0d", meta.op0_data_counts),
               $sformatf("op1=%0d", meta.op1_data_counts),
               $sformatf("op2=%0d", meta.op2_data_counts),
               $sformatf("op3=%0d", meta.op3_data_counts));
      $display("  total_counts : %-15s %-12s %-12s %-12s ",
               $sformatf("op0=(%0d,%0d)", meta.op0_input_data_total_counts, meta.op0_weight_total_counts),
               $sformatf("op1_w=%0d", meta.op1_weight_total_counts),
               $sformatf("op2_w=%0d", meta.op2_weight_total_counts),
               $sformatf("op3_w=%0d", meta.op3_weight_total_counts));
      $display("  shape        : batch=%2d image=%4dx%-4d in_c=%4d kernel=%2dx%-2d out_c=%4d stride=(%2d,%2d) padding=%2d",
               meta.batch, meta.img_row, meta.img_col, meta.in_channel,
               meta.ker_row, meta.ker_col, meta.out_channel,
               meta.stride_h, meta.stride_w, meta.padding);
      for (i = 0; i < 4; i++) begin
        op_code = metadata_get_op(meta.op, i);
        case (op_code)
          `OP_CONV, `OP_FC: begin
            $display("  quant %-4s   : output=(mul=%11d shift=%4d off=%6d act=[%6d,%6d])",
                     metadata_op_name(op_code), meta.op_quant[i].conv_requant_multiplier,
                     meta.op_quant[i].conv_requant_shift, meta.op_quant[i].conv_requant_output_offset,
                     meta.op_quant[i].conv_output_activation_min, meta.op_quant[i].conv_output_activation_max);
            $display("  quant %-4s   : input_req=(mul=%11d shift=%4d off=%6d act=[%4d,%4d]) weight_req=(mul=%11d shift=%4d off=%6d act=[%4d,%4d])",
                     metadata_op_name(op_code),
                     meta.op_quant[i].conv_input_requant_multiplier, meta.op_quant[i].conv_input_requant_shift,
                     meta.op_quant[i].conv_input_requant_offset, meta.op_quant[i].conv_input_activation_min,
                     meta.op_quant[i].conv_input_activation_max,
                     meta.op_quant[i].conv_weight_requant_multiplier, meta.op_quant[i].conv_weight_requant_shift,
                     meta.op_quant[i].conv_weight_requant_offset, meta.op_quant[i].conv_weight_activation_min,
                     meta.op_quant[i].conv_weight_activation_max);
          end
          `OP_EXP: begin
            $display("  quant EXP    : range=%11d zero=%6d multiplier=%11d left_shift=%4d req_mul=%11d req_shift=%4d req_offset=%6d",
                     meta.op_quant[i].exp_deq_input_range_radius, meta.op_quant[i].exp_deq_input_zero_point,
                     meta.op_quant[i].exp_deq_input_multiplier, meta.op_quant[i].exp_deq_input_left_shift,
                     meta.op_quant[i].exp_req_input_quantized_multiplier, meta.op_quant[i].exp_req_input_shift,
                     meta.op_quant[i].exp_req_input_offset);
          end
          `OP_RCP: begin
            $display("  quant RCP    : range=%11d zero=%6d multiplier=%11d left_shift=%4d req_mul=%11d req_shift=%4d req_offset=%6d",
                     meta.op_quant[i].reciprocal_deq_input_range_radius, meta.op_quant[i].reciprocal_deq_input_zero_point,
                     meta.op_quant[i].reciprocal_deq_input_multiplier, meta.op_quant[i].reciprocal_deq_input_left_shift,
                     meta.op_quant[i].reciprocal_req_input_quantized_multiplier, meta.op_quant[i].reciprocal_req_input_shift,
                     meta.op_quant[i].reciprocal_req_input_offset);
          end
          `OP_ADD: begin
            $display("  quant ADD    : off=(%6d,%6d) left_shift=%4d mul=(%11d,%11d) shift=(%4d,%4d) out=(mul=%11d shift=%4d off=%6d) act=[%6d,%6d]",
                     meta.op_quant[i].add_input1_offset, meta.op_quant[i].add_input2_offset, meta.op_quant[i].add_left_shift,
                     meta.op_quant[i].add_input1_multiplier, meta.op_quant[i].add_input2_multiplier,
                     meta.op_quant[i].add_input1_shift, meta.op_quant[i].add_input2_shift,
                     meta.op_quant[i].add_output_multiplier, meta.op_quant[i].add_output_shift, meta.op_quant[i].add_output_offset,
                     meta.op_quant[i].add_quantized_activation_min, meta.op_quant[i].add_quantized_activation_max);
          end
          `OP_SUB: begin
            $display("  quant SUB    : off=(%6d,%6d) left_shift=%4d mul=(%11d,%11d) shift=(%4d,%4d) out=(mul=%11d shift=%4d off=%6d) act=[%6d,%6d]",
                     meta.op_quant[i].sub_input1_offset, meta.op_quant[i].sub_input2_offset, meta.op_quant[i].sub_left_shift,
                     meta.op_quant[i].sub_input1_multiplier, meta.op_quant[i].sub_input2_multiplier,
                     meta.op_quant[i].sub_input1_shift, meta.op_quant[i].sub_input2_shift,
                     meta.op_quant[i].sub_output_multiplier, meta.op_quant[i].sub_output_shift, meta.op_quant[i].sub_output_offset,
                     meta.op_quant[i].sub_quantized_activation_min, meta.op_quant[i].sub_quantized_activation_max);
          end
          `OP_MUL: begin
            $display("  quant MUL    : off=(%6d,%6d) out=(mul=%11d shift=%4d off=%6d) act=[%6d,%6d]",
                     meta.op_quant[i].mul_input1_offset, meta.op_quant[i].mul_input2_offset,
                     meta.op_quant[i].mul_output_multiplier, meta.op_quant[i].mul_output_shift, meta.op_quant[i].mul_output_offset,
                     meta.op_quant[i].mul_quantized_activation_min, meta.op_quant[i].mul_quantized_activation_max);
            $display("  quant MUL    : in1_req=(mul=%11d shift=%4d off=%6d act=[%4d,%4d]) in2_req=(mul=%11d shift=%4d off=%6d act=[%4d,%4d])",
                     meta.op_quant[i].mul_in1_requant_multiplier, meta.op_quant[i].mul_in1_requant_shift,
                     meta.op_quant[i].mul_in1_requant_offset, meta.op_quant[i].mul_in1_activation_min,
                     meta.op_quant[i].mul_in1_activation_max,
                     meta.op_quant[i].mul_in2_requant_multiplier, meta.op_quant[i].mul_in2_requant_shift,
                     meta.op_quant[i].mul_in2_requant_offset, meta.op_quant[i].mul_in2_activation_min,
                     meta.op_quant[i].mul_in2_activation_max);
          end
          default: begin
          end
        endcase
      end
      $display("==============================================================================");
    end
  endtask

  // ----------------------------------------------------------------------------
  // Descriptor field packing
  // ----------------------------------------------------------------------------
  function automatic logic [7:0] metadata_pack_b_cast(input metadata_t meta);
    begin
      metadata_pack_b_cast = {
        meta.op3_broadcast[1:0],
        meta.op2_broadcast[1:0],
        meta.op1_broadcast[1:0],
        meta.op0_broadcast[1:0]
      };
    end
  endfunction

  function automatic logic [31:0] metadata_pack_i16_pair(input int min_value, input int max_value);
    logic signed [15:0] min16;
    logic signed [15:0] max16;
    begin
      min16 = min_value;
      max16 = max_value;
      metadata_pack_i16_pair = {max16, min16};
    end
  endfunction

  function automatic logic [DESC_LOC_BITS-1:0] metadata_pack_desc_location(input int bank, input int word_base);
    logic [2:0] bank_bits;
    logic [`SRAM_ADDR_WIDTH-1:0] base_bits;
    begin
      bank_bits = bank[2:0];
      base_bits = word_base[`SRAM_ADDR_WIDTH-1:0];
      metadata_pack_desc_location = {base_bits, bank_bits};
    end
  endfunction

  function automatic logic [47:0] metadata_pack_desc_locations(
    input int src0_bank,
    input int src0_word_base,
    input int src1_bank,
    input int src1_word_base,
    input int dst_bank,
    input int dst_word_base
  );
    begin
      metadata_pack_desc_locations = {
        3'd0,
        metadata_pack_desc_location(dst_bank, dst_word_base),
        metadata_pack_desc_location(src1_bank, src1_word_base),
        metadata_pack_desc_location(src0_bank, src0_word_base)
      };
    end
  endfunction

  // ----------------------------------------------------------------------------
  // Bank, shape, and count derivation
  // ----------------------------------------------------------------------------
  // Baseline SA descriptors retain their established idx0=data convention.
  // EW follows the compiler contract: op0 idx1=data, later slots use the prior result.
  function automatic int metadata_get_src0_bank(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    begin
      case (op_code)
        `OP_CONV, `OP_FC: metadata_get_src0_bank = meta.op0_weight_idx0;
        // EW op0 may consume external data; later EW ops consume the prior store output.
        `OP_ADD, `OP_SUB, `OP_MUL,
        `OP_EXP, `OP_RCP: metadata_get_src0_bank = (op_idx == 0) ? meta.op0_weight_idx1 : meta.store_sram_idx;
        default: metadata_get_src0_bank = 0;
      endcase
    end
  endfunction

  // Baseline SA descriptors retain idx1=weight. Binary EW follows the compiler
  // contract and takes its explicit weight/input2 tensor from idx0.
  function automatic int metadata_get_src1_bank(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    begin
      case (op_code)
        `OP_CONV, `OP_FC: metadata_get_src1_bank = meta.op0_weight_idx1;
        // Binary EW src1 is the explicit weight/input2 tensor bank.
        `OP_ADD, `OP_SUB, `OP_MUL: begin
          case (op_idx)
            0: metadata_get_src1_bank = meta.op0_weight_idx0;
            1: metadata_get_src1_bank = meta.op1_weight_idx0;
            2: metadata_get_src1_bank = meta.op2_weight_idx0;
            3: metadata_get_src1_bank = meta.op3_weight_idx0;
            default: metadata_get_src1_bank = -1;
          endcase
        end
        default: metadata_get_src1_bank = 0;
      endcase
    end
  endfunction

  function automatic int metadata_get_m(input metadata_t meta);
    int out_h;
    int out_w;
    begin
      if ((meta.stride_h > 0) && (meta.stride_w > 0) &&
          (meta.img_row > 0) && (meta.img_col > 0) &&
          (meta.ker_row > 0) && (meta.ker_col > 0)) begin
        out_h = ((meta.img_row + 2*meta.padding - meta.ker_row) / meta.stride_h) + 1;
        out_w = ((meta.img_col + 2*meta.padding - meta.ker_col) / meta.stride_w) + 1;
        metadata_get_m = out_h * out_w;
      end else begin
        metadata_get_m = 0;
      end
    end
  endfunction

  function automatic int metadata_get_k(input metadata_t meta);
    begin
      metadata_get_k = meta.ker_row * meta.ker_col * meta.in_channel;
    end
  endfunction

  function automatic int metadata_get_n(input metadata_t meta);
    begin
      metadata_get_n = meta.out_channel;
    end
  endfunction

  function automatic int metadata_get_total_words(input metadata_t meta);
    int m_dim;
    int n_dim;
    begin
      m_dim = metadata_get_m(meta);
      n_dim = metadata_get_n(meta);
      if ((m_dim > 0) && (n_dim > 0)) begin
        metadata_get_total_words = m_dim * ((n_dim + LANES - 1) / LANES);
      end else begin
        metadata_get_total_words = 0;
      end
    end
  endfunction

  function automatic int metadata_get_data_count(input metadata_t meta, input int op_idx);
    begin
      case (op_idx)
        0: metadata_get_data_count = meta.op0_data_counts;
        1: metadata_get_data_count = meta.op1_data_counts;
        2: metadata_get_data_count = meta.op2_data_counts;
        3: metadata_get_data_count = meta.op3_data_counts;
        default: metadata_get_data_count = 0;
      endcase
    end
  endfunction

  function automatic int metadata_get_broadcast(input metadata_t meta, input int op_idx);
    begin
      case (op_idx)
        0: metadata_get_broadcast = meta.op0_broadcast;
        1: metadata_get_broadcast = meta.op1_broadcast;
        2: metadata_get_broadcast = meta.op2_broadcast;
        3: metadata_get_broadcast = meta.op3_broadcast;
        default: metadata_get_broadcast = 0;
      endcase
    end
  endfunction

  // Return the logical src0/data element count. Only op0 owns an external data
  // payload; later fused ops receive src0 from the preceding result.
  function automatic int metadata_get_src0_count(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    begin
      if ((op_idx == 0) && (metadata_op_ew_type(op_code) != EW_IS_NONE)) begin
        metadata_get_src0_count = (meta.op0_input_data_total_counts > 0) ?
                                  meta.op0_input_data_total_counts :
                                  meta.op0_data_counts;
      end else begin
        metadata_get_src0_count = metadata_get_data_count(meta, op_idx);
      end
    end
  endfunction

  // Return the logical src1/weight element count.
  function automatic int metadata_get_src1_count(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    begin
      case (op_code)
        `OP_CONV, `OP_FC: metadata_get_src1_count = meta.op0_weight_total_counts;
        `OP_ADD, `OP_SUB, `OP_MUL: begin
          case (op_idx)
            0: metadata_get_src1_count = meta.op0_weight_total_counts;
            1: metadata_get_src1_count = meta.op1_weight_total_counts;
            2: metadata_get_src1_count = meta.op2_weight_total_counts;
            3: metadata_get_src1_count = meta.op3_weight_total_counts;
            default: metadata_get_src1_count = 0;
          endcase
        end
        default: metadata_get_src1_count = 0;
      endcase
    end
  endfunction

  // Compiler contract: selector 1 broadcasts src1/weight; selector 2 broadcasts
  // src0/data. Keep the selector semantics separate from the operand counts.
  function automatic int metadata_get_broadcast_count(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int broadcast;
    begin
      broadcast = metadata_get_broadcast(meta, op_idx);
      case (broadcast)
        1: metadata_get_broadcast_count = metadata_get_src1_count(meta, op_idx, op_code);
        2: metadata_get_broadcast_count = metadata_get_src0_count(meta, op_idx, op_code);
        default: metadata_get_broadcast_count = 0;
      endcase
    end
  endfunction

  // Detect EW descriptors that must use flat data_count-derived M/N shape.
  function automatic bit metadata_get_use_flat_ew_shape(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    begin
      metadata_get_use_flat_ew_shape = (metadata_op_ew_type(op_code) != EW_IS_NONE) &&
                                        ((metadata_get_m(meta) <= 0) ||
                                         (metadata_get_n(meta) <= 0) ||
                                         ((op_idx == 0) &&
                                          (metadata_get_src0_bank(meta, op_idx, op_code) != meta.store_sram_idx)));
    end
  endfunction

  // Return the runtime M for this op, including standalone EW fallback shape.
  function automatic int metadata_get_m_for_op(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int data_count;
    int broadcast_count;
    begin
      data_count = metadata_get_data_count(meta, op_idx);
      broadcast_count = metadata_get_broadcast_count(meta, op_idx, op_code);
      if (metadata_get_use_flat_ew_shape(meta, op_idx, op_code) && (data_count > 0)) begin
        if (broadcast_count > LANES) begin
          metadata_get_m_for_op = metadata_ceil_div(data_count, broadcast_count);
        end else begin
          metadata_get_m_for_op = metadata_ceil_div(data_count, LANES);
        end
      end else begin
        metadata_get_m_for_op = metadata_get_m(meta);
      end
    end
  endfunction

  function automatic int metadata_get_n_for_op(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int broadcast_count;
    begin
      broadcast_count = metadata_get_broadcast_count(meta, op_idx, op_code);
      if (metadata_get_use_flat_ew_shape(meta, op_idx, op_code) && (metadata_get_data_count(meta, op_idx) > 0)) begin
        metadata_get_n_for_op = (broadcast_count > LANES) ? broadcast_count : LANES;
      end else begin
        metadata_get_n_for_op = metadata_get_n(meta);
      end
    end
  endfunction

  function automatic int metadata_get_k_for_op(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    begin
      if (metadata_op_ew_type(op_code) != EW_IS_NONE) begin
        // EW ops do not use K.
        metadata_get_k_for_op = 0;
      end else begin
        metadata_get_k_for_op = metadata_get_k(meta);
      end
    end
  endfunction

  // Return the physical result word count implied by this op descriptor.
  function automatic int metadata_get_total_words_for_op(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int data_count;
    int broadcast_count;
    begin
      data_count = metadata_get_data_count(meta, op_idx);
      broadcast_count = metadata_get_broadcast_count(meta, op_idx, op_code);
      if (metadata_get_use_flat_ew_shape(meta, op_idx, op_code) && (data_count > 0)) begin
        // Wide broadcasts preserve their logical row boundary so the vector
        // restarts after N elements instead of after every physical SRAM word.
        if (broadcast_count > LANES) begin
          metadata_get_total_words_for_op =
            metadata_ceil_div(data_count, broadcast_count) *
            metadata_ceil_div(broadcast_count, LANES);
        end else begin
          metadata_get_total_words_for_op = metadata_ceil_div(data_count, LANES);
        end
      end else begin
        // CONV/FC-shaped EW keeps the padded M*ceil(N/LANES) layout.
        metadata_get_total_words_for_op = metadata_get_total_words(meta);
      end
    end
  endfunction

  // ----------------------------------------------------------------------------
  // Descriptor and instruction word packing
  // ----------------------------------------------------------------------------
  // Pack one lane-independent descriptor packet before splitting it into SRAM words.
  function automatic logic [DESC_PACKET_BITS-1:0] metadata_pack_desc_word(
    input metadata_t meta,
    input int op_idx,
    input logic [3:0] op_code
  );
    logic [DESC_PACKET_BITS-1:0] word;
    logic [31:0] header;
    logic [47:0] operand_location_pack;
    logic [3:0] op_slot;
    metadata_quant_t quant;
    begin
      word = '0;
      op_slot = op_idx;
      quant = meta.op_quant[op_idx];
      operand_location_pack = metadata_pack_desc_locations(
        metadata_get_src0_bank(meta, op_idx, op_code), 0,
        metadata_get_src1_bank(meta, op_idx, op_code), 0,
        meta.store_sram_idx, 0
      );
      header = {operand_location_pack[47:32], DESC_VERSION, op_slot, op_code};

      word[0*DESC_SLOT_BITS +: DESC_SLOT_BITS] = header;
      word[31*DESC_SLOT_BITS +: DESC_SLOT_BITS] = operand_location_pack[31:0];
      word[1*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_m_for_op(meta, op_idx, op_code);
      word[2*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_n_for_op(meta, op_idx, op_code);
      word[3*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_k_for_op(meta, op_idx, op_code);
      word[4*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_data_count(meta, op_idx);
      word[5*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_src1_count(meta, op_idx, op_code);
      word[6*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_total_words_for_op(meta, op_idx, op_code);
      word[7*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_get_broadcast_count(meta, op_idx, op_code);

      case (op_code)
        `OP_CONV, `OP_FC: begin
          word[8*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = meta.stride_h;
          word[9*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = meta.stride_w;
          word[10*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.padding;
          word[11*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.batch;
          word[12*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.img_row;
          word[13*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.img_col;
          word[14*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.in_channel;
          word[15*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.out_channel;
          word[16*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.ker_row;
          word[17*DESC_SLOT_BITS +: DESC_SLOT_BITS] = meta.ker_col;
          word[18*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_requant_multiplier;
          word[19*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_requant_shift;
          word[20*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_requant_output_offset;
          word[21*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_output_activation_min;
          word[22*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_output_activation_max;
          word[23*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_input_requant_multiplier;
          word[24*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_input_requant_shift;
          word[25*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_input_requant_offset;
          word[26*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_pack_i16_pair(quant.conv_input_activation_min, quant.conv_input_activation_max);
          word[27*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_weight_requant_multiplier;
          word[28*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_weight_requant_shift;
          word[29*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.conv_weight_requant_offset;
          word[30*DESC_SLOT_BITS +: DESC_SLOT_BITS] = metadata_pack_i16_pair(quant.conv_weight_activation_min, quant.conv_weight_activation_max);
        end
        `OP_EXP: begin
          word[8*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.exp_deq_input_range_radius;
          word[9*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.exp_deq_input_zero_point;
          word[10*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.exp_deq_input_multiplier;
          word[11*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.exp_deq_input_left_shift;
          word[12*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.exp_req_input_quantized_multiplier;
          word[13*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.exp_req_input_shift;
          word[14*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.exp_req_input_offset;
        end
        `OP_RCP: begin
          word[8*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.reciprocal_deq_input_range_radius;
          word[9*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.reciprocal_deq_input_zero_point;
          word[10*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.reciprocal_deq_input_multiplier;
          word[11*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.reciprocal_deq_input_left_shift;
          word[12*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.reciprocal_req_input_quantized_multiplier;
          word[13*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.reciprocal_req_input_shift;
          word[14*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.reciprocal_req_input_offset;
        end
        `OP_ADD: begin
          word[8*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.add_input1_offset;
          word[9*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.add_input2_offset;
          word[10*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_left_shift;
          word[11*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_input1_multiplier;
          word[12*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_input2_multiplier;
          word[13*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_input1_shift;
          word[14*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_input2_shift;
          word[15*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_output_multiplier;
          word[16*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_output_shift;
          word[17*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_output_offset;
          word[18*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_quantized_activation_min;
          word[19*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.add_quantized_activation_max;
        end
        `OP_SUB: begin
          word[8*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.sub_input1_offset;
          word[9*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.sub_input2_offset;
          word[10*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_left_shift;
          word[11*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_input1_multiplier;
          word[12*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_input2_multiplier;
          word[13*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_input1_shift;
          word[14*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_input2_shift;
          word[15*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_output_multiplier;
          word[16*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_output_shift;
          word[17*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_output_offset;
          word[18*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_quantized_activation_min;
          word[19*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.sub_quantized_activation_max;
        end
        `OP_MUL: begin
          word[8*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.mul_input1_offset;
          word[9*DESC_SLOT_BITS +: DESC_SLOT_BITS]  = quant.mul_input2_offset;
          word[10*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_output_multiplier;
          word[11*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_output_shift;
          word[12*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_output_offset;
          word[13*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_quantized_activation_min;
          word[14*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_quantized_activation_max;
          word[15*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in1_requant_multiplier;
          word[16*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in1_requant_shift;
          word[17*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in1_requant_offset;
          word[18*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in1_activation_min;
          word[19*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in1_activation_max;
          word[20*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in2_requant_multiplier;
          word[21*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in2_requant_shift;
          word[22*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in2_requant_offset;
          word[23*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in2_activation_min;
          word[24*DESC_SLOT_BITS +: DESC_SLOT_BITS] = quant.mul_in2_activation_max;
        end
        default: begin
        end
      endcase

      metadata_pack_desc_word = word;
    end
  endfunction

  // Directed baseline check for repeated opcodes with different quant params.
  task automatic metadata_check_quant_slot_smoke(input metadata_t meta);
    logic [DESC_PACKET_BITS-1:0] op0_desc;
    logic [DESC_PACKET_BITS-1:0] op1_desc;
    begin
      if ((metadata_get_op(meta.op, 0) != `OP_ADD) ||
          (metadata_get_op(meta.op, 1) != `OP_ADD)) begin
        $fatal(1, "[METADATA QUANT][FATAL] slot smoke requires consecutive ADD ops");
      end

      op0_desc = metadata_pack_desc_word(meta, 0, `OP_ADD);
      op1_desc = metadata_pack_desc_word(meta, 1, `OP_ADD);
      if ((meta.op_quant[0].add_output_offset != 11) ||
          (meta.op_quant[1].add_output_offset != -13) ||
          ($signed(op0_desc[17*DESC_SLOT_BITS +: DESC_SLOT_BITS]) !== 32'sd11) ||
          ($signed(op1_desc[17*DESC_SLOT_BITS +: DESC_SLOT_BITS]) !== -32'sd13)) begin
        $fatal(1,
               "[METADATA QUANT][FATAL] per-slot quant parsed/packed incorrectly parsed=%0d/%0d desc=%0d/%0d",
               meta.op_quant[0].add_output_offset,
               meta.op_quant[1].add_output_offset,
               $signed(op0_desc[17*DESC_SLOT_BITS +: DESC_SLOT_BITS]),
               $signed(op1_desc[17*DESC_SLOT_BITS +: DESC_SLOT_BITS]));
      end

      $display("[METADATA QUANT][PASS] ADD slot offsets parsed/packed independently: 11/-13");
    end
  endtask

  // Pack one frontend instruction from metadata op, tensor DMA count, broadcast, and descriptor index.
  function automatic logic [INST_BITS-1:0] metadata_pack_inst64(input metadata_t meta, input logic [24:0] dsc_idx);
    begin
      metadata_pack_inst64 = {
        meta.op,
        meta.weight_num[14:0],
        metadata_pack_b_cast(meta),
        dsc_idx
      };
    end
  endfunction

  // ============================================================================
  // Metadata Job Image and Auto-Issue Helpers
  // ============================================================================

  // ----------------------------------------------------------------------------
  // Descriptor DRAM image
  // ----------------------------------------------------------------------------
  // Build descriptor words for every non-IDLE op and write them into DRAM.
  task automatic metadata_write_desc_to_dram(
    input int first_entry,
    input int entry_count
  );
    int i;
    int local_idx;
    int entry_idx;
    int op_idx;
    int chunk_idx;
    logic [3:0] op_code;
    logic [DESC_PACKET_BITS-1:0] desc_packet;
    logic [DESC_STORAGE_BITS-1:0] desc_storage;
    logic [`SRAM_WIDTH_O-1:0] desc_word;
    begin
      metadata_desc_word_count = 0;
      for (i = 0; i < 10000; i++) begin
        metadata_desc_words[i] = '0;
        metadata_inst_dsc_idx[i] = 25'd0;
      end

      for (local_idx = 0; local_idx < entry_count; local_idx++) begin
        entry_idx = first_entry + local_idx;
        metadata_inst_dsc_idx[local_idx] = metadata_desc_word_count;
        for (op_idx = 0; op_idx < 4; op_idx++) begin
          op_code = metadata_get_op(metadata[entry_idx].op, op_idx);
          if (op_code != `OP_IDLE) begin
            if ((metadata_desc_word_count + DESC_WORDS_PER_PACKET) >
                (1 << `SRAM_ADDR_WIDTH)) begin
              $display("[DESC][FATAL] descriptor word count exceeds desc SRAM depth");
              $finish;
            end

            desc_packet = metadata_pack_desc_word(metadata[entry_idx], op_idx, op_code);
            desc_storage = '0;
            desc_storage[DESC_PACKET_BITS-1:0] = desc_packet;
            for (chunk_idx = 0; chunk_idx < DESC_WORDS_PER_PACKET; chunk_idx++) begin
              desc_word = desc_storage[
                chunk_idx*`SRAM_WIDTH_O +: `SRAM_WIDTH_O
              ];
              metadata_desc_words[metadata_desc_word_count] = desc_word;
              write_dram_word(DESC_DRAM_BASE + global_desc_offset + metadata_desc_word_count, desc_word);
              $display("[DESC WRITE] addr=0x%08h (word_idx=%0d) data=0x%032h", (DESC_DRAM_BASE + metadata_desc_word_count + global_desc_offset) << 4, metadata_desc_word_count, desc_word);
              metadata_desc_word_count++;
            end
            // DEBUG INFO
            // $display("[DESC PACK] base=%0d entry=%0d op%0d=%s header=0x%08h",
            //          metadata_desc_word_count - DESC_WORDS_PER_PACKET,
            //          entry_idx, op_idx, metadata_op_name(op_code),
            //          desc_packet[0 +: DESC_SLOT_BITS]);
          end
        end
      end

      // $display("[DESC PACK] total_words=%0d", metadata_desc_word_count);
    end
  endtask

  // ----------------------------------------------------------------------------
  // Runtime MNK shape setup
  // ----------------------------------------------------------------------------
  // Apply one descriptor's runtime M/K/N/TOTAL_WORDS to TB golden context.
  task automatic metadata_set_MNK_shape(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int m_dim;
    int n_dim;
    int k_dim;
    int total_words;
    begin
      if (!((op_code == `OP_CONV) || (op_code == `OP_FC) ||
            (metadata_op_ew_type(op_code) != EW_IS_NONE))) begin
        $display("[METADATA][FATAL] op%0d unsupported MNK shape op %b", op_idx, op_code);
        $finish;
      end

      m_dim = metadata_get_m_for_op(meta, op_idx, op_code);
      n_dim = metadata_get_n_for_op(meta, op_idx, op_code);
      k_dim = metadata_get_k_for_op(meta, op_idx, op_code);
      total_words = metadata_get_total_words_for_op(meta, op_idx, op_code);

      if ((m_dim <= 0) || (n_dim <= 0) || (total_words <= 0)) begin
        $display("[METADATA][FATAL] op%0d=%s invalid MNK shape M=%0d N=%0d total_words=%0d",
                 op_idx, metadata_op_name(op_code), m_dim, n_dim, total_words);
        $finish;
      end
      if (((op_code == `OP_CONV) || (op_code == `OP_FC)) && (k_dim <= 0)) begin
        $display("[METADATA][FATAL] op%0d=%s invalid K=%0d", op_idx, metadata_op_name(op_code), k_dim);
        $finish;
      end
      if ((m_dim > MAX_M) || (n_dim > MAX_N) || (k_dim > MAX_K)) begin
        $display("[METADATA][FATAL] op%0d=%s shape exceeds TB arrays M=%0d/%0d K=%0d/%0d N=%0d/%0d",
                 op_idx, metadata_op_name(op_code), m_dim, MAX_M, k_dim, MAX_K, n_dim, MAX_N);
        $finish;
      end
      if (total_words >= (1 << `SRAM_ADDR_WIDTH)) begin
        $display("[METADATA][FATAL] op%0d=%s total_words=%0d exceeds SRAM depth",
                 op_idx, metadata_op_name(op_code), total_words);
        $finish;
      end

      // EW-only descriptors can omit image-style dimensions; metadata_get_*_for_op
      // maps their data_count to M/N/K/TOTAL_WORDS before this assignment.
      IMG_H = meta.img_row;
      IMG_W = meta.img_col;
      IN_C  = meta.in_channel;
      K_H   = meta.ker_row;
      K_W   = meta.ker_col;
      STRIDE = 1;
      OUT_H = m_dim;
      OUT_W = 1;
      OUT_C = n_dim;
      M_DIM = m_dim;
      K_DIM = k_dim;
      N_DIM = n_dim;
      TOTAL_WORDS = total_words;
    end
  endtask


  // ----------------------------------------------------------------------------
  // Tensor DMA table helpers
  // ----------------------------------------------------------------------------
  // Shared by metadata preload and optional tensor checks.
  // Reset tensor DMA table construction and the TB shadow bank coverage.
  task automatic metadata_reset_tensor_dma_state();
    int bank;
    begin
      metadata_tensor_dma_count = 0;
      metadata_tensor_payload_next = global_tensor_payload_next;
      for (bank = 0; bank < 8; bank = bank + 1) begin
        metadata_tensor_bank_words[bank] = 0;
        metadata_tensor_producer_words[bank] = 0;
        metadata_tensor_word_valid[bank] = '0;
      end
    end
  endtask

  // Emit one tensor DMA table entry into DRAM.
  task automatic metadata_write_tensor_dma_entry_word(
    input int entry_idx,
    input int bank,
    input int unsigned dram_base,
    input int unsigned word_len
  );
    logic [`SRAM_WIDTH_O-1:0] entry_word;
    begin
      entry_word = '0;
      entry_word[0*TENSOR_DMA_SLOT_BITS +: TENSOR_DMA_SLOT_BITS] = bank[31:0];
      entry_word[1*TENSOR_DMA_SLOT_BITS +: TENSOR_DMA_SLOT_BITS] = dram_base[31:0];
      entry_word[2*TENSOR_DMA_SLOT_BITS +: TENSOR_DMA_SLOT_BITS] = word_len[31:0];
      write_dram_word(TENSOR_DMA_TABLE_DRAM_BASE + global_dma_offset + entry_idx, entry_word);
      $display("DMA Table Write: Addres:%h, Word:%h", (TENSOR_DMA_TABLE_DRAM_BASE + global_dma_offset + entry_idx), entry_word);
    end
  endtask

  // Mirror one tensor payload DMA into the shadow SRAM overwrite model.
  // This is the only place that defines TB overwrite semantics: write the
  // requested payload range from SRAM addr 0 and leave untouched tail words as-is.
  task automatic metadata_apply_tensor_dma_payload_to_shadow(
    input int bank,
    input int unsigned dram_base,
    input int unsigned word_len
  );
    int addr;
    int i;
    int byte_addr;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    begin
      if ((bank < 0) || (bank > 7)) return;
      if (word_len == 0) return;
      metadata_tensor_producer_words[bank] = word_len;

      for (addr = 0; addr < word_len; addr = addr + 1) begin
        //byte addressed dram
        byte_addr = (dram_base + addr) << ADDR_SHIFT;
        packed_word = '0;
        for (i = 0; i < (`SRAM_WIDTH_O / 8); i = i + 1) begin
          if (dram_mem.exists(byte_addr + i)) begin
            packed_word[i*8 +: 8] = dram_mem[byte_addr + i];
          end else begin
            packed_word[i*8 +: 8] = 8'h00;
          end
        end
        metadata_tensor_expected[bank][addr] = packed_word;
        metadata_tensor_word_valid[bank][addr] = 1'b1;
      end
      // Keep the checked range at the largest payload ever written to this bank.
      // A shorter later overwrite updates only addr 0..word_len-1; old tail
      // words beyond word_len must remain unchanged and still be verified.
      if (metadata_tensor_bank_words[bank] < word_len) begin
        metadata_tensor_bank_words[bank] = word_len;
      end
    end
  endtask

  // Replay a previously recorded table entry into shadow SRAM. Full metadata
  // golden uses this to match RTL load timing instead of preloading all entries.
  task automatic metadata_apply_tensor_dma_entry_to_shadow(input int entry_idx);
    begin
      if ((entry_idx < 0) || (entry_idx >= metadata_tensor_dma_count)) begin
        $display("[TENSOR DMA][FATAL] shadow replay entry index %0d out of range count=%0d",
                 entry_idx, metadata_tensor_dma_count);
        $finish;
      end
      metadata_apply_tensor_dma_payload_to_shadow(
        metadata_tensor_entry_bank[entry_idx],
        metadata_tensor_entry_dram_base[entry_idx],
        metadata_tensor_entry_word_len[entry_idx]
      );
    end
  endtask

  // Record one tensor preload DMA entry and optionally mirror it into shadow SRAM.
  // Directed LOAD_TENSOR smokes mirror immediately; full metadata tests record
  // only and replay each instruction's tensors at golden time.
  task automatic metadata_record_tensor_dma_entry(
    input int bank,
    input int unsigned dram_base,
    input int unsigned word_len,
    input string tag,
    input bit mirror_to_shadow
  );
    begin
      if (word_len == 0) return;
      if ((bank < 0) || (bank > 7)) begin
        $display("[TENSOR DMA][FATAL] %s bank id must be in 0..7, got %0d", tag, bank);
        $finish;
      end
      if (word_len >= (1 << `SRAM_ADDR_WIDTH)) begin
        $display("[TENSOR DMA][FATAL] %s word_len=%0d exceeds SRAM address width", tag, word_len);
        $finish;
      end
      if (metadata_tensor_dma_count >= (1 << `SRAM_ADDR_WIDTH)) begin
        $display("[TENSOR DMA][FATAL] tensor DMA entry count exceeds job header width");
        $finish;
      end

      metadata_write_tensor_dma_entry_word(metadata_tensor_dma_count, bank, dram_base, word_len);
      metadata_tensor_entry_bank[metadata_tensor_dma_count] = bank;
      metadata_tensor_entry_dram_base[metadata_tensor_dma_count] = dram_base;
      metadata_tensor_entry_word_len[metadata_tensor_dma_count] = word_len;

      if (mirror_to_shadow) begin
        metadata_apply_tensor_dma_payload_to_shadow(bank, dram_base, word_len);
      end

      // DEBUG INFO
      $display("[TENSOR DMA] entry=%0d bank=%0d dram_base=%0d sram_overwrite_base=0 words=%0d %s",
               metadata_tensor_dma_count, bank, dram_base, word_len, tag);
      metadata_tensor_dma_count++;
    end
  endtask

  // Count tensor streams required when an instruction cannot reuse the
  // immediately preceding result. op0 owns its explicit operands; later EW
  // slots receive src0 from the instruction-local result and only need src1.
  function automatic int metadata_get_dma_candidate_count(input metadata_t meta);
    int op_idx;
    logic [3:0] op_code;
    begin
      metadata_get_dma_candidate_count = 0;
      for (op_idx = 0; op_idx < 4; op_idx = op_idx + 1) begin
        op_code = metadata_get_op(meta.op, op_idx);
        if (op_code == `OP_IDLE) break;
        if ((op_code == `OP_CONV) || (op_code == `OP_FC)) begin
          metadata_get_dma_candidate_count += 2;
        end else if (metadata_op_ew_type(op_code) != EW_IS_NONE) begin
          if (op_idx == 0) metadata_get_dma_candidate_count += 1;
          if (metadata_op_ew_type(op_code) == EW_IS_BINARY) begin
            metadata_get_dma_candidate_count += 1;
          end
        end
      end
    end
  endfunction

  // Decode the one tensor stream omitted by weight_num as reuse of the
  // immediately preceding entry's result. Bank equality alone is insufficient:
  // an independent instruction may overwrite a bank after reloading it.
  task automatic metadata_get_previous_result_reuse(
    input int entry_idx,
    output bit depends_on_previous,
    output bit reuse_src0,
    output bit reuse_src1
  );
    int first_slot;
    int candidate_count;
    int omitted_count;
    int prev_store_bank;
    int src0_bank;
    int src1_bank;
    bit first_op_uses_src1;
    bit src0_matches;
    bit src1_matches;
    logic [3:0] first_op;
    begin
      depends_on_previous = 1'b0;
      reuse_src0 = 1'b0;
      reuse_src1 = 1'b0;
      first_slot = metadata_get_first_active_op_idx(metadata[entry_idx]);
      if (first_slot < 0) begin
        $fatal(1, "[METADATA][FATAL] entry%0d has no active compute op", entry_idx);
      end

      candidate_count = metadata_get_dma_candidate_count(metadata[entry_idx]);
      omitted_count = candidate_count - metadata[entry_idx].weight_num;
      if (omitted_count == 0) return;
      if (omitted_count != 1) begin
        $fatal(1,
               "[METADATA][FATAL] entry%0d weight_num=%0d omits %0d of %0d tensor inputs; only one previous-result reuse is representable",
               entry_idx, metadata[entry_idx].weight_num, omitted_count, candidate_count);
      end
      if (entry_idx == 0) begin
        $fatal(1,
               "[METADATA][FATAL] entry0 weight_num=%0d requires an unavailable previous result",
               metadata[entry_idx].weight_num);
      end

      first_op = metadata_get_op(metadata[entry_idx].op, first_slot);
      if (!((first_op == `OP_CONV) || (first_op == `OP_FC) ||
            (metadata_op_ew_type(first_op) != EW_IS_NONE))) begin
        $fatal(1, "[METADATA][FATAL] entry%0d starts with unsupported op %s",
               entry_idx, metadata_op_name(first_op));
      end

      prev_store_bank = metadata[entry_idx - 1].store_sram_idx;
      src0_bank = metadata_get_src0_bank(metadata[entry_idx], first_slot, first_op);
      first_op_uses_src1 = (first_op == `OP_CONV) || (first_op == `OP_FC) ||
                           (metadata_op_ew_type(first_op) == EW_IS_BINARY);
      src1_bank = first_op_uses_src1 ?
                  metadata_get_src1_bank(metadata[entry_idx], first_slot, first_op) : -1;
      src0_matches = (src0_bank == prev_store_bank);
      src1_matches = first_op_uses_src1 && (src1_bank == prev_store_bank);

      if (src0_matches == src1_matches) begin
        $fatal(1,
               "[METADATA][FATAL] entry%0d omits one tensor input but previous output bank%0d matches %0d first-op operands",
               entry_idx, prev_store_bank, int'(src0_matches) + int'(src1_matches));
      end

      depends_on_previous = 1'b1;
      reuse_src0 = src0_matches;
      reuse_src1 = src1_matches;
    end
  endtask

  // ----------------------------------------------------------------------------
  // Tensor payload DRAM image
  // ----------------------------------------------------------------------------
  // Build all tensor payloads needed before metadata auto-issue starts.
  task automatic metadata_write_tensor_payloads_to_dram(
    input int first_entry,
    input int entry_count
  );
    int bank;
    int broadcast;
    int total_count;
    int word_len;
    int unsigned dram_base;
    int num_m_tiles;
    int num_n_tiles;
    int input_words;
    int weight_words;
    int local_idx;
    int entry_idx;
    int op_idx;
    int entry_dma_start;
    int entry_dma_generated;
    bit depends_on_previous;
    bit reuse_src0;
    bit reuse_src1;
    logic [3:0] op_code;
    begin
      metadata_reset_tensor_dma_state();

      num_m_tiles = (M_DIM + PE_SIZE - 1) / PE_SIZE;
      num_n_tiles = (N_DIM + PE_SIZE - 1) / PE_SIZE;
      input_words = num_m_tiles * K_DIM;
      weight_words = K_DIM * num_n_tiles;

      for (local_idx = 0; local_idx < entry_count; local_idx = local_idx + 1) begin
        entry_idx = first_entry + local_idx;
        metadata_get_previous_result_reuse(entry_idx, depends_on_previous,
                                           reuse_src0, reuse_src1);
        if ((local_idx == 0) && depends_on_previous) begin
          $fatal(1,
                 "[METADATA][FATAL] job starting at entry%0d dropped its required previous result",
                 entry_idx);
        end
        entry_dma_start = metadata_tensor_dma_count;
        for (op_idx = 0; op_idx < 4; op_idx = op_idx + 1) begin
          op_code = metadata_get_op(metadata[entry_idx].op, op_idx);
          if (op_code == `OP_IDLE) break;

          // Payload sizes follow the same descriptor shape that RTL will use
          // after FETCH_DESC/SETUP_OP. This keeps the physical SRAM image
          // meaningful even when a metadata file mixes EW-only and CONV/FC ops.
          metadata_set_MNK_shape(metadata[entry_idx], op_idx, op_code);
          num_m_tiles = (M_DIM + PE_SIZE - 1) / PE_SIZE;
          num_n_tiles = (N_DIM + PE_SIZE - 1) / PE_SIZE;
          input_words = num_m_tiles * K_DIM;
          weight_words = K_DIM * num_n_tiles;

          if ((op_code == `OP_CONV) || (op_code == `OP_FC)) begin
            if (op_idx != 0) begin
              $display("[TENSOR DMA][FATAL] CONV/FC after op0 needs a later allocator update");
              $finish;
            end

            // Rebuild descriptor-shaped CONV/FC payloads for this instruction's
            // tensor DMA entries; golden replay applies them at instruction time.
            buid_case_AB(A_mat16, B_mat16, 2, 32'h1104);

            if (!reuse_src0) begin
              dram_base = metadata_tensor_payload_next;
              write_A_matrix_to_dram(dram_base);
              metadata_record_tensor_dma_entry(metadata_get_src0_bank(metadata[entry_idx], op_idx, op_code),
                                               dram_base, input_words,
                                               $sformatf("inst entry%0d op%0d %s input", entry_idx, op_idx, metadata_op_name(op_code)),
                                               TENSOR_DMA_REPLAY_IN_GOLDEN);
              metadata_tensor_payload_next += input_words;
            end

            if (!reuse_src1) begin
              dram_base = metadata_tensor_payload_next;
              write_B_matrix_to_dram(dram_base);
              metadata_record_tensor_dma_entry(metadata_get_src1_bank(metadata[entry_idx], op_idx, op_code),
                                               dram_base, weight_words,
                                               $sformatf("inst entry%0d op%0d %s weight", entry_idx, op_idx, metadata_op_name(op_code)),
                                               TENSOR_DMA_REPLAY_IN_GOLDEN);
              metadata_tensor_payload_next += weight_words;
            end
          end else if (metadata_op_ew_type(op_code) != EW_IS_NONE) begin
            // op0 may reuse the immediately preceding instruction result.
            // Later EW slots always consume the instruction-local result as src0.
            if ((op_idx == 0) && !reuse_src0) begin
              bank = metadata_get_src0_bank(metadata[entry_idx], op_idx, op_code);
              broadcast = metadata_get_broadcast(metadata[entry_idx], op_idx);
              total_count = metadata_get_src0_count(metadata[entry_idx], op_idx, op_code);
              dram_base = metadata_tensor_payload_next;
              build_EW_input1_matrix(EW_input1_mat16, (broadcast == 2), total_count);
              write_ew_tensor_to_dram(dram_base, EW_input1_mat16, op_code,
                                      (broadcast == 2), total_count);
              word_len = (broadcast == 2) ?
                         metadata_ceil_div((total_count <= 0) ? 1 : total_count, PE_SIZE) :
                         TOTAL_WORDS;
              metadata_record_tensor_dma_entry(bank, dram_base, word_len,
                                               $sformatf("inst entry%0d op%0d %s input1", entry_idx, op_idx, metadata_op_name(op_code)),
                                               TENSOR_DMA_REPLAY_IN_GOLDEN);
              metadata_tensor_payload_next += word_len;
            end

            // Binary EW also preloads src1/input2. Unary EXP/RCP intentionally skip this.
            if ((metadata_op_ew_type(op_code) == EW_IS_BINARY) &&
                !((op_idx == 0) && reuse_src1)) begin
              bank = metadata_get_src1_bank(metadata[entry_idx], op_idx, op_code);
              broadcast = metadata_get_broadcast(metadata[entry_idx], op_idx);
              total_count = metadata_get_src1_count(metadata[entry_idx], op_idx, op_code);

              dram_base = metadata_tensor_payload_next;
              build_EW_input2_matrix(EW_input2_mat16, op_code, (broadcast == 1), total_count);
              write_ew_tensor_to_dram(dram_base, EW_input2_mat16, op_code,
                                      (broadcast == 1), total_count);
              word_len = (broadcast == 1) ?
                         metadata_ceil_div((total_count <= 0) ? 1 : total_count, PE_SIZE) :
                         TOTAL_WORDS;
              metadata_record_tensor_dma_entry(bank, dram_base, word_len,
                                               $sformatf("inst entry%0d op%0d %s input2", entry_idx, op_idx, metadata_op_name(op_code)),
                                               TENSOR_DMA_REPLAY_IN_GOLDEN);
              metadata_tensor_payload_next += word_len;
            end
          end
        end

        entry_dma_generated = metadata_tensor_dma_count - entry_dma_start;
        if (metadata[entry_idx].weight_num != entry_dma_generated) begin
          $fatal(1,
                 "[TENSOR DMA][FATAL] entry%0d weight_num=%0d but builder generated %0d entries",
                 entry_idx, metadata[entry_idx].weight_num, entry_dma_generated);
        end
      end

      // $display("[TENSOR DMA] total_entries=%0d payload_words=%0d",
      //          metadata_tensor_dma_count, metadata_tensor_payload_next - TENSOR_PAYLOAD_DRAM_BASE);
    end
  endtask

  // ----------------------------------------------------------------------------
  // Instruction DRAM image
  // ----------------------------------------------------------------------------
  // Pack all metadata instructions and write the frontend instruction stream.
  task automatic metadata_write_inst_to_dram(
    input int first_entry,
    input int entry_count
  );
    int local_idx;
    int entry_idx;
    int word_idx;
    int slot_idx;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    begin
      packed_word = '0;
      metadata_inst_word_count = (entry_count + INST_PER_WORD - 1) / INST_PER_WORD;
      for (word_idx = 0; word_idx < 1024; word_idx++) begin
        metadata_inst_words[word_idx] = '0;
      end

      for (local_idx = 0; local_idx < entry_count; local_idx++) begin
        entry_idx = first_entry + local_idx;
        word_idx = local_idx / INST_PER_WORD;
        slot_idx = local_idx % INST_PER_WORD;
        if (slot_idx == 0) packed_word = '0;

        metadata_inst64[local_idx] =
          metadata_pack_inst64(metadata[entry_idx], metadata_inst_dsc_idx[local_idx]);
        packed_word[slot_idx*INST_BITS +: INST_BITS] = metadata_inst64[local_idx];

        if ((slot_idx == (INST_PER_WORD - 1)) ||
            (local_idx == (entry_count - 1))) begin
          metadata_inst_words[word_idx] = packed_word;
          write_dram_word(INST_DRAM_BASE + global_inst_offset + word_idx, packed_word);
          $display("[INST WRITE] addr=0x%08h (word_idx=%0d) data=0x%032h", (INST_DRAM_BASE + global_inst_offset + word_idx) << 4, word_idx, packed_word);
        end

        // DEBUG INFO
        $display("[INST] entry=%0d inst64=0x%016h op=0x%04h reserved=0x%04h b_cast=%b dsc_idx=%0d",
                 entry_idx, metadata_inst64[local_idx], metadata[entry_idx].op,
                 metadata_inst64[local_idx][47:33],
                 metadata_pack_b_cast(metadata[entry_idx]),
                 metadata_inst_dsc_idx[local_idx]);
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // Auto-issue metadata flow
  // ----------------------------------------------------------------------------
  // Launch the full metadata runtime path. This stays independent from
  // NPU_FSM_CTRL_TB so metadata regressions can run without ctrl_test.svh.
  // RTL-internal result-store and descriptor-SRAM probes belong to ctrl_test.svh.

  //Modifying this to be like queueing job (appending data)
  task automatic metadata_run_auto_issue_job(
    input int first_entry,
    input int entry_count,
    input bit is_last
  );
    int first_slot;
    begin
      first_slot = metadata_get_first_active_op_idx(metadata[first_entry]);
      metadata_set_MNK_shape(metadata[first_entry], first_slot,
                             metadata_get_op(metadata[first_entry].op, first_slot));
      metadata_write_desc_to_dram(first_entry, entry_count);
      metadata_write_inst_to_dram(first_entry, entry_count);
      metadata_write_tensor_payloads_to_dram(first_entry, entry_count);
      if (metadata_inst_word_count == 0) begin
        $display("[METADATA][FATAL] no instruction words generated");
        $finish;
      end

      write_job_header(entry_count, metadata_desc_word_count, metadata_tensor_dma_count, global_job_idx, is_last, current_result_base, global_inst_offset, global_desc_offset, global_dma_offset);
      // write_exp_rcp_lut_to_dram();

      $display("Finished writing job header for job %d", global_job_idx);
      $display("Word Counts: Inst:%d, Desc:%d, DMA:%d", metadata_inst_word_count, metadata_desc_word_count, metadata_tensor_dma_count);
      $display("Total Result Words:%d", TOTAL_WORDS);
      // Increment trackers
      global_inst_offset += metadata_inst_word_count;
      global_desc_offset += metadata_desc_word_count;
      global_dma_offset  += metadata_tensor_dma_count;
      global_tensor_payload_next = metadata_tensor_payload_next;
      current_result_base += TOTAL_WORDS;  //this part needs work
      global_job_idx++;

      // pulse_npu_start();
      // wait (done === 1'b1);
      // $display("[METADATA FLOW] PASS entries=%0d..%0d count=%0d",
              //  first_entry, first_entry + entry_count - 1, entry_count);
      // repeat (2) @(posedge clk);
    end
  endtask

  // ============================================================================
  // Optional NPU FSM Control Include
  // ============================================================================
  // Built only when NPU_FSM_CTRL_TB is defined. METADATA_TB must not depend on it.
`ifdef NPU_FSM_CTRL_TB
  `include "../00_TESTBED/npu_fsm_ctrl_test.svh"
`endif

  // ============================================================================
  // Metadata Regression Flow and Shadow SRAM Golden
  // ============================================================================

  // ----------------------------------------------------------------------------
  // metadata.txt loader
  // ----------------------------------------------------------------------------
  // Parse metadata.txt into metadata[] while preserving per-op field order.
  task automatic read_metadata_file(input string metadata_file, output int meta_count);
    int file, r, i;
    string line;
    metadata_t tmp;
    logic [3:0] op_code;
    begin
      meta_count = 0;
      file = $fopen(metadata_file, "r");
      if (file == 0) begin
        $display("[METADATA][FATAL] Unable to open %s", metadata_file);
        $finish;
      end

      while (1) begin
        line = metadata_read_next_line(file);
        if (line == "") break;
        if (line == "1234567890") break;

        tmp = '{default:0};
        metadata_set_param_defaults(tmp);
        r = $sscanf(line, "%b", tmp.op);
        line = metadata_read_next_line(file);
        r = $sscanf(line, "%d", tmp.weight_num);
        line = metadata_read_next_line(file);
        r = $sscanf(line, "%d %d %d %d %d %d", tmp.store_sram_idx, tmp.op0_weight_idx0,
                    tmp.op0_weight_idx1, tmp.op1_weight_idx0, tmp.op2_weight_idx0, tmp.op3_weight_idx0);
        line = metadata_read_next_line(file);
        r = $sscanf(line, "%d %d %d %d", tmp.op0_broadcast, tmp.op1_broadcast,
                    tmp.op2_broadcast, tmp.op3_broadcast);
        line = metadata_read_next_line(file);
        r = $sscanf(line, "%d %d %d %d", tmp.op0_data_counts, tmp.op1_data_counts,
                    tmp.op2_data_counts, tmp.op3_data_counts);
        line = metadata_read_next_line(file);
        r = $sscanf(line, "%d %d %d %d %d", tmp.op0_input_data_total_counts,
                    tmp.op0_weight_total_counts, tmp.op1_weight_total_counts,
                    tmp.op2_weight_total_counts, tmp.op3_weight_total_counts);

        for (i = 0; i < 4; i++) begin
          op_code = metadata_get_op(tmp.op, i);
          if (op_code == `OP_IDLE) break;
          line = metadata_read_next_line(file);
          case (op_code)
            `OP_CONV, `OP_FC: begin
              r = $sscanf(line, "%d %d %d", tmp.stride_h, tmp.stride_w, tmp.padding);
              line = metadata_read_next_line(file);
              r = $sscanf(line, "%d %d %d %d", tmp.batch, tmp.img_row, tmp.img_col, tmp.in_channel);
              line = metadata_read_next_line(file);
              r = $sscanf(line, "%d %d %d", tmp.out_channel, tmp.ker_row, tmp.ker_col);
              line = metadata_read_next_line(file);
              r = $sscanf(line, "%d %d %d", tmp.op_quant[i].conv_requant_multiplier,
                          tmp.op_quant[i].conv_requant_shift, tmp.op_quant[i].conv_requant_output_offset);
            end
            `OP_EXP: begin
              r = $sscanf(line, "%d %d %d %d %d %d %d", tmp.op_quant[i].exp_deq_input_range_radius,
                          tmp.op_quant[i].exp_deq_input_zero_point, tmp.op_quant[i].exp_deq_input_multiplier,
                          tmp.op_quant[i].exp_deq_input_left_shift, tmp.op_quant[i].exp_req_input_quantized_multiplier,
                          tmp.op_quant[i].exp_req_input_shift, tmp.op_quant[i].exp_req_input_offset);
            end
            `OP_RCP: begin
              r = $sscanf(line, "%d %d %d %d %d %d %d", tmp.op_quant[i].reciprocal_deq_input_range_radius,
                          tmp.op_quant[i].reciprocal_deq_input_zero_point, tmp.op_quant[i].reciprocal_deq_input_multiplier,
                          tmp.op_quant[i].reciprocal_deq_input_left_shift, tmp.op_quant[i].reciprocal_req_input_quantized_multiplier,
                          tmp.op_quant[i].reciprocal_req_input_shift, tmp.op_quant[i].reciprocal_req_input_offset);
            end
            `OP_ADD: begin
              r = $sscanf(line, "%d %d %d %d %d %d %d %d %d %d %d %d", tmp.op_quant[i].add_input1_offset,
                          tmp.op_quant[i].add_input2_offset, tmp.op_quant[i].add_left_shift, tmp.op_quant[i].add_input1_multiplier,
                          tmp.op_quant[i].add_input2_multiplier, tmp.op_quant[i].add_input1_shift, tmp.op_quant[i].add_input2_shift,
                          tmp.op_quant[i].add_output_multiplier, tmp.op_quant[i].add_output_shift, tmp.op_quant[i].add_output_offset,
                          tmp.op_quant[i].add_quantized_activation_min, tmp.op_quant[i].add_quantized_activation_max);
            end
            `OP_SUB: begin
              r = $sscanf(line, "%d %d %d %d %d %d %d %d %d %d %d %d", tmp.op_quant[i].sub_input1_offset,
                          tmp.op_quant[i].sub_input2_offset, tmp.op_quant[i].sub_left_shift, tmp.op_quant[i].sub_input1_multiplier,
                          tmp.op_quant[i].sub_input2_multiplier, tmp.op_quant[i].sub_input1_shift, tmp.op_quant[i].sub_input2_shift,
                          tmp.op_quant[i].sub_output_multiplier, tmp.op_quant[i].sub_output_shift, tmp.op_quant[i].sub_output_offset,
                          tmp.op_quant[i].sub_quantized_activation_min, tmp.op_quant[i].sub_quantized_activation_max);
            end
            `OP_MUL: begin
              r = $sscanf(line, "%d %d %d %d %d %d %d", tmp.op_quant[i].mul_input1_offset,
                          tmp.op_quant[i].mul_input2_offset, tmp.op_quant[i].mul_output_multiplier, tmp.op_quant[i].mul_output_shift,
                          tmp.op_quant[i].mul_output_offset, tmp.op_quant[i].mul_quantized_activation_min,
                          tmp.op_quant[i].mul_quantized_activation_max);
            end
            default: begin
              $display("[METADATA][FATAL] Unsupported op code %b in %s", op_code, metadata_file);
              $finish;
            end
          endcase
        end

        metadata[meta_count] = tmp;
        // $display("[METADATA] entry=%0d word=%016b ops=%-4s -> %-4s -> %-4s -> %-4s", meta_count, tmp.op,
        //          metadata_op_name(metadata_get_op(tmp.op, 0)), metadata_op_name(metadata_get_op(tmp.op, 1)),
        //          metadata_op_name(metadata_get_op(tmp.op, 2)), metadata_op_name(metadata_get_op(tmp.op, 3)));
        meta_count++;
      end
      $fclose(file);
      $display("[METADATA] read entries=%0d file=%s", meta_count, metadata_file);
    end
  endtask


  // ----------------------------------------------------------------------------
  // Runtime bank and quant setup
  // ----------------------------------------------------------------------------
  task automatic metadata_check_tensor_bank(input int bank, input string field_name);
    begin
      if ((bank < 0) || (bank > 7)) begin
        $display("[METADATA][FATAL] %s bank id must be in 0..7, got %0d", field_name, bank);
        $finish;
      end
    end
  endtask

  // Validate descriptor bank/broadcast fields used by the metadata runtime path.
  task automatic metadata_validate_op_banks(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int ew_src0_bank;
    int ew_src1_bank;
    begin
      metadata_check_tensor_bank(meta.store_sram_idx, "store_sram_idx");

      if ((op_idx == 0) && ((op_code == `OP_CONV) || (op_code == `OP_FC))) begin
        metadata_check_tensor_bank(meta.op0_weight_idx0, "op0_weight_idx0/data/src0");
        metadata_check_tensor_bank(meta.op0_weight_idx1, "op0_weight_idx1/weight/src1");
      end else if (metadata_op_ew_type(op_code) == EW_IS_BINARY) begin
        ew_src0_bank = metadata_get_src0_bank(meta, op_idx, op_code);
        ew_src1_bank = metadata_get_src1_bank(meta, op_idx, op_code);
        metadata_check_tensor_bank(ew_src0_bank, $sformatf("op%0d_src0/input1", op_idx));
        metadata_check_tensor_bank(ew_src1_bank, $sformatf("op%0d_src1/input2", op_idx));
        if (ew_src1_bank == meta.store_sram_idx) begin
          $display("[METADATA][FATAL] op%0d input2 bank equals dst/store bank %0d; current baseline would overwrite result payload",
                   op_idx, ew_src1_bank);
          $finish;
        end
      end else if (metadata_op_ew_type(op_code) == EW_IS_UNARY) begin
        ew_src0_bank = metadata_get_src0_bank(meta, op_idx, op_code);
        metadata_check_tensor_bank(ew_src0_bank, $sformatf("op%0d_src0/input", op_idx));
      end
    end
  endtask


  // Copy metadata quantization fields into TB golden parameter signals.
  task automatic apply_metadata_params(input metadata_t meta, input int op_idx);
    metadata_quant_t quant;
    begin
      quant = meta.op_quant[op_idx];
      conv_qm         = quant.conv_requant_multiplier;
      shift           = quant.conv_requant_shift;
      conv_out_offset = quant.conv_requant_output_offset;
      conv_act_min    = quant.conv_output_activation_min;
      conv_act_max    = quant.conv_output_activation_max;
      conv_input_requant_multiplier = quant.conv_input_requant_multiplier;
      conv_input_requant_shift      = quant.conv_input_requant_shift;
      conv_input_requant_offset     = quant.conv_input_requant_offset;
      conv_input_activation_min     = quant.conv_input_activation_min;
      conv_input_activation_max     = quant.conv_input_activation_max;
      conv_weight_requant_multiplier = quant.conv_weight_requant_multiplier;
      conv_weight_requant_shift      = quant.conv_weight_requant_shift;
      conv_weight_requant_offset     = quant.conv_weight_requant_offset;
      conv_weight_activation_min     = quant.conv_weight_activation_min;
      conv_weight_activation_max     = quant.conv_weight_activation_max;
      exp_deq_input_range_radius         = quant.exp_deq_input_range_radius;
      exp_deq_input_zero_point           = quant.exp_deq_input_zero_point;
      exp_deq_input_multiplier           = quant.exp_deq_input_multiplier;
      exp_deq_input_left_shift           = quant.exp_deq_input_left_shift;
      exp_req_input_quantized_multiplier = quant.exp_req_input_quantized_multiplier;
      exp_req_input_shift                = quant.exp_req_input_shift;
      exp_req_input_offset               = quant.exp_req_input_offset;
      reciprocal_deq_input_range_radius         = quant.reciprocal_deq_input_range_radius;
      reciprocal_deq_input_zero_point           = quant.reciprocal_deq_input_zero_point;
      reciprocal_deq_input_multiplier           = quant.reciprocal_deq_input_multiplier;
      reciprocal_deq_input_left_shift           = quant.reciprocal_deq_input_left_shift;
      reciprocal_req_input_quantized_multiplier = quant.reciprocal_req_input_quantized_multiplier;
      reciprocal_req_input_shift                = quant.reciprocal_req_input_shift;
      reciprocal_req_input_offset               = quant.reciprocal_req_input_offset;
      add_input1_offset     = quant.add_input1_offset;
      add_input2_offset     = quant.add_input2_offset;
      add_left_shift        = quant.add_left_shift;
      add_input1_multiplier = quant.add_input1_multiplier;
      add_input2_multiplier = quant.add_input2_multiplier;
      add_input1_shift      = quant.add_input1_shift;
      add_input2_shift      = quant.add_input2_shift;
      add_output_multiplier = quant.add_output_multiplier;
      add_output_shift      = quant.add_output_shift;
      add_output_offset     = quant.add_output_offset;
      add_act_min           = quant.add_quantized_activation_min;
      add_act_max           = quant.add_quantized_activation_max;
      sub_input1_offset     = quant.sub_input1_offset;
      sub_input2_offset     = quant.sub_input2_offset;
      sub_left_shift        = quant.sub_left_shift;
      sub_input1_multiplier = quant.sub_input1_multiplier;
      sub_input2_multiplier = quant.sub_input2_multiplier;
      sub_input1_shift      = quant.sub_input1_shift;
      sub_input2_shift      = quant.sub_input2_shift;
      sub_output_multiplier = quant.sub_output_multiplier;
      sub_output_shift      = quant.sub_output_shift;
      sub_output_offset     = quant.sub_output_offset;
      sub_act_min           = quant.sub_quantized_activation_min;
      sub_act_max           = quant.sub_quantized_activation_max;
      mul_input1_offset     = quant.mul_input1_offset;
      mul_input2_offset     = quant.mul_input2_offset;
      mul_output_multiplier = quant.mul_output_multiplier;
      mul_output_shift      = quant.mul_output_shift;
      mul_output_offset     = quant.mul_output_offset;
      mul_act_min           = quant.mul_quantized_activation_min;
      mul_act_max           = quant.mul_quantized_activation_max;
      mul_in1_multiplier    = quant.mul_in1_requant_multiplier;
      mul_in1_shift         = quant.mul_in1_requant_shift;
      mul_in1_offset        = quant.mul_in1_requant_offset;
      mul_in1_act_min       = quant.mul_in1_activation_min;
      mul_in1_act_max       = quant.mul_in1_activation_max;
      mul_in2_multiplier    = quant.mul_in2_requant_multiplier;
      mul_in2_shift         = quant.mul_in2_requant_shift;
      mul_in2_offset        = quant.mul_in2_requant_offset;
      mul_in2_act_min       = quant.mul_in2_activation_min;
      mul_in2_act_max       = quant.mul_in2_activation_max;
    end
  endtask


  // ----------------------------------------------------------------------------
  // Shadow SRAM readers and writers
  // ----------------------------------------------------------------------------
  // Reject consumers that request more words than the latest logical producer
  // wrote. Physical tail words can remain valid after a shorter overwrite, but
  // they are not part of the current tensor.
  task automatic metadata_shadow_require_words(
    input int bank,
    input int required_words,
    input string consumer
  );
    begin
      if ((bank < 0) || (bank > 7) ||
          (required_words < 0) ||
          (required_words > (1 << `SRAM_ADDR_WIDTH))) begin
        $fatal(1,
               "[METADATA][FATAL] %s invalid shadow extent bank=%0d required=%0d",
               consumer, bank, required_words);
      end
      if (required_words > metadata_tensor_producer_words[bank]) begin
        $fatal(1,
               "[METADATA][FATAL] %s bank=%0d requires %0d words but current producer has %0d",
               consumer, bank, required_words, metadata_tensor_producer_words[bank]);
      end
    end
  endtask

  // Read one INT16 lane from the TB shadow image of physical SRAM contents.
  function automatic logic signed [`INT16_SIZE-1:0] metadata_shadow_lane(input int bank, input int addr, input int lane);
    logic [`SRAM_WIDTH_O-1:0] word;
    logic signed [`INT16_SIZE-1:0] lane_value;
    begin
      if ((bank < 0) || (bank > 7) || (addr < 0) || (addr >= (1 << `SRAM_ADDR_WIDTH)) ||
          (lane < 0) || (lane >= LANES)) begin
        $fatal(1, "[METADATA][FATAL] shadow lane out of range bank=%0d addr=%0d lane=%0d",
               bank, addr, lane);
      end
      if (addr >= metadata_tensor_producer_words[bank]) begin
        $fatal(1,
               "[METADATA][FATAL] shadow read exceeds current producer bank=%0d addr=%0d producer_words=%0d",
               bank, addr, metadata_tensor_producer_words[bank]);
      end
      if (!metadata_tensor_word_valid[bank][addr]) begin
        $fatal(1, "[METADATA][FATAL] shadow read of unwritten word bank=%0d addr=%0d",
               bank, addr);
      end
      word = metadata_tensor_expected[bank][addr];
      lane_value = word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE];
      if ($isunknown(lane_value)) begin
        $fatal(1, "[METADATA][FATAL] shadow read contains X/Z bank=%0d addr=%0d lane=%0d",
               bank, addr, lane);
      end
      metadata_shadow_lane = lane_value;
    end
  endfunction

  // Unpack SA input layout: rows are distributed across lanes by M index.
  task automatic metadata_shadow_unpack_sa_input(
    input int bank,
    ref logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_K-1]
  );
    int m;
    int k;
    int addr;
    int lane;
    int required_words;
    begin
      required_words = ((M_DIM + LANES - 1) / LANES) * K_DIM;
      metadata_shadow_require_words(bank, required_words, "SA input");
      for (m = 0; m < M_DIM; m = m + 1) begin
        for (k = 0; k < K_DIM; k = k + 1) begin
          addr = (m / LANES) * K_DIM + k;
          lane = m % LANES;
          out_mat[m][k] = metadata_shadow_lane(bank, addr, lane);
        end
      end
    end
  endtask

  // Unpack SA weight layout: each K row is tiled across N lanes.
  task automatic metadata_shadow_unpack_sa_weight(
    input int bank,
    ref logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_K-1][0:MAX_N-1]
  );
    int k;
    int n;
    int addr;
    int lane;
    int words_per_row;
    begin
      words_per_row = (N_DIM + LANES - 1) / LANES;
      if (words_per_row == 0) words_per_row = 1;
      metadata_shadow_require_words(bank, K_DIM * words_per_row, "SA weight");
      for (k = 0; k < K_DIM; k = k + 1) begin
        for (n = 0; n < N_DIM; n = n + 1) begin
          addr = k * words_per_row + (n / LANES);
          lane = n % LANES;
          out_mat[k][n] = metadata_shadow_lane(bank, addr, lane);
        end
      end
    end
  endtask

  // EW operands use the flat physical layout [word_addr][lane]. Binary src1
  // can broadcast a vector spanning one or more words across logical columns.
  task automatic metadata_shadow_unpack_ew_operand(
    input int bank,
    input bit broadcast,
    input int broadcast_count,
    input int desc_n,
    ref logic signed [`INT16_SIZE-1:0] out_mat [0:MAX_M-1][0:MAX_N-1]
  );
    int addr;
    int lane;
    int words_per_row;
    int tile_col;
    int logical_col;
    int src_element_idx;
    int src_word_addr;
    int src_lane_idx;
    int required_words;
    string consumer_tag;
    begin
      words_per_row = (desc_n + LANES - 1) / LANES;
      if (words_per_row == 0) words_per_row = 1;
      if (broadcast) begin
        required_words = metadata_ceil_div((broadcast_count <= 0) ? 1 : broadcast_count,
                                           LANES);
      end else begin
        required_words = TOTAL_WORDS;
      end
      consumer_tag = broadcast ? "EW broadcast operand" : "EW operand";
      metadata_shadow_require_words(
        bank,
        required_words,
        consumer_tag
      );

      for (addr = 0; addr < TOTAL_WORDS; addr = addr + 1) begin
        for (lane = 0; lane < LANES; lane = lane + 1) begin
          if (broadcast) begin
            tile_col = addr % words_per_row;
            logical_col = tile_col * LANES + lane;
            src_element_idx = (broadcast_count <= 1) ? 0 :
                              (logical_col % broadcast_count);
            src_word_addr = src_element_idx / LANES;
            src_lane_idx = src_element_idx % LANES;
            out_mat[addr][lane] = metadata_shadow_lane(bank, src_word_addr, src_lane_idx);
          end else begin
            out_mat[addr][lane] = metadata_shadow_lane(bank, addr, lane);
          end
        end
      end
    end
  endtask

  // Write EW golden output back to shadow SRAM exactly as RTL overwrites dst base 0.
  task automatic metadata_shadow_write_ew_result(
    input int bank,
    input logic signed [`INT16_SIZE-1:0] in_mat [0:MAX_M-1][0:MAX_N-1]
  );
    int addr;
    int lane;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    begin
      metadata_check_tensor_bank(bank, "metadata physical golden dst");
      for (addr = 0; addr < TOTAL_WORDS; addr = addr + 1) begin
        packed_word = '0;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
          packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] = in_mat[addr][lane];
        end
        metadata_tensor_expected[bank][addr] = packed_word;
        metadata_tensor_word_valid[bank][addr] = 1'b1;
      end
      metadata_tensor_producer_words[bank] = TOTAL_WORDS;
      if (metadata_tensor_bank_words[bank] < TOTAL_WORDS) begin
        metadata_tensor_bank_words[bank] = TOTAL_WORDS;
      end
    end
  endtask

  // Write SA golden output back using the same packed output layout as RTL.
  task automatic metadata_shadow_write_sa_result(
    input int bank,
    input logic signed [`INT16_SIZE-1:0] in_mat [0:MAX_M-1][0:MAX_N-1]
  );
    int m;
    int tile_n;
    int lane;
    int n;
    int addr;
    int words_per_row;
    int signed padded_y32;
    int signed padded_clamp;
    logic signed [`INT16_SIZE-1:0] padded_lane;
    logic [`SRAM_WIDTH_O-1:0] packed_word;
    begin
      metadata_check_tensor_bank(bank, "metadata physical golden dst");
      words_per_row = (N_DIM + LANES - 1) / LANES;
      if (words_per_row == 0) words_per_row = 1;

      // SA still writes a full SRAM word for the final partial-N tile. For
      // padded lanes the PE accumulation is zero, then the normal output
      // requant/offset/activation path is applied.
      padded_y32 = ref_multiply_by_conv_qm(0, conv_qm, shift) + conv_out_offset;
      if (padded_y32 > conv_act_max) padded_clamp = conv_act_max;
      else if (padded_y32 < conv_act_min) padded_clamp = conv_act_min;
      else padded_clamp = padded_y32;
      padded_lane = sat_int16(padded_clamp);

      for (m = 0; m < M_DIM; m = m + 1) begin
        for (tile_n = 0; tile_n < words_per_row; tile_n = tile_n + 1) begin
          packed_word = '0;
          for (lane = 0; lane < LANES; lane = lane + 1) begin
            n = tile_n * LANES + lane;
            packed_word[((lane+1)*`INT16_SIZE-1) -: `INT16_SIZE] =
              (n < N_DIM) ? in_mat[m][n] : padded_lane;
          end
          addr = m * words_per_row + tile_n;
          metadata_tensor_expected[bank][addr] = packed_word;
          metadata_tensor_word_valid[bank][addr] = 1'b1;
        end
      end
      metadata_tensor_producer_words[bank] = M_DIM * words_per_row;
      if (metadata_tensor_bank_words[bank] < metadata_tensor_producer_words[bank]) begin
        metadata_tensor_bank_words[bank] = metadata_tensor_producer_words[bank];
      end
    end
  endtask

  // ----------------------------------------------------------------------------
  // Physical EW shape setup
  // ----------------------------------------------------------------------------
  // EW golden treats each SRAM word as one row and LANES as columns.
  task automatic metadata_apply_physical_ew_shape(input metadata_t meta, input int op_idx, input logic [3:0] op_code);
    int total_words;
    begin
      total_words = metadata_get_total_words_for_op(meta, op_idx, op_code);
      if ((total_words <= 0) || (total_words > MAX_M)) begin
        $display("[METADATA][FATAL] op%0d=%s physical EW total_words=%0d exceeds MAX_M=%0d",
                 op_idx, metadata_op_name(op_code), total_words, MAX_M);
        $finish;
      end
      M_DIM = total_words;
      K_DIM = 0;
      N_DIM = LANES;
      TOTAL_WORDS = total_words;
      end
  endtask

  // ----------------------------------------------------------------------------
  // Shadow SRAM golden execution
  // ----------------------------------------------------------------------------
  // Read operands from shadow SRAM, run golden compute, then update dst bank.
  task automatic run_metadata_op_sram_golden(input metadata_t meta, input int op_idx, input logic [3:0] op_code, inout int last_slot);
    int src0_bank;
    int src1_bank;
    int dst_bank;
    int broadcast;
    int broadcast_count;
    int desc_n;
    begin
      src0_bank = metadata_get_src0_bank(meta, op_idx, op_code);
      src1_bank = metadata_get_src1_bank(meta, op_idx, op_code);
      dst_bank  = meta.store_sram_idx;
      broadcast = metadata_get_broadcast(meta, op_idx);
      broadcast_count = metadata_get_broadcast_count(meta, op_idx, op_code);
      desc_n = metadata_get_n_for_op(meta, op_idx, op_code);

      metadata_validate_op_banks(meta, op_idx, op_code);
      apply_metadata_params(meta, op_idx);

      case (op_code)
        `OP_IDLE: begin end
        `OP_CONV, `OP_FC: begin
          metadata_set_MNK_shape(meta, op_idx, op_code);
          metadata_shadow_unpack_sa_input(src0_bank, A_mat16);
          metadata_shadow_unpack_sa_weight(src1_bank, B_mat16);
          compute_CONV(A_mat16, B_mat16, C_golden16);
          metadata_shadow_write_sa_result(dst_bank, C_golden16);
          last_slot = 0;
        end
        `OP_ADD: begin
          metadata_apply_physical_ew_shape(meta, op_idx, op_code);
          metadata_shadow_unpack_ew_operand(src0_bank, (broadcast == 2), broadcast_count, desc_n, EW_input1_mat16);
          metadata_shadow_unpack_ew_operand(src1_bank, (broadcast == 1), broadcast_count, desc_n, EW_input2_mat16);
          compute_ADD_SUB(`OP_ADD, EW_input2_mat16, EW_input1_mat16, ADD_golden16);
          metadata_shadow_write_ew_result(dst_bank, ADD_golden16);
          last_slot = 2;
        end
        `OP_SUB: begin
          metadata_apply_physical_ew_shape(meta, op_idx, op_code);
          metadata_shadow_unpack_ew_operand(src0_bank, (broadcast == 2), broadcast_count, desc_n, EW_input1_mat16);
          metadata_shadow_unpack_ew_operand(src1_bank, (broadcast == 1), broadcast_count, desc_n, EW_input2_mat16);
          compute_ADD_SUB(`OP_SUB, EW_input2_mat16, EW_input1_mat16, SUB_golden16);
          metadata_shadow_write_ew_result(dst_bank, SUB_golden16);
          last_slot = 1;
        end
        `OP_MUL: begin
          metadata_apply_physical_ew_shape(meta, op_idx, op_code);
          metadata_shadow_unpack_ew_operand(src0_bank, (broadcast == 2), broadcast_count, desc_n, EW_input1_mat16);
          metadata_shadow_unpack_ew_operand(src1_bank, (broadcast == 1), broadcast_count, desc_n, EW_input2_mat16);
          compute_MUL(EW_input2_mat16, EW_input1_mat16, MUL_golden16);
          metadata_shadow_write_ew_result(dst_bank, MUL_golden16);
          last_slot = 3;
        end
        `OP_EXP: begin
          metadata_apply_physical_ew_shape(meta, op_idx, op_code);
          metadata_shadow_unpack_ew_operand(src0_bank, 1'b0, 0, desc_n, EW_input1_mat16);
          compute_EXP(EW_input1_mat16, EXP_golden16);
          metadata_shadow_write_ew_result(dst_bank, EXP_golden16);
          last_slot = 4;
        end
        `OP_RCP: begin
          metadata_apply_physical_ew_shape(meta, op_idx, op_code);
          metadata_shadow_unpack_ew_operand(src0_bank, 1'b0, 0, desc_n, EW_input1_mat16);
          compute_RCP(EW_input1_mat16, RCP_golden16);
          metadata_shadow_write_ew_result(dst_bank, RCP_golden16);
          last_slot = 5;
        end
        default: begin
          $display("[METADATA][FATAL] Unsupported op code %b", op_code);
          $finish;
        end
      endcase

      // $display("[METADATA SRAM GOLDEN] op%0d=%s src0=%0d src1=%0d dst=%0d words=%0d",
      //          op_idx, metadata_op_name(op_code), src0_bank, src1_bank, dst_bank, TOTAL_WORDS);
    end
  endtask

  // Select the final golden matrix produced by the last metadata op.
  task automatic check_metadata_result(input string case_name, input int last_slot);
    begin
      case (last_slot)
        0: check_results(case_name, C_golden16);
        1: check_results(case_name, SUB_golden16);
        2: check_results(case_name, ADD_golden16);
        3: check_results(case_name, MUL_golden16);
        4: check_results(case_name, EXP_golden16);
        5: check_results(case_name, RCP_golden16);
        default: begin $display("[METADATA][FATAL] No valid output stage to check"); $finish; end
      endcase
    end
  endtask

  // Iterate the four op slots in one metadata instruction and build shadow golden state.
  // RTL auto-issue has already executed the real ops before this loop runs.
  task automatic run_metadata_entry(input metadata_t meta, input int entry_idx, inout int last_slot);
    int op_idx;
    logic [3:0] op_code;
    begin
      metadata_print_entry(meta, entry_idx);
      for (op_idx = 0; op_idx < 4; op_idx++) begin
        op_code = metadata_get_op(meta.op, op_idx);
        if (op_code == `OP_IDLE) break;
        // $display("[METADATA RUN] entry%2d op%0d=%-4s(%04b)", entry_idx, op_idx, metadata_op_name(op_code), op_code);
        run_metadata_op_sram_golden(meta, op_idx, op_code, last_slot);
      end
    end
  endtask

  // Build expected output from the TB shadow SRAM after RTL auto-issue completes.
  task automatic build_metadata_sram_golden(
    input int first_entry,
    input int entry_count,
    output int last_slot
  );
    int local_idx;
    int entry_idx;
    int entry_i;
    int tensor_entry_cursor;
    begin
      last_slot = -1;
      tensor_entry_cursor = 0;
      // Match RTL timing: each instruction loads exactly weight_num tensor
      // entries, then the golden op consumes the resulting shadow SRAM image.
      for (local_idx = 0; local_idx < entry_count; local_idx++) begin
        entry_idx = first_entry + local_idx;
        for (entry_i = 0; entry_i < metadata[entry_idx].weight_num; entry_i++) begin
          metadata_apply_tensor_dma_entry_to_shadow(tensor_entry_cursor);
          tensor_entry_cursor++;
        end
        run_metadata_entry(metadata[entry_idx], entry_idx, last_slot);
      end
      if (tensor_entry_cursor != metadata_tensor_dma_count) begin
        $display("[TENSOR DMA][FATAL] metadata weight_num consumed %0d tensor entries, table has %0d",
                 tensor_entry_cursor, metadata_tensor_dma_count);
        $finish;
      end
    end
  endtask

  // Classify whether one entry consumes the immediately preceding entry.
  // Independent entries become separate jobs so each result reaches OUT_DRAM.
  task automatic metadata_get_entry_dependency(
    input int entry_idx,
    output bit depends_on_previous
  );
    bit reuse_src0;
    bit reuse_src1;
    begin
      metadata_get_previous_result_reuse(entry_idx, depends_on_previous,
                                         reuse_src0, reuse_src1);
    end
  endtask

  // Execute and check one contiguous dependency group.
  // task automatic run_metadata_job(
  //   input string metadata_file,
  //   input int first_entry,
  //   input int entry_count
  // );
  //   int first_slot;
  //   int last_slot;
  //   string case_name;
  //   begin
  //     metadata_run_auto_issue_job(first_entry, entry_count);

  //     first_slot = metadata_get_first_active_op_idx(metadata[first_entry]);
  //     metadata_set_MNK_shape(metadata[first_entry], first_slot,
  //                            metadata_get_op(metadata[first_entry].op, first_slot));
  //     $display("==============================================================================");
  //     $display("[METADATA JOB]");
  //     $display("  file         : %s", metadata_file);
  //     $display("  entries      : %0d..%0d", first_entry,
  //              first_entry + entry_count - 1);
  //     $display("  dims         : M=%0d  K=%0d  N=%0d", M_DIM, K_DIM, N_DIM);
  //     $display("  total_words  : %0d", TOTAL_WORDS);

  //     build_metadata_sram_golden(first_entry, entry_count, last_slot);

  //     // --- ADD THIS BLOCK TO DUMP THE SV GOLDEN BINARY WORDS TO FILE ---
  //     begin
  //       int final_bank = metadata[metadata_num_ops-1].store_sram_idx;
  //       int fd;
  //       int w, b;
  //       logic [7:0] byte_val;
  //       logic [`SRAM_WIDTH_O-1:0] word_val;
        
  //       $display("==============================================================================");
  //       $display("[SV_GOLDEN_DUMP] Writing %0d words from final bank %0d to golden_result.bin", TOTAL_WORDS, final_bank);
  //       $display("==============================================================================");
        
  //       // Open file in binary write mode
  //       fd = $fopen("/home/jasper/npu/npu_testing_system/tb_scripts/all_ops_8x8/golden_result_sv_each.bin", "wb");
  //       if (fd) begin
  //         for (w = 0; w < TOTAL_WORDS; w++) begin
  //           word_val = metadata_tensor_expected[final_bank][w];
            
  //           // Write out the 128-bit word byte-by-byte (Little-Endian)
  //           // This perfectly mimics Python's .to_bytes(16, byteorder="little")
  //           for (b = 0; b < (`SRAM_WIDTH_O / 8); b = b + 1) begin
  //             byte_val = word_val[b*8 +: 8];
  //             $fwrite(fd, "%c", byte_val);
  //           end
  //         end
  //         $fclose(fd);
  //         $display("[SV_GOLDEN_DUMP] Successfully wrote %0d bytes to golden_result.bin", TOTAL_WORDS * (`SRAM_WIDTH_O / 8));
  //       end else begin
  //         $display("[SV_GOLDEN_DUMP] FATAL ERROR: Could not open golden_result.bin for writing.");
  //       end
  //       $display("==============================================================================");
  //     end
  //     // -----------------------------------------------------------------

  //     unpack_result_from_dram(OUT_DRAM_BASE);
  //     case_name = $sformatf("metadata file %s entries %0d..%0d",
  //                           metadata_file, first_entry,
  //                           first_entry + entry_count - 1);
  //     check_metadata_result(case_name, last_slot);
  //   end
  // endtask

  // ----------------------------------------------------------------------------
  // Metadata main flow
  // ----------------------------------------------------------------------------
  // Run each dependency group separately so every independent result is checked.
  task automatic run_metadata_test();
    string metadata_file;
    int group_first;
    int group_count;
    bit depends_on_previous;
    bit is_last;
    logic [31:0] dram_cycles;
    logic [31:0] sa_cycles;
    logic [31:0] ew_cycles;
    logic [31:0] total_cycles;
    begin
      int first_slot;
      int last_slot;
      string case_name;

      metadata_file = "../00_TESTBED/metadata_all_ops_smoke.txt";
      void'($value$plusargs("METADATA_FILE=%s", metadata_file));
      read_metadata_file(metadata_file, metadata_num_ops);
      if (metadata_num_ops == 0) begin
        $display("[METADATA][FATAL] no metadata entries in %s", metadata_file);
        $finish;
      end

      if ($test$plusargs("METADATA_QUANT_SLOT_CHECK")) begin
        metadata_check_quant_slot_smoke(metadata[0]);
      end

      if ((metadata_get_op(metadata[0].op, 0) == `OP_IDLE) ||
          !((metadata_get_op(metadata[0].op, 0) == `OP_CONV) || (metadata_get_op(metadata[0].op, 0) == `OP_FC) ||
            (metadata_op_ew_type(metadata_get_op(metadata[0].op, 0)) != EW_IS_NONE))) begin
        $display("[METADATA][FATAL] first metadata entry op0 must be supported compute op, got %b",
                 metadata_get_op(metadata[0].op, 0));
        $finish;
      end

      // Metadata correctness is independent of the optional FSM/control smoke.
      // Use NPU_FSM_CTRL_TB when only frontend/controller behavior is needed.
      reset_dut();

      metadata_get_entry_dependency(0, depends_on_previous);
      group_first = 0;
      while (group_first < metadata_num_ops) begin
        group_count = 1;
        while ((group_first + group_count) < metadata_num_ops) begin
          metadata_get_entry_dependency(group_first + group_count,
                                        depends_on_previous);
          if (!depends_on_previous) break;
          group_count++;
        end
        // run_metadata_job(metadata_file, group_first, group_count);
        is_last = ((group_first + group_count) >= metadata_num_ops);
        metadata_run_auto_issue_job(group_first, group_count, is_last); //more like queue job
        
        group_first += group_count;
      end
      write_exp_rcp_lut_to_dram();

      $display("==============================================================================");
      $display("[TESTBENCH] Dumping initialized DRAM regions to .bin files...");
      $display("==============================================================================");
      
      dump_dram_to_bin("dram_jobs.bin",            JOB_DRAM_BASE,              global_job_idx);
      dump_dram_to_bin("dram_instructions.bin",    INST_DRAM_BASE,             global_inst_offset);
      dump_dram_to_bin("dram_descriptors.bin",     DESC_DRAM_BASE,             global_desc_offset);
      dump_dram_to_bin("dram_dma_tables.bin",      TENSOR_DMA_TABLE_DRAM_BASE, global_dma_offset);
      
      // The tensor payload span is the difference between the next pointer and the base
      dump_dram_to_bin("dram_tensor_payloads.bin", TENSOR_PAYLOAD_DRAM_BASE,   global_tensor_payload_next - TENSOR_PAYLOAD_DRAM_BASE);
      
      // LUTs are a fixed block. RCP starts at offset 256, plus its word length (LUT_WORD_NUM).
      dump_dram_to_bin("dram_luts.bin",            LUT_DRAM_BASE,              RCP_LUT_BASE_ADDR + LUT_WORD_NUM);
      
      $display("==============================================================================");

      $display("[TESTBENCH] All jobs queued. Pulsing start_i ONCE.");
      pulse_npu_start();
      wait (done === 1'b1);
      $display("[TESTBENCH] NPU finished all jobs in the queue!");
      repeat (2) @(posedge clk);
      //Have to implement checking below
      $display("========================================");
      $display("[TESTBENCH] Starting Verification Phase");
      group_first = 0;
      current_result_base = OUT_DRAM_BASE; // Reset to the first output address
      global_tensor_payload_next = TENSOR_PAYLOAD_DRAM_BASE;
      while (group_first < metadata_num_ops) begin
        group_count = 1;
        while ((group_first + group_count) < metadata_num_ops) begin
          metadata_get_entry_dependency(group_first + group_count, depends_on_previous);
          if (!depends_on_previous) break;
          group_count++;
        end
        
        // A. Rebuild the internal testbench tracking arrays for THIS specific chunk
        // (This safely overwrites the deterministic payload DRAM with identical data)
        metadata_write_tensor_payloads_to_dram(group_first, group_count);

        global_tensor_payload_next = metadata_tensor_payload_next;
        
        // B. Generate the expected golden SRAM output for this chunk
        build_metadata_sram_golden(group_first, group_count, last_slot);

        // C. Unpack the hardware results from this chunk's specific DRAM address!
        unpack_result_from_dram(current_result_base);

        // D. Compare the Hardware DRAM vs the Golden SRAM
        case_name = $sformatf("Job chunk entries %0d..%0d", group_first, group_first + group_count - 1);
        check_metadata_result(case_name, last_slot);

        // E. Move to the next chunk's output address
        // Make sure this matches exactly how you offset it during queueing!
        current_result_base += TOTAL_WORDS; 
        group_first += group_count;
      end

      $display("==============================================================================");
      $display("[TESTBENCH] Dumping hardware results from DRAM to .bin...");
      dump_dram_to_bin("dram_all_results.bin", OUT_DRAM_BASE, current_result_base - OUT_DRAM_BASE);
      $display("==============================================================================");
      
      dram_cycles = {dram_mem[PROFILE_DRAM_BASE + 3], dram_mem[PROFILE_DRAM_BASE + 2], dram_mem[PROFILE_DRAM_BASE + 1], dram_mem[PROFILE_DRAM_BASE + 0]};
      sa_cycles   = {dram_mem[PROFILE_DRAM_BASE + 7], dram_mem[PROFILE_DRAM_BASE + 6], dram_mem[PROFILE_DRAM_BASE + 5], dram_mem[PROFILE_DRAM_BASE + 4]};
      ew_cycles   = {dram_mem[PROFILE_DRAM_BASE + 11], dram_mem[PROFILE_DRAM_BASE + 10], dram_mem[PROFILE_DRAM_BASE + 9], dram_mem[PROFILE_DRAM_BASE + 8]};
      total_cycles = {dram_mem[PROFILE_DRAM_BASE + 15], dram_mem[PROFILE_DRAM_BASE + 14], dram_mem[PROFILE_DRAM_BASE + 13], dram_mem[PROFILE_DRAM_BASE + 12]};

      $display("\n==================================================");
      $display("               NPU PERFORMANCE METRICS            ");
      $display("==================================================");
      $display(" DRAM Transfer Cycles : %0d", dram_cycles);
      $display(" Systolic Array Cycles: %0d", sa_cycles);
      $display(" Element-Wise Cycles  : %0d", ew_cycles);
      $display(" Total Cycles  : %0d", total_cycles);
      $display("==================================================\n");

    end
  endtask

  // ============================================================================
  // Reset Helpers
  // ============================================================================
  // Drive all TB-controlled DUT inputs to a known idle state.
  task automatic tb_idle_inputs();
    begin
      npu_start_i = 1'b0;
      dram_rd_ready = 1'b1;
      dram_wr_ready = 1'b1;
    end
  endtask


  // Reset the DUT and return TB-driven inputs to idle.
  task automatic reset_dut();
    begin
      tb_drive_after_posedge();
      tb_idle_inputs();

      rst_n = 1'b0;
      repeat (10) @(posedge clk);
      tb_drive_after_posedge();
      rst_n = 1'b1;
      repeat (4) @(posedge clk);

    end
  endtask

  // ============================================================================
  // Main Test Entry
  // ============================================================================

  // Set initial TB state.
  initial begin
    errors = 0;
    tb_idle_inputs();
  end

  // Select exactly one top-level flow by runtime case or compile define.
  initial begin
`ifdef ALL_NPU_TESTS
    npu_test_case = "";
    if (!$value$plusargs("NPU_TEST_CASE=%s", npu_test_case)) begin
      $fatal(1, "[TB][FATAL] Missing +NPU_TEST_CASE");
    end

    case (npu_test_case)
`ifndef FULL_NPU_GATE
      "fsm": run_npu_fsm_ctrl_test();
      "metadata_quant_slot": run_metadata_test();
`endif
      "metadata_generic",
      "metadata_all_ops",
      "metadata_broadcast_selector": run_metadata_test();
      default: $fatal(1, "[TB][FATAL] Unknown NPU_TEST_CASE=%s", npu_test_case);
    endcase
`else
  `ifdef NPU_FSM_CTRL_TB
        // Optional frontend/controller-only smoke; does not run metadata golden.
        run_npu_fsm_ctrl_test();
  `elsif METADATA_TB
        // Metadata correctness flow: auto-issue job plus shadow SRAM golden.
        run_metadata_test();
  `else
        // Default to the metadata runtime path.
        run_metadata_test();
  `endif
`endif
    $display("========================================");
    $display("CLOCK TIME: %0d ns", CLK_PERIOD);
    `ifdef RTL
      $display("[RTL] All test finished.");
    `endif
    `ifdef GATE
      $display("[GATE] All test finished.");
    `endif

    if (errors == 0) begin
      pass();
    end else begin
      fail();
    end
    $finish;
  end

endmodule
`default_nettype wire