library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.transceiver_pkg.all;
library UNISIM;
use UNISIM.Vcomponents.ALL;

entity zynq_top is
  generic (
    MARK_DEBUG_TOP_ENABLE : string := "TRUE";
    MARK_DEBUG_EVR_ENABLE : string := "TRUE";
    MARK_DEBUG_BUF_ENABLE : string := "FALSE"
  );
  port (
    PL_CLK       : in std_logic;
    PL_LED1      : out std_logic;  -- Carrier D6
    PL_LED2      : out std_logic;  -- Carrier D7
    PL_LED3      : out std_logic;  -- Carrier D8
    PL_LED4      : out std_logic;  -- Carrier D9

    PL_PB1       : in std_logic;   -- JX1 pin 19,  Zynq G2, Carrier SW1 N
    PL_PB2       : in std_logic;   -- JX2 pin 100, Zynq T16, Carrier SW5 S
    PL_PB3       : in std_logic;   -- JX2 pin 95,  Zynq AB22, Carrier SW3, E
    PL_PB4       : in std_logic;   -- JX2 pin 94,  Zynq AB18, Carrier SW2, W
    PL_PB5       : in std_logic;   -- JX2 pin 96,  Zynq AB19, Carrier SW4, C

    BANK13_LVDS_8_P : out std_logic;
    BANK13_LVDS_8_N : out std_logic;
    
    MGTREFCLK1_P : in std_logic;   -- JX3 pin 2,   Zynq U5
    MGTREFCLK1_N : in std_logic;   -- JX3 pin 3,   Zynq V5

    MGTTX2_P     : out std_logic;  -- JX3 pin 25,  Zynq AA5
    MGTTX2_N     : out std_logic;  -- JX3 pin 27,  Zynq AB5
    MGTRX2_P     : in std_logic;   -- JX3 pin 20,  Zynq AA9
    MGTRX2_N     : in std_logic    -- JX3 pin 22,  Zynq AB9
    );
end zynq_top;

