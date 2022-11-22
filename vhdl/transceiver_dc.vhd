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

use work.transceiver_pkg.all;

entity transceiver_dc is
  port (
    sys_clk         : in std_logic;   -- system bus clock

    recclk_out      : out std_logic;
    refclk_out      : out std_logic;

    event_clk       : in std_logic;   -- event clock input (phase shifted by DCM)
    
    -- Receiver side connections
    event_rxd       : out std_logic_vector(7 downto 0); -- RX event code output
    dbus_rxd        : out std_logic_vector(7 downto 0); -- RX distributed bus bits
    databuf_rxd     : out std_logic_vector(7 downto 0); -- RX data buffer data
    databuf_rx_k    : out std_logic; -- RX data buffer K-character
    databuf_rx_ena  : out std_logic; -- RX data buffer data enable
    databuf_rx_mode : in std_logic;  -- RX data buffer mode, must be '1'
				     -- enabled for delay compensation mode
    dc_mode         : in std_logic;  -- delay compensation mode enable when '1'
    
    rx_link_ok      : out   std_logic; -- RX link OK
    rx_violation    : out   std_logic; -- RX violation detected
    rx_clear_viol   : in    std_logic; -- Clear RX violation
    rx_beacon       : out   std_logic; -- Received DC beacon
    tx_beacon       : out   std_logic; -- Transmitted DC beacon
    rx_int_beacon   : out   std_logic; -- Received DC beacon after DC FIFO

    delay_inc       : in    std_logic; -- Insert extra event in FIFO
    delay_dec       : in    std_logic; -- Drop event from FIFO
                                       -- These two control signals are used
				       -- only during the initial phase of
				       -- delay compensation adjustment
    
    reset           : in    std_logic; -- Transceiver reset

    -- Transmitter side connections
    event_txd       : in  std_logic_vector(7 downto 0); -- TX event code
    tx_event_ena    : out std_logic; -- 1 when event is sent out
                                     -- With backward events the beacon event
                                     -- has highest priority
    dbus_txd        : in  std_logic_vector(7 downto 0); -- TX distributed bus data
    databuf_txd     : in  std_logic_vector(7 downto 0); -- TX data buffer data
    databuf_tx_k    : in  std_logic; -- TX data buffer K-character
    databuf_tx_ena  : out std_logic; -- TX data buffer data enable
    databuf_tx_mode : in  std_logic; -- TX data buffer mode enabled when '1'

    -- MGT
    mgtIb           : in  transceiver_ob_type;
    mgtOb           : out transceiver_ib_type
    );
end transceiver_dc;

