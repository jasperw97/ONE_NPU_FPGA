//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Sun Jun 21 10:57:00 2026
//Host        : lx3211-B650M-AORUS-ELITE running 64-bit Ubuntu 22.04.3 LTS
//Command     : generate_target tb_design.bd
//Design      : tb_design
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "tb_design,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=tb_design,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=5,numReposBlks=5,numNonXlnxBlks=1,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,da_axi4_cnt=1,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "tb_design.hwdef" *) 
module tb_design
   (clk_in1_0,
    ext_reset_in_0,
    m00_axi_error_0,
    m00_axi_init_axi_txn_0,
    m00_axi_txn_done_0,
    reset_0);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK_IN1_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK_IN1_0, CLK_DOMAIN tb_design_clk_in1_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input clk_in1_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.EXT_RESET_IN_0 RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.EXT_RESET_IN_0, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input ext_reset_in_0;
  output m00_axi_error_0;
  input m00_axi_init_axi_txn_0;
  output m00_axi_txn_done_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET_0 RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET_0, INSERT_VIP 0, POLARITY ACTIVE_HIGH" *) input reset_0;

  wire [31:0]adder_0_M00_AXI_ARADDR;
  wire [1:0]adder_0_M00_AXI_ARBURST;
  wire [3:0]adder_0_M00_AXI_ARCACHE;
  wire [0:0]adder_0_M00_AXI_ARID;
  wire [7:0]adder_0_M00_AXI_ARLEN;
  wire adder_0_M00_AXI_ARLOCK;
  wire [2:0]adder_0_M00_AXI_ARPROT;
  wire [3:0]adder_0_M00_AXI_ARQOS;
  wire adder_0_M00_AXI_ARREADY;
  wire [2:0]adder_0_M00_AXI_ARSIZE;
  wire adder_0_M00_AXI_ARVALID;
  wire [31:0]adder_0_M00_AXI_AWADDR;
  wire [1:0]adder_0_M00_AXI_AWBURST;
  wire [3:0]adder_0_M00_AXI_AWCACHE;
  wire [0:0]adder_0_M00_AXI_AWID;
  wire [7:0]adder_0_M00_AXI_AWLEN;
  wire adder_0_M00_AXI_AWLOCK;
  wire [2:0]adder_0_M00_AXI_AWPROT;
  wire [3:0]adder_0_M00_AXI_AWQOS;
  wire adder_0_M00_AXI_AWREADY;
  wire [2:0]adder_0_M00_AXI_AWSIZE;
  wire adder_0_M00_AXI_AWVALID;
  wire [0:0]adder_0_M00_AXI_BID;
  wire adder_0_M00_AXI_BREADY;
  wire [1:0]adder_0_M00_AXI_BRESP;
  wire adder_0_M00_AXI_BVALID;
  wire [31:0]adder_0_M00_AXI_RDATA;
  wire [0:0]adder_0_M00_AXI_RID;
  wire adder_0_M00_AXI_RLAST;
  wire adder_0_M00_AXI_RREADY;
  wire [1:0]adder_0_M00_AXI_RRESP;
  wire adder_0_M00_AXI_RVALID;
  wire [31:0]adder_0_M00_AXI_WDATA;
  wire adder_0_M00_AXI_WLAST;
  wire adder_0_M00_AXI_WREADY;
  wire [3:0]adder_0_M00_AXI_WSTRB;
  wire adder_0_M00_AXI_WVALID;
  wire [31:0]axi_smc_M00_AXI_ARADDR;
  wire [1:0]axi_smc_M00_AXI_ARBURST;
  wire [3:0]axi_smc_M00_AXI_ARCACHE;
  wire [7:0]axi_smc_M00_AXI_ARLEN;
  wire [0:0]axi_smc_M00_AXI_ARLOCK;
  wire [2:0]axi_smc_M00_AXI_ARPROT;
  wire [3:0]axi_smc_M00_AXI_ARQOS;
  wire axi_smc_M00_AXI_ARREADY;
  wire axi_smc_M00_AXI_ARVALID;
  wire [31:0]axi_smc_M00_AXI_AWADDR;
  wire [1:0]axi_smc_M00_AXI_AWBURST;
  wire [3:0]axi_smc_M00_AXI_AWCACHE;
  wire [7:0]axi_smc_M00_AXI_AWLEN;
  wire [0:0]axi_smc_M00_AXI_AWLOCK;
  wire [2:0]axi_smc_M00_AXI_AWPROT;
  wire [3:0]axi_smc_M00_AXI_AWQOS;
  wire axi_smc_M00_AXI_AWREADY;
  wire axi_smc_M00_AXI_AWVALID;
  wire axi_smc_M00_AXI_BREADY;
  wire [1:0]axi_smc_M00_AXI_BRESP;
  wire axi_smc_M00_AXI_BVALID;
  wire [31:0]axi_smc_M00_AXI_RDATA;
  wire axi_smc_M00_AXI_RLAST;
  wire axi_smc_M00_AXI_RREADY;
  wire [1:0]axi_smc_M00_AXI_RRESP;
  wire axi_smc_M00_AXI_RVALID;
  wire [31:0]axi_smc_M00_AXI_WDATA;
  wire axi_smc_M00_AXI_WLAST;
  wire axi_smc_M00_AXI_WREADY;
  wire [3:0]axi_smc_M00_AXI_WSTRB;
  wire axi_smc_M00_AXI_WVALID;
  wire clk_in1_0;
  wire clk_wiz_clk_out1;
  wire clk_wiz_locked;
  wire ext_reset_in_0;
  wire m00_axi_error_0;
  wire m00_axi_init_axi_txn_0;
  wire m00_axi_txn_done_0;
  wire reset_0;
  wire [0:0]rst_clk_wiz_100M_peripheral_aresetn;

  tb_design_adder_0_3 adder_0
       (.m00_axi_aclk(clk_wiz_clk_out1),
        .m00_axi_araddr(adder_0_M00_AXI_ARADDR),
        .m00_axi_arburst(adder_0_M00_AXI_ARBURST),
        .m00_axi_arcache(adder_0_M00_AXI_ARCACHE),
        .m00_axi_aresetn(rst_clk_wiz_100M_peripheral_aresetn),
        .m00_axi_arid(adder_0_M00_AXI_ARID),
        .m00_axi_arlen(adder_0_M00_AXI_ARLEN),
        .m00_axi_arlock(adder_0_M00_AXI_ARLOCK),
        .m00_axi_arprot(adder_0_M00_AXI_ARPROT),
        .m00_axi_arqos(adder_0_M00_AXI_ARQOS),
        .m00_axi_arready(adder_0_M00_AXI_ARREADY),
        .m00_axi_arsize(adder_0_M00_AXI_ARSIZE),
        .m00_axi_arvalid(adder_0_M00_AXI_ARVALID),
        .m00_axi_awaddr(adder_0_M00_AXI_AWADDR),
        .m00_axi_awburst(adder_0_M00_AXI_AWBURST),
        .m00_axi_awcache(adder_0_M00_AXI_AWCACHE),
        .m00_axi_awid(adder_0_M00_AXI_AWID),
        .m00_axi_awlen(adder_0_M00_AXI_AWLEN),
        .m00_axi_awlock(adder_0_M00_AXI_AWLOCK),
        .m00_axi_awprot(adder_0_M00_AXI_AWPROT),
        .m00_axi_awqos(adder_0_M00_AXI_AWQOS),
        .m00_axi_awready(adder_0_M00_AXI_AWREADY),
        .m00_axi_awsize(adder_0_M00_AXI_AWSIZE),
        .m00_axi_awvalid(adder_0_M00_AXI_AWVALID),
        .m00_axi_bid(adder_0_M00_AXI_BID),
        .m00_axi_bready(adder_0_M00_AXI_BREADY),
        .m00_axi_bresp(adder_0_M00_AXI_BRESP),
        .m00_axi_bvalid(adder_0_M00_AXI_BVALID),
        .m00_axi_error(m00_axi_error_0),
        .m00_axi_init_axi_txn(m00_axi_init_axi_txn_0),
        .m00_axi_rdata(adder_0_M00_AXI_RDATA),
        .m00_axi_rid(adder_0_M00_AXI_RID),
        .m00_axi_rlast(adder_0_M00_AXI_RLAST),
        .m00_axi_rready(adder_0_M00_AXI_RREADY),
        .m00_axi_rresp(adder_0_M00_AXI_RRESP),
        .m00_axi_rvalid(adder_0_M00_AXI_RVALID),
        .m00_axi_txn_done(m00_axi_txn_done_0),
        .m00_axi_wdata(adder_0_M00_AXI_WDATA),
        .m00_axi_wlast(adder_0_M00_AXI_WLAST),
        .m00_axi_wready(adder_0_M00_AXI_WREADY),
        .m00_axi_wstrb(adder_0_M00_AXI_WSTRB),
        .m00_axi_wvalid(adder_0_M00_AXI_WVALID));
  tb_design_axi_smc_0 axi_smc
       (.M00_AXI_araddr(axi_smc_M00_AXI_ARADDR),
        .M00_AXI_arburst(axi_smc_M00_AXI_ARBURST),
        .M00_AXI_arcache(axi_smc_M00_AXI_ARCACHE),
        .M00_AXI_arlen(axi_smc_M00_AXI_ARLEN),
        .M00_AXI_arlock(axi_smc_M00_AXI_ARLOCK),
        .M00_AXI_arprot(axi_smc_M00_AXI_ARPROT),
        .M00_AXI_arqos(axi_smc_M00_AXI_ARQOS),
        .M00_AXI_arready(axi_smc_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_smc_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_smc_M00_AXI_AWADDR),
        .M00_AXI_awburst(axi_smc_M00_AXI_AWBURST),
        .M00_AXI_awcache(axi_smc_M00_AXI_AWCACHE),
        .M00_AXI_awlen(axi_smc_M00_AXI_AWLEN),
        .M00_AXI_awlock(axi_smc_M00_AXI_AWLOCK),
        .M00_AXI_awprot(axi_smc_M00_AXI_AWPROT),
        .M00_AXI_awqos(axi_smc_M00_AXI_AWQOS),
        .M00_AXI_awready(axi_smc_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_smc_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_smc_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_smc_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_smc_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_smc_M00_AXI_RDATA),
        .M00_AXI_rlast(axi_smc_M00_AXI_RLAST),
        .M00_AXI_rready(axi_smc_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_smc_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_smc_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_smc_M00_AXI_WDATA),
        .M00_AXI_wlast(axi_smc_M00_AXI_WLAST),
        .M00_AXI_wready(axi_smc_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_smc_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_smc_M00_AXI_WVALID),
        .S00_AXI_araddr(adder_0_M00_AXI_ARADDR),
        .S00_AXI_arburst(adder_0_M00_AXI_ARBURST),
        .S00_AXI_arcache(adder_0_M00_AXI_ARCACHE),
        .S00_AXI_arid(adder_0_M00_AXI_ARID),
        .S00_AXI_arlen(adder_0_M00_AXI_ARLEN),
        .S00_AXI_arlock(adder_0_M00_AXI_ARLOCK),
        .S00_AXI_arprot(adder_0_M00_AXI_ARPROT),
        .S00_AXI_arqos(adder_0_M00_AXI_ARQOS),
        .S00_AXI_arready(adder_0_M00_AXI_ARREADY),
        .S00_AXI_arsize(adder_0_M00_AXI_ARSIZE),
        .S00_AXI_arvalid(adder_0_M00_AXI_ARVALID),
        .S00_AXI_awaddr(adder_0_M00_AXI_AWADDR),
        .S00_AXI_awburst(adder_0_M00_AXI_AWBURST),
        .S00_AXI_awcache(adder_0_M00_AXI_AWCACHE),
        .S00_AXI_awid(adder_0_M00_AXI_AWID),
        .S00_AXI_awlen(adder_0_M00_AXI_AWLEN),
        .S00_AXI_awlock(adder_0_M00_AXI_AWLOCK),
        .S00_AXI_awprot(adder_0_M00_AXI_AWPROT),
        .S00_AXI_awqos(adder_0_M00_AXI_AWQOS),
        .S00_AXI_awready(adder_0_M00_AXI_AWREADY),
        .S00_AXI_awsize(adder_0_M00_AXI_AWSIZE),
        .S00_AXI_awvalid(adder_0_M00_AXI_AWVALID),
        .S00_AXI_bid(adder_0_M00_AXI_BID),
        .S00_AXI_bready(adder_0_M00_AXI_BREADY),
        .S00_AXI_bresp(adder_0_M00_AXI_BRESP),
        .S00_AXI_bvalid(adder_0_M00_AXI_BVALID),
        .S00_AXI_rdata(adder_0_M00_AXI_RDATA),
        .S00_AXI_rid(adder_0_M00_AXI_RID),
        .S00_AXI_rlast(adder_0_M00_AXI_RLAST),
        .S00_AXI_rready(adder_0_M00_AXI_RREADY),
        .S00_AXI_rresp(adder_0_M00_AXI_RRESP),
        .S00_AXI_rvalid(adder_0_M00_AXI_RVALID),
        .S00_AXI_wdata(adder_0_M00_AXI_WDATA),
        .S00_AXI_wlast(adder_0_M00_AXI_WLAST),
        .S00_AXI_wready(adder_0_M00_AXI_WREADY),
        .S00_AXI_wstrb(adder_0_M00_AXI_WSTRB),
        .S00_AXI_wvalid(adder_0_M00_AXI_WVALID),
        .aclk(clk_wiz_clk_out1),
        .aresetn(rst_clk_wiz_100M_peripheral_aresetn));
  tb_design_axi_vip_0_0 axi_vip_0
       (.aclk(clk_wiz_clk_out1),
        .aresetn(rst_clk_wiz_100M_peripheral_aresetn),
        .s_axi_araddr(axi_smc_M00_AXI_ARADDR),
        .s_axi_arburst(axi_smc_M00_AXI_ARBURST),
        .s_axi_arcache(axi_smc_M00_AXI_ARCACHE),
        .s_axi_arlen(axi_smc_M00_AXI_ARLEN),
        .s_axi_arlock(axi_smc_M00_AXI_ARLOCK),
        .s_axi_arprot(axi_smc_M00_AXI_ARPROT),
        .s_axi_arqos(axi_smc_M00_AXI_ARQOS),
        .s_axi_arready(axi_smc_M00_AXI_ARREADY),
        .s_axi_arvalid(axi_smc_M00_AXI_ARVALID),
        .s_axi_awaddr(axi_smc_M00_AXI_AWADDR),
        .s_axi_awburst(axi_smc_M00_AXI_AWBURST),
        .s_axi_awcache(axi_smc_M00_AXI_AWCACHE),
        .s_axi_awlen(axi_smc_M00_AXI_AWLEN),
        .s_axi_awlock(axi_smc_M00_AXI_AWLOCK),
        .s_axi_awprot(axi_smc_M00_AXI_AWPROT),
        .s_axi_awqos(axi_smc_M00_AXI_AWQOS),
        .s_axi_awready(axi_smc_M00_AXI_AWREADY),
        .s_axi_awvalid(axi_smc_M00_AXI_AWVALID),
        .s_axi_bready(axi_smc_M00_AXI_BREADY),
        .s_axi_bresp(axi_smc_M00_AXI_BRESP),
        .s_axi_bvalid(axi_smc_M00_AXI_BVALID),
        .s_axi_rdata(axi_smc_M00_AXI_RDATA),
        .s_axi_rlast(axi_smc_M00_AXI_RLAST),
        .s_axi_rready(axi_smc_M00_AXI_RREADY),
        .s_axi_rresp(axi_smc_M00_AXI_RRESP),
        .s_axi_rvalid(axi_smc_M00_AXI_RVALID),
        .s_axi_wdata(axi_smc_M00_AXI_WDATA),
        .s_axi_wlast(axi_smc_M00_AXI_WLAST),
        .s_axi_wready(axi_smc_M00_AXI_WREADY),
        .s_axi_wstrb(axi_smc_M00_AXI_WSTRB),
        .s_axi_wvalid(axi_smc_M00_AXI_WVALID));
  tb_design_clk_wiz_0 clk_wiz
       (.clk_in1(clk_in1_0),
        .clk_out1(clk_wiz_clk_out1),
        .locked(clk_wiz_locked),
        .reset(reset_0));
  tb_design_rst_clk_wiz_100M_0 rst_clk_wiz_100M
       (.aux_reset_in(1'b1),
        .dcm_locked(clk_wiz_locked),
        .ext_reset_in(ext_reset_in_0),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_clk_wiz_100M_peripheral_aresetn),
        .slowest_sync_clk(clk_wiz_clk_out1));
endmodule
