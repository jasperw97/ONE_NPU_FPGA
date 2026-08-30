// +incdir+../01_RTL/src
// +incdir+../00_TESTBED

// -------------------------
// testbench, choose 1
// -------------------------

//Testbench for behavorial npu
// ../00_TESTBED/tb_npu_int16.sv

../00_TESTBED/tb_npu_axi_each.sv

//Testbench for npu axi wrapped
// ../00_TESTBED/tb_npu_axi.sv

// ../00_TESTBED/tb_sa.sv
// ../00_TESTBED/tb_dw_mult_pipe.sv

// -------------------------
// RTL
// -------------------------
// top, choose 1

// top for behavorial npu
// ../01_RTL/src/npu_int16.sv

// top for npu axi wrapped
// ../01_RTL/src/npu_axi_full.v
../01_RTL/src/npu_axi_full_burst.v


// ../01_RTL/src/npu_int16.sv
../01_RTL/src/npu_int16_burst.sv
// Systolic array
../01_RTL/src/SystolicArray_OS_INT8_requant_sram.sv 
../01_RTL/src/PE_INT8_OS.sv 
../01_RTL/src/fifo.sv

// elementwise
../01_RTL/src/element_wise_LUT.sv 
../01_RTL/src/SUB.v 
../01_RTL/src/SUB_Element.v 
../01_RTL/src/ADD.v 
../01_RTL/src/ADD_Element.v 
../01_RTL/src/MUL.v 
../01_RTL/src/MUL_Element.v 
../01_RTL/src/lut_vec_tflite.sv
../01_RTL/src/lut_lane_mem.sv

// mqm
../01_RTL/src/MultiplyByQuantizedMultiplier.v 
../01_RTL/src/MultiplyByQuantizedMultiplierSmallerThanOneExp.v 
../01_RTL/src/mult_pipe.sv

// sram
../01_RTL/src/sram.sv 
../01_RTL/src/banked_mem_1r1w.sv 
../01_RTL/src/mem_bank_1r1w.sv 

// other units
../01_RTL/src/op_decoder.sv
../01_RTL/src/desc_decoder.sv
../01_RTL/src/controller.sv
// ../01_RTL/src/LSU.sv
../01_RTL/src/LSU_axi_burst.sv
../01_RTL/src/broadcast_unit.sv

