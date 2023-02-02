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

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity transceiver_dc is
  generic
    (
      MARK_DEBUG_ENABLE            : string    := "FALSE"
      );
  port (
    sys_clk         : in std_logic;   -- system bus clock
    REFCLK_RST      : out std_logic;
    recclk_rst      : out std_logic;

    event_clk       : in std_logic;   -- event clock input (phase shifted by DCM)
    event_clk_rst   : in std_logic;   -- event clock input (phase shifted by DCM)
    
    -- Receiver side connections
    event_rxd       : out std_logic_vector(7 downto 0); -- RX event code output
    dbus_rxd        : out std_logic_vector(7 downto 0); -- RX distributed bus bits
    databuf_rxd     : out std_logic_vector(7 downto 0); -- RX data buffer data
    databuf_rx_k    : out std_logic; -- RX data buffer K-character
    databuf_rx_ena  : out std_logic; -- RX data buffer data enable
    databuf_rx_mode : in std_logic;  -- RX data buffer mode, must be '1'
				     -- enabled for delay compensation mode
    dc_mode         : in std_logic;  -- delay compensation mode enable when '1'
    
    rx_link_ok      : out   std_logic; -- RX link OK (REFCLK (txusrclk) domain)
    rx_violation    : out   std_logic; -- RX violation detected (sys_clk domain)
    rx_clear_viol   : in    std_logic; -- Clear RX violation (sys_clk domain)
    rx_beacon       : out   std_logic; -- Received DC beacon (recclk (rxusrclk) domain)
    tx_beacon       : out   std_logic; -- Transmitted DC beacon (REFCLK (txusrclk) domain)
    rx_int_beacon   : out   std_logic; -- Received DC beacon after DC FIFO (event_clk domain)

    delay_inc       : in    std_logic; -- Insert extra event in FIFO (async)
    delay_dec       : in    std_logic; -- Drop event from FIFO (async)
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

    -- Transceiver connections
    transceiverIb   : out EvrTransceiverIbType;
    transceiverOb   : in  EvrTransceiverObType
    );

  attribute MARK_DEBUG of databuf_tx_mode : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of databuf_tx_k : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of databuf_txd : signal is MARK_DEBUG_ENABLE;

end transceiver_dc;

