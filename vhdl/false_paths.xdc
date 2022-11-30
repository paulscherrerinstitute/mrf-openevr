# false paths for the many clock synchronizers.
# Some false paths also have been added to parallel data registers
# which are involved in CDC (sync signal passes through a synchronizer
# and source data is supposed to be held stable)
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly/sync_beacon_0_reg[[]3[]]}] -filter {REF_PIN_NAME==D}]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly/sync_beacon_1_reg[[]3[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*p_evr_dc_sync_[^./]*[.]sync_[^/]*_reg[[]1[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream/.*beacon_cnt_reg[[]3[]]} -filter ASYNC_REG] -filter {REF_PIN_NAME==D}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream/[^/]*sync_.*_reg[[]1[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream.*sr_delay_trig_reg[[]2[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream/violation_detect[.]clrvio_reg[[]1[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*i_upstream/violation_flag[.]vio_reg[[]1[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_dc_id_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_control[.]dcm_updt_sr_reg[[]0[]]}] -filter {REF_PIN_NAME==D || REF_PIN_NAME==S || REF_PIN_NAME==R}]

set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_dc_update_reg[[]0[]]}] -filter {REF_PIN_NAME==D}]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_id_update_reg[[]0[]]}] -filter {REF_PIN_NAME==D}]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_init_reg[[]0[]]}] -filter {REF_PIN_NAME==D}]
set_false_path -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/[^/]*sync_link_ok_reg[[]1[]]}] -filter {REF_PIN_NAME==D}]

# parallel CDC where dcm_step_phase_reg/dcm_phase_reg are held stable
set_false_path  -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_dc_value_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path  -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/sync_id_value_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path  -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/cycle_adjust[.]sync_link_ok_reg[[]1[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -through [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_step_change_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==Q}] -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_control[.]dcm_step_phase_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -through [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_phase_change_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==Q}] -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_control[.]dcm_phase_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -through [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_step_change_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==Q}] -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_control[.]dcm_phase_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

set_false_path -through [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_phase_change_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==Q}] -to [get_pins -of_objects [get_cells -hier -regex {.*int_dly_adj/dcm_control[.]dcm_step_phase_reg[[][0-9]+[]]}] -filter {REF_PIN_NAME==D}]

