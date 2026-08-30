//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (lin64) Build 6299465 Fri Nov 14 12:34:56 MST 2025
//Date        : Tue Jul 14 14:53:26 2026
//Host        : pc04 running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target design_1.bd
//Design      : design_1
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "design_1,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=design_1,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=7,numReposBlks=7,numNonXlnxBlks=1,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,da_axi4_cnt=3,da_board_cnt=3,da_clkrst_cnt=2,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "design_1.hwdef" *) 
module design_1
   (c0_ddr4_32G_act_n,
    c0_ddr4_32G_adr,
    c0_ddr4_32G_ba,
    c0_ddr4_32G_bg,
    c0_ddr4_32G_ck_c,
    c0_ddr4_32G_ck_t,
    c0_ddr4_32G_cke,
    c0_ddr4_32G_cs_n,
    c0_ddr4_32G_dm_n,
    c0_ddr4_32G_dq,
    c0_ddr4_32G_dqs_c,
    c0_ddr4_32G_dqs_t,
    c0_ddr4_32G_odt,
    c0_ddr4_32G_reset_n,
    diff_clock_rtl_0_clk_n,
    diff_clock_rtl_0_clk_p,
    reset_rtl_0);
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G ACT_N" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME c0_ddr4_32G, AXI_ARBITRATION_SCHEME RD_PRI_REG, BURST_LENGTH 8, CAN_DEBUG false, CAS_LATENCY 14, CAS_WRITE_LATENCY 12, CS_ENABLED true, CUSTOM_PARTS ../../../../../../../../../Bob2_32GB_DDR4.csv, DATA_MASK_ENABLED DM_NO_DBI, DATA_WIDTH 64, MEMORY_PART MTA16ATF4G64HZ-4, MEMORY_TYPE SODIMMs, MEM_ADDR_MAP ROW_COLUMN_BANK, SLOT Single, TIMEPERIOD_PS 1333" *) output c0_ddr4_32G_act_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G ADR" *) output [16:0]c0_ddr4_32G_adr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G BA" *) output [1:0]c0_ddr4_32G_ba;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G BG" *) output [1:0]c0_ddr4_32G_bg;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G CK_C" *) output [1:0]c0_ddr4_32G_ck_c;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G CK_T" *) output [1:0]c0_ddr4_32G_ck_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G CKE" *) output [1:0]c0_ddr4_32G_cke;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G CS_N" *) output [1:0]c0_ddr4_32G_cs_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G DM_N" *) inout [7:0]c0_ddr4_32G_dm_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G DQ" *) inout [63:0]c0_ddr4_32G_dq;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G DQS_C" *) inout [7:0]c0_ddr4_32G_dqs_c;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G DQS_T" *) inout [7:0]c0_ddr4_32G_dqs_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G ODT" *) output [1:0]c0_ddr4_32G_odt;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddr4:1.0 c0_ddr4_32G RESET_N" *) output c0_ddr4_32G_reset_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 diff_clock_rtl_0 CLK_N" *) (* X_INTERFACE_MODE = "Slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME diff_clock_rtl_0, CAN_DEBUG false, FREQ_HZ 300000000" *) input diff_clock_rtl_0_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 diff_clock_rtl_0 CLK_P" *) input diff_clock_rtl_0_clk_p;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET_RTL_0 RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET_RTL_0, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input reset_rtl_0;

  wire c0_ddr4_32G_act_n;
  wire [16:0]c0_ddr4_32G_adr;
  wire [1:0]c0_ddr4_32G_ba;
  wire [1:0]c0_ddr4_32G_bg;
  wire [1:0]c0_ddr4_32G_ck_c;
  wire [1:0]c0_ddr4_32G_ck_t;
  wire [1:0]c0_ddr4_32G_cke;
  wire [1:0]c0_ddr4_32G_cs_n;
  wire [7:0]c0_ddr4_32G_dm_n;
  wire [63:0]c0_ddr4_32G_dq;
  wire [7:0]c0_ddr4_32G_dqs_c;
  wire [7:0]c0_ddr4_32G_dqs_t;
  wire [1:0]c0_ddr4_32G_odt;
  wire c0_ddr4_32G_reset_n;
  wire ddr4_0_c0_ddr4_ui_clk;
  wire ddr4_0_c0_ddr4_ui_clk_sync_rst;
  wire diff_clock_rtl_0_clk_n;
  wire diff_clock_rtl_0_clk_p;
  wire [31:0]jtag_axi_0_M_AXI_ARADDR;
  wire [1:0]jtag_axi_0_M_AXI_ARBURST;
  wire [3:0]jtag_axi_0_M_AXI_ARCACHE;
  wire [0:0]jtag_axi_0_M_AXI_ARID;
  wire [7:0]jtag_axi_0_M_AXI_ARLEN;
  wire jtag_axi_0_M_AXI_ARLOCK;
  wire [2:0]jtag_axi_0_M_AXI_ARPROT;
  wire [3:0]jtag_axi_0_M_AXI_ARQOS;
  wire jtag_axi_0_M_AXI_ARREADY;
  wire [2:0]jtag_axi_0_M_AXI_ARSIZE;
  wire jtag_axi_0_M_AXI_ARVALID;
  wire [31:0]jtag_axi_0_M_AXI_AWADDR;
  wire [1:0]jtag_axi_0_M_AXI_AWBURST;
  wire [3:0]jtag_axi_0_M_AXI_AWCACHE;
  wire [0:0]jtag_axi_0_M_AXI_AWID;
  wire [7:0]jtag_axi_0_M_AXI_AWLEN;
  wire jtag_axi_0_M_AXI_AWLOCK;
  wire [2:0]jtag_axi_0_M_AXI_AWPROT;
  wire [3:0]jtag_axi_0_M_AXI_AWQOS;
  wire jtag_axi_0_M_AXI_AWREADY;
  wire [2:0]jtag_axi_0_M_AXI_AWSIZE;
  wire jtag_axi_0_M_AXI_AWVALID;
  wire [0:0]jtag_axi_0_M_AXI_BID;
  wire jtag_axi_0_M_AXI_BREADY;
  wire [1:0]jtag_axi_0_M_AXI_BRESP;
  wire jtag_axi_0_M_AXI_BVALID;
  wire [31:0]jtag_axi_0_M_AXI_RDATA;
  wire [0:0]jtag_axi_0_M_AXI_RID;
  wire jtag_axi_0_M_AXI_RLAST;
  wire jtag_axi_0_M_AXI_RREADY;
  wire [1:0]jtag_axi_0_M_AXI_RRESP;
  wire jtag_axi_0_M_AXI_RVALID;
  wire [31:0]jtag_axi_0_M_AXI_WDATA;
  wire jtag_axi_0_M_AXI_WLAST;
  wire jtag_axi_0_M_AXI_WREADY;
  wire [3:0]jtag_axi_0_M_AXI_WSTRB;
  wire jtag_axi_0_M_AXI_WVALID;
  wire npu_axi_full_0_busy_o;
  wire npu_axi_full_0_done_o;
  wire [31:0]npu_axi_full_0_m_axi_ARADDR;
  wire [1:0]npu_axi_full_0_m_axi_ARBURST;
  wire [7:0]npu_axi_full_0_m_axi_ARLEN;
  wire npu_axi_full_0_m_axi_ARREADY;
  wire [2:0]npu_axi_full_0_m_axi_ARSIZE;
  wire npu_axi_full_0_m_axi_ARVALID;
  wire [31:0]npu_axi_full_0_m_axi_AWADDR;
  wire [1:0]npu_axi_full_0_m_axi_AWBURST;
  wire [7:0]npu_axi_full_0_m_axi_AWLEN;
  wire npu_axi_full_0_m_axi_AWREADY;
  wire [2:0]npu_axi_full_0_m_axi_AWSIZE;
  wire npu_axi_full_0_m_axi_AWVALID;
  wire npu_axi_full_0_m_axi_BREADY;
  wire [1:0]npu_axi_full_0_m_axi_BRESP;
  wire npu_axi_full_0_m_axi_BVALID;
  wire [1023:0]npu_axi_full_0_m_axi_RDATA;
  wire npu_axi_full_0_m_axi_RLAST;
  wire npu_axi_full_0_m_axi_RREADY;
  wire [1:0]npu_axi_full_0_m_axi_RRESP;
  wire npu_axi_full_0_m_axi_RVALID;
  wire [1023:0]npu_axi_full_0_m_axi_WDATA;
  wire npu_axi_full_0_m_axi_WLAST;
  wire npu_axi_full_0_m_axi_WREADY;
  wire [127:0]npu_axi_full_0_m_axi_WSTRB;
  wire npu_axi_full_0_m_axi_WVALID;
  wire reset_rtl_0;
  wire [0:0]rst_ddr4_0_187M_peripheral_aresetn;
  wire [34:0]smartconnect_0_M00_AXI_ARADDR;
  wire [1:0]smartconnect_0_M00_AXI_ARBURST;
  wire [3:0]smartconnect_0_M00_AXI_ARCACHE;
  wire [7:0]smartconnect_0_M00_AXI_ARLEN;
  wire [0:0]smartconnect_0_M00_AXI_ARLOCK;
  wire [2:0]smartconnect_0_M00_AXI_ARPROT;
  wire [3:0]smartconnect_0_M00_AXI_ARQOS;
  wire smartconnect_0_M00_AXI_ARREADY;
  wire [2:0]smartconnect_0_M00_AXI_ARSIZE;
  wire smartconnect_0_M00_AXI_ARVALID;
  wire [34:0]smartconnect_0_M00_AXI_AWADDR;
  wire [1:0]smartconnect_0_M00_AXI_AWBURST;
  wire [3:0]smartconnect_0_M00_AXI_AWCACHE;
  wire [7:0]smartconnect_0_M00_AXI_AWLEN;
  wire [0:0]smartconnect_0_M00_AXI_AWLOCK;
  wire [2:0]smartconnect_0_M00_AXI_AWPROT;
  wire [3:0]smartconnect_0_M00_AXI_AWQOS;
  wire smartconnect_0_M00_AXI_AWREADY;
  wire [2:0]smartconnect_0_M00_AXI_AWSIZE;
  wire smartconnect_0_M00_AXI_AWVALID;
  wire smartconnect_0_M00_AXI_BREADY;
  wire [1:0]smartconnect_0_M00_AXI_BRESP;
  wire smartconnect_0_M00_AXI_BVALID;
  wire [511:0]smartconnect_0_M00_AXI_RDATA;
  wire smartconnect_0_M00_AXI_RLAST;
  wire smartconnect_0_M00_AXI_RREADY;
  wire [1:0]smartconnect_0_M00_AXI_RRESP;
  wire smartconnect_0_M00_AXI_RVALID;
  wire [511:0]smartconnect_0_M00_AXI_WDATA;
  wire smartconnect_0_M00_AXI_WLAST;
  wire smartconnect_0_M00_AXI_WREADY;
  wire [63:0]smartconnect_0_M00_AXI_WSTRB;
  wire smartconnect_0_M00_AXI_WVALID;
  wire [0:0]util_vector_logic_0_Res;
  wire [0:0]vio_0_probe_out0;

  design_1_ddr4_0_2 ddr4_0
       (.c0_ddr4_act_n(c0_ddr4_32G_act_n),
        .c0_ddr4_adr(c0_ddr4_32G_adr),
        .c0_ddr4_aresetn(rst_ddr4_0_187M_peripheral_aresetn),
        .c0_ddr4_ba(c0_ddr4_32G_ba),
        .c0_ddr4_bg(c0_ddr4_32G_bg),
        .c0_ddr4_ck_c(c0_ddr4_32G_ck_c),
        .c0_ddr4_ck_t(c0_ddr4_32G_ck_t),
        .c0_ddr4_cke(c0_ddr4_32G_cke),
        .c0_ddr4_cs_n(c0_ddr4_32G_cs_n),
        .c0_ddr4_dm_dbi_n(c0_ddr4_32G_dm_n),
        .c0_ddr4_dq(c0_ddr4_32G_dq),
        .c0_ddr4_dqs_c(c0_ddr4_32G_dqs_c),
        .c0_ddr4_dqs_t(c0_ddr4_32G_dqs_t),
        .c0_ddr4_odt(c0_ddr4_32G_odt),
        .c0_ddr4_reset_n(c0_ddr4_32G_reset_n),
        .c0_ddr4_s_axi_araddr(smartconnect_0_M00_AXI_ARADDR),
        .c0_ddr4_s_axi_arburst(smartconnect_0_M00_AXI_ARBURST),
        .c0_ddr4_s_axi_arcache(smartconnect_0_M00_AXI_ARCACHE),
        .c0_ddr4_s_axi_arid(1'b0),
        .c0_ddr4_s_axi_arlen(smartconnect_0_M00_AXI_ARLEN),
        .c0_ddr4_s_axi_arlock(smartconnect_0_M00_AXI_ARLOCK),
        .c0_ddr4_s_axi_arprot(smartconnect_0_M00_AXI_ARPROT),
        .c0_ddr4_s_axi_arqos(smartconnect_0_M00_AXI_ARQOS),
        .c0_ddr4_s_axi_arready(smartconnect_0_M00_AXI_ARREADY),
        .c0_ddr4_s_axi_arsize(smartconnect_0_M00_AXI_ARSIZE),
        .c0_ddr4_s_axi_arvalid(smartconnect_0_M00_AXI_ARVALID),
        .c0_ddr4_s_axi_awaddr(smartconnect_0_M00_AXI_AWADDR),
        .c0_ddr4_s_axi_awburst(smartconnect_0_M00_AXI_AWBURST),
        .c0_ddr4_s_axi_awcache(smartconnect_0_M00_AXI_AWCACHE),
        .c0_ddr4_s_axi_awid(1'b0),
        .c0_ddr4_s_axi_awlen(smartconnect_0_M00_AXI_AWLEN),
        .c0_ddr4_s_axi_awlock(smartconnect_0_M00_AXI_AWLOCK),
        .c0_ddr4_s_axi_awprot(smartconnect_0_M00_AXI_AWPROT),
        .c0_ddr4_s_axi_awqos(smartconnect_0_M00_AXI_AWQOS),
        .c0_ddr4_s_axi_awready(smartconnect_0_M00_AXI_AWREADY),
        .c0_ddr4_s_axi_awsize(smartconnect_0_M00_AXI_AWSIZE),
        .c0_ddr4_s_axi_awvalid(smartconnect_0_M00_AXI_AWVALID),
        .c0_ddr4_s_axi_bready(smartconnect_0_M00_AXI_BREADY),
        .c0_ddr4_s_axi_bresp(smartconnect_0_M00_AXI_BRESP),
        .c0_ddr4_s_axi_bvalid(smartconnect_0_M00_AXI_BVALID),
        .c0_ddr4_s_axi_rdata(smartconnect_0_M00_AXI_RDATA),
        .c0_ddr4_s_axi_rlast(smartconnect_0_M00_AXI_RLAST),
        .c0_ddr4_s_axi_rready(smartconnect_0_M00_AXI_RREADY),
        .c0_ddr4_s_axi_rresp(smartconnect_0_M00_AXI_RRESP),
        .c0_ddr4_s_axi_rvalid(smartconnect_0_M00_AXI_RVALID),
        .c0_ddr4_s_axi_wdata(smartconnect_0_M00_AXI_WDATA),
        .c0_ddr4_s_axi_wlast(smartconnect_0_M00_AXI_WLAST),
        .c0_ddr4_s_axi_wready(smartconnect_0_M00_AXI_WREADY),
        .c0_ddr4_s_axi_wstrb(smartconnect_0_M00_AXI_WSTRB),
        .c0_ddr4_s_axi_wvalid(smartconnect_0_M00_AXI_WVALID),
        .c0_ddr4_ui_clk(ddr4_0_c0_ddr4_ui_clk),
        .c0_ddr4_ui_clk_sync_rst(ddr4_0_c0_ddr4_ui_clk_sync_rst),
        .c0_sys_clk_n(diff_clock_rtl_0_clk_n),
        .c0_sys_clk_p(diff_clock_rtl_0_clk_p),
        .sys_rst(util_vector_logic_0_Res));
  design_1_jtag_axi_0_0 jtag_axi_0
       (.aclk(ddr4_0_c0_ddr4_ui_clk),
        .aresetn(rst_ddr4_0_187M_peripheral_aresetn),
        .m_axi_araddr(jtag_axi_0_M_AXI_ARADDR),
        .m_axi_arburst(jtag_axi_0_M_AXI_ARBURST),
        .m_axi_arcache(jtag_axi_0_M_AXI_ARCACHE),
        .m_axi_arid(jtag_axi_0_M_AXI_ARID),
        .m_axi_arlen(jtag_axi_0_M_AXI_ARLEN),
        .m_axi_arlock(jtag_axi_0_M_AXI_ARLOCK),
        .m_axi_arprot(jtag_axi_0_M_AXI_ARPROT),
        .m_axi_arqos(jtag_axi_0_M_AXI_ARQOS),
        .m_axi_arready(jtag_axi_0_M_AXI_ARREADY),
        .m_axi_arsize(jtag_axi_0_M_AXI_ARSIZE),
        .m_axi_arvalid(jtag_axi_0_M_AXI_ARVALID),
        .m_axi_awaddr(jtag_axi_0_M_AXI_AWADDR),
        .m_axi_awburst(jtag_axi_0_M_AXI_AWBURST),
        .m_axi_awcache(jtag_axi_0_M_AXI_AWCACHE),
        .m_axi_awid(jtag_axi_0_M_AXI_AWID),
        .m_axi_awlen(jtag_axi_0_M_AXI_AWLEN),
        .m_axi_awlock(jtag_axi_0_M_AXI_AWLOCK),
        .m_axi_awprot(jtag_axi_0_M_AXI_AWPROT),
        .m_axi_awqos(jtag_axi_0_M_AXI_AWQOS),
        .m_axi_awready(jtag_axi_0_M_AXI_AWREADY),
        .m_axi_awsize(jtag_axi_0_M_AXI_AWSIZE),
        .m_axi_awvalid(jtag_axi_0_M_AXI_AWVALID),
        .m_axi_bid(jtag_axi_0_M_AXI_BID),
        .m_axi_bready(jtag_axi_0_M_AXI_BREADY),
        .m_axi_bresp(jtag_axi_0_M_AXI_BRESP),
        .m_axi_bvalid(jtag_axi_0_M_AXI_BVALID),
        .m_axi_rdata(jtag_axi_0_M_AXI_RDATA),
        .m_axi_rid(jtag_axi_0_M_AXI_RID),
        .m_axi_rlast(jtag_axi_0_M_AXI_RLAST),
        .m_axi_rready(jtag_axi_0_M_AXI_RREADY),
        .m_axi_rresp(jtag_axi_0_M_AXI_RRESP),
        .m_axi_rvalid(jtag_axi_0_M_AXI_RVALID),
        .m_axi_wdata(jtag_axi_0_M_AXI_WDATA),
        .m_axi_wlast(jtag_axi_0_M_AXI_WLAST),
        .m_axi_wready(jtag_axi_0_M_AXI_WREADY),
        .m_axi_wstrb(jtag_axi_0_M_AXI_WSTRB),
        .m_axi_wvalid(jtag_axi_0_M_AXI_WVALID));
  design_1_npu_axi_full_0_0 npu_axi_full_0
       (.busy_o(npu_axi_full_0_busy_o),
        .clk(ddr4_0_c0_ddr4_ui_clk),
        .done_o(npu_axi_full_0_done_o),
        .m_axi_araddr(npu_axi_full_0_m_axi_ARADDR),
        .m_axi_arburst(npu_axi_full_0_m_axi_ARBURST),
        .m_axi_arlen(npu_axi_full_0_m_axi_ARLEN),
        .m_axi_arready(npu_axi_full_0_m_axi_ARREADY),
        .m_axi_arsize(npu_axi_full_0_m_axi_ARSIZE),
        .m_axi_arvalid(npu_axi_full_0_m_axi_ARVALID),
        .m_axi_awaddr(npu_axi_full_0_m_axi_AWADDR),
        .m_axi_awburst(npu_axi_full_0_m_axi_AWBURST),
        .m_axi_awlen(npu_axi_full_0_m_axi_AWLEN),
        .m_axi_awready(npu_axi_full_0_m_axi_AWREADY),
        .m_axi_awsize(npu_axi_full_0_m_axi_AWSIZE),
        .m_axi_awvalid(npu_axi_full_0_m_axi_AWVALID),
        .m_axi_bready(npu_axi_full_0_m_axi_BREADY),
        .m_axi_bresp(npu_axi_full_0_m_axi_BRESP),
        .m_axi_bvalid(npu_axi_full_0_m_axi_BVALID),
        .m_axi_rdata(npu_axi_full_0_m_axi_RDATA),
        .m_axi_rlast(npu_axi_full_0_m_axi_RLAST),
        .m_axi_rready(npu_axi_full_0_m_axi_RREADY),
        .m_axi_rresp(npu_axi_full_0_m_axi_RRESP),
        .m_axi_rvalid(npu_axi_full_0_m_axi_RVALID),
        .m_axi_wdata(npu_axi_full_0_m_axi_WDATA),
        .m_axi_wlast(npu_axi_full_0_m_axi_WLAST),
        .m_axi_wready(npu_axi_full_0_m_axi_WREADY),
        .m_axi_wstrb(npu_axi_full_0_m_axi_WSTRB),
        .m_axi_wvalid(npu_axi_full_0_m_axi_WVALID),
        .rst_n(rst_ddr4_0_187M_peripheral_aresetn),
        .start_i(vio_0_probe_out0));
  design_1_rst_ddr4_0_187M_0 rst_ddr4_0_187M
       (.aux_reset_in(1'b1),
        .dcm_locked(1'b1),
        .ext_reset_in(ddr4_0_c0_ddr4_ui_clk_sync_rst),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_ddr4_0_187M_peripheral_aresetn),
        .slowest_sync_clk(ddr4_0_c0_ddr4_ui_clk));
  design_1_smartconnect_0_0 smartconnect_0
       (.M00_AXI_araddr(smartconnect_0_M00_AXI_ARADDR),
        .M00_AXI_arburst(smartconnect_0_M00_AXI_ARBURST),
        .M00_AXI_arcache(smartconnect_0_M00_AXI_ARCACHE),
        .M00_AXI_arlen(smartconnect_0_M00_AXI_ARLEN),
        .M00_AXI_arlock(smartconnect_0_M00_AXI_ARLOCK),
        .M00_AXI_arprot(smartconnect_0_M00_AXI_ARPROT),
        .M00_AXI_arqos(smartconnect_0_M00_AXI_ARQOS),
        .M00_AXI_arready(smartconnect_0_M00_AXI_ARREADY),
        .M00_AXI_arsize(smartconnect_0_M00_AXI_ARSIZE),
        .M00_AXI_arvalid(smartconnect_0_M00_AXI_ARVALID),
        .M00_AXI_awaddr(smartconnect_0_M00_AXI_AWADDR),
        .M00_AXI_awburst(smartconnect_0_M00_AXI_AWBURST),
        .M00_AXI_awcache(smartconnect_0_M00_AXI_AWCACHE),
        .M00_AXI_awlen(smartconnect_0_M00_AXI_AWLEN),
        .M00_AXI_awlock(smartconnect_0_M00_AXI_AWLOCK),
        .M00_AXI_awprot(smartconnect_0_M00_AXI_AWPROT),
        .M00_AXI_awqos(smartconnect_0_M00_AXI_AWQOS),
        .M00_AXI_awready(smartconnect_0_M00_AXI_AWREADY),
        .M00_AXI_awsize(smartconnect_0_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(smartconnect_0_M00_AXI_AWVALID),
        .M00_AXI_bready(smartconnect_0_M00_AXI_BREADY),
        .M00_AXI_bresp(smartconnect_0_M00_AXI_BRESP),
        .M00_AXI_bvalid(smartconnect_0_M00_AXI_BVALID),
        .M00_AXI_rdata(smartconnect_0_M00_AXI_RDATA),
        .M00_AXI_rlast(smartconnect_0_M00_AXI_RLAST),
        .M00_AXI_rready(smartconnect_0_M00_AXI_RREADY),
        .M00_AXI_rresp(smartconnect_0_M00_AXI_RRESP),
        .M00_AXI_rvalid(smartconnect_0_M00_AXI_RVALID),
        .M00_AXI_wdata(smartconnect_0_M00_AXI_WDATA),
        .M00_AXI_wlast(smartconnect_0_M00_AXI_WLAST),
        .M00_AXI_wready(smartconnect_0_M00_AXI_WREADY),
        .M00_AXI_wstrb(smartconnect_0_M00_AXI_WSTRB),
        .M00_AXI_wvalid(smartconnect_0_M00_AXI_WVALID),
        .S00_AXI_araddr(jtag_axi_0_M_AXI_ARADDR),
        .S00_AXI_arburst(jtag_axi_0_M_AXI_ARBURST),
        .S00_AXI_arcache(jtag_axi_0_M_AXI_ARCACHE),
        .S00_AXI_arid(jtag_axi_0_M_AXI_ARID),
        .S00_AXI_arlen(jtag_axi_0_M_AXI_ARLEN),
        .S00_AXI_arlock(jtag_axi_0_M_AXI_ARLOCK),
        .S00_AXI_arprot(jtag_axi_0_M_AXI_ARPROT),
        .S00_AXI_arqos(jtag_axi_0_M_AXI_ARQOS),
        .S00_AXI_arready(jtag_axi_0_M_AXI_ARREADY),
        .S00_AXI_arsize(jtag_axi_0_M_AXI_ARSIZE),
        .S00_AXI_arvalid(jtag_axi_0_M_AXI_ARVALID),
        .S00_AXI_awaddr(jtag_axi_0_M_AXI_AWADDR),
        .S00_AXI_awburst(jtag_axi_0_M_AXI_AWBURST),
        .S00_AXI_awcache(jtag_axi_0_M_AXI_AWCACHE),
        .S00_AXI_awid(jtag_axi_0_M_AXI_AWID),
        .S00_AXI_awlen(jtag_axi_0_M_AXI_AWLEN),
        .S00_AXI_awlock(jtag_axi_0_M_AXI_AWLOCK),
        .S00_AXI_awprot(jtag_axi_0_M_AXI_AWPROT),
        .S00_AXI_awqos(jtag_axi_0_M_AXI_AWQOS),
        .S00_AXI_awready(jtag_axi_0_M_AXI_AWREADY),
        .S00_AXI_awsize(jtag_axi_0_M_AXI_AWSIZE),
        .S00_AXI_awvalid(jtag_axi_0_M_AXI_AWVALID),
        .S00_AXI_bid(jtag_axi_0_M_AXI_BID),
        .S00_AXI_bready(jtag_axi_0_M_AXI_BREADY),
        .S00_AXI_bresp(jtag_axi_0_M_AXI_BRESP),
        .S00_AXI_bvalid(jtag_axi_0_M_AXI_BVALID),
        .S00_AXI_rdata(jtag_axi_0_M_AXI_RDATA),
        .S00_AXI_rid(jtag_axi_0_M_AXI_RID),
        .S00_AXI_rlast(jtag_axi_0_M_AXI_RLAST),
        .S00_AXI_rready(jtag_axi_0_M_AXI_RREADY),
        .S00_AXI_rresp(jtag_axi_0_M_AXI_RRESP),
        .S00_AXI_rvalid(jtag_axi_0_M_AXI_RVALID),
        .S00_AXI_wdata(jtag_axi_0_M_AXI_WDATA),
        .S00_AXI_wlast(jtag_axi_0_M_AXI_WLAST),
        .S00_AXI_wready(jtag_axi_0_M_AXI_WREADY),
        .S00_AXI_wstrb(jtag_axi_0_M_AXI_WSTRB),
        .S00_AXI_wvalid(jtag_axi_0_M_AXI_WVALID),
        .S01_AXI_araddr(npu_axi_full_0_m_axi_ARADDR),
        .S01_AXI_arburst(npu_axi_full_0_m_axi_ARBURST),
        .S01_AXI_arcache({1'b0,1'b0,1'b1,1'b1}),
        .S01_AXI_arlen(npu_axi_full_0_m_axi_ARLEN),
        .S01_AXI_arlock(1'b0),
        .S01_AXI_arprot({1'b0,1'b0,1'b0}),
        .S01_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_arready(npu_axi_full_0_m_axi_ARREADY),
        .S01_AXI_arsize(npu_axi_full_0_m_axi_ARSIZE),
        .S01_AXI_arvalid(npu_axi_full_0_m_axi_ARVALID),
        .S01_AXI_awaddr(npu_axi_full_0_m_axi_AWADDR),
        .S01_AXI_awburst(npu_axi_full_0_m_axi_AWBURST),
        .S01_AXI_awcache({1'b0,1'b0,1'b1,1'b1}),
        .S01_AXI_awlen(npu_axi_full_0_m_axi_AWLEN),
        .S01_AXI_awlock(1'b0),
        .S01_AXI_awprot({1'b0,1'b0,1'b0}),
        .S01_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_awready(npu_axi_full_0_m_axi_AWREADY),
        .S01_AXI_awsize(npu_axi_full_0_m_axi_AWSIZE),
        .S01_AXI_awvalid(npu_axi_full_0_m_axi_AWVALID),
        .S01_AXI_bready(npu_axi_full_0_m_axi_BREADY),
        .S01_AXI_bresp(npu_axi_full_0_m_axi_BRESP),
        .S01_AXI_bvalid(npu_axi_full_0_m_axi_BVALID),
        .S01_AXI_rdata(npu_axi_full_0_m_axi_RDATA),
        .S01_AXI_rlast(npu_axi_full_0_m_axi_RLAST),
        .S01_AXI_rready(npu_axi_full_0_m_axi_RREADY),
        .S01_AXI_rresp(npu_axi_full_0_m_axi_RRESP),
        .S01_AXI_rvalid(npu_axi_full_0_m_axi_RVALID),
        .S01_AXI_wdata(npu_axi_full_0_m_axi_WDATA),
        .S01_AXI_wlast(npu_axi_full_0_m_axi_WLAST),
        .S01_AXI_wready(npu_axi_full_0_m_axi_WREADY),
        .S01_AXI_wstrb(npu_axi_full_0_m_axi_WSTRB),
        .S01_AXI_wvalid(npu_axi_full_0_m_axi_WVALID),
        .aclk(ddr4_0_c0_ddr4_ui_clk),
        .aresetn(rst_ddr4_0_187M_peripheral_aresetn));
  design_1_util_vector_logic_0_0 util_vector_logic_0
       (.Op1(reset_rtl_0),
        .Res(util_vector_logic_0_Res));
  design_1_vio_0_0 vio_0
       (.clk(ddr4_0_c0_ddr4_ui_clk),
        .probe_in0(npu_axi_full_0_busy_o),
        .probe_in1(npu_axi_full_0_done_o),
        .probe_out0(vio_0_probe_out0));
endmodule
