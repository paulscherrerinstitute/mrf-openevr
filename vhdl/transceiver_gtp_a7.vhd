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
use work.transceiver_pkg.all;

entity transceiver_gt is
  generic
    (
      RX_POLARITY                  : std_logic := '0';
      TX_POLARITY                  : std_logic := '0';
      REFCLKSEL                    : std_logic := '0' -- 0 - REFCLK0, 1 - REFCLK1
      );
  port (
    -- MGT interface
    REFCLK0P        : in std_logic;   -- MGTREFCLK0_P
    REFCLK0N        : in std_logic;   -- MGTREFCLK0_N
    REFCLK1P        : in std_logic;   -- MGTREFCLK1_P
    REFCLK1N        : in std_logic;   -- MGTREFCLK1N

    RXN             : in    std_logic;
    RXP             : in    std_logic;

    TXN             : out   std_logic;
    TXP             : out   std_logic;

    -- fabric interface
    transceiverIb   : in  EvrTransceiverIbType;
    transceiverOb   : out EvrTransceiverObType
    );
end transceiver_gt;

architecture structure of transceiver_gt is
  attribute ASYNC_REG       : string;

  signal REFCLK_P, REFCLK_N : std_logic;

  signal txusrclk_i         : std_logic;
  signal rxusrclk_i         : std_logic;
  signal rx_data_i          : std_logic_vector(15 downto 0);      
  signal rx_charisk         : std_logic_vector(1 downto 0);
  signal rx_disperr         : std_logic_vector(1 downto 0);
  signal rx_notintable      : std_logic_vector(1 downto 0);
  signal tx_bufstatus       : std_logic_vector(1 downto 0) := (others => '0');

  signal drpclk             : std_logic;
  signal drpdo              : std_logic_vector(15 downto 0);
  signal drprdy             : std_logic;
  signal drpbsy             : std_logic := '0';
  signal cpll_locked        : std_logic;


  signal txRst_i            : std_logic;
  signal rxRst_i            : std_logic;

  signal sys_clk            : std_logic;
  signal reset              : std_logic;

  signal evr_cdcsync_txrst      : std_logic_vector(1 downto 0) := (others => '1');
  attribute ASYNC_REG       of evr_cdcsync_txrst : signal is "TRUE";
  signal evr_cdcsync_rxrst      : std_logic_vector(1 downto 0) := (others => '1');
  attribute ASYNC_REG       of evr_cdcsync_rxrst : signal is "TRUE";

begin
  sys_clk               <= transceiverIb.sys_clk;
  reset                 <= transceiverIb.sys_rst;

  drpclk                <= sys_clk;

  P_RST : process ( sys_clk ) is
  begin
    if ( rising_edge( sys_clk ) ) then
      evr_cdcsync_txrst <= shiftl( evr_cdcsync_txrst, transceiverIb.tx_rst );
      evr_cdcsync_rxrst <= shiftl( evr_cdcsync_rxrst, transceiverIb.rx_rst );
    end if;
  end process P_RST;

  txRst_i               <= (lbit( evr_cdcsync_txrst ) or reset);
  rxRst_i               <= (lbit( evr_cdcsync_rxrst ) or reset);

  G_REF0 : if ( REFCLKSEL = '0' ) generate
    REFCLK_P <= REFCLK0P;
    REFCLK_N <= REFCLK0N;
  end generate G_REF0;

  G_REF1 : if ( REFCLKSEL /= '0' ) generate
    REFCLK_P <= REFCLK1P;
    REFCLK_N <= REFCLK1N;
  end generate G_REF1;

  i_gtp : entity work.gtwizard_gtp_bufbypass
  port map (
    SOFT_RESET_TX_IN                        => txRst_i,
    SOFT_RESET_RX_IN                        => rxRst_i,
    DONT_RESET_ON_DATA_ERROR_IN             => '0',
    Q0_CLK1_GTREFCLK_PAD_N_IN               => REFCLK_N,
    Q0_CLK1_GTREFCLK_PAD_P_IN               => REFCLK_P,

    GT0_TX_FSM_RESET_DONE_OUT               => open,
    GT0_RX_FSM_RESET_DONE_OUT               => open,
    GT0_DATA_VALID_IN                       => '1',

    GT0_TXUSRCLK_OUT                        => txusrclk_i,
    GT0_TXUSRCLK2_OUT                       => open,
    GT0_RXUSRCLK_OUT                        => rxusrclk_i,
    GT0_RXUSRCLK2_OUT                       => open,

    --_________________________________________________________________________
    --GT0  (X0Y0)
    --____________________________CHANNEL PORTS________________________________
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          => transceiverIb.drp_addr,
    gt0_drpdi_in                            => transceiverIb.drp_di,
    gt0_drpdo_out                           => drpdo,
    gt0_drpen_in                            => transceiverIb.drp_en,
    gt0_drprdy_out                          => drprdy,
    gt0_drpwe_in                            => transceiverIb.drp_we,
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_eyescanreset_in                     => '0',
    gt0_rxuserrdy_in                        => transceiverIb.rx_usr_rdy,
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                => open,
    gt0_eyescantrigger_in                   => '0',
    ------------------ Receive Ports - FPGA RX Interface Ports -----------------
    gt0_rxdata_out                          => rx_data_i,
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
    gt0_txuserrdy_in                        => transceiverIb.tx_usr_rdy,
    ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
    gt0_txdata_in                           => transceiverIb.tx_data,
    ------------------ Transmit Ports - TX 8B/10B Encoder Ports ----------------
    gt0_txcharisk_in                        => transceiverIb.tx_charisk,
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
    GT0_PLL0LOCK_OUT                        => cpll_locked,
    GT0_PLL0REFCLKLOST_OUT                  => open,
    GT0_PLL1OUTCLK_OUT                      => open,
    GT0_PLL1OUTREFCLK_OUT                   => open,

    sysclk_in                               => sys_clk
  );

  P_ASSIGN : process (
    rxusrclk_i,
    rx_data_i,
    rx_charisk,
    rx_disperr,
    rx_notintable,
    txusrclk_i,
    tx_bufstatus,
    drpclk,
    drpdo,
    drprdy,
    drpbsy,
    cpll_locked
  ) is
  begin
    -- defaults
    transceiverOb               <= EVR_TRANSCEIVER_OB_INIT_C;
    -- override
    transceiverOb.rx_usr_clk    <= rxusrclk_i;
    transceiverOb.rx_data       <= rx_data_i( transceiverOb.rx_data'range );
    transceiverOb.rx_charisk    <= rx_charisk;
    transceiverOb.rx_disperr    <= rx_disperr;
    transceiverOb.rx_notintable <= rx_notintable;
    transceiverOb.tx_usr_clk    <= txusrclk_i;
    transceiverOb.tx_bufstatus  <= tx_bufstatus;
    transceiverOb.drp_clk       <= drpclk;
    transceiverOb.drp_do        <= drpdo;
    transceiverOb.drp_rdy       <= drprdy;
    transceiverOb.drp_bsy       <= drpbsy;
    transceiverOb.dly_adj       <= NONE;
    transceiverOb.cpll_locked   <= cpll_locked;
  end process P_ASSIGN;

end architecture structure;
