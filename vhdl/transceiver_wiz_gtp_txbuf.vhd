---------------------------------------------------------------------------
--
--  File        : transceiver_wiz_gtp_txbuf.vhd
--
--  Title       : Event Transceiver Multi-Gigabit Transceiver for Xilinx
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
use ieee.std_logic_unsigned.all;

use     work.transceiver_pkg.all;

entity transceiver_dc_gt is
  generic
    (
      RX_POLARITY                  : std_logic := '0';
      TX_POLARITY                  : std_logic := '0';
      REFCLKSEL                    : std_logic := '0' -- 0 - REFCLK0, 1 - REFCLK1
      );
  port
    (
      sys_clk                      : in  std_logic;

      ib                           : in  transceiver_ib_type;
      ob                           : out transceiver_ob_type;

      REFCLK0P                     : in  std_logic;
      REFCLK0N                     : in  std_logic;
      REFCLK1P                     : in  std_logic;
      REFCLK1N                     : in  std_logic;

      rxp                          : in  std_logic;
      rxn                          : in  std_logic;

      txp                          : out std_logic;
      txn                          : out std_logic
      );
end entity transceiver_dc_gt;

architecture structure of transceiver_dc_gt is

  signal rxRecClk_i: std_logic;
  signal txUsrClk_i: std_logic;

  attribute ASYNC_REG : string;

  signal synRstDone : std_logic_vector(1 downto 0) := (others => '0');
  attribute ASYNC_REG of synRstDone : signal is "TRUE";

  signal rxRstDone      : std_logic;

  signal refClkP        : std_logic;
  signal refClkN        : std_logic;

  signal txRst_i        : std_logic;
  signal rxRst_i        : std_logic;
  
