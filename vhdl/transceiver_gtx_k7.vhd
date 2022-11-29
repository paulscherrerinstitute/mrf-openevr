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
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

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
    txbufstatus     : out std_logic_vector(1 downto 0);  
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
    RXCDRLOCK_out   : out std_logic;
    RXRESETDONE_out : out std_logic;
    TXUSERRDY_in    : in  std_logic;
    
    reset           : in    std_logic;

    RXN             : in    std_logic;
    RXP             : in    std_logic;

    TXN             : out   std_logic;
    TXP             : out   std_logic
    );
end transceiver_gt;

architecture structure of transceiver_gt is
  constant RX_DFE_KL_CFG2_IN            : bit_vector :=  X"3010D90C";
  constant PMA_RSV_IN                   : bit_vector :=  x"00018480";
  constant PCS_RSVD_ATTR_IN             : bit_vector :=  X"000000000002";

  signal rxusrclk_i    : std_logic;
  signal txusrclk_i    : std_logic;
  signal drpclk_i      : std_logic;

-- local
  signal vcc     : std_logic := '1';
  signal gnd     : std_logic := '0';
  signal gnd_vec : std_logic_vector(31 downto 0) := (others => '0');

  signal REFCLK0       : std_logic;
  signal REFCLK1       : std_logic;
  signal tx_outclk     : std_logic;

  signal rxcharisk_float_i                :   std_logic_vector(5 downto 0);
  signal rxdisperr_float_i                :   std_logic_vector(5 downto 0);
  signal rxnotintable_float_i             :   std_logic_vector(5 downto 0);

  signal txkerr_float_i                   :   std_logic_vector(5 downto 0);
  signal txrundisp_float_i                :   std_logic_vector(5 downto 0);
 
  signal CPLLFBCLKLOST_out : std_logic;
  signal CPLLREFCLKSEL_in : std_logic_vector(2 downto 0);
  signal CPLLREFCLKLOST_out : std_logic;
  signal RXCDRHOLD_in : std_logic;
  signal RXDISPERR_out : std_logic_vector(1 downto 0);
  signal RXNOTINTABLE_out : std_logic_vector(1 downto 0);
  signal RXBUFRESET_in : std_logic;
  signal RXDLYEN_in : std_logic;
  signal RXDLYSRESET_in : std_logic;
  signal RXDLYSRESETDONE_out : std_logic;
  signal RXPHALIGN_in : std_logic;
  signal RXPHALIGNDONE_out : std_logic;
  signal RXPHALIGNEN_in : std_logic;
  signal RXPHDLYRESET_in : std_logic;
  signal RXPHMONITOR_out : std_logic_vector(4 downto 0);
  signal RXPHSLIPMONITOR_out : std_logic_vector(4 downto 0);
  signal RXBYTEISALIGNED_out : std_logic;
  signal RXBYTEREALIGN_out : std_logic;
  signal RXCOMMADET_out : std_logic;
  signal RXDFELPMRESET_in : std_logic;
  signal RXOUTCLK_out : std_logic;
  signal RXOUTCLKPCS_out : std_logic; 
  signal RXPCSRESET_in : std_logic;
  signal RXPMARESET_in : std_logic;
  signal RXLPMEN_in : std_logic;
  signal RXPOLARITY_in : std_logic;
  signal RXSLIDE_in : std_logic;
  signal RXCHARISK_out : std_logic_vector(1 downto 0);
  signal TXDLYEN_in : std_logic;
  signal TXDLYSRESET_in : std_logic;
  signal TXPHALIGN_in : std_logic;
  signal TXPHALIGNEN_in : std_logic;
  signal TXPHDLYRESET_in : std_logic;
  signal TXPHINIT_in : std_logic;
  signal TXOUTCLK_out : std_logic;
  signal TXOUTCLKFABRIC_out : std_logic;
  signal TXOUTCLKPCS_out : std_logic;
  signal TXPCSRESET_in : std_logic;
  signal TXPMARESET_in : std_logic;
  signal TXCHARISK_in : std_logic_vector(1 downto 0);
  signal TXRESETDONE_out : std_logic;
  signal TXPOLARITY_in : std_logic;
 