architecture structure of zynq_top is

  attribute ASYNC_REG        : string;
  attribute MARK_DEBUG       : string;

  component evr_dc is
      generic (
    MARK_DEBUG_ENABLE            : string    := "FALSE"
    );
  port (
    -- System bus clock
    sys_clk         : in std_logic;
    refclk_rst      : out std_logic;
    event_clk_out   : out std_logic; -- Event clock output, delay compensated
				     -- and locked to EVG
    event_clk_rst   : out std_logic;

    -- Receiver side connections
    event_rxd       : out std_logic_vector(7 downto 0);  -- Received event code
    dbus_rxd        : out std_logic_vector(7 downto 0);  -- Distributed bus data
    databuf_rxd     : out std_logic_vector(7 downto 0);  -- Databuffer data
    databuf_rx_k    : out std_logic; -- Databuffer K-character
    databuf_rx_ena  : out std_logic; -- Databuf data enable
    databuf_rx_mode : in std_logic;  -- Databuf receive mode, '1' enabled, '0'
				     -- disabled (only for non-DC)
    dc_mode         : in std_logic;  -- Delay compensation mode enable
    delay_meas_value: out std_logic_vector(31 downto 0);
      
    rx_link_ok      : out   std_logic; -- Received link ok
    rx_violation    : out   std_logic; -- Receiver violation detected
    rx_clear_viol   : in    std_logic; -- Clear receiver violatio flag
      
    -- Transmitter side connections
    event_txd       : in  std_logic_vector(7 downto 0); -- TX event code
    dbus_txd        : in  std_logic_vector(7 downto 0); -- TX distributed bus data
    databuf_txd     : in  std_logic_vector(7 downto 0); -- TX databuffer data
    databuf_tx_k    : in  std_logic; -- TX databuffer K-character
    databuf_tx_ena  : out std_logic; -- TX databuffer data enable
    databuf_tx_mode : in  std_logic; -- TX databuffer transmit mode, '1'
				     -- enabled, '0' disabled

    reset           : in  std_logic; -- Transmitter reset

    -- Delay compensation signals
    delay_comp_update : in std_logic;
    delay_comp_value  : in std_logic_vector(31 downto 0);
    delay_comp_target : in std_logic_vector(31 downto 0);
    delay_comp_locked_out : out std_logic;

    transceiverIb : out EvrTransceiverIbType;
    transceiverOb : in  EvrTransceiverObType
    );
  end component;

  component databuf_rx_dc is
    generic (
      MARK_DEBUG_ENABLE : string    := "FALSE"
    );
    port (
      -- Memory buffer RAMB read interface
      data_out          : out std_logic_vector(31 downto 0);
      size_data_out     : out std_logic_vector(31 downto 0);
      addr_in           : in std_logic_vector(10 downto 2);
      clk               : in std_logic;
      
      -- Data stream interface
      databuf_data      : in std_logic_vector(7 downto 0);
      databuf_k         : in std_logic;
      databuf_ena       : in std_logic;
      event_clk         : in std_logic;
      
      delay_comp_update : out std_logic;
      delay_comp_rx     : out std_logic_vector(31 downto 0);
      delay_comp_status : out std_logic_vector(31 downto 0);
      topology_addr     : out std_logic_vector(31 downto 0);

      -- Control interface
      irq_out           : out std_logic;

      sirq_ena          : in std_logic_vector(0 to 127);
      rx_flag           : out std_logic_vector(0 to 127);
      cs_flag           : out std_logic_vector(0 to 127);
      ov_flag           : out std_logic_vector(0 to 127);
      clear_flag        : in std_logic_vector(0 to 127);
      
      reset             : in std_logic);
  end component;

  component transceiver_gt is
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
  end component transceiver_gt;


  signal gnd     : std_logic;
  signal vcc     : std_logic;
  
  signal sys_clk : std_logic;
  signal sys_reset : std_logic;

  signal refclk          : std_logic;
  signal refclk_rst      : std_logic;
  signal event_clk       : std_logic;
  signal event_clk_rst   : std_logic;

  signal dc_mode         : std_logic;

  signal tx_reset : std_logic;
  
  signal event_link_ok : std_logic;

  signal event_rxd       : std_logic_vector(7 downto 0);
  signal dbus_rxd        : std_logic_vector(7 downto 0);
  signal databuf_rxd     : std_logic_vector(7 downto 0);
  signal databuf_rx_k    : std_logic;
  signal databuf_rx_ena  : std_logic;
  signal databuf_rx_mode : std_logic;
    
  signal rx_link_ok      : std_logic;
  signal rx_violation    : std_logic;
  signal rx_clear_viol   : std_logic;

  signal event_txd       : std_logic_vector(7 downto 0);
  signal dbus_txd        : std_logic_vector(7 downto 0);
  signal databuf_txd     : std_logic_vector(7 downto 0);
  signal databuf_tx_k    : std_logic;
  signal databuf_tx_ena  : std_logic;
  signal databuf_tx_mode : std_logic;

  signal delay_comp_locked  : std_logic;
  signal delay_comp_update  : std_logic;
  signal delay_comp_value   : std_logic_vector(31 downto 0);
  signal delay_comp_target  : std_logic_vector(31 downto 0);

  signal delay_comp_rx_status : std_logic_vector(31 downto 0);

  signal databuf_dc_addr     : std_logic_vector(10 downto 2);
  signal databuf_dc_data_out : std_logic_vector(31 downto 0);
  signal databuf_dc_size_out : std_logic_vector(31 downto 0);
  signal databuf_sirq_ena    : std_logic_vector(0 to 127);
  signal databuf_rx_flag     : std_logic_vector(0 to 127);
  signal databuf_cs_flag     : std_logic_vector(0 to 127);
  signal databuf_ov_flag     : std_logic_vector(0 to 127);
  signal databuf_clear_flag  : std_logic_vector(0 to 127);
  signal databuf_irq_dc      : std_logic;

  signal topology_addr       : std_logic_vector(31 downto 0);
  
  signal transceiverIb       : EvrTransceiverIbType;
  signal transceiverOb       : EvrTransceiverObType;
  
  attribute MARK_DEBUG of event_rxd: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of dbus_rxd: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of databuf_rxd: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of databuf_rx_k: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of databuf_rx_ena: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of databuf_rx_mode: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of rx_link_ok: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of rx_violation: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of rx_clear_viol: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of delay_comp_locked: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of delay_comp_update: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of delay_comp_value: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of delay_comp_target: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of delay_comp_rx_status: signal is MARK_DEBUG_TOP_ENABLE;
  attribute MARK_DEBUG of topology_addr: signal is MARK_DEBUG_TOP_ENABLE;
  
