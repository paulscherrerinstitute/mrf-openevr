create_clock -name txOutClk -period [get_property PERIOD [get_clocks -of_objects [get_pins -of_object [ get_cells -hier -filter {NAME=~*gt_i/gtxe2_X0Y0_i}] -filter {REF_PIN_NAME=~GTREFCLK?}]]] [get_pins -filter {REF_PIN_NAME =~*TXOUTCLK} -of_objects [get_cells -hier -filter {NAME=~*gt_i/gtxe2_X0Y0_i}]]
create_clock -name rxOutClk -period [get_property PERIOD [get_clocks -of_objects [get_pins -of_object [ get_cells -hier -filter {NAME=~*gt_i/gtxe2_X0Y0_i}] -filter {REF_PIN_NAME=~GTREFCLK?}]]] [get_pins -filter {REF_PIN_NAME =~*RXOUTCLK} -of_objects [get_cells -hier -filter {NAME=~*gt_i/gtxe2_X0Y0_i}]]
