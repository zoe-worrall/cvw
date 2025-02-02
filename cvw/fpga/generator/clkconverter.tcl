
set partNumber $::env(XILINX_PART)
set boardName $::env(XILINX_BOARD)
#set partNumber xcvu9p-flga2104-2L-e
#set boardName  xilinx.com:vcu118:part0:2.4

set ipName clkconverter

create_project $ipName . -force -part $partNumber
if {$boardName!="ArtyA7"} {
    set_property board_part $boardName [current_project]
}

create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name $ipName

set_property -dict [list CONFIG.ACLK_ASYNC {1} \
			CONFIG.PROTOCOL {AXI4} \
			CONFIG.ADDR_WIDTH {32} \
			CONFIG.DATA_WIDTH {64} \
			CONFIG.ID_WIDTH {4} \
		        CONFIG.MI_CLK.FREQ_HZ {208333333} \
			CONFIG.SI_CLK.FREQ_HZ {10000000}] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
