library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.Vcomponents.ALL;

use work.transceiver_pkg.all;

entity zynq_top is
  generic (
    MAX_RW_REGS_G : natural   := 8;
    MAX_RO_REGS_G : natural   := 8;
    RX_POLARITY   : std_logic := '0';
    TX_POLARITY   : std_logic := '0';
    REFCLKSEL     : std_logic := '1'
  );
  port (
    sys_clk      : in  std_logic;

    led          : out std_logic_vector(5 downto 0);
    ctl          : out std_logic_vector(7 downto 0);

    MGTREFCLK0_P : in  std_logic;   -- JX3 pin 2,   Zynq U5
    MGTREFCLK0_N : in  std_logic;   -- JX3 pin 3,   Zynq V5
    MGTREFCLK1_P : in  std_logic;   -- JX3 pin 2,   Zynq U5
    MGTREFCLK1_N : in  std_logic;   -- JX3 pin 3,   Zynq V5

    MGTTX2_P     : out std_logic;  -- JX3 pin 25,  Zynq AA5
    MGTTX2_N     : out std_logic;  -- JX3 pin 27,  Zynq AB5
    MGTRX2_P     : in  std_logic;   -- JX3 pin 20,  Zynq AA9
    MGTRX2_N     : in  std_logic;   -- JX3 pin 22,  Zynq AB9

    widx         : in  natural;
    wstrb        : in  std_logic_vector(3 downto 0);
    wdata        : in  std_logic_vector(31           downto 0);
    werr         : out std_logic;

    ridx         : in  natural;
    rdata        : out std_logic_vector(31          downto 0);
    rerr         : out std_logic
    );
end zynq_top;

architecture structure of zynq_top is

  component evr_dc is
  port (
    -- System bus clock
    sys_clk         : in std_logic;
    refclk_out      : out std_logic; -- Reference clock output
    event_clk_out   : out std_logic; -- Event clock output, delay compensated
				     -- and locked to EVG

    -- Receiver side connections
    event_rxd       : out std_logic_vector(7 downto 0);  -- Received event code
    dbus_rxd        : out std_logic_vector(7 downto 0);  -- Distributed bus data
    databuf_rxd     : out std_logic_vector(7 downto 0);  -- Databuffer data
    databuf_rx_k    : out std_logic; -- Databuffer K-character
    databuf_rx_ena  : out std_logic; -- Databuf data enable
    databuf_rx_mode : in std_logic;  -- Databuf receive mode, '1' enabled, '0'
				     -- disabled (only for non-DC)
    dc_mode         : in std_logic;  -- Delay compensation mode enable
      
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
    dc_slow_adjust  : in  std_logic;
    mode_mst        : in  std_logic;
    rx_commaalignen : in  std_logic := '0';

    reset           : in  std_logic; -- Transmitter reset

    -- Delay compensation signals
    delay_comp_update : in std_logic;
    delay_comp_value  : in std_logic_vector(31 downto 0);
    delay_comp_target : in std_logic_vector(31 downto 0);
    delay_comp_locked_out : out std_logic;

    int_delay_value_out   : out std_logic_vector(31 downto 0);
    int_delay_update_out  : out std_logic;

     -- MGT
    mgtIb             : in  transceiver_ob_type;
    mgtOb             : out transceiver_ib_type
    );
  end component;

  component databuf_rx_dc is
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

  COMPONENT ila_0
    PORT (
      clk : IN STD_LOGIC;
      probe0 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      probe1 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      probe2 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      probe3 : IN STD_LOGIC_VECTOR(63 DOWNTO 0)
      );
  END COMPONENT;

  signal TRIG0 : std_logic_vector(255 downto 0);

  signal gnd     : std_logic;
  signal vcc     : std_logic;
  
  signal sys_reset : std_logic;

  signal refclk  : std_logic;
  signal event_clk : std_logic;

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

  signal dc_status             : std_logic_vector(31 downto 0);
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
  signal int_delay_value     : std_logic_vector(31 downto 0);
  signal int_delay_update    : std_logic;
  signal int_delay_updcnt    : std_logic_vector( 3 downto 0) := (others => '0');
  signal int_delay_updsyn    : std_logic := '0';
  signal dc_slow_adjust      : std_logic;
  signal mode_mst            : std_logic;

  signal topology_addr       : std_logic_vector(31 downto 0);

  constant NUM_RW_REGS_C     : natural := 8;
  constant NUM_RO_REGS_C     : natural := 8;

  type RegArray is array ( natural range <> ) of std_logic_vector(31 downto 0);

  signal rwRegs : RegArray(0 to NUM_RW_REGS_C - 1) := (
    0 => x"0000_0000",
    1 => X"0210_0000",
    2 => X"0100_0000",
    others => (others => '0')
  );

  signal roRegs : RegArray(0 to NUM_RO_REGS_C - 1) := ( others => (others => '0') );

  signal PL_LED2, PL_LED3, PL_LED4 : std_logic;

  signal mgtIb  : transceiver_ib_type;
  signal mgtOb  : transceiver_ob_type;

  signal rxCommaAlignEn: std_logic;
   
