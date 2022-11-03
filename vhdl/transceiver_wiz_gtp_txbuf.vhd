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
use ieee.numeric_std.all;

library unisim;
use     unisim.vcomponents.all;

use     work.transceiver_pkg.all;
use     work.GtpCommonPkg.all;

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

  signal rxRecClk_i     : std_logic;
  signal rxRecClk_nb    : std_logic;
  signal txUsrClk_i     : std_logic;
  signal txOutClk_nb    : std_logic;
  signal txOutClk       : std_logic;
  signal txRefClk_nb    : std_logic_vector(1 downto 0);
  signal txRefClk       : std_logic;
  signal txBufStatus    : std_logic_vector(1 downto 0);

  attribute ASYNC_REG   : string;

  signal synRxRstDone     : std_logic_vector(1 downto 0) := (others => '0');
  signal synTxRstDone     : std_logic_vector(1 downto 0) := (others => '0');
  attribute ASYNC_REG of synRxRstDone      : signal is "TRUE";
  attribute ASYNC_REG of synTxRstDone      : signal is "TRUE";

  signal rxRstDone      : std_logic;
  signal txRstDone      : std_logic;
  signal pllLocked      : std_logic := '0';

  signal refClkP        : std_logic;
  signal refClkN        : std_logic;

  signal txRst_i        : std_logic;
  signal rxRst_i        : std_logic;

  signal pllIb          : GtpCommonIbArray( 1 downto 0);
  signal pllOb          : GtpCommonObArray( 1 downto 0);

  function toInt(x : std_logic) return natural is
  begin
    if ( x = '1' ) then return 1; else return 0; end if;
  end function toInt;

  signal pippmStepSize   : std_logic_vector(4 downto 0) := (others => '0');
  signal pippmEn         : std_logic := '0';

  constant GEN_PLL_C     : boolean := true;

  signal usrInp          : std_logic_vector(ib.usrInp'range) := (others => '0');
  signal usrOut          : std_logic_vector(ob.usrOut'range) := (others => '0');
  signal usrOut_i        : std_logic_vector(ob.usrOut'range) := (others => '0');
  signal usrOutSync      : std_logic := '0';
  signal usrInpSync      : std_logic := '0';

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
      synRxRstDone <= synRxRstDone(synRxRstDone'left-1 downto 0) & rxRstDone;
      synTxRstDone <= synTxRstDone(synTxRstDone'left-1 downto 0) & (txRstDone and pllLocked);
    end if;
  end process P_SYNC;

  -- disable automatic comma-aligment; only PCS mode available which introduces
  -- non-deterministic latencies. The evr_dc keeps resetting the GT until aligment
  -- is achieved...
 -- rxCommaAlignEn <= '0';

  -- not routed out by wizard when common block is in the core
  -- wizard internally uses sys_clk
  ob.drpclk       <= sys_clk;

  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!
  -- tuning the delay does currently not work (necessary signals not
  -- routed out by wizard!)
  ob.txdlyadjen   <= '0';

  -- not routed out by wizard
  ob.rxcdrlocked  <= '1';
  ob.rxresetdone  <= synRxRstDone(synRxRstDone'left);
  ob.txresetdone  <= synTxRstDone(synTxRstDone'left);
  ob.rxrecclk     <= rxRecClk_i;
  ob.txbufstatus  <= txBufStatus;

  U_TXOUTCLK_BUF : BUFG
    port map (
      I => txOutClk_nb,
      O => txOutClk
    );

  U_TXREFCLK_BUF : BUFG
    port map (
      I => txRefClk_nb( toInt( REFCLKSEL ) ),
      O => ob.txoutclk
    );


  U_RXOUTCLK_BUF : BUFG
    port map (
      I => rxRecClk_nb,
      O => rxRecClk_i
    );

  rxRst_i         <= ib.gtrxreset or ib.mgtreset;
  txRst_i         <= ib.gttxreset or ib.mgtreset;

  txUsrClk_i      <= ib.txusrclk;

  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  -- NOTE: we MUST let the wizard create the GTP *without* the common block
  --       - no control over txoutclk/txusrclk, i.e., they can't be different
  --       - I found that the wizard sets TXPIPPMSTEPSIZE to "000" when
  --         the common block is included; a setting with according to the
  --         UG is illegal. When the common block is excluded then vivado
  --         (2021.2) produces a TXPIPPMSTEPSIZE = "001". Unfortunately the
  --         generic is not propagated to the outside world :-(.

  i_mgt : entity work.transceiver_wiz_gtp_txbuf
    port map (
      SYSCLK_IN => sys_clk, -- in STD_LOGIC
      SOFT_RESET_TX_IN => txRst_i, -- in STD_LOGIC;
      SOFT_RESET_RX_IN => rxRst_i, -- in STD_LOGIC;
      DONT_RESET_ON_DATA_ERROR_IN => '0', -- in STD_LOGIC;
      GT0_DRP_BUSY_OUT => ob.drpbsy, -- out STD_LOGIC;
      GT0_TX_FSM_RESET_DONE_OUT => txRstDone, -- out STD_LOGIC;
      GT0_RX_FSM_RESET_DONE_OUT => rxRstDone, -- out STD_LOGIC;
      -- monitored by the rx startup FSM; purpose not clear, in particular
      -- how it differs from rxUsrRdy
      GT0_DATA_VALID_IN => '1', -- in STD_LOGIC;
      gt0_drpclk_in => sys_clk,
      gt0_drpaddr_in => ib.drpaddr, -- in STD_LOGIC_VECTOR ( 8 downto 0 );
      gt0_drpdi_in => ib.drpdi, -- in STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_drpdo_out => ob.drpdo, -- out STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_drpen_in => ib.drpen, -- in STD_LOGIC;
      gt0_drprdy_out => ob.drprdy, -- out STD_LOGIC;
      gt0_drpwe_in => ib.drpwe, -- in STD_LOGIC;
      gt0_rxrate_in => GTP_OUTDIV_1_C, -- in STD_LOGIC_VECTOR ( 2 downto 0 );
      gt0_eyescanreset_in => '0', -- in STD_LOGIC;
      gt0_rxuserrdy_in => ib.rxusrrdy, -- in STD_LOGIC;
      gt0_eyescandataerror_out => open, -- out STD_LOGIC;
      gt0_eyescantrigger_in => '0', -- in STD_LOGIC;
      gt0_rxdata_out => ob.rxdata, -- out STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_rxusrclk_in => rxRecClk_i, -- in STD_LOGIC;
      gt0_rxusrclk2_in => rxRecClk_i, -- in STD_LOGIC;
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
      gt0_rxratedone_out => open, -- out STD_LOGIC;
      gt0_rxoutclk_out => rxRecClk_nb, -- out STD_LOGIC;
      gt0_rxoutclkfabric_out => open, -- out STD_LOGIC;
      gt0_gtrxreset_in => '0', -- in STD_LOGIC;
      gt0_rxlpmreset_in => '0', -- in STD_LOGIC;
      gt0_rxpolarity_in => RX_POLARITY, -- in STD_LOGIC;
      gt0_rxresetdone_out => open, -- out STD_LOGIC;
      gt0_gttxreset_in => '0', -- in STD_LOGIC;
      gt0_txuserrdy_in => ib.txusrrdy, -- in STD_LOGIC;
      gt0_txpippmen_in => pippmen, -- in STD_LOGIC;
      gt0_txpippmstepsize_in => pippmstepsize, -- in STD_LOGIC_VECTOR ( 4 downto 0 );
      gt0_txdata_in => ib.txdata, -- in STD_LOGIC_VECTOR ( 15 downto 0 );
      gt0_txusrclk_in  => txUsrClk_i, -- in STD_LOGIC;
      gt0_txusrclk2_in  => txUsrClk_i, -- in STD_LOGIC;
      gt0_txrate_in => GTP_OUTDIV_1_C, -- in STD_LOGIC_VECTOR ( 2 downto 0 );
      gt0_txcharisk_in => ib.txcharisk, -- in STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_txbufstatus_out => txBufStatus, -- out STD_LOGIC_VECTOR ( 1 downto 0 );
      gt0_gtptxn_out => txn, -- out STD_LOGIC;
      gt0_gtptxp_out => txp, -- out STD_LOGIC;
      gt0_txoutclk_out => txOutClk_nb, -- out STD_LOGIC;
      gt0_txoutclkfabric_out => open, -- out STD_LOGIC;
      gt0_txoutclkpcs_out => open, -- out STD_LOGIC;
      gt0_txratedone_out => open, -- out STD_LOGIC;
      gt0_txresetdone_out => open, -- out STD_LOGIC;
      gt0_txpolarity_in => TX_POLARITY, -- in STD_LOGIC;
      GT0_PLL0OUTCLK_IN  => pllOb(0).pllOutClk, -- in  STD_LOGIC;
      GT0_PLL0OUTREFCLK_IN => pllOb(0).pllOutRefClk, -- in STD_LOGIC;
      GT0_PLL0RESET_OUT => pllIb(0).pllReset, -- out STD_LOGIC;
      GT0_PLL0LOCK_IN => pllOb(0).pllLock, -- in STD_LOGIC;
      GT0_PLL0REFCLKLOST_IN => pllOb(0).pllRefClkLost, -- in STD_LOGIC;
      GT0_PLL1OUTCLK_IN => pllOb(1).pllOutClk, -- in STD_LOGIC;
      GT0_PLL1OUTREFCLK_IN => pllOb(1).pllOutRefClk -- in STD_LOGIC;
      );

   -- watch out for how the wizard sets TXOUT_DIV/RXOUT_DIV !!
   -- update: we now use the rx/tx-rate ports for explicit
   -- control.
   -- (see comment in GtpCommon)
   U_COMMON : entity work.GtpCommon
      generic map (
         PLL0_FBDIV_IN    => 2,
         PLL0_FBDIV_45_IN => 5
      )
      port map (
         DRPCLK_COMMON_IN => sys_clk,
         pllIb            => pllIb,
         pllOb            => pllOb,
         GTREFCLK_P_IN(0) => REFCLK0P,
         GTREFCLK_P_IN(1) => REFCLK1P,
         GTREFCLK_N_IN(0) => REFCLK0N,
         GTREFCLK_N_IN(1) => REFCLK1N,

         GTREFCLK_OUT     => txRefClk_nb
      );

   pllIb(1)       <= GTP_COMMON_IB_INIT_C;

   pllIb(0).pllPD <= '0';

   pllIb(0).pllRefClkSel(2) <= '0';
   pllIb(0).pllRefClkSel(1) <=     REFCLKSEL;
   pllIb(0).pllRefClkSel(0) <= not REFCLKSEL;

   ob.cpll_locked <= pllOb(0).pllLock;

  G_PLL : if ( GEN_PLL_C ) generate
    signal filterCnt         : unsigned(19 downto 0) := (others => '1');
    signal freq              : signed(15 downto 0) := (others => '0');
    signal freqm             : signed(15 downto 0) := (others => '0');
    signal freqmax           : signed(15 downto 0) := to_signed( 5120, 16);
    signal fmod              : signed(15 downto 0) := (others => '0');

    signal decm              : unsigned(15 downto 0) := to_unsigned( 4-1, 16);
    signal pstep             : signed  (15 downto 0) := to_signed  ( 2, 16);
    signal istep             : signed  (15 downto 0) := to_signed  ( 1, 16);
    signal ishft             : unsigned(15 downto 0) := to_unsigned( 3, 16);
    signal mshft             : unsigned(15 downto 0) := to_unsigned(15, 16);
    signal piVcoRst          : std_logic := '1';
    signal pllFInc           : std_logic := '0';
    signal pllcen            : std_logic := '0';
    signal phavg             : unsigned(15 downto 0) := (others => '0');
    signal phavgrun          : unsigned(15 downto 0) := (others => '0');
    signal phavgcnt          : unsigned(15 downto 0) := (others => '1');
    signal phavgwin          : unsigned(15 downto 0) := (others => '1');
    signal plldi             : std_logic := '0';

  begin

  U_VCO : entity work.pivco
    generic map (
      WIDTH_G => freq'length
    )
    port map (
      clk     => txUsrClk_i,
      rst     => piVcoRst,
      ceo     => pllcen,
      fmod    => fmod,
      freqmax => freqmax,
      freqctl => freq
    );

  U_PLL : entity work.bbpll
    generic map (
      WIDTH_G => freq'length
    )
    port map (
      clk     => txUsrClk_i,
      rst     => piVcoRst,
      cen     => pllcen,

      fInc    => pllFInc,
      decm    => decm,
      pstep   => pstep,
      istep   => istep,
      ishft   => ishft,
      mshft   => mshft,
      freq    => freq,
      freqm   => freqm
    );

  pstep <= resize(signed  (usrInp( 3 downto  0)), pstep'length);
  istep <= resize(signed  (usrInp( 7 downto  4)), istep'length);
  ishft <= resize(unsigned(usrInp(11 downto  8)), ishft'length);
  mshft <= resize(unsigned(usrInp(15 downto 12)), mshft'length);
  decm  <= resize(unsigned(usrInp(23 downto 16)), decm'length );
  plldi <= usrInp(31);

  phavgwin <= unsigned(usrInp(47 downto 32));

  usrOut_i(15 downto  0)            <= std_logic_vector( freqm );
  usrOut_i(31 downto 16)            <= std_logic_vector( freq  );
  usrOut_i(47 downto 32)            <= std_logic_vector( phavg );
  usrOut_i(usrOut_i'left downto 48) <= (others => '0');

  P_PHASAVG : process ( txUsrClk_i ) is
    variable v : unsigned(phavgcnt'range);
  begin
    if ( rising_edge( txUsrClk_i ) ) then
       if ( phavgcnt = 0 ) then
          phavg    <= phavgrun;
          v        := (others => '0');
          phavgcnt <= phavgwin;
       else
          v        := phavgrun;
          phavgcnt <= phavgcnt - 1;
       end if;
       if ( txBufStatus(0) = '1' ) then
          v        := v + 1;
       end if;
       phavgrun <= v;
    end if;
  end process P_PHASAVG;

  -- for now - just wait...
  P_LOCKDET : process ( txUsrClk_i ) is
    variable l : std_logic;
  begin
    if ( rising_edge( txUsrClk_i ) ) then
      if ( txRst_i = '1' ) then
        piVcoRst      <= '1';
        pllLocked     <= '0';
      end if;
      if ( txRstDone = '1' ) then
        piVcoRst      <= '0';
      end if;
      if ( piVcoRst = '1' ) then
        pllLocked <= '0';
        filterCnt <= (others => '1');
      elsif ( filterCnt = 0 ) then
        pllLocked <= '1';
      else
        filterCnt <= filterCnt - 1;
      end if;
      if ( txBufStatus(1) = '1' ) then
        pllLocked <= '0';
      end if;
    end if;
  end process P_LOCKDET;

  pllFInc                   <= txBufStatus(0);

  P_PLL_EXT : process ( plldi, fmod, piVcoRst, ib ) is
  begin
    if ( plldi = '1' ) then
      pippmStepSize             <= ib.txpippmstepsize;
      pippmEn                   <= ib.txpippmen;
    else
      pippmStepSize(3 downto 0) <= "0001";
      pippmStepSize(4)          <= fmod(fmod'left);
      pippmEn                   <= not piVcoRst;
    end if;
  end process P_PLL_EXT;
  
  end generate G_PLL;

  G_NO_PLL : if ( not GEN_PLL_C ) generate
    pippmStepSize <= ib.txpippmstepsize;
    pippmEn       <= ib.txpippmen;
  end generate;

  B_SYNC : block is
    signal t2s_i : std_logic_vector(2 downto 0) := (others => '0');
    signal s2t_i : std_logic_vector(2 downto 0) := (others => '0');
    signal t2s_o : std_logic_vector(2 downto 0) := (others => '0');
    signal s2t_o : std_logic_vector(2 downto 0) := (others => '0');

    attribute ASYNC_REG of t2s_i : signal is "TRUE";
    attribute ASYNC_REG of s2t_i : signal is "TRUE";
    attribute ASYNC_REG of t2s_o : signal is "TRUE";
    attribute ASYNC_REG of s2t_o : signal is "TRUE";

  begin

    process ( txUsrClk_i ) is
    begin
      if ( rising_edge( txUsrClk_i ) ) then
         s2t_i      <= ib.usrInpSync & s2t_i(s2t_i'left downto 1);
         s2t_o      <= ib.usrOutAck  & s2t_o(s2t_o'left downto 1);

         usrInpSync <= s2t_i(0);
         if ( usrInpSync /= s2t_i(0) ) then
            usrInp <= ib.usrInp;
         end if;
         if ( usrOutSync = s2t_o(0) ) then
            usrOut     <= usrOut_i;
            usrOutSync <= not s2t_o(0);
         end if;
      end if;
    end process;

    process is
    begin
      if ( rising_edge( sys_clk ) ) then
         t2s_i <= s2t_i(0)   & t2s_i(t2s_i'left downto 1);
         t2s_o <= usrOutSync & t2s_o(t2s_o'left downto 1);
      end if;
    end process;

    ob.usrInpAck  <= t2s_i(0);
    ob.usrOutSync <= t2s_o(0);
    ob.usrOut     <= usrOut;

  end block B_SYNC;

end architecture structure;