begin

  i_bufg : bufg
    port map (
      I => PL_CLK,
      O => sys_clk);

  i_mgt : transceiver_gt
    generic map (
      RX_POLARITY   => '0',
      TX_POLARITY   => '0',
      REFCLKSEL     => '1') -- 0 - REFCLK0, 1 - REFCLK1
    port map (
      REFCLK0P      => gnd,
      REFCLK0N      => gnd,
      REFCLK1P      => MGTREFCLK1_P,
      REFCLK1N      => MGTREFCLK1_N,
      
      
      RXN           => MGTRX2_N,
      RXP           => MGTRX2_p,

      TXN           => MGTTX2_N,
      TXP           => MGTTX2_P,

      transceiverIb => transceiverIb,
      transceiverOb => transceiverOb);

  refclk <= transceiverOb.tx_usr_clk;

  i_evr_dc : evr_dc
    generic map (
      MARK_DEBUG_ENABLE => MARK_DEBUG_EVR_ENABLE
      )
    port map (
      sys_clk => sys_clk,
      refclk_rst => refclk_rst,
      event_clk_out => event_clk,
      event_clk_rst => event_clk_rst,
      
      -- Receiver side connections
      event_rxd => event_rxd,
      dbus_rxd => dbus_rxd,
      databuf_rxd => databuf_rxd,
      databuf_rx_k => databuf_rx_k,
      databuf_rx_ena => databuf_rx_ena,
      databuf_rx_mode => databuf_rx_mode,
      dc_mode => dc_mode,
      delay_meas_value => open,
      
      rx_link_ok => rx_link_ok,
      rx_violation => rx_violation,
      rx_clear_viol => rx_clear_viol,
      
      -- Transmitter side connections
      event_txd => event_txd,
      dbus_txd => dbus_txd,
      databuf_txd => databuf_txd,
      databuf_tx_k => databuf_tx_k,
      databuf_tx_ena => databuf_tx_ena,
      databuf_tx_mode => databuf_tx_mode,

      reset => tx_reset,

      delay_comp_update => delay_comp_update,
      delay_comp_value => delay_comp_value,
      delay_comp_target => delay_comp_target,
      delay_comp_locked_out => delay_comp_locked,

      transceiverIb => transceiverIb,
      transceiverOb => transceiverOb);

  i_databuf_dc : databuf_rx_dc
    generic map (
      MARK_DEBUG_ENABLE => MARK_DEBUG_BUF_ENABLE
    )
    port map (
      data_out => databuf_dc_data_out,
      size_data_out => databuf_dc_size_out,
      addr_in(10 downto 2) => databuf_dc_addr,
      clk => sys_clk,

      databuf_data => databuf_rxd,
      databuf_k => databuf_rx_k,
      databuf_ena => databuf_rx_ena,
      event_clk => event_clk,

      delay_comp_update => delay_comp_update,
      delay_comp_rx => delay_comp_value,
      delay_comp_status => delay_comp_rx_status,
      topology_addr => topology_addr,
      
      irq_out => databuf_irq_dc,

      sirq_ena => databuf_sirq_ena,
      rx_flag => databuf_rx_flag,
      cs_flag => databuf_cs_flag,
      ov_flag => databuf_ov_flag,
      clear_flag => databuf_clear_flag,

      reset => event_clk_rst);

  gnd <= '0';
  vcc <= '1';
  
  databuf_rx_mode <= '1';
  databuf_tx_mode <= '1';
  dc_mode <= '1';

  delay_comp_target <= X"02100000";

  dbus_txd <= X"00";
  databuf_txd <= X"00";
  databuf_tx_k <= '0';

  -- Process to send out event 0x01 periodically
  process (refclk)
    variable count : std_logic_vector(31 downto 0) := X"FFFFFFFF";
  begin
    if rising_edge(refclk) then
      event_txd <= X"00";
      if count(26) = '0' then
	event_txd <= X"01";
	count := X"FFFFFFFF";
      end if;
      count := count - 1;
    end if;
  end process;
  
  
  process (sys_clk)
    variable count : std_logic_vector(31 downto 0) := X"FFFFFFFF";
  begin
    if rising_edge(sys_clk) then
      rx_clear_viol <= PL_PB1;
      tx_reset <= PL_PB2;
      sys_reset <= PL_PB3;
      PL_LED1 <= rx_violation;
--      PL_LED3 <= event_rxd(0);
      PL_LED4 <= count(25);
      count := count - 1;
    end if;
  end process;

  PL_LED2 <= rx_link_ok;

  process (event_clk, event_rxd)
    variable pulse_cnt : std_logic_vector(19 downto 0) := X"00000";
    variable sync_link_ok : std_logic_vector(1 downto 0) := (others => '0');
    attribute ASYNC_REG of sync_link_ok : variable is "TRUE";
  begin
    if rising_edge(event_clk) then
      sync_link_ok := rx_link_ok & sync_link_ok(sync_link_ok'left downto 1);
      PL_LED3 <= pulse_cnt(pulse_cnt'high);
      BANK13_LVDS_8_P <= pulse_cnt(pulse_cnt'high);
      BANK13_LVDS_8_N <= not pulse_cnt(pulse_cnt'high);
      if pulse_cnt(pulse_cnt'high) = '1' then
	pulse_cnt := pulse_cnt - 1;
      end if;
      if event_rxd = X"01" then
	pulse_cnt := X"FFFFF";
      end if;
      if sync_link_ok(0) = '0' then
	pulse_cnt := X"0000F";
      end if;
    end if;
  end process;
    
  
end structure;
