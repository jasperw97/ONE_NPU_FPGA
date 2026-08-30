open_project npu_8x8.xpr

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 24
wait_on_run impl_1

close_project
