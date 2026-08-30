// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module tb_design (
  m00_axi_init_axi_txn_0,
  m00_axi_txn_done_0,
  m00_axi_error_0,
  clk_in1_0,
  reset_0,
  ext_reset_in_0
);

  (* X_INTERFACE_IGNORE = "true" *)
  input m00_axi_init_axi_txn_0;
  (* X_INTERFACE_IGNORE = "true" *)
  output m00_axi_txn_done_0;
  (* X_INTERFACE_IGNORE = "true" *)
  output m00_axi_error_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK_IN1_0 CLK" *)
  (* X_INTERFACE_MODE = "slave CLK.CLK_IN1_0" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK_IN1_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN tb_design_clk_in1_0, INSERT_VIP 0" *)
  input clk_in1_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET_0 RST" *)
  (* X_INTERFACE_MODE = "slave RST.RESET_0" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET_0, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
  input reset_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.EXT_RESET_IN_0 RST" *)
  (* X_INTERFACE_MODE = "slave RST.EXT_RESET_IN_0" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.EXT_RESET_IN_0, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
  input ext_reset_in_0;

  // stub module has no contents

endmodule
