# mrf-openevr
Open source Event Receiver implementation

## Fork Information

This fork aims at unbundling the transceiver from the rest
of the project. We also try to use a 'wizard'-generated wrapper
rather than an explicit instantiation of the MGT primitive.

Modern MGTs have so many attributes and ports that porting to
different transceivers causes a major headache. The amount of
information details available from Xilinx is inversely proportional
to the complexity of the newer devices, alas.

We try to configure MGT trying to minimize latency and increase
determinism:
  - disable RX and TX buffer
  - use phase-alignment (automatic when possible)
  - use 8B/10B encoding.
  - note that w/o the buffer comma-alignment in the PMA is not available
    and alignment in the PCS causes non-deterministic delays (different
    every time the RX resynchronizes).

    Therefore we configure the MGT with the additional comma-alignment
    inputs and then tie these to zero. The openevr uses a brute-force
    method to realign with minimal latency: it just keeps resetting the
    RX until alignment is achieved (with minimal and reproducible latency).

  - while the original openevr uses the TX buffer and some black-box
    magic to align the PMA phase we instead try to disable the buffer and
    give the wizard's standard method a shot. We still need to confirm that
    this yields acceptable results.

One more note: GTP transceivers are a bit special - they always require
a connection from *both* PLLs in the common block (QPLLs are not available).
This makes untangling the common block from the MGT more cumbersome than
for other devices.

## Prerequisites

Hardware

Avnet PicoZed 7Z030 Module P/N AES-Z7PZ-7Z030-SOM-G

Avnet PicoZed FMC Carrier Card V2 P/N AES-PZCC-FMC-V2-G

Trenz TE0715 (and custom carrier card)

Software Tools

Xilinx Vivado 2017.4 (Free WebPack version is sufficient to build to project)

Reference clock programming on FMC carrier

http://picozed.org/support/design/13076/106

Building the exmaple design

git clone https://github.com/jpietari/mrf-openevr

vivado -mode tcl

%vivado source ./openevr.tcl