architecture structure of transceiver_dc is

  signal vcc     : std_logic  := '1';
  signal gnd     : std_logic  := '0';
  signal gnd_vec : std_logic_vector(31 downto 0) := (others => '0');
  signal tied_to_ground_i     :   std_logic      := '0';
  signal tied_to_ground_vec_i :   std_logic_vector(63 downto 0) := (others => '0');
  signal tied_to_vcc_i        :   std_logic := '1';

  signal rx_beacon_i   : std_logic;
  signal rxcdrreset    : std_logic;

  signal rx_gtreset_i   : std_logic;
  signal rx_gtresetting : std_logic := '0';
  signal tx_gtreset_i  : std_logic;
  signal tx_usrrdy_i   : std_logic;
  signal rx_usrrdy_i   : std_logic;
  signal cpll_reset_i  : std_logic;

  signal link_ok         : std_logic;
  signal align_error     : std_logic;
  signal rx_error        : std_logic;
  signal rx_int_beacon_i : std_logic;
  signal rx_vio_usrclk   : std_logic;
  
  signal rx_link_ok_i    : std_logic;
  signal rx_error_i      : std_logic;
 
  signal rx_powerdown   : std_logic;
  signal tx_powerdown   : std_logic;

  signal databuf_rxd_i : std_logic_vector(7 downto 0);
  signal databuf_rx_k_i    : std_logic;

  signal fifo_do       : std_logic_vector(63 downto 0);
  signal fifo_dop      : std_logic_vector(7 downto 0);
  signal fifo_rden     : std_logic;
  signal fifo_rst      : std_logic;
  signal fifo_wren     : std_logic;
  signal fifo_di       : std_logic_vector(63 downto 0);
  signal fifo_dip      : std_logic_vector(7 downto 0);

  signal tx_fifo_do    : std_logic_vector(31 downto 0);
  signal tx_fifo_dop   : std_logic_vector(3 downto 0);
  signal tx_fifo_rden  : std_logic;
  signal tx_fifo_rderr : std_logic;
  signal tx_fifo_empty : std_logic;
  signal tx_fifo_rst   : std_logic;
  signal tx_fifo_wren  : std_logic;
  signal tx_fifo_di    : std_logic_vector(31 downto 0);
  signal tx_fifo_dip   : std_logic_vector(3 downto 0);

  signal tx_event_ena_i : std_logic;
  
  -- TX Datapath signals

  signal phase_acc    : std_logic_vector(6 downto 0);
  signal phase_acc_en : std_logic := '0';
  signal TRIG0 : std_logic_vector(255 downto 0);

    -- MGT interface

  signal cpll_locked     :  std_logic;

  signal rx_resetdone    :  std_logic;

  signal rx_recclk       :  std_logic;
  signal rx_cdrlocked    :  std_logic;
  signal rx_charisk      :  std_logic_vector(1 downto 0);
  signal rx_data         :  std_logic_vector(15 downto 0);
  signal rx_disperr      :  std_logic_vector(1 downto 0);
  signal rx_notintable   :  std_logic_vector(1 downto 0);

  signal tx_usrclk       :  std_logic;

  signal tx_data         :  std_logic_vector(15 downto 0);
  signal tx_charisk      :  std_logic_vector( 1 downto 0);
  signal tx_bufstatus    :  std_logic_vector(1 downto 0);

  signal drpclk          :  std_logic;
  signal drpaddr         :  std_logic_vector(8 downto 0)  := (others => '0');
  signal drpdi           :  std_logic_vector(15 downto 0) := (others => '0');
  signal drpdo           :  std_logic_vector(15 downto 0);
  signal drpen           :  std_logic := '0';
  signal drpwe           :  std_logic := '0';
  signal drprdy          :  std_logic;

  COMPONENT ila_0
    PORT (
      clk : IN STD_LOGIC;
      probe0 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      probe1 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      probe2 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      probe3 : IN STD_LOGIC_VECTOR(63 DOWNTO 0)
      );
  END COMPONENT;