architecture structure of transceiver_dc is

  attribute ASYNC_REG         : string;

  signal evr_cdcsync_reset_txusrclk  : std_logic_vector(1 downto 0) := (others => '0');
  signal evr_cdcsync_reset_rxusrclk  : std_logic_vector(1 downto 0) := (others => '0');
  signal evr_cdcsync_reset_drpclk    : std_logic_vector(1 downto 0) := (others => '0');

  attribute ASYNC_REG of evr_cdcsync_reset_txusrclk  : signal is "TRUE";
  attribute ASYNC_REG of evr_cdcsync_reset_rxusrclk  : signal is "TRUE";
  attribute ASYNC_REG of evr_cdcsync_reset_drpclk    : signal is "TRUE";

  signal vcc     : std_logic;
  signal gnd     : std_logic;
  signal gnd_vec : std_logic_vector(31 downto 0);
  signal tied_to_ground_i     :   std_logic;
  signal tied_to_ground_vec_i :   std_logic_vector(63 downto 0);
  signal tied_to_vcc_i        :   std_logic;

  signal refclk        : std_logic;
  
  signal rx_charisk    : std_logic_vector(1 downto 0);
  signal rx_data       : std_logic_vector(15 downto 0);
  signal rx_disperr    : std_logic_vector(1 downto 0);
  signal rx_notintable : std_logic_vector(1 downto 0);
  signal rx_beacon_i   : std_logic;
  signal rxusrclk      : std_logic;
  signal txusrclk      : std_logic;
  signal rxcdrreset    : std_logic;

  signal rx_gtresetting : std_logic := '0';

  signal link_ok         : std_logic;
  signal link_ok_rxusr   : std_logic;
  signal align_error     : std_logic;
  signal rx_error        : std_logic;
  signal rx_int_beacon_i : std_logic;
  signal rx_vio_usrclk   : std_logic;
  signal rx_clear_viol_usrclk   : std_logic;
  
  signal rx_link_ok_i    : std_logic;
  signal rx_error_i      : std_logic;
  
  signal tx_charisk    : std_logic_vector(1 downto 0);
  signal tx_data       : std_logic_vector(15 downto 0);

  signal rx_powerdown   : std_logic;
  signal tx_powerdown   : std_logic;

  signal databuf_rxd_i : std_logic_vector(7 downto 0);
  signal databuf_rx_k_i    : std_logic;

  signal fifo_do_i     : std_logic_vector(63 downto 0);
  signal fifo_dop_i    : std_logic_vector(7 downto 0);
  signal fifo_do       : std_logic_vector(15 downto 0);
  signal fifo_dop      : std_logic_vector(3 downto 0);
  signal fifo_rden     : std_logic;
  signal fifo_rst      : std_logic;
  signal fifo_wren     : std_logic;
  signal fifo_di       : std_logic_vector(63 downto 0);
  signal fifo_dip      : std_logic_vector(7 downto 0);

  signal rx_resetdone  : std_logic;

  signal tx_fifo_do_i  : std_logic_vector(31 downto 0);
  signal rx_resetdone  : std_logic;

  signal tx_fifo_do    : std_logic_vector( 7 downto 0);
  signal tx_fifo_dop   : std_logic_vector(3 downto 0);
  signal tx_fifo_rden  : std_logic;
  signal tx_fifo_rderr : std_logic;
  signal tx_fifo_empty : std_logic;
  signal tx_fifo_rst   : std_logic;
  signal tx_fifo_wren  : std_logic;
  signal tx_fifo_di_i  : std_logic_vector(31 downto 0);
  signal tx_fifo_di    : std_logic_vector( 7 downto 0);
  signal tx_fifo_dip   : std_logic_vector(3 downto 0);

  signal tx_event_ena_i : std_logic;
  
  -- TX Datapath signals
  signal txbufstatus_i                    :   std_logic_vector(1 downto 0);  

  signal phase_acc    : std_logic_vector(6 downto 0);
  signal phase_acc_en : std_logic;
  signal drpclk  : std_logic;
  signal drpaddr : std_logic_vector(8 downto 0);
  signal drpdi   : std_logic_vector(15 downto 0);
  signal drpdo   : std_logic_vector(15 downto 0);
  signal drpen   : std_logic;
  signal drpwe   : std_logic;
  signal drprdy  : std_logic;
  signal drpbsy  : std_logic;
  signal useDrpDlyAdj : TxDelayAdjType;

  signal CPLLRESET_in : std_logic;
  signal CPLLLOCK_out : std_logic;
  signal GTRXRESET_in : std_logic;
  signal GTTXRESET_in : std_logic;
  signal RXUSERRDY_in : std_logic;
  signal TXUSERRDY_in : std_logic;

  attribute MARK_DEBUG of rx_data : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_charisk : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_disperr : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_notintable : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of link_ok : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of CPLLRESET_in : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of GTTXRESET_in : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of TXUSERRDY_in : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of GTRXRESET_in : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of RXUSERRDY_in : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_data : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_charisk : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_error : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rxcdrreset : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of align_error : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of databuf_rxd_i : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of databuf_rx_k_i : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of fifo_do : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of fifo_dop : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of fifo_rden : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_fifo_do : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_fifo_di : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_fifo_wren : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_fifo_rden : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_fifo_empty : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of tx_event_ena_i : signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_error_i : signal is MARK_DEBUG_ENABLE;

