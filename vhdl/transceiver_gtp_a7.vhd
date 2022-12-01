---------------------------------------------------------------------------
--
--  File        : transceiver_dc_k7.vhd
--
--  Title       : Event Transceiver Multi-Gigabit Transceiver for Xilinx K7
--
--  Author      : Jukka Pietarinen
--                Micro-Research Finland Oy
--                <jukka.pietarinen@mrf.fi>
--
--  		
--
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.evr_pkg.all;

entity transceiver_gt is
  generic
    (
      RX_POLARITY                  : std_logic := '0';
      TX_POLARITY                  : std_logic := '0';
      REFCLKSEL                    : std_logic := '0' -- 0 - REFCLK0, 1 - REFCLK1
      );
  port (
    sys_clk         : in std_logic;   -- system bus clock
    REFCLK0P        : in std_logic;   -- MGTREFCLK0_P
    REFCLK0N        : in std_logic;   -- MGTREFCLK0_N
    REFCLK1P        : in std_logic;   -- MGTREFCLK1_P
    REFCLK1N        : in std_logic;   -- MGTREFCLK1N

    rxusrclk        : out std_logic;
    txusrclk        : out std_logic;

    -- RX Datapath signals
    RXUSERRDY_in    : in  std_logic;
    rx_data         : out std_logic_vector(63 downto 0);      
    rx_charisk      : out std_logic_vector(1 downto 0);
    rx_disperr      : out std_logic_vector(1 downto 0);
    rx_notintable   : out std_logic_vector(1 downto 0);

    -- TX Datapath signals
    tx_data         : in  std_logic_vector(63 downto 0);
    txbufstatus     : out std_logic_vector(1 downto 0) := "00";
    tx_charisk      : in  std_logic_vector(1 downto 0);

    -- DRP
    drpclk          : out std_logic;
    drpaddr         : in  std_logic_vector(8 downto 0);
    drpdi           : in  std_logic_vector(15 downto 0);
    drpdo           : out std_logic_vector(15 downto 0);
    drpen           : in  std_logic;
    drpwe           : in  std_logic;
    drprdy          : out std_logic;
    drpbsy          : out std_logic := '0';

    useDrpDlyAdj    : out std_logic;

    CPLLRESET_in    : in  std_logic;
    CPLLLOCK_out    : out std_logic;
    GTRXRESET_in    : in  std_logic;
    GTTXRESET_in    : in  std_logic;
    RXCDRLOCK_out   : out std_logic := '0';
    RXRESETDONE_out : out std_logic := '0';
    TXUSERRDY_in    : in  std_logic;
    
    reset           : in    std_logic;

    RXN             : in    std_logic;
    RXP             : in    std_logic;

    TXN             : out   std_logic;
    TXP             : out   std_logic
    );
end transceiver_gt;

architecture structure of transceiver_gt is

  signal REFCLK_P, REFCLK_N : std_logic;

  signal txusrclk_i         : std_logic;
  signal rxusrclk_i         : std_logic;