begin

  assert NUM_RW_REGS_C <= MAX_RW_REGS_G severity failure;
  assert NUM_RO_REGS_C <= MAX_RO_REGS_G severity failure;

  P_READ : process ( ridx, roRegs, widx, rwRegs ) is
  begin
    if    ( ridx < NUM_RO_REGS_C ) then
      rdata <= roRegs(ridx);
      rerr  <= '0';
    elsif ( ridx >= MAX_RO_REGS_G and ridx < MAX_RO_REGS_G + NUM_RW_REGS_C ) then
      rdata <= rwRegs(ridx - MAX_RO_REGS_G);
      rerr  <= '0';
    else
      rdata <= x"dead_beef";
      rerr  <= '1';
    end if;

    if ( widx < NUM_RW_REGS_C ) then
      werr <= '0';
    else
      werr <= '1';
    end if;
  end process P_READ;

  P_WRITE : process ( sys_clk ) is
  begin
    if ( rising_edge( sys_clk ) ) then
      if ( widx < NUM_RW_REGS_C ) then
        for i in 0 to 3 loop
          if ( wstrb(i) = '1' ) then
             rwRegs(widx)(8*i+7 downto 8*i) <= wdata(8*i+7 downto 8*i);
          end if;
        end loop;
      end if;
      int_delay_updsyn <= int_delay_update;
      if ( int_delay_updsyn = '0' and int_delay_update = '1' ) then
         int_delay_updcnt <= int_delay_updcnt + 1;
      end if;
    end if;
  end process P_WRITE;

  -- ILA debug core
