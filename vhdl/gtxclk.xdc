create_clock -period 7.000 -name txOutClk [get_pins -filter {REF_PIN_NAME =~*TXOUTCLK} -of_objects [get_cells -hier -filter {NAME=~*mrfevr_gtxe2_X0Y0_i}]]
create_clock -period 7.000 -name rxOutClk [get_pins -filter {REF_PIN_NAME =~*RXOUTCLK} -of_objects [get_cells -hier -filter {NAME=~*mrfevr_gtxe2_X0Y0_i}]]