begin

  useDrpDlyAdj          <= '0';

  rxusrclk              <= rxusrclk_i;
  txusrclk              <= txusrclk_i;
  drpclk                <= sys_clk;

  rx_data(63 downto 16) <= (others => '0');

  G_REF0 : if ( REFCLKSEL = '0' ) generate
    REFCLK_P <= REFCLK0P;
    REFCLK_N <= REFCLK0N;
  end generate G_REF0;

  G_REF1 : if ( REFCLKSEL /= '0' ) generate
    REFCLK_P <= REFCLK1P;
    REFCLK_N <= REFCLK_N;
  end generate G_REF1;

  i_gtp : entity work.gtwizard_gtp_bufbypass
  port map (
    SOFT_RESET_TX_IN                        => reset,
    SOFT_RESET_RX_IN                        => reset,
    DONT_RESET_ON_DATA_ERROR_IN             => '0',
    Q0_CLK1_GTREFCLK_PAD_N_IN               => REFCLK_N,
    Q0_CLK1_GTREFCLK_PAD_P_IN               => REFCLK_P,

    GT0_TX_FSM_RESET_DONE_OUT               => open,
    GT0_RX_FSM_RESET_DONE_OUT               => RXRESETDONE_out,
    GT0_DATA_VALID_IN                       => '1',

    GT0_TXUSRCLK_OUT                        => txusrclk_i,
    GT0_TXUSRCLK2_OUT                       => open,
    GT0_RXUSRCLK_OUT                        => rxusrclk_i,
    GT0_RXUSRCLK2_OUT                       => open,

    --_________________________________________________________________________
    --GT0  (X0Y0)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          => drpaddr,
    gt0_drpdi_in                            => drpdi,
    gt0_drpdo_out                           => drpdo,
    gt0_drpen_in                            => drpen,
    gt0_drprdy_out                          => drprdy,
    gt0_drpwe_in                            => drpwe,
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_eyescanreset_in                     => '0',
    gt0_rxuserrdy_in                        => RXUSERRDY_in,
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                => open,
    gt0_eyescantrigger_in                   => '0',
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt0_rxdata_out                          => rx_data(15 downto 0),
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt0_rxcharisk_out                       => rx_charisk,
    gt0_rxdisperr_out                       => rx_disperr,
    gt0_rxnotintable_out                    => rx_notintable,
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt0_gtprxn_in                           => RXN,
    gt0_gtprxp_in                           => RXP,
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt0_rxphmonitor_out                     => open,
    gt0_rxphslipmonitor_out                 => open,
    -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
    gt0_rxmcommaalignen_in                  => '0',
    gt0_rxpcommaalignen_in                  => '0',
    ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
    gt0_dmonitorout_out                     => open,
    -------------------- Receive Ports - RX Equailizer Ports -------------------
    gt0_rxlpmhfhold_in                      => '0',
    gt0_rxlpmlfhold_in                      => '0',
    --------------- Receive Ports - RX Fabric Output Control Ports -------------
    gt0_rxoutclkfabric_out                  => open,
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt0_gtrxreset_in                        => '0',
    gt0_rxlpmreset_in                       => '0',
    ----------------- Receive Ports - RX Polarity Control Ports ----------------
    gt0_rxpolarity_in                       => RX_POLARITY,
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt0_rxresetdone_out                     => open,
    --------------------- TX Initialization and Reset Ports --------------------
    gt0_gttxreset_in                        => '0',
    gt0_txuserrdy_in                        => TXUSERRDY_in,
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt0_txdata_in                           => tx_data(15 downto 0),
    ------------------ Transmit Ports - TX 8B/10B Encoder Ports ----------------
    gt0_txcharisk_in                        => tx_charisk,
    --------------- Transmit Ports - TX Configurable Driver Ports --------------
    gt0_gtptxn_out                          => TXN,
    gt0_gtptxp_out                          => TXP,
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt0_txoutclkfabric_out                  => open,
    gt0_txoutclkpcs_out                     => open,
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt0_txresetdone_out                     => open,
    ----------------- Transmit Ports - TX Polarity Control Ports ---------------
    gt0_txpolarity_in                       => TX_POLARITY,

    GT0_DRPADDR_COMMON_IN                   => x"00",
    GT0_DRPDI_COMMON_IN                     => x"0000",
    GT0_DRPDO_COMMON_OUT                    => open,
    GT0_DRPEN_COMMON_IN                     => '0',
    GT0_DRPRDY_COMMON_OUT                   => open,
    GT0_DRPWE_COMMON_IN                     => '0',
    --____________________________COMMON PORTS________________________________
    GT0_PLL0RESET_OUT                       => open,
    GT0_PLL0OUTCLK_OUT                      => open,
    GT0_PLL0OUTREFCLK_OUT                   => open,
    GT0_PLL0LOCK_OUT                        => CPLLLOCK_out,
    GT0_PLL0REFCLKLOST_OUT                  => open,
    GT0_PLL1OUTCLK_OUT                      => open,
    GT0_PLL1OUTREFCLK_OUT                   => open,

    sysclk_in                               => sys_clk
  );

end architecture structure;