--  i_ila : ila_0
--    port map (
--      CLK => event_clk,
--      probe0 => TRIG0( 63 downto   0),
--      probe1 => TRIG0(127 downto  64),
--      probe2 => TRIG0(191 downto 128),
--      probe3 => TRIG0(255 downto 192)
--      );

  i_mgt : entity work.transceiver_dc_gt
    generic map (
      RX_POLARITY => RX_POLARITY,
      TX_POLARITY => TX_POLARITY,
      refclksel   => REFCLKSEL)
    port map (
      sys_clk   => sys_clk,
      ib        => mgtIb,
      ob        => mgtOb,

      REFCLK0P  => MGTREFCLK0_P,
      REFCLK0N  => MGTREFCLK0_N,
      REFCLK1P  => MGTREFCLK1_P,
      REFCLK1N  => MGTREFCLK1_N,

      rxp       => MGTRX2_P,
      rxn       => MGTRX2_N,
      txp       => MGTTX2_P,
      txn       => MGTTX2_N
      );

  i_evr_dc : evr_dc
    port map (
      sys_clk => sys_clk,
      refclk_out => refclk,
      event_clk_out => event_clk,
      
      -- Receiver side connections
      event_rxd => event_rxd,
      dbus_rxd => dbus_rxd,
      databuf_rxd => databuf_rxd,
      databuf_rx_k => databuf_rx_k,
      databuf_rx_ena => databuf_rx_ena,
      databuf_rx_mode => databuf_rx_mode,
      dc_mode => dc_mode,
      
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

      dc_slow_adjust => dc_slow_adjust,
      mode_mst => mode_mst,
      rx_commaalignen => rxCommaAlignEn,
 
      reset => tx_reset,

      delay_comp_update => delay_comp_update,
      delay_comp_value => delay_comp_value,
      delay_comp_target => delay_comp_target,
      delay_comp_locked_out => delay_comp_locked,

      int_delay_value_out => int_delay_value,
      int_delay_update_out => int_delay_update,

      mgtIb => mgtOb,
      mgtOb => mgtIb
      );

  i_databuf_dc : databuf_rx_dc
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

      reset => sys_reset);

  gnd <= '0';
  vcc <= '1';

  dc_mode           <= not rwRegs(0)(0);
  databuf_rx_mode   <= not rwRegs(0)(1);
  databuf_tx_mode   <= not rwRegs(0)(2);


  rx_clear_viol     <= rwRegs(0)(4);
  tx_reset          <= rwRegs(0)(5);
  sys_reset         <= rwRegs(0)(6);
  dc_slow_adjust    <= rwRegs(0)(7);
  rxCommaAlignEn    <= rwRegs(0)(8);
  mode_mst          <= rwRegs(0)(9);

  ctl               <= rwRegs(0)(31 downto 24);

  delay_comp_target <= rwRegs(1);

  dbus_txd          <= rwRegs(2)( 7 downto 0);
  databuf_txd       <= rwRegs(2)(15 downto 8);
  databuf_tx_k      <= rwRegs(2)(         16);

  P_LED : process ( rwRegs(3), PL_LED2, PL_LED3, PL_LED4 ) is
    variable v : std_logic_vector(led'range);
  begin
    v := rwRegs(3)(led'range);
    v(0) := v(0) or PL_LED2;
    v(1) := v(1) or PL_LED3;
    v(2) := v(2) or PL_LED4;
    led <= v;
  end process P_LED;

  databuf_dc_addr                   <= rwRegs(4)(databuf_dc_addr'range);

  P_FLAGS : process ( rwRegs(5), databuf_cs_flag, databuf_rx_flag ) is
  begin
    databuf_clear_flag <= (others => '0');
    for i in 31 downto 0 loop
      databuf_clear_flag(i) <= rwRegs(5)(i);
      roRegs(5)(i)          <= databuf_cs_flag(i);
      roRegs(6)(i)          <= databuf_rx_flag(i);
    end loop;
  end process P_FLAGS;

  -- Process to send out event 0x01 periodically
  process (refclk)
    variable count : std_logic_vector(31 downto 0) := X"FFFFFFFF";
    variable blink : std_logic := '0';
  begin
    if rising_edge(refclk) then
      event_txd <= X"00";
      if count(26) = '0' then
	event_txd <= rwRegs(2)(31 downto 24);
	count := X"FFFFFFFF";
    blink := not blink;
      end if;
      count := count - 1;
    end if;
    PL_LED2 <= blink;
  end process;

  process (event_clk)
    variable count : std_logic_vector(31 downto 0) := X"FFFFFFFF";
    variable blink : std_logic := '0';
  begin
    if rising_edge(event_clk) then
      if count(26) = '0' then
	count := X"FFFFFFFF";
    blink := not blink;
      end if;
      count := count - 1;
    end if;
    PL_LED4 <= blink;
  end process;

  roRegs(0)(0) <= rx_violation;
  roRegs(0)(1) <= rx_link_ok;
  roRegs(0)(2) <= delay_comp_locked;
  roRegs(0)(3) <= delay_comp_update;
  roRegs(0)(7 downto 4) <= int_delay_updcnt;
  roRegs(1)    <= delay_comp_value;
  roRegs(2)    <= delay_comp_rx_status;
  roRegs(3)    <= databuf_dc_data_out;
  roRegs(4)    <= databuf_dc_size_out;
  roRegs(7)    <= int_delay_value;
 
  process (event_clk)
  begin
    if rising_edge(event_clk) then
      TRIG0(7 downto 0) <= event_rxd;
      TRIG0(15 downto 8) <= dbus_rxd;
      TRIG0(23 downto 16) <= databuf_rxd;
      TRIG0(24) <= databuf_rx_k;
      TRIG0(25) <= databuf_rx_ena;
      TRIG0(26) <= databuf_rx_mode;
      TRIG0(27) <= rx_link_ok;
      TRIG0(28) <= rx_violation;
      TRIG0(29) <= rx_clear_viol;
      TRIG0(30) <= delay_comp_locked;
      TRIG0(31) <= delay_comp_update;
      TRIG0(63 downto 32) <= delay_comp_value;
      TRIG0(95 downto 64) <= delay_comp_target;
      TRIG0(127 downto 96) <= dc_status;
      TRIG0(159 downto 128) <= delay_comp_rx_status;
      TRIG0(191 downto 160) <= topology_addr;
      TRIG0(255 downto 192) <= (others => '0');
    end if;
  end process;

  process (event_clk, event_rxd)
    variable pulse_cnt : std_logic_vector(19 downto 0) := X"00000";
  begin
    if rising_edge(event_clk) then
      PL_LED3 <= pulse_cnt(pulse_cnt'high);
      if pulse_cnt(pulse_cnt'high) = '1' then
	pulse_cnt := pulse_cnt - 1;
      end if;
      if event_rxd = rwRegs(2)(31 downto 24) then
	pulse_cnt := X"FFFFF";
      end if;
      if rx_link_ok = '0' then
	pulse_cnt := X"0000F";
      end if;
    end if;
  end process;
    
  
end structure;
