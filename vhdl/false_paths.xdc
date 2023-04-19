# false paths for the many clock synchronizers.
# Some false paths also have been added to parallel data registers
# which are involved in CDC (sync signal passes through a synchronizer
# and source data is supposed to be held stable)
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly/sync_beacon_0_reg[[]3[]]}] -filter REF_PIN_NAME==D]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly/sync_beacon_1_reg[[]3[]]}] -filter REF_PIN_NAME==D]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*p_evr_dc_sync_[^./]*[.]sync_[^/]*_reg[[]1[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream/.*beacon_cnt_reg[[]3[]]} -filter ASYNC_REG] -filter REF_PIN_NAME==D]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*\<evr_cdcsync_[a-zA-Z0-9_]*_reg[[]0[]]} -filter ASYNC_REG] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream.*sr_delay_trig_reg[[]2[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_dc_id_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_control[.]dcm_updt_sr_reg[[]0[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_dc_update_reg[[]0[]]}] -filter REF_PIN_NAME==D]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_id_update_reg[[]0[]]}] -filter REF_PIN_NAME==D]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_init_reg[[]0[]]}] -filter REF_PIN_NAME==D]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/[^/]*sync_link_ok_reg[[]1[]]}] -filter REF_PIN_NAME==D]

# parallel CDC of dcm_step_phase_reg/dcm_phase_reg
set obj  [get_nets -hier -regex {.*int_dly_adj/dcm_phase_add.*}]

set sysclk [get_clocks -of_objects [get_pins -of_objects [get_cell -hier int_dly_adj] -filter {NAME=~*/clk}]]
set psclk [get_clocks -of_objects [get_pins -of_objects [get_cell -hier int_dly_adj] -filter {NAME=~*/psclk}]]

set_max_delay -datapath_only -from $sysclk -through $obj -to $psclk [get_property PERIOD $psclk]

set obj   [get_nets -hier -regex {.*/int_dly_adj/delay_comp_value_k.*}]
set_max_delay -datapath_only -from [get_clocks -of_objects [all_fanin -startpoints_only -flat $obj]] -through $obj -to $sysclk [get_property PERIOD $sysclk]
set obj   [get_nets -hier -regex {.*/int_dly_adj/int_delay_value_k.*}]
set_max_delay -datapath_only -from [get_clocks -of_objects [all_fanin -startpoints_only -flat $obj]] -through $obj -to $sysclk [get_property PERIOD $sysclk]

# According to some forum talk this can be set as a false path because
# the FIFO internals handle it correctly
set_false_path -through [get_pins -hier -regex {.*/i_upstream/i_dc_fifo/RST}]
