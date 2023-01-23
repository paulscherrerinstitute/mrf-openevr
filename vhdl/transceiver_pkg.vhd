---------------------------------------------------------------------------
--
--  File        : transceiver_pkg.vhd
--
--  Title       : Package for wrapping transceiver/EVR interface signals
--
--  Author      : Till Straumann
--                PSI
--
--  License     : GPL (see LICENSE file)
--  		
--
---------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

package transceiver_pkg is

  type TxDelayAdjType is (NONE, DRP, PIPPM);

  -- signals from the transceiver directed to the EVR
  type EvrTransceiverObType is record
    -- RX clock domain
    rx_usr_clk           : std_logic;
    rx_data              : std_logic_vector(15 downto 0);
    rx_charisk           : std_logic_vector( 1 downto 0);
    rx_disperr           : std_logic_vector( 1 downto 0);
    rx_notintable        : std_logic_vector( 1 downto 0);

    -- TX clock domain
    tx_usr_clk           : std_logic;
    tx_bufstatus         : std_logic_vector( 1 downto 0);

    -- DRP clock domain
    drp_clk              : std_logic;
    drp_do               : std_logic_vector(15 downto 0);
    drp_rdy              : std_logic;
    drp_bsy              : std_logic;

    -- SYS clock domain
    dly_adj              : TxDelayAdjType;

    -- ASYNC
    cpll_locked          : std_logic;
  end record EvrTransceiverObType;

  constant EVR_TRANSCEIVER_OB_INIT_C : EvrTransceiverObType := (
    rx_usr_clk           => '0',
    rx_data              => (others => '0'),
    rx_charisk           => (others => '0'),
    rx_disperr           => (others => '0'),
    rx_notintable        => (others => '0'),
    tx_usr_clk           => '0',
    tx_bufstatus         => (others => '0'),
    drp_clk              => '0',
    drp_do               => (others => '0'),
    drp_rdy              => '0',
    drp_bsy              => '0',
    dly_adj              => NONE,
    cpll_locked          => '0'
  );

  -- signals from the EVR directed to the transceiver
  type EvrTransceiverIbType is record
    -- RX clock domain

    -- TX clock domain
    tx_data              : std_logic_vector(15 downto 0);
    tx_charisk           : std_logic_vector( 1 downto 0);

    -- DRP clock domain
    drp_addr             : std_logic_vector( 8 downto 0);
    drp_di               : std_logic_vector(15 downto 0);
    drp_en               : std_logic;
    drp_we               : std_logic;

    -- SYS clock domain
    sys_clk              : std_logic;
    sys_rst              : std_logic;
    rx_rst               : std_logic;
    tx_rst               : std_logic;

    -- ASYNC
    rx_usr_rdy           : std_logic;
    tx_usr_rdy           : std_logic;
    cpll_rst             : std_logic;
  end record EvrTransceiverIbType;

  constant EVR_TRANSCEIVER_IB_INIT_C : EvrTransceiverIbType := (
    tx_data              => (others => '0'),
    tx_charisk           => (others => '0'),
    drp_addr             => (others => '0'),
    drp_di               => (others => '0'),
    drp_en               => '0',
    drp_we               => '0',
    sys_clk              => '0',
    sys_rst              => '0',
    rx_rst               => '0',
    tx_rst               => '0',
    rx_usr_rdy           => '0',
    tx_usr_rdy           => '0',
    cpll_rst             => '0'
  );

end package transceiver_pkg;
