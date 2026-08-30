# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "LANES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_K" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_M" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_N" -parent ${Page_0}


}

proc update_PARAM_VALUE.LANES { PARAM_VALUE.LANES } {
	# Procedure called to update LANES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LANES { PARAM_VALUE.LANES } {
	# Procedure called to validate LANES
	return true
}

proc update_PARAM_VALUE.MAX_K { PARAM_VALUE.MAX_K } {
	# Procedure called to update MAX_K when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_K { PARAM_VALUE.MAX_K } {
	# Procedure called to validate MAX_K
	return true
}

proc update_PARAM_VALUE.MAX_M { PARAM_VALUE.MAX_M } {
	# Procedure called to update MAX_M when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_M { PARAM_VALUE.MAX_M } {
	# Procedure called to validate MAX_M
	return true
}

proc update_PARAM_VALUE.MAX_N { PARAM_VALUE.MAX_N } {
	# Procedure called to update MAX_N when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_N { PARAM_VALUE.MAX_N } {
	# Procedure called to validate MAX_N
	return true
}


proc update_MODELPARAM_VALUE.LANES { MODELPARAM_VALUE.LANES PARAM_VALUE.LANES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LANES}] ${MODELPARAM_VALUE.LANES}
}

proc update_MODELPARAM_VALUE.MAX_M { MODELPARAM_VALUE.MAX_M PARAM_VALUE.MAX_M } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_M}] ${MODELPARAM_VALUE.MAX_M}
}

proc update_MODELPARAM_VALUE.MAX_K { MODELPARAM_VALUE.MAX_K PARAM_VALUE.MAX_K } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_K}] ${MODELPARAM_VALUE.MAX_K}
}

proc update_MODELPARAM_VALUE.MAX_N { MODELPARAM_VALUE.MAX_N PARAM_VALUE.MAX_N } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_N}] ${MODELPARAM_VALUE.MAX_N}
}

