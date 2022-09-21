---------------------------------------------------------------------------
--
--  File        : transceiver_wiz.vhd
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

library unisim;
use     unisim.vcomponents.all;

use     work.TimingGtpPkg.all;
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

  constant SEL_PLL0_C : std_logic := '0';
  constant SEL_PLL1_C : std_logic := '1';

  signal txControl : std_logic_vector(15 downto 0) := (others => '0');
  signal rxControl : std_logic_vector(15 downto 0) := (others => '0');
  signal txStatus  : std_logic_vector(15 downto 0) := (others => '0');
  signal rxStatus  : std_logic_vector(15 downto 0) := (others => '0');

  signal rxRecClk_i: std_logic;
  signal txUsrClk_i: std_logic;

  signal pllRst    : std_logic_vector(1 downto 0);
  signal gtRefClk  : std_logic_vector(1 downto 0);

  signal gtgRefClk : std_logic_vector(1 downto 0);
  signal pllClkSel : PllRefClkSelArray;

  signal gtg_clk   : std_logic;

  attribute ASYNC_REG : string;

  signal synRstDone : std_logic_vector(1 downto 0) := (others => '0');
  attribute ASYNC_REG of synRstDone : signal is "TRUE";

  signal drpAddr   : std_logic_vector(15 downto 0);
  
  function toPllSel(constant x : in std_logic) return std_logic_vector is
  begin
    if ( x = '1' ) then
      return PLLREFCLK_SEL_REF1_C;
    else
      return PLLREFCLK_SEL_REF0_C;
    end if; 
  end function toPllSel;

begin

  P_SYNC : process ( rxRecClk_i ) is
  begin
    if ( rising_edge( rxRecClk_i ) ) then
      synRstDone <= synRstDone(synRstDone'left-1 downto 0) & rxStatus(0);
    end if;
  end process P_SYNC;

  P_DRPA : process( ib ) is
  begin
    drpAddr                   <= (others => '0');
    drpAddr(ib.drpaddr'range) <= ib.drpaddr;
  end process P_DRPA;

  ob.drpclk       <= sys_clk;

  ob.rxdisperr    <= rxStatus( 7 downto 6 );
  ob.rxnotintable <= rxStatus( 5 downto 4 );
  ob.rxcdrlocked  <= '1';
  ob.rxresetdone  <= synRstDone(synRstDone'left);
  ob.rxrecclk     <= rxRecClk_i;
  ob.txbufstatus  <= txStatus( 5 downto 4 );

  ob.cpll_locked  <= rxStatus(1);

  rxControl(0) <= ib.gtrxreset or ib.mgtreset;
  rxControl(1) <= RX_POLARITY;
  rxControl(2) <= ib.rxcommaalignen;
  rxControl(3) <= ib.rxcommaalignen;
  rxControl(15 downto 4) <= (others => '0');

  txControl(0) <= ib.gttxreset or ib.mgtreset;
  txControl(1) <= TX_POLARITY;
  txControl(15 downto 2) <= (others => '0');

  ob.txusrclk  <= txUsrClk_i;

  pllClkSel(1) <= toPllSel(REFCLKSEL);
  pllClkSel(0) <= toPllSel(REFCLKSEL);

  gtgRefClk(0) <= gtg_clk;
  gtgRefClk(1) <= gtg_clk;

  i_mmcm : entity work.clk_wiz_0
    port map (
      clk_in1  => sys_clk,
      locked   => open,
      clk_out1 => gtg_clk,
      clk_out2 => open
   );

  i_wrap : entity work.TimingMgtWrapper
    port map (
      sysClk                     => sys_clk,
      gtRxPllSel                 => SEL_PLL1_C,
      gtTxPllSel                 => SEL_PLL0_C,
      pllRst                     => pllRst,

      sysRst                     => '0',

      gtRxP                      => rxp,
      gtRxN                      => rxn,
      gtTxP                      => txp,
      gtTxN                      => txn,

      gtRefClk                   => gtRefClk,
      gtgRefClk                  => gtgRefClk,
      pllRefClkSel               => pllClkSel,

      drpAddr                    => drpAddr,
      drpEn                      => ib.drpen,
      drpWe                      => ib.drpwe,
      drpDin                     => ib.drpdi,
      drpRdy                     => ob.drprdy,
      drpDou                     => ob.drpdo,
      drpBsy                     => ob.drpbsy,

      rxControl                  => rxControl,
      rxStatus                   => rxStatus,
      rxUsrClk                   => rxRecClk_i,
      rxData                     => ob.rxdata,
      rxDataK                    => ob.rxcharisk,
      rxOutClk                   => rxRecClk_i,

      rxRefClk                   => open, -- reference clock used by the receiver
    
      txControl                  => txControl,
      txStatus                   => txStatus,
      txUsrClk                   => txUsrClk_i,
      txData                     => ib.txdata,
      txDataK                    => ib.txcharisk,
      txOutClk                   => txUsrClk_i

    );

  i_buf_ref0 : IBUFDS_GTE2
    generic map (
      CLKRCV_TRST  => true,
      CLKCM_CFG    => true,
      CLKSWING_CFG => "11"
    )
    port map (
      I     => REFCLK0P,
      IB    => REFCLK0N,
      CEB   => '0',
      O     => gtRefClk(0),
      ODIV2 => open
    );

  i_buf_ref1 : IBUFDS_GTE2
    generic map (
      CLKRCV_TRST  => true,
      CLKCM_CFG    => true,
      CLKSWING_CFG => "11"
    )
    port map (
      I     => REFCLK1P,
      IB    => REFCLK1N,
      CEB   => '0',
      O     => gtRefClk(1),
      ODIV2 => open
    );


end architecture structure;