begin

  process ( txusrclk ) is
  begin
    if ( rising_edge( txusrclk ) ) then
       evr_cdcsync_reset_txusrclk <= shiftl( evr_cdcsync_reset_txusrclk, reset );
    end if;
  end process;

  process ( rxusrclk ) is
  begin
    if ( rising_edge( rxusrclk ) ) then
       evr_cdcsync_reset_rxusrclk <= shiftl( evr_cdcsync_reset_rxusrclk, reset );
    end if;
  end process;

  process ( drpclk ) is
  begin
    if ( rising_edge( drpclk ) ) then
       evr_cdcsync_reset_drpclk <= shiftl( evr_cdcsync_reset_drpclk, (reset or not TXUSERRDY_in) );
    end if;
  end process;

  CPLLLOCK_out                     <= transceiverOb.cpll_locked;

  P_ASSIGN : process (
    tx_data,
    tx_charisk,
    drpaddr,
    drpdi,
    drpen,
    drpwe,
    sys_clk,
    reset,
    GTRXRESET_in,
    GTTXRESET_in,
    RXUSERRDY_in,
    TXUSERRDY_in,
    CPLLRESET_in
  ) is
  begin
    transceiverIb                    <= EVR_TRANSCEIVER_IB_INIT_C;
    transceiverIb.tx_data            <= tx_data;
    transceiverIb.tx_charisk         <= tx_charisk;
    transceiverIb.drp_addr           <= drpaddr;
    transceiverIb.drp_di             <= drpdi;
    transceiverIb.drp_en             <= drpen;
    transceiverIb.drp_we             <= drpwe;

    transceiverIb.sys_clk            <= sys_clk;
    transceiverIb.sys_rst            <= reset;
    transceiverIb.rx_rst             <= GTRXRESET_in;
    transceiverIb.tx_rst             <= GTTXRESET_in;
    transceiverIb.rx_usr_rdy         <= RXUSERRDY_in;
    transceiverIb.tx_usr_rdy         <= TXUSERRDY_in;
    transceiverIb.cpll_rst           <= CPLLRESET_in;
  end process P_ASSIGN;

  drpclk                           <= transceiverOb.drp_clk;
  drpdo                            <= transceiverOb.drp_do;
  drprdy                           <= transceiverOb.drp_rdy;
  drpbsy                           <= transceiverOb.drp_bsy;
  useDrpDlyAdj                     <= transceiverOb.dly_adj;

  rxusrclk                         <= transceiverOb.rx_usr_clk;
  rx_data                          <= transceiverOb.rx_data;
  rx_charisk                       <= transceiverOb.rx_charisk;
  rx_disperr                       <= transceiverOb.rx_disperr;
  rx_notintable                    <= transceiverOb.rx_notintable;
  rx_resetdone                     <= transceiverOb.rx_resetdone;
  
  txusrclk                         <= transceiverOb.tx_usr_clk;
  txbufstatus_i                    <= transceiverOb.tx_bufstatus;

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
      DO => fifo_do_i,
      DOP => fifo_dop_i,
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
      WRCLK => rxusrclk,
      WREN => fifo_wren,
      DI => fifo_di,
      DIP => fifo_dip,
      INJECTDBITERR => gnd,
      INJECTSBITERR => gnd);

  fifo_do  <= fifo_do_i(fifo_do'range);
  fifo_dop <= fifo_dop_i(fifo_dop'range);
  
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
      DO => tx_fifo_do_i,
      DOP => tx_fifo_dop,
      ALMOSTEMPTY => open,
      ALMOSTFULL => open,
      EMPTY => tx_fifo_empty,
      FULL => open,
      RDCOUNT => open,
      RDERR => tx_fifo_rderr,
      WRCOUNT => open,
      WRERR => open,
      RDCLK => txusrclk,
      RDEN => tx_fifo_rden,
      REGCE => vcc,
      RST => tx_fifo_rst,
      RSTREG => gnd,
      WRCLK => refclk,
      WREN => tx_fifo_wren,
      DI => tx_fifo_di_i,
      DIP => tx_fifo_dip);

  tx_fifo_do  <= tx_fifo_do_i(tx_fifo_do'range);
  tx_fifo_di  <= tx_fifo_di_i(tx_fifo_di'range);

  vcc <= '1';
  gnd <= '0';
  gnd_vec <= (others => '0');
  tied_to_ground_i                    <= '0';
  tied_to_ground_vec_i(63 downto 0)   <= (others => '0');
  tied_to_vcc_i                       <= '1';

  recclk_rst <= lbit( evr_cdcsync_reset_rxusrclk );
  REFCLK_RST <= lbit( evr_cdcsync_reset_txusrclk );
  refclk <= txusrclk;
  
  rx_powerdown <= '0';
  tx_powerdown <= '0';

  fifo_di(63 downto 16) <= (others => '0');
  fifo_di(15 downto 0) <= rx_data;
  fifo_dip(7 downto 4) <= (others => '0');
  fifo_dip(2) <= '0';
  fifo_dip(1 downto 0) <= rx_charisk;

  rx_beacon <= rx_beacon_i;
  rx_int_beacon <= rx_int_beacon_i;
  rx_int_beacon_i <= fifo_dop(3);
  fifo_dip(3) <= rx_beacon_i;
  
  receive_error_detect : process (rxusrclk, rx_data, rx_charisk,
				  rx_disperr, rx_notintable)
    variable beacon_cnt : std_logic_vector(2 downto 0) := "000";
    variable cnt : std_logic_vector(12 downto 0);
    variable evr_cdcsync_link_ok : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of evr_cdcsync_link_ok : variable is "TRUE";
    variable evr_cdcsync_dc_mode : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of evr_cdcsync_dc_mode : variable is "TRUE";
  begin
    if rising_edge(rxusrclk) then
      evr_cdcsync_link_ok  := shiftl( evr_cdcsync_link_ok, link_ok );
      evr_cdcsync_dc_mode  := shiftl( evr_cdcsync_dc_mode, dc_mode );
      link_ok_rxusr <= lbit( evr_cdcsync_link_ok );
      rx_error <= '0';
      if (rx_charisk(0) = '1' and rx_data(7) = '1') or
        rx_disperr /= "00" or rx_notintable /= "00" then
        rx_error <= '1';
      end if;
      if beacon_cnt(beacon_cnt'high) = '1' then
        beacon_cnt := beacon_cnt - 1;
      end if;
      if lbit( evr_cdcsync_link_ok ) = '1' and rx_charisk(1) = '0' and rx_data(15 downto 8) = C_EVENT_BEACON then
        beacon_cnt := "111";
      end if;
      rx_beacon_i <= beacon_cnt(beacon_cnt'high);
      if lbit( evr_cdcsync_dc_mode ) = '0' then
        rx_beacon_i <= cnt(cnt'high);
      end if;
      if cnt(cnt'high) = '1' then
        cnt(cnt'high) := '0';
      end if;
      cnt := cnt + 1;
    end if;
  end process;

  link_ok_detection : process (refclk, link_ok, rx_link_ok_i, evr_cdcsync_reset_txusrclk, rx_error_i)
    variable link_ok_delay : std_logic_vector(19 downto 0) := (others => '0');
  begin
    rx_link_ok <= rx_link_ok_i;
    rx_link_ok_i <= link_ok_delay(link_ok_delay'high);
    if rising_edge(refclk) then
      if link_ok_delay(link_ok_delay'high) = '0' then
        link_ok_delay := link_ok_delay + 1;
      end if;
      if lbit( evr_cdcsync_reset_txusrclk ) = '1' or link_ok = '0' or rx_error_i = '1' then
        link_ok_delay := (others => '0');
      end if;
    end if;
  end process;

  link_status_testing : process (refclk, reset, rx_charisk, link_ok,
				 rx_disperr, CPLLLOCK_out)
    variable prescaler : std_logic_vector(14 downto 0);
    variable count : std_logic_vector(3 downto 0);
    variable evr_cdcsync_rx_error : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of evr_cdcsync_rx_error : variable is "TRUE";
    variable loss_lock : std_logic;
    variable rx_error_count : std_logic_vector(5 downto 0);
    variable evr_cdcsync_reset : std_logic_vector(1 downto 0);
    attribute ASYNC_REG of evr_cdcsync_reset : variable is "TRUE";
    attribute MARK_DEBUG of rx_error_count : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of loss_lock      : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of prescaler      : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of count          : variable is MARK_DEBUG_ENABLE;
  begin
    
    if rising_edge(refclk) then
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

        if lbit( evr_cdcsync_rx_error ) = '1' then
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

      rx_error_i <= lbit( evr_cdcsync_rx_error );

      evr_cdcsync_rx_error := shiftl( evr_cdcsync_rx_error, rx_error );
      
      if lbit( evr_cdcsync_reset ) = '1' then
        count := "1111";
      end if;

      -- Synchronize asynchronous resets
      evr_cdcsync_reset := shiftl( evr_cdcsync_reset, ( ( reset or not CPLLLOCK_out ) and not rx_gtresetting ) );
    end if;
  end process;

  reg_dbus_data : process (event_clk, rx_link_ok_i, rx_data, databuf_rxd_i, databuf_rx_k_i)
    variable even : std_logic;
    variable evr_cdcsync_link_ok_dly: std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of evr_cdcsync_link_ok_dly : variable is "TRUE";
  begin
    databuf_rxd <= databuf_rxd_i;
    databuf_rx_k <= databuf_rx_k_i;
    if rising_edge(event_clk) then
      evr_cdcsync_link_ok_dly := shiftl( evr_cdcsync_link_ok_dly, rx_link_ok_i );
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
      
      if lbit( evr_cdcsync_link_ok_dly ) = '0' then
	databuf_rxd_i <= (others => '0');
	databuf_rx_k_i <= '0';
	dbus_rxd <= (others => '0');
      end if;

      even := not even;
      event_rxd <= fifo_do(15 downto 8);
      if lbit( evr_cdcsync_link_ok_dly ) = '0' or fifo_dop(1) = '1' or event_clk_rst = '1' then
	event_rxd <= (others => '0');
	even := '0';
      end if;
    end if;
  end process;

  rx_data_align_detect : process (rxusrclk, reset, rx_charisk, rx_data,
				  rx_clear_viol_usrclk, evr_cdcsync_reset_rxusrclk)
  begin
    if lbit( evr_cdcsync_reset_rxusrclk ) = '1' or rx_clear_viol_usrclk = '1' then
      align_error <= '0';
    elsif rising_edge(rxusrclk) then
      align_error <= '0';
      if rx_charisk(0) = '1' and rx_data(7) = '1' then
	align_error <= '1';
      end if;
    end if;
  end process;

  violation_flag : process (sys_clk, rx_clear_viol, link_ok_rxusr, rx_vio_usrclk)
    variable evr_cdcsync_vio : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of evr_cdcsync_vio : variable is "TRUE";
    variable vio_in : std_logic;
  begin
    vio_in := rx_vio_usrclk or not link_ok_rxusr;
    if rising_edge(sys_clk) then
      if rx_clear_viol = '1' then
        rx_violation <= '0';
      end if;
      if lbit( evr_cdcsync_vio ) = '1' then
        rx_violation <= '1';
      end if;
      evr_cdcsync_vio := shiftl( evr_cdcsync_vio, vio_in );
    end if;
  end process;
  
  violation_detect : process (rxusrclk, rx_clear_viol,
			      rx_disperr, rx_notintable, link_ok)
    variable evr_cdcsync_clrvio : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of evr_cdcsync_clrvio : variable is "TRUE";
  begin
    rx_clear_viol_usrclk <= lbit( evr_cdcsync_clrvio );
    if rising_edge(rxusrclk) then
      if rx_disperr /= "00" or
        rx_notintable /= "00" then
	rx_vio_usrclk <= '1';
      elsif lbit( evr_cdcsync_clrvio ) = '1' then
        rx_vio_usrclk <= '0';
      end if;

      evr_cdcsync_clrvio := shiftl( evr_cdcsync_clrvio, rx_clear_viol );
    end if;
  end process;

  process (rxusrclk)
    variable toggle : std_logic := '0';
    attribute MARK_DEBUG of toggle : variable is MARK_DEBUG_ENABLE;
  begin
    if rising_edge(rxusrclk) then
      toggle := not toggle;
    end if;
  end process;
  
  -- Scalers for clocks for debugging purposes to see which clocks
  -- are running using the ILA core
  
  process (refclk)
    variable cnt : std_logic_vector(2 downto 0);
    variable cntHi : std_logic;
    attribute MARK_DEBUG of cntHi : variable is MARK_DEBUG_ENABLE;
  begin
    cntHi := cnt(cnt'high);
    if rising_edge(refclk) then
      cnt := cnt + 1;
      if lbit( evr_cdcsync_reset_txusrclk ) = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (sys_clk)
    variable cnt : std_logic_vector(2 downto 0);
    variable cntHi : std_logic;
    attribute MARK_DEBUG of cntHi : variable is MARK_DEBUG_ENABLE;
  begin
    cntHi := cnt(cnt'high);
    if rising_edge(sys_clk) then
      cnt := cnt + 1;
      if reset = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (event_clk)
    variable cnt : std_logic_vector(2 downto 0);
    variable cntHi : std_logic;
    attribute MARK_DEBUG of cntHi : variable is MARK_DEBUG_ENABLE;
  begin
    cntHi := cnt(cnt'high);
    if rising_edge(event_clk) then
      cnt := cnt + 1;
      if event_clk_rst = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (rxusrclk)
    variable cnt : std_logic_vector(2 downto 0);
    variable cntHi : std_logic;
    attribute MARK_DEBUG of cntHi : variable is MARK_DEBUG_ENABLE;
  begin
    cntHi := cnt(cnt'high);
    if rising_edge(rxusrclk) then
      cnt := cnt + 1;
      if lbit( evr_cdcsync_reset_rxusrclk ) = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (txusrclk)
    variable cnt : std_logic_vector(2 downto 0);
    variable cntHi : std_logic;
    attribute MARK_DEBUG of cntHi : variable is MARK_DEBUG_ENABLE;
  begin
    cntHi := cnt(cnt'high);
    if rising_edge(txusrclk) then
      cnt := cnt + 1;
      if lbit( evr_cdcsync_reset_txusrclk ) = '1' then
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  cpll_reset: process (sys_clk)
    variable cnt : std_logic_vector(25 downto 0) := (others => '1');
  begin
    if rising_edge(sys_clk) then
      CPLLRESET_in <= cnt(cnt'high);
      if cnt(cnt'high) = '1' then
        cnt := cnt - 1;
        GTTXRESET_in <= '1';
        TXUSERRDY_in <= '0';
      end if;
      if reset = '1' then
        cnt := (others => '1');
      end if;
      if CPLLLOCK_out = '1' then
        GTTXRESET_in <= '0';
        TXUSERRDY_in <= '1';
      end if;
    end if;
  end process;
  
  rx_resetting: process (refclk, rxcdrreset)
    variable cnt : std_logic_vector(25 downto 0) := (others => '1');
    variable rx_resetdone_sync : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of rx_resetdone_sync : variable is "TRUE";
  begin
    if rising_edge(refclk) then
      rx_resetdone_sync := rx_resetdone & rx_resetdone_sync(rx_resetdone_sync'left downto 1);
      GTRXRESET_in <= cnt(cnt'high);
      if cnt(cnt'high) = '1' then
        rx_gtresetting <= '1';
      end if;
      if ( rx_resetdone_sync(0) = '1' ) then
        rx_gtresetting <= '0';
      end if;
      RXUSERRDY_in <= not cnt(cnt'high);
      if cnt(cnt'high) = '1' then
        cnt := cnt - 1;
      end if;
      if rxcdrreset = '1' then
        cnt := (others => '1');
      end if;
    end if;
  end process;

  transmit_data : process (txusrclk, tx_fifo_do, tx_fifo_empty, dbus_txd,
                           databuf_txd, databuf_tx_k, databuf_tx_mode, dc_mode,
                           evr_cdcsync_reset_txusrclk, tx_event_ena_i)
    variable even       : std_logic_vector(1 downto 0) := "00";
    variable beacon_cnt : std_logic_vector(3 downto 0) := "0000"; 
    variable fifo_pend  : std_logic;
    attribute ASYNC_REG of beacon_cnt : variable is "TRUE";
    variable even0      : std_logic;
    attribute MARK_DEBUG of even0 : variable is MARK_DEBUG_ENABLE;
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
    if rising_edge(txusrclk) then
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
      even0 := even(0);
      even := even + 1;
      beacon_cnt := rx_beacon_i & beacon_cnt(beacon_cnt'high downto 1);
      if lbit( evr_cdcsync_reset_txusrclk ) = '1' then
        fifo_pend := '0';
      end if;
    end if;
  end process;

  -- Read and write enables are used to adjust the coarse delay
  -- These can cause data packet corruption and missing events -
  -- thus this method is used only during link training
  
  fifo_read_enable : process (event_clk, delay_inc)
    variable sr_delay_trig : std_logic_vector(2 downto 0) := "000";
    attribute ASYNC_REG of sr_delay_trig : variable is "TRUE";
  begin
    if rising_edge(event_clk) then
      fifo_rden <= '1';
      if sr_delay_trig(1 downto 0) = "10" then
        fifo_rden <= '0';
      end if;
      sr_delay_trig := delay_inc & sr_delay_trig(2 downto 1);
    end if;
  end process;
  
  fifo_write_enable : process (rxusrclk, delay_dec)
    variable sr_delay_trig : std_logic_vector(2 downto 0) := "000";
    attribute ASYNC_REG of sr_delay_trig : variable is "TRUE";
  begin
    if rising_edge(rxusrclk) then
      fifo_wren <= '1';
      if sr_delay_trig(1 downto 0) = "10" then
        fifo_wren <= '0';
      end if;
      sr_delay_trig := delay_dec & sr_delay_trig(2 downto 1);
    end if;
  end process;

  fifo_rst <= not link_ok_rxusr;

  tx_fifo_writing : process (refclk, event_txd)
  begin
    tx_fifo_di_i <= (others => '0');
    tx_fifo_di_i(7 downto 0) <= event_txd;
    tx_fifo_wren <= '0';
    if event_txd /= X"00" then
      tx_fifo_wren <= '1';
    end if;
  end process;
  
  tx_fifo_dip <= (others => '0');
  tx_fifo_rst <= lbit( evr_cdcsync_reset_txusrclk );
  
  process (drpclk, txbufstatus_i, TXUSERRDY_in)
    type state is (init, init_delay, acq_bufstate, deldec, delinc, locked);
    variable ph_state : state;
    variable phase       : std_logic_vector(6 downto 0);
    variable cnt      : std_logic_vector(19 downto 0);
    variable halffull : std_logic;
  begin
    if rising_edge(drpclk) then
      if (ph_state = acq_bufstate) or
        (ph_state = delinc) or
        (ph_state = deldec) then
        if txbufstatus_i(0) = '1' then
          halffull := '1';
        end if;
      end if;

      phase_acc_en <= '0';
      if cnt(cnt'high) = '1' then
        case ph_state is
          when init =>
            if lbit( evr_cdcsync_reset_drpclk ) = '0' then
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
            phase_acc_en <= '1';
          when delinc =>
            if halffull = '0' then
              phase := phase + 1;
            else
              ph_state := locked;
            end if;
            halffull := '0';
            phase_acc_en <= '1';
          when others =>
        end case;
        phase_acc <= phase;
        cnt := (others => '0');
      else
        cnt := cnt + 1;
      end if;
      if lbit( evr_cdcsync_reset_drpclk ) = '1' or useDrpDlyAdj /= DRP  then
        phase_acc_en <= '0';
        ph_state := init;
        phase := (others => '0');
        cnt := (others => '0');
      end if;
    end if;
  end process;
  
  process (drpclk, phase_acc, phase_acc_en)
    type state is (idle, a64_0, a64_1, a64_2, a9f_0, a9f_1, a9f_2, a9f_3, a9f_4, a9f_5);
    variable drp_state, next_state : state;
    variable rdy_wait : std_logic;
  begin
    if rising_edge(drpclk) then
      rdy_wait := '0';
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
      if ( drpbsy = '0' ) and ( rdy_wait = '0' or drprdy = '1' ) then
        if drp_state = idle and phase_acc_en = '1' then
          next_state := a64_0;
        end if;
        drp_state := next_state;
      end if;
      if lbit( evr_cdcsync_reset_drpclk ) = '1' then
        drp_state := idle;
        rdy_wait := '0';
      end if;
    end if;
  end process;

end structure;