begin

  G_REFCLK0 : if ( REFCLKSEL = '0' ) generate
    refClkP <= REFCLK0P;
    refClkN <= REFCLK0N;
  end generate G_REFCLK0;

  G_REFCLK1 : if ( REFCLKSEL = '1' ) generate
    refClkP <= REFCLK1P;
    refClkN <= REFCLK1N;
  end generate G_REFCLK1;

  P_SYNC : process ( rxRecClk_i ) is
  begin
    if ( rising_edge( rxRecClk_i ) ) then
      synRstDone <= synRstDone(synRstDone'left-1 downto 0) & rxRstDone;
    end if;
  end process P_SYNC;

  -- disable automatic comma-aligment; only PCS mode available which introduces
  -- non-deterministic latencies. The evr_dc keeps resetting the GT until aligment
  -- is achieved...
 -- rxCommaAlignEn <= '0';

  -- not routed out by wizard when common block is in the core
  ob.drpbsy       <= '0';
  -- wizard internally uses sys_clk
  ob.drpclk       <= sys_clk;

  -- not routed out by wizard
  ob.rxcdrlocked  <= '1';
  ob.rxresetdone  <= synRstDone(synRstDone'left);
  ob.rxrecclk     <= rxRecClk_i;

  ob.txusrclk  <= txUsrClk_i;

  rxRst_i         <= ib.gtrxreset or ib.mgtreset;
  txRst_i         <= ib.gttxreset or ib.mgtreset;

  i_mgt : entity work.transceiver_wiz_gtp_txbuf
    port map (
      SOFT_RESET_TX_IN => txRst_i, -- in STD_LOGIC;
      SOFT_RESET_RX_IN => rxRst_i, -- in STD_LOGIC;
      DONT_RESET_ON_DATA_ERROR_IN => '0', -- in STD_LOGIC;
      Q0_CLK1_GTREFCLK_PAD_N_IN => refClkN, -- in STD_LOGIC;
      Q0_CLK1_GTREFCLK_PAD_P_IN => refClkP, -- in STD_LOGIC;
      GT0_TX_FSM_RESET_DONE_OUT => open,    -- out STD_LOGIC;
      GT0_RX_FSM_RESET_DONE_OUT => rxRstDone, -- out STD_LOGIC;
      -- monitored by the rx startup FSM; purpose not clear, in particular
      -- how it differs from rxUsrRdy
      GT0_DATA_VALID_IN => '1', -- in STD_LOGIC;
      GT0_TXUSRCLK_OUT => open, -- out STD_LOGIC;
      GT0_TXUSRCLK2_OUT => txUsrClk_i, -- out STD_LOGIC;
      GT0_RXUSRCLK_OUT => open, -- out STD_LOGIC;
      GT0_RXUSRCLK2_OUT => rxRecClk_i, -- out STD_LOGIC;
      gt0_drpaddr_in => ib.drpaddr, -- in STD_LOGIC_VECTOR ( 8 downto 0 );
      gt0_drpdi_in => ib.drpdi, -- in STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_drpdo_out => ob.drpdo, -- out STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_drpen_in => ib.drpen, -- in STD_LOGIC;
      gt0_drprdy_out => ob.drprdy, -- out STD_LOGIC;
      gt0_drpwe_in => ib.drpwe, -- in STD_LOGIC;
      gt0_eyescanreset_in => '0', -- in STD_LOGIC;
      gt0_rxuserrdy_in => ib.rxusrrdy, -- in STD_LOGIC;
      gt0_eyescandataerror_out => open, -- out STD_LOGIC;
      gt0_eyescantrigger_in => '0', -- in STD_LOGIC;
      gt0_rxdata_out => ob.rxdata, -- out STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_rxcharisk_out => ob.rxcharisk, -- out STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_rxdisperr_out => ob.rxdisperr, -- out STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_rxnotintable_out => ob.rxnotintable, -- out STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_gtprxn_in => rxn, -- in STD_LOGIC;
      gt0_gtprxp_in => rxp, -- in STD_LOGIC;
      gt0_rxphmonitor_out => open, -- out STD_LOGIC_VECTOR ( 4 downto 0 );
      gt0_rxphslipmonitor_out => open, -- out STD_LOGIC_VECTOR ( 4 downto 0 );
      gt0_rxmcommaalignen_in => ib.rxcommaalignen, -- in STD_LOGIC;
      gt0_rxpcommaalignen_in => ib.rxcommaalignen, -- in STD_LOGIC;
      gt0_dmonitorout_out => open, -- out STD_LOGIC_VECTOR ( 14 downto 0 );
      gt0_rxlpmhfhold_in => '0', -- in STD_LOGIC;
      gt0_rxlpmlfhold_in => '0', -- in STD_LOGIC;
      gt0_rxoutclkfabric_out => open, -- out STD_LOGIC;
      gt0_gtrxreset_in => '0', -- in STD_LOGIC;
      gt0_rxlpmreset_in => '0', -- in STD_LOGIC;
      gt0_rxpolarity_in => RX_POLARITY, -- in STD_LOGIC;
      gt0_rxresetdone_out => open, -- out STD_LOGIC;
      gt0_gttxreset_in => '0', -- in STD_LOGIC;
      gt0_txuserrdy_in => ib.txusrrdy, -- in STD_LOGIC;
      gt0_txdata_in => ib.txdata, -- in STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_txcharisk_in => ib.txcharisk, -- in STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_txbufstatus_out => ob.txbufstatus, -- out STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_gtptxn_out => txn, -- out STD_LOGIC;
      gt0_gtptxp_out => txp, -- out STD_LOGIC;
      gt0_txoutclkfabric_out => open, -- out STD_LOGIC;
      gt0_txoutclkpcs_out => open, -- out STD_LOGIC;
      gt0_txresetdone_out => open, -- out STD_LOGIC;
      gt0_txpolarity_in => TX_POLARITY, -- in STD_LOGIC;
      GT0_PLL0RESET_OUT => open, -- out STD_LOGIC;
      GT0_PLL0OUTCLK_OUT => open, -- out STD_LOGIC;
      GT0_PLL0OUTREFCLK_OUT => open, -- out STD_LOGIC;
      GT0_PLL0LOCK_OUT => ob.cpll_locked, -- out STD_LOGIC;
      GT0_PLL0REFCLKLOST_OUT => open, -- out STD_LOGIC;
      GT0_PLL1OUTCLK_OUT => open, -- out STD_LOGIC;
      GT0_PLL1OUTREFCLK_OUT => open, -- out STD_LOGIC;
      sysclk_in => sys_clk -- in STD_LOGIC
      );
end architecture structure;