begin

  gtxe2_X0Y0_i :GTXE2_CHANNEL
    generic map
    (

        --_______________________ Simulation-Only Attributes ___________________

        SIM_RECEIVER_DETECT_PASS   =>      ("TRUE"),
        SIM_RESET_SPEEDUP          =>      ("TRUE"),
        SIM_TX_EIDLE_DRIVE_LEVEL   =>      ("X"),
        SIM_CPLLREFCLK_SEL         =>      ("001"),
        SIM_VERSION                =>      ("4.0"), 
        

       ------------------RX Byte and Word Alignment Attributes---------------
        ALIGN_COMMA_DOUBLE                      =>     ("FALSE"),
        ALIGN_COMMA_ENABLE                      =>     ("1111111111"),
        ALIGN_COMMA_WORD                        =>     (1),
        ALIGN_MCOMMA_DET                        =>     ("TRUE"),
        ALIGN_MCOMMA_VALUE                      =>     ("1010000011"),
        ALIGN_PCOMMA_DET                        =>     ("TRUE"),
        ALIGN_PCOMMA_VALUE                      =>     ("0101111100"),
        SHOW_REALIGN_COMMA                      =>     ("FALSE"),
        RXSLIDE_AUTO_WAIT                       =>     (7),
        RXSLIDE_MODE                            =>     ("OFF"),
        RX_SIG_VALID_DLY                        =>     (10),

       ------------------RX 8B/10B Decoder Attributes---------------
        RX_DISPERR_SEQ_MATCH                    =>     ("TRUE"),
        DEC_MCOMMA_DETECT                       =>     ("TRUE"),
        DEC_PCOMMA_DETECT                       =>     ("TRUE"),
        DEC_VALID_COMMA_ONLY                    =>     ("FALSE"),

       ------------------------RX Clock Correction Attributes----------------------
        CBCC_DATA_SOURCE_SEL                    =>     ("DECODED"),
        CLK_COR_SEQ_2_USE                       =>     ("FALSE"),
        CLK_COR_KEEP_IDLE                       =>     ("FALSE"),
        CLK_COR_MAX_LAT                         =>     (9),
        CLK_COR_MIN_LAT                         =>     (7),
        CLK_COR_PRECEDENCE                      =>     ("TRUE"),
        CLK_COR_REPEAT_WAIT                     =>     (0),
        CLK_COR_SEQ_LEN                         =>     (1),
        CLK_COR_SEQ_1_ENABLE                    =>     ("1111"),
        CLK_COR_SEQ_1_1                         =>     ("0000000000"),
        CLK_COR_SEQ_1_2                         =>     ("0000000000"),
        CLK_COR_SEQ_1_3                         =>     ("0000000000"),
        CLK_COR_SEQ_1_4                         =>     ("0000000000"),
        CLK_CORRECT_USE                         =>     ("FALSE"),
        CLK_COR_SEQ_2_ENABLE                    =>     ("1111"),
        CLK_COR_SEQ_2_1                         =>     ("0000000000"),
        CLK_COR_SEQ_2_2                         =>     ("0000000000"),
        CLK_COR_SEQ_2_3                         =>     ("0000000000"),
        CLK_COR_SEQ_2_4                         =>     ("0000000000"),

       ------------------------RX Channel Bonding Attributes----------------------
        CHAN_BOND_KEEP_ALIGN                    =>     ("FALSE"),
        CHAN_BOND_MAX_SKEW                      =>     (1),
        CHAN_BOND_SEQ_LEN                       =>     (1),
        CHAN_BOND_SEQ_1_1                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_2                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_3                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_4                       =>     ("0000000000"),
        CHAN_BOND_SEQ_1_ENABLE                  =>     ("1111"),
        CHAN_BOND_SEQ_2_1                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_2                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_3                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_4                       =>     ("0000000000"),
        CHAN_BOND_SEQ_2_ENABLE                  =>     ("1111"),
        CHAN_BOND_SEQ_2_USE                     =>     ("FALSE"),
        FTS_DESKEW_SEQ_ENABLE                   =>     ("1111"),
        FTS_LANE_DESKEW_CFG                     =>     ("1111"),
        FTS_LANE_DESKEW_EN                      =>     ("FALSE"),

       ---------------------------RX Margin Analysis Attributes----------------------------
        ES_CONTROL                              =>     ("000000"),
        ES_ERRDET_EN                            =>     ("FALSE"),
        ES_EYE_SCAN_EN                          =>     ("TRUE"),
        ES_HORZ_OFFSET                          =>     (x"000"),
        ES_PMA_CFG                              =>     ("0000000000"),
        ES_PRESCALE                             =>     ("00000"),
        ES_QUALIFIER                            =>     (x"00000000000000000000"),
        ES_QUAL_MASK                            =>     (x"00000000000000000000"),
        ES_SDATA_MASK                           =>     (x"00000000000000000000"),
        ES_VERT_OFFSET                          =>     ("000000000"),

       -------------------------FPGA RX Interface Attributes-------------------------
        RX_DATA_WIDTH                           =>     (20),

       ---------------------------PMA Attributes----------------------------
        OUTREFCLK_SEL_INV                       =>     ("11"),
        PMA_RSV                                 =>     (PMA_RSV_IN),
        PMA_RSV2                                =>     (x"2050"),
        PMA_RSV3                                =>     ("00"),
        PMA_RSV4                                =>     (x"00000000"),
        RX_BIAS_CFG                             =>     ("000000000100"),
        DMONITOR_CFG                            =>     (x"000A00"),
        RX_CM_SEL                               =>     ("11"),
        RX_CM_TRIM                              =>     ("010"),
        RX_DEBUG_CFG                            =>     ("000000000000"),
        RX_OS_CFG                               =>     ("0000010000000"),
        TERM_RCAL_CFG                           =>     ("10000"),
        TERM_RCAL_OVRD                          =>     ('0'),
        TST_RSV                                 =>     (x"00000000"),
        RX_CLK25_DIV                            =>     (5),
        TX_CLK25_DIV                            =>     (5),
        UCODEER_CLR                             =>     ('0'),

       ---------------------------PCI Express Attributes----------------------------
        PCS_PCIE_EN                             =>     ("FALSE"),

       ---------------------------PCS Attributes----------------------------
        PCS_RSVD_ATTR                           =>     (PCS_RSVD_ATTR_IN),

       -------------RX Buffer Attributes------------
        RXBUF_ADDR_MODE                         =>     ("FAST"),
        RXBUF_EIDLE_HI_CNT                      =>     ("1000"),
        RXBUF_EIDLE_LO_CNT                      =>     ("0000"),
        RXBUF_EN                                =>     ("FALSE"),
        RX_BUFFER_CFG                           =>     ("000000"),
        RXBUF_RESET_ON_CB_CHANGE                =>     ("TRUE"),
        RXBUF_RESET_ON_COMMAALIGN               =>     ("FALSE"),
        RXBUF_RESET_ON_EIDLE                    =>     ("FALSE"),
        RXBUF_RESET_ON_RATE_CHANGE              =>     ("TRUE"),
        RXBUFRESET_TIME                         =>     ("00001"),
        RXBUF_THRESH_OVFLW                      =>     (61),
        RXBUF_THRESH_OVRD                       =>     ("FALSE"),
        RXBUF_THRESH_UNDFLW                     =>     (4),
        RXDLY_CFG                               =>     (x"001F"),
        RXDLY_LCFG                              =>     (x"030"),
        RXDLY_TAP_CFG                           =>     (x"0000"),
        RXPH_CFG                                =>     (x"000000"),
        RXPHDLY_CFG                             =>     (x"084020"),
        RXPH_MONITOR_SEL                        =>     ("00000"),
        RX_XCLK_SEL                             =>     ("RXUSR"),
        RX_DDI_SEL                              =>     ("000000"),
        RX_DEFER_RESET_BUF_EN                   =>     ("TRUE"),

       -----------------------CDR Attributes-------------------------

       --For GTX only: Display Port, HBR/RBR- set RXCDR_CFG=72'h0380008bff40200002

       --For GTX only: Display Port, HBR2 -   set RXCDR_CFG=72'h03000023ff10200020
        RXCDR_CFG                               =>     (x"03000023ff40200020"),
        RXCDR_FR_RESET_ON_EIDLE                 =>     ('0'),
        RXCDR_HOLD_DURING_EIDLE                 =>     ('0'),
        RXCDR_PH_RESET_ON_EIDLE                 =>     ('0'),
        RXCDR_LOCK_CFG                          =>     ("010101"),

       -------------------RX Initialization and Reset Attributes-------------------
        RXCDRFREQRESET_TIME                     =>     ("00001"),
        RXCDRPHRESET_TIME                       =>     ("00001"),
        RXISCANRESET_TIME                       =>     ("00001"),
        RXPCSRESET_TIME                         =>     ("00001"),
        RXPMARESET_TIME                         =>     ("00011"),

       -------------------RX OOB Signaling Attributes-------------------
        RXOOB_CFG                               =>     ("0000110"),

       -------------------------RX Gearbox Attributes---------------------------
        RXGEARBOX_EN                            =>     ("FALSE"),
        GEARBOX_MODE                            =>     ("000"),

       -------------------------PRBS Detection Attribute-----------------------
        RXPRBS_ERR_LOOPBACK                     =>     ('0'),

       -------------Power-Down Attributes----------
        PD_TRANS_TIME_FROM_P2                   =>     (x"03c"),
        PD_TRANS_TIME_NONE_P2                   =>     (x"3c"),
        PD_TRANS_TIME_TO_P2                     =>     (x"64"),

       -------------RX OOB Signaling Attributes----------
        SAS_MAX_COM                             =>     (64),
        SAS_MIN_COM                             =>     (36),
        SATA_BURST_SEQ_LEN                      =>     ("1111"),
        SATA_BURST_VAL                          =>     ("100"),
        SATA_EIDLE_VAL                          =>     ("100"),
        SATA_MAX_BURST                          =>     (8),
        SATA_MAX_INIT                           =>     (21),
        SATA_MAX_WAKE                           =>     (7),
        SATA_MIN_BURST                          =>     (4),
        SATA_MIN_INIT                           =>     (12),
        SATA_MIN_WAKE                           =>     (4),

       -------------RX Fabric Clock Output Control Attributes----------
        TRANS_TIME_RATE                         =>     (x"0E"),

       --------------TX Buffer Attributes----------------
        TXBUF_EN                                =>     ("TRUE"),
        TXBUF_RESET_ON_RATE_CHANGE              =>     ("TRUE"),
        TXDLY_CFG                               =>     (x"001F"),
        TXDLY_LCFG                              =>     (x"034"),
        TXDLY_TAP_CFG                           =>     (x"0000"),
        TXPH_CFG                                =>     (x"0780"),
        TXPHDLY_CFG                             =>     (x"084020"),
        TXPH_MONITOR_SEL                        =>     ("00000"),
        TX_XCLK_SEL                             =>     ("TXOUT"),

       -------------------------FPGA TX Interface Attributes-------------------------
        TX_DATA_WIDTH                           =>     (20),

       -------------------------TX Configurable Driver Attributes-------------------------
        TX_DEEMPH0                              =>     ("00000"),
        TX_DEEMPH1                              =>     ("00000"),
        TX_EIDLE_ASSERT_DELAY                   =>     ("110"),
        TX_EIDLE_DEASSERT_DELAY                 =>     ("100"),
        TX_LOOPBACK_DRIVE_HIZ                   =>     ("FALSE"),
        TX_MAINCURSOR_SEL                       =>     ('0'),
        TX_DRIVE_MODE                           =>     ("DIRECT"),
        TX_MARGIN_FULL_0                        =>     ("1001110"),
        TX_MARGIN_FULL_1                        =>     ("1001001"),
        TX_MARGIN_FULL_2                        =>     ("1000101"),
        TX_MARGIN_FULL_3                        =>     ("1000010"),
        TX_MARGIN_FULL_4                        =>     ("1000000"),
        TX_MARGIN_LOW_0                         =>     ("1000110"),
        TX_MARGIN_LOW_1                         =>     ("1000100"),
        TX_MARGIN_LOW_2                         =>     ("1000010"),
        TX_MARGIN_LOW_3                         =>     ("1000000"),
        TX_MARGIN_LOW_4                         =>     ("1000000"),

       -------------------------TX Gearbox Attributes--------------------------
        TXGEARBOX_EN                            =>     ("FALSE"),

       -------------------------TX Initialization and Reset Attributes--------------------------
        TXPCSRESET_TIME                         =>     ("00001"),
        TXPMARESET_TIME                         =>     ("00001"),

       -------------------------TX Receiver Detection Attributes--------------------------
        TX_RXDETECT_CFG                         =>     (x"1832"),
        TX_RXDETECT_REF                         =>     ("100"),

       ----------------------------CPLL Attributes----------------------------
        CPLL_CFG                                =>     (x"BC07DC"),
        CPLL_FBDIV                              =>     (4),
        CPLL_FBDIV_45                           =>     (5),
        CPLL_INIT_CFG                           =>     (x"00001E"),
        CPLL_LOCK_CFG                           =>     (x"01E8"),
        CPLL_REFCLK_DIV                         =>     (1),
        RXOUT_DIV                               =>     (2),
        TXOUT_DIV                               =>     (2),
        SATA_CPLL_CFG                           =>     ("VCO_3000MHZ"),

       --------------RX Initialization and Reset Attributes-------------
        RXDFELPMRESET_TIME                      =>     ("0001111"),

       --------------RX Equalizer Attributes-------------
        RXLPM_HF_CFG                            =>     ("00000011110000"),
        RXLPM_LF_CFG                            =>     ("00000011110000"),
        RX_DFE_GAIN_CFG                         =>     (x"020FEA"),
        RX_DFE_H2_CFG                           =>     ("000000000000"),
        RX_DFE_H3_CFG                           =>     ("000001000000"),
        RX_DFE_H4_CFG                           =>     ("00011110000"),
        RX_DFE_H5_CFG                           =>     ("00011100000"),
        RX_DFE_KL_CFG                           =>     ("0000011111110"),
        RX_DFE_LPM_CFG                          =>     (x"0954"),
        RX_DFE_LPM_HOLD_DURING_EIDLE            =>     ('0'),
        RX_DFE_UT_CFG                           =>     ("10001111000000000"),
        RX_DFE_VP_CFG                           =>     ("00011111100000011"),

       -------------------------Power-Down Attributes-------------------------
        RX_CLKMUX_PD                            =>     ('1'),
        TX_CLKMUX_PD                            =>     ('1'),

       -------------------------FPGA RX Interface Attribute-------------------------
        RX_INT_DATAWIDTH                        =>     (0),

       -------------------------FPGA TX Interface Attribute-------------------------
        TX_INT_DATAWIDTH                        =>     (0),

       ------------------TX Configurable Driver Attributes---------------
        TX_QPI_STATUS_EN                        =>     ('0'),

       -------------------------RX Equalizer Attributes--------------------------
        RX_DFE_KL_CFG2                          =>     (RX_DFE_KL_CFG2_IN),
        RX_DFE_XYD_CFG                          =>     ("0000000000000"),

       -------------------------TX Configurable Driver Attributes--------------------------
        TX_PREDRIVER_MODE                       =>     ('0')


    )
    port map
    (
        --------------------------------- CPLL Ports -------------------------------
        CPLLFBCLKLOST                   =>      CPLLFBCLKLOST_out,
        CPLLLOCK                        =>      CPLLLOCK_out,
        CPLLLOCKDETCLK                  =>      sys_clk,
        CPLLLOCKEN                      =>      vcc,
        CPLLPD                          =>      gnd,
        CPLLREFCLKLOST                  =>      CPLLREFCLKLOST_out,
        CPLLREFCLKSEL                   =>      CPLLREFCLKSEL_in,
        CPLLRESET                       =>      CPLLRESET_in,
        GTRSVD                          =>      "0000000000000000",
        PCSRSVDIN                       =>      "0000000000000000",
        PCSRSVDIN2                      =>      "00000",
        PMARSVDIN                       =>      "00000",
        PMARSVDIN2                      =>      "00000",
        TSTIN                           =>      "11111111111111111111",
        TSTOUT                          =>      open,
        ---------------------------------- Channel ---------------------------------
        CLKRSVD                         =>      "0000",
        -------------------------- Channel - Clocking Ports ------------------------
        GTGREFCLK                       =>      gnd,
        GTNORTHREFCLK0                  =>      gnd,
        GTNORTHREFCLK1                  =>      gnd,
        GTREFCLK0                       =>      REFCLK0,
        GTREFCLK1                       =>      REFCLK1,
        GTSOUTHREFCLK0                  =>      gnd,
        GTSOUTHREFCLK1                  =>      gnd,
        ---------------------------- Channel - DRP Ports  --------------------------
        DRPADDR                         =>      drpaddr,
        DRPCLK                          =>      drpclk_i,
        DRPDI                           =>      drpdi,
        DRPDO                           =>      drpdo,
        DRPEN                           =>      drpen,
        DRPRDY                          =>      drprdy,
        DRPWE                           =>      drpwe,
       ------------------------------- Clocking Ports -----------------------------
        GTREFCLKMONITOR                 =>      open,
        QPLLCLK                         =>      gnd,
        QPLLREFCLK                      =>      gnd,
        RXSYSCLKSEL                     =>      "00",
        TXSYSCLKSEL                     =>      "00",
        --------------------------- Digital Monitor Ports --------------------------
        DMONITOROUT                     =>      open,
        ----------------- FPGA TX Interface Datapath Configuration  ----------------
        TX8B10BEN                       =>      vcc,
        ------------------------------- Loopback Ports -----------------------------
        LOOPBACK                        =>      gnd_vec(2 downto 0),
        ----------------------------- PCI Express Ports ----------------------------
        PHYSTATUS                       =>      open,
        RXRATE                          =>      gnd_vec(2 downto 0),
        RXVALID                         =>      open,
        ------------------------------ Power-Down Ports ----------------------------
        RXPD                            =>      "00",
        TXPD                            =>      "00",
        -------------------------- RX 8B/10B Decoder Ports -------------------------
        SETERRSTATUS                    =>      gnd,
        --------------------- RX Initialization and Reset Ports --------------------
        EYESCANRESET                    =>      gnd,
        RXUSERRDY                       =>      RXUSERRDY_in,
        -------------------------- RX Margin Analysis Ports ------------------------
        EYESCANDATAERROR                =>      open,
        EYESCANMODE                     =>      gnd,
        EYESCANTRIGGER                  =>      gnd,
        ------------------------- Receive Ports - CDR Ports ------------------------
        RXCDRFREQRESET                  =>      gnd,
        RXCDRHOLD                       =>      gnd,
        RXCDRLOCK                       =>      RXCDRLOCK_out,
        RXCDROVRDEN                     =>      gnd,
        RXCDRRESET                      =>      gnd,
        RXCDRRESETRSV                   =>      gnd,
        ------------------- Receive Ports - Clock Correction Ports -----------------
        RXCLKCORCNT                     =>      open,
        ---------- Receive Ports - FPGA RX Interface Datapath Configuration --------
        RX8B10BEN                       =>      vcc,
        ------------------ Receive Ports - FPGA RX Interface Ports -----------------
        RXUSRCLK                        =>      rxusrclk_i,
        RXUSRCLK2                       =>      rxusrclk_i,
        ------------------ Receive Ports - FPGA RX interface Ports -----------------
        RXDATA                          =>      rx_data,
        ------------------- Receive Ports - Pattern Checker Ports ------------------
        RXPRBSERR                       =>      open,
        RXPRBSSEL                       =>      gnd_vec(2 downto 0),
        ------------------- Receive Ports - Pattern Checker ports ------------------
        RXPRBSCNTRESET                  =>      gnd,
        -------------------- Receive Ports - RX  Equalizer Ports -------------------
        RXDFEXYDEN                      =>      gnd,
        RXDFEXYDHOLD                    =>      gnd,
        RXDFEXYDOVRDEN                  =>      gnd,
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        RXDISPERR(7 downto 2)           =>      rxdisperr_float_i,
        RXDISPERR(1 downto 0)           =>      rx_disperr,
        RXNOTINTABLE(7 downto 2)        =>      rxnotintable_float_i,
        RXNOTINTABLE(1 downto 0)        =>      rx_notintable,
        --------------------------- Receive Ports - RX AFE -------------------------
        GTXRXP                          =>      RXP,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        GTXRXN                          =>      RXN,
        ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
        RXBUFRESET                      =>      gnd,
        RXBUFSTATUS                     =>      open,
        RXDDIEN                         =>      vcc,
        RXDLYBYPASS                     =>      gnd,
        RXDLYEN                         =>      RXDLYEN_in,
        RXDLYOVRDEN                     =>      gnd,
        RXDLYSRESET                     =>      RXDLYSRESET_in,
        RXDLYSRESETDONE                 =>      RXDLYSRESETDONE_out,
        RXPHALIGN                       =>      RXPHALIGN_in,
        RXPHALIGNDONE                   =>      RXPHALIGNDONE_out,
        RXPHALIGNEN                     =>      RXPHALIGNEN_in,
        RXPHDLYPD                       =>      gnd,
        RXPHDLYRESET                    =>      RXPHDLYRESET_in,
        RXPHMONITOR                     =>      RXPHMONITOR_out,
        RXPHOVRDEN                      =>      gnd,
        RXPHSLIPMONITOR                 =>      RXPHSLIPMONITOR_out,
        RXSTATUS                        =>      open,
        -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
        RXBYTEISALIGNED                 =>      RXBYTEISALIGNED_out,
        RXBYTEREALIGN                   =>      RXBYTEREALIGN_out,
        RXCOMMADET                      =>      RXCOMMADET_out,
        RXCOMMADETEN                    =>      gnd,
        RXMCOMMAALIGNEN                 =>      gnd,
        RXPCOMMAALIGNEN                 =>      gnd,
        ------------------ Receive Ports - RX Channel Bonding Ports ----------------
        RXCHANBONDSEQ                   =>      open,
        RXCHBONDEN                      =>      gnd,
        RXCHBONDLEVEL                   =>      gnd_vec(2 downto 0),
        RXCHBONDMASTER                  =>      gnd,
        RXCHBONDO                       =>      open,
        RXCHBONDSLAVE                   =>      gnd,
        ----------------- Receive Ports - RX Channel Bonding Ports  ----------------
        RXCHANISALIGNED                 =>      open,
        RXCHANREALIGN                   =>      open,
        --------------------- Receive Ports - RX Equalizer Ports -------------------
        RXDFEAGCHOLD                    =>      gnd,
        RXDFEAGCOVRDEN                  =>      gnd,
        RXDFECM1EN                      =>      gnd,
        RXDFELFHOLD                     =>      gnd,
        RXDFELFOVRDEN                   =>      vcc,
        RXDFELPMRESET                   =>      RXDFELPMRESET_in,
        RXDFETAP2HOLD                   =>      gnd,
        RXDFETAP2OVRDEN                 =>      gnd,
        RXDFETAP3HOLD                   =>      gnd,
        RXDFETAP3OVRDEN                 =>      gnd,
        RXDFETAP4HOLD                   =>      gnd,
        RXDFETAP4OVRDEN                 =>      gnd,
        RXDFETAP5HOLD                   =>      gnd,
        RXDFETAP5OVRDEN                 =>      gnd,
        RXDFEUTHOLD                     =>      gnd,
        RXDFEUTOVRDEN                   =>      gnd,
        RXDFEVPHOLD                     =>      gnd,
        RXDFEVPOVRDEN                   =>      gnd,
        RXDFEVSEN                       =>      gnd,
        RXLPMLFKLOVRDEN                 =>      gnd,
        RXMONITOROUT                    =>      open,
        RXMONITORSEL                    =>      "01",
        RXOSHOLD                        =>      gnd,
        RXOSOVRDEN                      =>      gnd,
        --------------------- Receive Ports - RX Equilizer Ports -------------------
        RXLPMHFHOLD                     =>      gnd,
        RXLPMHFOVRDEN                   =>      gnd,
        RXLPMLFHOLD                     =>      gnd,
        ------------ Receive Ports - RX Fabric ClocK Output Control Ports ----------
        RXRATEDONE                      =>      open,
        --------------- Receive Ports - RX Fabric Output Control Ports -------------
        RXOUTCLK                        =>      RXOUTCLK_out,
        RXOUTCLKFABRIC                  =>      open,
        RXOUTCLKPCS                     =>      RXOUTCLKPCS_out,
        RXOUTCLKSEL                     =>      "010",
        ---------------------- Receive Ports - RX Gearbox Ports --------------------
        RXDATAVALID                     =>      open,
        RXHEADER                        =>      open,
        RXHEADERVALID                   =>      open,
        RXSTARTOFSEQ                    =>      open,
        --------------------- Receive Ports - RX Gearbox Ports  --------------------
        RXGEARBOXSLIP                   =>      gnd,
        ------------- Receive Ports - RX Initialization and Reset Ports ------------
        GTRXRESET                       =>      GTRXRESET_in,
        RXOOBRESET                      =>      gnd,
        RXPCSRESET                      =>      RXPCSRESET_in,
        RXPMARESET                      =>      RXPMARESET_in,
        ------------------ Receive Ports - RX Margin Analysis ports ----------------
        RXLPMEN                         =>      gnd,
        ------------------- Receive Ports - RX OOB Signaling ports -----------------
        RXCOMSASDET                     =>      open,
        RXCOMWAKEDET                    =>      open,
        ------------------ Receive Ports - RX OOB Signaling ports  -----------------
        RXCOMINITDET                    =>      open,
        ------------------ Receive Ports - RX OOB signalling Ports -----------------
        RXELECIDLE                      =>      open,
        RXELECIDLEMODE                  =>      "11",
        ----------------- Receive Ports - RX Polarity Control Ports ----------------
        RXPOLARITY                      =>      RXPOLARITY_in,
        ---------------------- Receive Ports - RX gearbox ports --------------------
        RXSLIDE                         =>      RXSLIDE_in,
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        RXCHARISCOMMA                   =>      open,
        RXCHARISK(7 downto 2)           =>      rxcharisk_float_i,
        RXCHARISK(1 downto 0)           =>      rx_charisk,
        ------------------ Receive Ports - Rx Channel Bonding Ports ----------------
        RXCHBONDI                       =>      "00000",
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        RXRESETDONE                     =>      RXRESETDONE_out,
        -------------------------------- Rx AFE Ports ------------------------------
        RXQPIEN                         =>      gnd,
        RXQPISENN                       =>      open,
        RXQPISENP                       =>      open,
        --------------------------- TX Buffer Bypass Ports -------------------------
        TXPHDLYTSTCLK                   =>      gnd,
        ------------------------ TX Configurable Driver Ports ----------------------
        TXPOSTCURSOR                    =>      "00000",
        TXPOSTCURSORINV                 =>      gnd,
        TXPRECURSOR                     =>      gnd_vec(4 downto 0),
        TXPRECURSORINV                  =>      gnd,
        TXQPIBIASEN                     =>      gnd,
        TXQPISTRONGPDOWN                =>      gnd,
        TXQPIWEAKPUP                    =>      gnd,
        --------------------- TX Initialization and Reset Ports --------------------
        CFGRESET                        =>      gnd,
        GTTXRESET                       =>      GTTXRESET_in,
        PCSRSVDOUT                      =>      open,
        TXUSERRDY                       =>      TXUSERRDY_in,
        ---------------------- Transceiver Reset Mode Operation --------------------
        GTRESETSEL                      =>      gnd,
        RESETOVRD                       =>      gnd,
        ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        TXCHARDISPMODE                  =>      gnd_vec(7 downto 0),
        TXCHARDISPVAL                   =>      gnd_vec(7 downto 0),
        ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
        TXUSRCLK                        =>      txusrclk_i,
        TXUSRCLK2                       =>      txusrclk_i,
        --------------------- Transmit Ports - PCI Express Ports -------------------
        TXELECIDLE                      =>      gnd,
        TXMARGIN                        =>      gnd_vec(2 downto 0),
        TXRATE                          =>      gnd_vec(2 downto 0),
        TXSWING                         =>      gnd,
        ------------------ Transmit Ports - Pattern Generator Ports ----------------
        TXPRBSFORCEERR                  =>      gnd,
        ------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
        TXDLYBYPASS                     =>      vcc,
        TXDLYEN                         =>      gnd,
        TXDLYHOLD                       =>      gnd,
        TXDLYOVRDEN                     =>      gnd,
        TXDLYSRESET                     =>      TXDLYSRESET_in,
        TXDLYSRESETDONE                 =>      open,
        TXDLYUPDOWN                     =>      gnd,
        TXPHALIGN                       =>      vcc,
        TXPHALIGNDONE                   =>      open,
        TXPHALIGNEN                     =>      vcc,
        TXPHDLYPD                       =>      gnd,
        TXPHDLYRESET                    =>      gnd,
        TXPHINIT                        =>      gnd,
        TXPHINITDONE                    =>      open,
        TXPHOVRDEN                      =>      vcc,
        ---------------------- Transmit Ports - TX Buffer Ports --------------------
        TXBUFSTATUS                     =>      txbufstatus,
        --------------- Transmit Ports - TX Configurable Driver Ports --------------
        TXBUFDIFFCTRL                   =>      "100",
        TXDEEMPH                        =>      gnd,
        TXDIFFCTRL                      =>      "1000",
        TXDIFFPD                        =>      gnd,
        TXINHIBIT                       =>      gnd,
        TXMAINCURSOR                    =>      "0000000",
        TXPISOPD                        =>      gnd,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        TXDATA                          =>      tx_data,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        GTXTXN                          =>      TXN,
        GTXTXP                          =>      TXP,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        TXOUTCLK                        =>      tx_outclk,
        TXOUTCLKFABRIC                  =>      TXOUTCLKFABRIC_out,
        TXOUTCLKPCS                     =>      TXOUTCLKPCS_out,
        TXOUTCLKSEL                     =>      "011",
        TXRATEDONE                      =>      open,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        TXCHARISK(7 downto 2)           =>      gnd_vec(5 downto 0),
        TXCHARISK(1 downto 0)           =>      tx_charisk,
        TXGEARBOXREADY                  =>      open,
        TXHEADER                        =>      gnd_vec(2 downto 0),
        TXSEQUENCE                      =>      gnd_vec(6 downto 0),
        TXSTARTSEQ                      =>      gnd,
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
        TXPCSRESET                      =>      TXPCSRESET_in,
        TXPMARESET                      =>      TXPMARESET_in,
        TXRESETDONE                     =>      TXRESETDONE_out,
        ------------------ Transmit Ports - TX OOB signalling Ports ----------------
        TXCOMFINISH                     =>      open,
        TXCOMINIT                       =>      gnd,
        TXCOMSAS                        =>      gnd,
        TXCOMWAKE                       =>      gnd,
        TXPDELECIDLEMODE                =>      gnd,
        ----------------- Transmit Ports - TX Polarity Control Ports ---------------
        TXPOLARITY                      =>      TXPOLARITY_in,
        --------------- Transmit Ports - TX Receiver Detection Ports  --------------
        TXDETECTRX                      =>      gnd,
        ------------------ Transmit Ports - TX8b/10b Encoder Ports -----------------
        TX8B10BBYPASS                   =>      gnd_vec(7 downto 0),
        ------------------ Transmit Ports - pattern Generator Ports ----------------
        TXPRBSSEL                       =>      gnd_vec(2 downto 0),
        ----------------------- Tx Configurable Driver  Ports ----------------------
        TXQPISENN                       =>      open,
        TXQPISENP                       =>      open

    );


  refclk_select_1: 
  if REFCLKSEL = '1' generate
    REFCLK0 <= '0';
    refclk1_ibufds_i : IBUFDS_GTE2
      port map
      (
        I     => REFCLK1P,
        IB    => REFCLK1N,
        CEB   => gnd,
        O     => REFCLK1,
        ODIV2 => open);
    CPLLREFCLKSEL_in <= "010"; -- MGTREFCLK1
  end generate;

  refclk_select_0: 
  if REFCLKSEL = '0' generate
    refclk0_ibufds_i : IBUFDS_GTE2
      port map
      (
        I	=> REFCLK0P,
        IB      => REFCLK0N,
        CEB     => gnd,
        O	=> REFCLK0,
        ODIV2   => open);
    REFCLK1 <= '0';
    CPLLREFCLKSEL_in <= "001"; -- MGTREFCLK0
  end generate;

  RXDFELPMRESET_in <= reset;
  RXDLYEN_in <= '0';
  RXDLYSRESET_in <= reset;
  RXPCSRESET_in <= reset;
  RXPHALIGN_in <= '0';
  RXPHALIGNEN_in <= '0';
  RXPHDLYRESET_in <= reset;
  RXPMARESET_in <= reset;
  RXPOLARITY_in <= RX_POLARITY;
  RXSLIDE_in <= '0';
  TXDLYEN_in <= '0';
  TXDLYSRESET_in <= reset;
  TXPCSRESET_in <= '0';
  TXPHALIGN_in <= '0';
  TXPHALIGNEN_in <= '0';
  TXPHDLYRESET_in <= '0';
  TXPHINIT_in <= '0';
  TXPMARESET_in <= '0';
  TXPOLARITY_in <= TX_POLARITY;
 
  i_bufg0: BUFG
    port map (
      O => rxusrclk_i,
      I => RXOUTCLK_out);

  i_bufg1: BUFG
    port map (
      O => txusrclk_i,
      I => tx_outclk);

  rxusrclk <= rxusrclk_i;
  txusrclk <= txusrclk_i;

  drpclk_i <= txusrclk_i;
  drpclk   <= drpclk_i;
 
  useDrpDlyAdj <= '1';
  drpbsy       <= '0';
end architecture structure;
