# Vivado behavorial synthesis
# Modify the top for either behavorial rtl or axi simulation
vivado_rtl:

	xvlog -sv -i ../01_RTL/src -f ../00_TESTBED/filelist_rtl.f

	xelab -top tb_npu_axi_each -snapshot npu_behavioral_sim

	xsim npu_behavioral_sim -R