begin

  -- ILA debug core
  G_ILA : if ( false ) generate
  begin
  i_ila : ila_0
    port map (
      CLK => tx_usrclk,
      probe0 => TRIG0( 63 downto   0),
      probe1 => TRIG0(127 downto  64),
      probe2 => TRIG0(191 downto 128),
      probe3 => TRIG0(255 downto 192)
    );
  end generate G_ILA;
      
  i_dc_fifo : FIFO36E1
    generic map (
      ALMOST_EMPTY_OFFSET => X"0080",
      ALMOST_FULL_OFFSET => X"0080",
      DATA_WIDTH => 36,
      DO_REG => 1,
      EN_SYN => FALSE,
      FIFO_MODE => "FIFO36",
      FIRST_WORD_FALL_THROUGH => FALSE,
      INIT => X"000000000",
      SIM_DEVICE => "7SERIES",
      SRVAL => X"000000000")
    port map (
      DO => fifo_do,
      DOP => fifo_dop,
      ECCPARITY => open,
      ALMOSTEMPTY => open,
      ALMOSTFULL => open,
      DBITERR => open,
      SBITERR => open,
      EMPTY => open,
      FULL => open,
      RDCOUNT => open,
      RDERR => open,
      WRCOUNT => open,
      WRERR => open,
      RDCLK => event_clk,
      RDEN => fifo_rden,
      REGCE => vcc,
      RST => fifo_rst,
      RSTREG => gnd,
      WRCLK => rx_recclk,
      WREN => fifo_wren,
      DI => fifo_di,
      DIP => fifo_dip,
      INJECTDBITERR => gnd,
      INJECTSBITERR => gnd);
  
  i_txfifo : FIFO18E1
    generic map (
      ALMOST_EMPTY_OFFSET => X"0080",
      ALMOST_FULL_OFFSET => X"0080",
      DATA_WIDTH => 9,
      DO_REG => 1,
      EN_SYN => FALSE,
      FIFO_MODE => "FIFO18",
      FIRST_WORD_FALL_THROUGH => FALSE,
      INIT => X"000000000",
      SIM_DEVICE => "7SERIES",
      SRVAL => X"000000000")
    port map (
      DO => tx_fifo_do,
      DOP => tx_fifo_dop,
      ALMOSTEMPTY => open,
      ALMOSTFULL => open,
      EMPTY => tx_fifo_empty,
      FULL => open,
      RDCOUNT => open,
      RDERR => tx_fifo_rderr,
      WRCOUNT => open,
      WRERR => open,
      RDCLK => tx_usrclk,
      RDEN => tx_fifo_rden,
      REGCE => vcc,
      RST => tx_fifo_rst,
      RSTREG => gnd,
      WRCLK => tx_usrclk,
      WREN => tx_fifo_wren,
      DI => tx_fifo_di,
      DIP => tx_fifo_dip);

  mgtOb.mgtreset   <= reset;
  
  mgtOb.cpll_reset <= cpll_reset_i;
  cpll_locked      <= mgtIb.cpll_locked;

  drpclk           <= mgtIb.drpclk;
  mgtOb.drpaddr    <= drpaddr;
  mgtOb.drpdi      <= drpdi;
  drpdo            <= mgtIb.drpdo;
  mgtOb.drpen      <= drpen;
  mgtOb.drpwe      <= drpwe;
  drprdy           <= mgtIb.drprdy;

  mgtOb.gtrxreset  <= rx_gtreset_i;
  mgtOb.rxusrrdy   <= rx_usrrdy_i;

  rx_data          <= mgtIb.rxdata;
  rx_charisk       <= mgtIb.rxcharisk;
  rx_disperr       <= mgtIb.rxdisperr;
  rx_notintable    <= mgtIb.rxnotintable;
  rx_cdrlocked     <= mgtIb.rxcdrlocked;
  rx_resetdone     <= mgtIb.rxresetdone;
  rx_recclk        <= mgtIb.rxrecclk;

  mgtOb.gttxreset  <= tx_gtreset_i;
  mgtOb.txusrrdy   <= tx_usrrdy_i;
  mgtOb.txdata     <= tx_data;
  mgtOb.txcharisk  <= tx_charisk;
  tx_bufstatus     <= mgtIb.txbufstatus;
  tx_usrclk        <= mgtIb.txrefclk;
  mgtOb.txusrclk   <= tx_usrclk;

  recclk_out       <= rx_recclk;
  refclk_out       <= tx_usrclk;

  rx_powerdown     <= '0';
  tx_powerdown     <= '0';

  fifo_di(63 downto 16) <= (others => '0');
  fifo_di(15 downto 0) <= rx_data;
  fifo_dip(7 downto 4) <= (others => '0');
  fifo_dip(2) <= '0';
  fifo_dip(1 downto 0) <= rx_charisk;

  rx_beacon <= rx_beacon_i;
  rx_int_beacon <= rx_int_beacon_i;
  rx_int_beacon_i <= fifo_dop(3);
  fifo_dip(3) <= rx_beacon_i;

  receive_error_detect : process (rx_recclk, rx_data, rx_charisk,
				  rx_disperr, rx_notintable)
    variable beacon_cnt : std_logic_vector(2 downto 0) := "000";
    variable cnt : std_logic_vector(12 downto 0);
  begin
    if rising_edge(rx_recclk) then
      rx_error <= '0';
      if (rx_charisk(0) = '1' and rx_data(7) = '1') or
        rx_disperr /= "00" or rx_notintable /= "00" then
        rx_error <= '1';
      end if;
      if beacon_cnt(beacon_cnt'high) = '1' then
        beacon_cnt := beacon_cnt - 1;
      end if;
      if link_ok = '1' and rx_charisk(1) = '0' and rx_data(15 downto 8) = C_EVENT_BEACON then
        beacon_cnt := "111";
      end if;
      rx_beacon_i <= beacon_cnt(beacon_cnt'high);
      if dc_mode = '0' then
        rx_beacon_i <= cnt(cnt'high);
      end if;
      if cnt(cnt'high) = '1' then
        cnt(cnt'high) := '0';
      end if;
      cnt := cnt + 1;
    end if;
  end process;

  link_ok_detection : process (tx_usrclk, link_ok, reset, rx_error_i, rx_link_ok_i)
    variable link_ok_delay : std_logic_vector(19 downto 0) := (others => '0');
  begin
    rx_link_ok <= rx_link_ok_i;
    rx_link_ok_i <= link_ok_delay(link_ok_delay'high);
    if rising_edge(tx_usrclk) then
      if link_ok_delay(link_ok_delay'high) = '0' then
        link_ok_delay := link_ok_delay + 1;
      end if;
      if reset = '1' or link_ok = '0' or rx_error_i = '1' then
        link_ok_delay := (others => '0');
      end if;
    end if;
  end process;

  link_status_testing : process (tx_usrclk, reset, rx_charisk, link_ok,
				 rx_disperr, cpll_locked)
    variable prescaler : std_logic_vector(14 downto 0);
    variable count : std_logic_vector(3 downto 0);
    variable rx_error_sync : std_logic;
    variable rx_error_sync_1 : std_logic;
    variable loss_lock : std_logic;
    variable rx_error_count : std_logic_vector(5 downto 0);
    variable reset_sync : std_logic_vector(1 downto 0);
  begin
    TRIG0(58 downto 53) <= rx_error_count;
    TRIG0(59) <= loss_lock;
    TRIG0(60) <= rx_error_sync;
    TRIG0(78 downto 64) <= prescaler;
    TRIG0(82 downto 79) <= count;
    
    if rising_edge(tx_usrclk) then
      rxcdrreset <= '0';
      if rx_gtresetting = '0' then
        if prescaler(prescaler'high) = '1' then
          link_ok <= '0';
          if count = "0000" then
            link_ok <= '1';
          end if;
      
          if count = "1111" then
            rxcdrreset <= '1';
          end if;

          if count(count'high) = '1' then
            rx_error_count := "011111";
          end if;
          
          if count /= "0000" then
            count := count - 1;
          end if;
        end if;

        if count = "0000" then
          if loss_lock = '1' then
            count := "1111";
          end if;
        end if;

	loss_lock := rx_error_count(5);

        if rx_error_sync = '1' then
          if rx_error_count(5) = '0' then
            rx_error_count := rx_error_count - 1;
          end if;
        else
          if prescaler(prescaler'high) = '1' and
            (rx_error_count(5) = '1' or rx_error_count(4) = '0') then
            rx_error_count := rx_error_count + 1;
          end if;
        end if;
	
        if prescaler(prescaler'high) = '1' then
          prescaler := "011111111111111";
        else
          prescaler := prescaler - 1;
        end if;
      end if;

      rx_error_i <= rx_error_sync_1;
      rx_error_sync := rx_error_sync_1;
      rx_error_sync_1 := rx_error;
      
      if reset_sync(0) = '1' then
        count := "1111";
      end if;

      -- Synchronize asynchronous resets
      reset_sync(0) := reset_sync(1);
      reset_sync(1) := '0';
      if (reset = '1' or cpll_locked = '0') and ( rx_gtresetting = '0' ) then
        reset_sync(1) := '1';
      end if;
    end if;
  end process;

  reg_dbus_data : process (event_clk, rx_link_ok_i, rx_data, databuf_rxd_i, databuf_rx_k_i)
    variable even : std_logic;
  begin
    databuf_rxd <= databuf_rxd_i;
    databuf_rx_k <= databuf_rx_k_i;
    if rising_edge(event_clk) then
      if databuf_rx_mode = '0' or even = '0' then
	dbus_rxd <= fifo_do(7 downto 0);
      end if;
      if databuf_rx_mode = '1' then
	if even = '1' then
	  databuf_rxd_i <= fifo_do(7 downto 0);
	  databuf_rx_k_i <= fifo_dop(0);
	end if;
      else
	databuf_rxd_i <= (others => '0');
	databuf_rx_k_i <= '0';
      end if;

      databuf_rx_ena <= even;
      
      if rx_link_ok_i = '0' then
	databuf_rxd_i <= (others => '0');
	databuf_rx_k_i <= '0';
	dbus_rxd <= (others => '0');
      end if;

      even := not even;
      event_rxd <= fifo_do(15 downto 8);
      if rx_link_ok_i = '0' or fifo_dop(1) = '1' or
	reset = '1' then
	event_rxd <= (others => '0');
	even := '0';
      end if;
    end if;
  end process;

  rx_data_align_detect : process (rx_recclk, reset, rx_charisk, rx_data,
				  rx_clear_viol)
  begin
    if reset = '1' or rx_clear_viol = '1' then
      align_error <= '0';
    elsif rising_edge(rx_recclk) then
      align_error <= '0';
      if rx_charisk(0) = '1' and rx_data(7) = '1' then
	align_error <= '1';
      end if;
    end if;
  end process;

  violation_flag : process (sys_clk, rx_clear_viol, rx_link_ok_i, rx_vio_usrclk)
    variable vio : std_logic;
  begin
    if rising_edge(sys_clk) then
      if rx_clear_viol = '1' then
        rx_violation <= '0';
      end if;
      if vio = '1' or rx_link_ok_i = '0' then
        rx_violation <= '1';
      end if;
      vio := rx_vio_usrclk;
    end if;
  end process;
  
  violation_detect : process (rx_recclk, rx_clear_viol,
			      rx_disperr, rx_notintable, link_ok)
    variable clrvio : std_logic;
  begin
    if rising_edge(rx_recclk) then
      if rx_disperr /= "00" or
        rx_notintable /= "00" then
	rx_vio_usrclk <= '1';
      elsif clrvio = '1' then
        rx_vio_usrclk <= '0';
      end if;

      clrvio := rx_clear_viol;
    end if;
  end process;

  TRIG0(15 downto 0) <= rx_data;
  TRIG0(17 downto 16) <= rx_charisk;
  TRIG0(19 downto 18) <= rx_disperr;
  TRIG0(          20) <= cpll_locked;
  TRIG0(          21) <= fifo_wren;
  TRIG0(23 downto 22) <= rx_notintable;
  TRIG0(24) <= link_ok;
  TRIG0(25) <= cpll_reset_i;
  TRIG0(26) <= tx_gtreset_i;
  TRIG0(27) <= tx_usrrdy_i;
  TRIG0(28) <= rx_gtreset_i;
  TRIG0(29) <= rx_usrrdy_i;
  TRIG0(30) <= rx_gtresetting;
  TRIG0(31) <= '0';
  TRIG0(47 downto 32) <= tx_data;
  TRIG0(49 downto 48) <= tx_charisk;
  TRIG0(50) <= rx_error;
  TRIG0(51) <= rxcdrreset;
  TRIG0(52) <= align_error;
  TRIG0(63 downto 61) <= (others => '0');
  TRIG0(90 downto 83) <= databuf_rxd_i;
  TRIG0(91) <= databuf_rx_k_i;
  TRIG0(92) <= rx_cdrlocked;
  TRIG0(93) <= reset;
  TRIG0(94) <= rx_resetdone;
  TRIG0(116 downto 95) <= (others => '0');
  TRIG0(117) <= databuf_tx_mode;
  TRIG0(119) <= databuf_tx_k;
  TRIG0(127 downto 120) <= databuf_txd;
  TRIG0(143 downto 128) <= fifo_do(15 downto 0);
  TRIG0(147 downto 144) <= fifo_dop(3 downto 0);
  TRIG0(148) <= fifo_rden;
  TRIG0(156 downto 149) <= tx_fifo_do(7 downto 0);
  TRIG0(164 downto 157) <= tx_fifo_di(7 downto 0);
  TRIG0(165) <= tx_fifo_wren;
  TRIG0(166) <= tx_fifo_rden;
  TRIG0(167) <= tx_fifo_empty;
  TRIG0(168) <= tx_event_ena_i;
  TRIG0(250 downto 173) <= (others => '0');

  process (rx_recclk)
    variable toggle : std_logic := '0';
  begin
    TRIG0(169) <= toggle;
    if rising_edge(rx_recclk) then
      toggle := not toggle;
    end if;
  end process;
  
  -- Scalers for clocks for debugging purposes to see which clocks
  -- are running using the ILA core
  
  process (tx_usrclk, reset)
    variable cnt : std_logic_vector(2 downto 0);
  begin
    TRIG0(255) <= cnt(cnt'high);
    if rising_edge(tx_usrclk) then
      cnt := cnt + 1;
      if reset = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (sys_clk, reset)
    variable cnt : std_logic_vector(2 downto 0);
  begin
    TRIG0(254) <= cnt(cnt'high);
    if rising_edge(sys_clk) then
      cnt := cnt + 1;
      if reset = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (event_clk, reset)
    variable cnt : std_logic_vector(2 downto 0);
  begin
    TRIG0(253) <= cnt(cnt'high);
    if rising_edge(event_clk) then
      cnt := cnt + 1;
      if reset = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (rx_recclk, reset)
    variable cnt : std_logic_vector(2 downto 0);
  begin
    TRIG0(252) <= cnt(cnt'high);
    if rising_edge(rx_recclk) then
      cnt := cnt + 1;
      if reset = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (tx_usrclk, reset)
    variable cnt : std_logic_vector(2 downto 0);
  begin
    TRIG0(251) <= cnt(cnt'high);
    if rising_edge(tx_usrclk) then
      cnt := cnt + 1;
      if reset = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  cpll_resetting: process (sys_clk, reset)
    variable cnt : std_logic_vector(25 downto 0) := (others => '1');
  begin
    if rising_edge(sys_clk) then
      cpll_reset_i <= cnt(cnt'high);
      if cnt(cnt'high) = '1' then
        cnt := cnt - 1;
        tx_gtreset_i <= '1';
        tx_usrrdy_i <= '0';
      end if;
      if reset = '1' then
        cnt := (others => '1');
      end if;
      if cpll_locked = '1' then
        tx_gtreset_i <= '0';
        tx_usrrdy_i <= '1';
      end if;
    end if;
  end process;
  
  rx_resetting: process (tx_usrclk, rxcdrreset)
    variable cnt : std_logic_vector(25 downto 0) := (others => '1');
  begin
    if rising_edge(tx_usrclk) then
      rx_gtreset_i <= cnt(cnt'high);
      if ( cnt(cnt'high) = '1' ) then
        rx_gtresetting <= '1';
      elsif ( rx_resetdone = '1' ) then
        rx_gtresetting <= '0';
      end if;
      rx_usrrdy_i <= not cnt(cnt'high);
      if cnt(cnt'high) = '1' then
        cnt := cnt - 1;
      end if;
      if rxcdrreset = '1' then
        cnt := (others => '1');
      end if;
    end if;
  end process;

  transmit_data : process (tx_usrclk, tx_fifo_do, tx_fifo_empty, dbus_txd,
                           databuf_txd, databuf_tx_k, databuf_tx_mode, dc_mode,
                           reset, tx_event_ena_i)
    variable even       : std_logic_vector(1 downto 0) := "00";
    variable beacon_cnt : std_logic_vector(3 downto 0) := "0000"; 
    variable fifo_pend  : std_logic;
  begin
    tx_event_ena <= tx_event_ena_i;
    tx_event_ena_i <= '1';
    tx_fifo_rden <= '1';
    if beacon_cnt(1 downto 0) = "10" and dc_mode = '1' then
      tx_event_ena_i <= '0';
      if tx_fifo_empty = '0' then
        tx_fifo_rden <= '0';
      end if;
    end if;
    if rising_edge(tx_usrclk) then
      tx_charisk <= "00";
      tx_data(15 downto 8) <= (others => '0');
      tx_beacon <= beacon_cnt(1);
      if beacon_cnt(1 downto 0) = "10" and dc_mode = '1' then
	tx_data(15 downto 8) <= C_EVENT_BEACON; -- Beacon event
      elsif tx_fifo_rderr = '0' then
        tx_data(15 downto 8) <= tx_fifo_do(7 downto 0);
        fifo_pend := '0';
      elsif even = "00" then
	tx_charisk <= "10";
	tx_data(15 downto 8) <= X"BC"; -- K28.5 character
      end if;

      if tx_fifo_empty = '0' then
        fifo_pend := '1';
      end if;

      tx_data(7 downto 0) <= dbus_txd;
      if even(0) = '0' and databuf_tx_mode = '1' then
	tx_data(7 downto 0) <= databuf_txd;
	tx_charisk(0) <= databuf_tx_k;
      end if;
      databuf_tx_ena <= even(0);
      TRIG0(118) <= even(0);
      even := even + 1;
      beacon_cnt := rx_beacon_i & beacon_cnt(beacon_cnt'high downto 1);
      if reset = '1' then
        fifo_pend := '0';
      end if;
    end if;
  end process;

  -- Read and write enables are used to adjust the coarse delay
  -- These can cause data packet corruption and missing events -
  -- thus this method is used only during link training
  
  fifo_read_enable : process (event_clk, delay_inc)
    variable sr_delay_trig : std_logic_vector(2 downto 0) := "000";
  begin
    if rising_edge(event_clk) then
      fifo_rden <= '1';
      if sr_delay_trig(1 downto 0) = "10" then
        fifo_rden <= '0';
      end if;
      sr_delay_trig := delay_inc & sr_delay_trig(2 downto 1);
    end if;
  end process;
  
  fifo_write_enable : process (rx_recclk, delay_dec)
    variable sr_delay_trig : std_logic_vector(2 downto 0) := "000";
  begin
    if rising_edge(rx_recclk) then
      fifo_wren <= '1';
      if sr_delay_trig(1 downto 0) = "10" then
        fifo_wren <= '0';
      end if;
      sr_delay_trig := delay_dec & sr_delay_trig(2 downto 1);
    end if;
  end process;

  fifo_rst <= not link_ok;

  tx_fifo_writing : process (tx_usrclk, event_txd)
  begin
    tx_fifo_di <= (others => '0');
    tx_fifo_di(7 downto 0) <= event_txd;
    tx_fifo_wren <= '0';
    if event_txd /= X"00" then
      tx_fifo_wren <= '1';
    end if;
  end process;
  
  tx_fifo_dip <= (others => '0');
  tx_fifo_rst <= reset;
  
  process (tx_usrclk, reset, tx_bufstatus, tx_usrrdy_i)
    type state is (init, init_delay, acq_bufstate, deldec, delinc, locked);
    variable ph_state : state;
    variable phase       : std_logic_vector(6 downto 0);
    variable cnt      : std_logic_vector(19 downto 0);
    variable halffull : std_logic;
  begin
    TRIG0(172 downto 170) <= conv_std_logic_vector( state'pos( ph_state ), 3 );
    if rising_edge(tx_usrclk) then
      if (ph_state = acq_bufstate) or
        (ph_state = delinc) or
        (ph_state = deldec) then
        if tx_bufstatus(0) = '1' then
          halffull := '1';
        end if;
      end if;

      if cnt(cnt'high) = '1' then
        case ph_state is
          when init =>
            if reset = '0' and mgtIb.txdlyadjen = '1' then
              ph_state := init_delay;
            end if;
          when init_delay =>
            halffull := '0';
            ph_state := acq_bufstate;
          when acq_bufstate =>
            if halffull = '0' then
              ph_state := delinc;
            else
              ph_state := deldec;
            end if;
            halffull := '0';
          when deldec =>
            if halffull = '1' then
              phase := phase - 1;
            else
              ph_state := delinc;
            end if;
            halffull := '0';
            phase_acc_en <= not phase_acc_en;
          when delinc =>
            if halffull = '0' then
              phase := phase + 1;
            else
              ph_state := locked;
            end if;
            halffull := '0';
            phase_acc_en <= not phase_acc_en;
          when others =>
        end case;
        phase_acc <= phase;
        cnt := (others => '0');
      else
        cnt := cnt + 1;
      end if;
      if reset = '1' or tx_usrrdy_i = '0' then
        ph_state := init;
        phase := (others => '0');
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (drpclk, phase_acc, phase_acc_en, reset)
    type state is (idle, a64_0, a64_1, a64_2, a9f_0, a9f_1, a9f_2, a9f_3, a9f_4, a9f_5);
    variable drp_state, next_state : state;
    variable rdy_wait : std_logic;
    variable phase_acc_en_sync : std_logic_vector(3 downto 0) := (others => '0');
    variable phase_acc_en_i    : std_logic;
  begin
    if rising_edge(drpclk) then
      rdy_wait := '0';
      -- synchronize 'phase_acc_en' into drpclock domain. The 'sender' negates the bit and we
      -- look for a change in the synchronized bit. This allows for both clocks having different
      -- frequencies and yet propagating a single trigger (as long as the trigger-frequency is
      -- much lower than the lowest clock).
      phase_acc_en_sync := phase_acc_en_sync(phase_acc_en_sync'left - 1 downto 0) & phase_acc_en;
      phase_acc_en_i    := phase_acc_en_sync(phase_acc_en_sync'left) xor phase_acc_en_sync(phase_acc_en_sync'left - 1);
      case drp_state is
        when a64_0 =>
          drpaddr <= '0' & X"64";
          drpdi <= X"00" & '0' & phase_acc;
          drpen <= '0';
          drpwe <= '0';
          next_state := a64_1;
        when a64_1 =>
          drpaddr <= '0' & X"64";
          drpdi <= X"00" & '0' & phase_acc;
          drpen <= '1';
          drpwe <= '1';
          next_state := a64_2;
        when a64_2 =>
          drpaddr <= '0' & X"64";
          drpdi <= X"00" & '0' & phase_acc;
          drpen <= '0';
          drpwe <= '0';
          next_state := a9f_0;
          rdy_wait := '1';
        when a9f_0 =>
          drpaddr <= '0' & X"9F";
          drpdi <= X"0035";
          drpen <= '0';
          drpwe <= '0';
          next_state := a9f_1;
        when a9f_1 =>
          drpaddr <= '0' & X"9F";
          drpdi <= X"0035";
          drpen <= '1';
          drpwe <= '1';
          next_state := a9f_2;
        when a9f_2 =>
          drpaddr <= '0' & X"9F";
          drpdi <= X"0035";
          drpen <= '0';
          drpwe <= '0';
          rdy_wait := '1';
          next_state := a9f_3;
        when a9f_3 =>
          drpaddr <= '0' & X"9F";
          drpdi <= X"0034";
          drpen <= '0';
          drpwe <= '0';
          next_state := a9f_4;
        when a9f_4 =>
          drpaddr <= '0' & X"9F";
          drpdi <= X"0034";
          drpen <= '1';
          drpwe <= '1';
          next_state := a9f_5;
        when a9f_5 =>
          drpaddr <= '0' & X"9F";
          drpdi <= X"0034";
          drpen <= '0';
          drpwe <= '0';
          rdy_wait := '1';
          next_state := idle;
        when others =>
          drpaddr <= '0' & X"64";
          drpdi <= X"00" & '0' & phase_acc;
          drpen <= '0';
          drpwe <= '0';
          next_state := idle;
          rdy_wait := '0';
      end case;
      if rdy_wait = '0' or drprdy = '1' then
        if drp_state = idle and phase_acc_en_i = '1' then
          next_state := a64_0;
        end if;
        drp_state := next_state;
      end if;
      if reset = '1' then
        drp_state := idle;
        rdy_wait := '0';
      end if;
    end if;
  end process;

end structure;
