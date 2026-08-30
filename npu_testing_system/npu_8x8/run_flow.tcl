open_project npu_8x8.xpr

puts "INFO: Launching synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 24
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]

if {$synth_progress == "100%" && [string match "*Complete*" $synth_status]} {
    puts "SUCCESS: Synthesis completed! Launching implementation..."
    
    # 4. Reset and launch Implementation
    reset_run impl_1
    launch_runs impl_1 -jobs 24
    wait_on_run impl_1
} else {
    puts "ERROR: Synthesis failed with status: $synth_status. Aborting Implementation."
}
close_project
