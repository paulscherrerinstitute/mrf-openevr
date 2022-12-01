# mrf-openevr
Open source Event Receiver implementation

Prerequisites

Hardware

Avnet PicoZed 7Z030 Module P/N AES-Z7PZ-7Z030-SOM-G

Avnet PicoZed FMC Carrier Card V2 P/N AES-PZCC-FMC-V2-G

Software Tools

Xilinx Vivado 2017.4 (Free WebPack version is sufficient to build to project)

Reference clock programming on FMC carrier

http://picozed.org/support/design/13076/106

Building the exmaple design

git clone https://github.com/jpietari/mrf-openevr

vivado -mode tcl

%vivado source ./openevr.tcl

For Artix-A7 fabrics with GTP transceivers:
  - remove 'transceiver_gtx_k7.vhd' and 'gtxclk.xdc' from the project
  - add 'transceiver_gtp_a7.vhd' instead
  - use the 'gen_gtp_bufbypass.tcl' script to generate the GTP IP
    (source the script from the vivado TCL console)
