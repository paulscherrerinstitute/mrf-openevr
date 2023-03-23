---------------------------------------------------------------------------
--
--  File        : databuf_rx_dc.vhd
--
--  Title       : Data memory buffer to receive a configurable size
--                segmented data buffer from EVG
--
--  Author      : Jukka Pietarinen
--                Micro-Research Finland Oy
--                <jukka.pietarinen@mrf.fi>
--
--  Description :
--
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.evr_pkg.all;
--LIBRARY UNISIM;
--use UNISIM.VCOMPONENTS.ALL;

entity databuf_rx_dc is
  generic (
    MARK_DEBUG_ENABLE : string := "FALSE"
  );
  port (
    -- Memory buffer RAMB read interface (clk domain)
    clk               : in std_logic;
    data_out          : out std_logic_vector(31 downto 0);
    size_data_out     : out std_logic_vector(31 downto 0);
    addr_in           : in std_logic_vector(10 downto 2);
    
    -- Data stream interface (event_clk domain)
    event_clk         : in std_logic;
    databuf_data      : in std_logic_vector(7 downto 0);
    databuf_k         : in std_logic;
    databuf_ena       : in std_logic;

    -- Databuf outbound stream interface;
    -- someone may be interested in picking out snippets of
    -- the databuf as it is streamed into the memory
    databuf_strm_data : out std_logic_vector( 7 downto 0);
    databuf_strm_addr : out std_logic_vector(10 downto 0);
    databuf_strm_vld  : out std_logic;

    delay_comp_update : out std_logic;
    delay_comp_rx     : out std_logic_vector(31 downto 0);
    delay_comp_status : out std_logic_vector(31 downto 0);
    topology_addr     : out std_logic_vector(31 downto 0);

    -- Control interface (clk domain)
    irq_out           : out std_logic;
    sirq_ena          : in std_logic_vector(0 to 127);

    -- Control interface (event_clk domain)
    rx_flag           : out std_logic_vector(0 to 127);
    cs_flag           : out std_logic_vector(0 to 127);
    ov_flag           : out std_logic_vector(0 to 127);
    clear_flag        : in std_logic_vector(0 to 127);
    reset             : in std_logic
    );
end databuf_rx_dc;

architecture implementation of databuf_rx_dc is

  attribute MARK_DEBUG    : string;

  signal rx_addr          : std_logic_vector(10 downto 0);
  signal rx_data          : std_logic_vector(7 downto 0);
  signal seg_addr         : std_logic_vector(9 downto 0);
  signal rx_size          : std_logic_vector(15 downto 0);
  signal wr_size          : std_logic;
  signal size_data_int_i  : std_logic_vector(31 downto 0);
  signal size_data_int    : std_logic_vector(15 downto 0);
  
  signal we_A             : std_logic;
  signal delay_comp_cyc   : std_logic_vector(4 downto 0);

  signal rx_flag_i        : std_logic_vector(0 to 127);
  signal cs_flag_i        : std_logic_vector(0 to 127);
  signal ov_flag_i        : std_logic_vector(0 to 127);

  signal read_segment     : integer range 0 to 127;

  signal gnd              : std_logic;
  signal gnd32            : std_logic_vector(31 downto 0);
  signal vcc              : std_logic;

  attribute MARK_DEBUG of databuf_data: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of databuf_k: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of databuf_ena: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_addr: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_data: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of we_A: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of seg_addr: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of rx_size: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of wr_size: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of delay_comp_cyc: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of addr_in: signal is MARK_DEBUG_ENABLE;
  attribute MARK_DEBUG of size_data_int: signal is MARK_DEBUG_ENABLE;
 
  component buf_bsram IS
    port (
      addra: IN std_logic_VECTOR(10 downto 0);
      addrb: IN std_logic_VECTOR(8 downto 0);
      clka: IN std_logic;
      clkb: IN std_logic;
      dina: IN std_logic_VECTOR(7 downto 0);
      doutb: OUT std_logic_VECTOR(31 downto 0);
      wea: IN std_logic);
  end component;

  component DPRAM_2k_16_16_ecp2m IS
    port (
      DOA   : out std_logic_vector(15 downto 0);
      DOB   : out std_logic_vector(15 downto 0);
      ADDRA : in  std_logic_vector(9 downto 0);
      ADDRB : in  std_logic_vector(9 downto 0);
      CLKA  : in  std_logic;
      CLKB  : in  std_logic;
      DIA   : in  std_logic_vector(15 downto 0);
      DIB   : in  std_logic_vector(15 downto 0);
      WEA   : in  std_logic;
      WEB   : in  std_logic);
  end component;

  component RAMB36E1 is
    generic (

    DOA_REG : integer := 0;
    DOB_REG : integer := 0;
    EN_ECC_READ : boolean := FALSE;
    EN_ECC_WRITE : boolean := FALSE; 
    INITP_00 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_01 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_02 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_03 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_04 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_05 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_06 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_07 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_08 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_09 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_0A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
      INITP_0B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_0C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_0D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_0E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INITP_0F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_00 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_01 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_02 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_03 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_04 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_05 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_06 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_07 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_08 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_09 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_0A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_0B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_0C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_0D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_0E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_0F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_10 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_11 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_12 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_13 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_14 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_15 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_16 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_17 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_18 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_19 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_1A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_1B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_1C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_1D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_1E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_1F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_20 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_21 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_22 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_23 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_24 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_25 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_26 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_27 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_28 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_29 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_2A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_2B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_2C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_2D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_2E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_2F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_30 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_31 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_32 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_33 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_34 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_35 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_36 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_37 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_38 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_39 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_3A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_3B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_3C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_3D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_3E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_3F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_40 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_41 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_42 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_43 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_44 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_45 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_46 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_47 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_48 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_49 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_4A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_4B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_4C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_4D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_4E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_4F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_50 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_51 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_52 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_53 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_54 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_55 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_56 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_57 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_58 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_59 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_5A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_5B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_5C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_5D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_5E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_5F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_60 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_61 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_62 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_63 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_64 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_65 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_66 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_67 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_68 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_69 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_6A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_6B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_6C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_6D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_6E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_6F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_70 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_71 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_72 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_73 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_74 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_75 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_76 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_77 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_78 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_79 : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_7A : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_7B : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_7C : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_7D : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_7E : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_7F : bit_vector := X"0000000000000000000000000000000000000000000000000000000000000000";
    INIT_A : bit_vector := X"000000000";
    INIT_B : bit_vector := X"000000000";
    INIT_FILE : string := "NONE";
    IS_CLKARDCLK_INVERTED : std_ulogic := '0';
    IS_CLKBWRCLK_INVERTED : std_ulogic := '0';
    IS_ENARDEN_INVERTED : std_ulogic := '0';
    IS_ENBWREN_INVERTED : std_ulogic := '0';
    IS_RSTRAMARSTRAM_INVERTED : std_ulogic := '0';
    IS_RSTRAMB_INVERTED : std_ulogic := '0';
    IS_RSTREGARSTREG_INVERTED : std_ulogic := '0';
    IS_RSTREGB_INVERTED : std_ulogic := '0';
    RAM_EXTENSION_A : string := "NONE";
    RAM_EXTENSION_B : string := "NONE";
    RAM_MODE : string := "TDP";
    RDADDR_COLLISION_HWCONFIG : string := "DELAYED_WRITE";
    READ_WIDTH_A : integer := 0;
    READ_WIDTH_B : integer := 0;
    RSTREG_PRIORITY_A : string := "RSTREG";
    RSTREG_PRIORITY_B : string := "RSTREG";
    SIM_COLLISION_CHECK : string := "ALL";
    SIM_DEVICE : string := "VIRTEX6";
    SRVAL_A : bit_vector := X"000000000";
    SRVAL_B : bit_vector := X"000000000";
    WRITE_MODE_A : string := "WRITE_FIRST";
    WRITE_MODE_B : string := "WRITE_FIRST";
    WRITE_WIDTH_A : integer := 0;
    WRITE_WIDTH_B : integer := 0
    
  );
port (

    CASCADEOUTA : out std_ulogic;
    CASCADEOUTB : out std_ulogic;
    DBITERR : out std_ulogic;
    DOADO : out std_logic_vector(31 downto 0);
    DOBDO : out std_logic_vector(31 downto 0);
    DOPADOP : out std_logic_vector(3 downto 0);
    DOPBDOP : out std_logic_vector(3 downto 0);
    ECCPARITY : out std_logic_vector(7 downto 0);
    RDADDRECC : out std_logic_vector(8 downto 0);
    SBITERR : out std_ulogic;
    
    ADDRARDADDR : in std_logic_vector(15 downto 0);
    ADDRBWRADDR : in std_logic_vector(15 downto 0);
    CASCADEINA : in std_ulogic;
    CASCADEINB : in std_ulogic;
    CLKARDCLK : in std_ulogic;
    CLKBWRCLK : in std_ulogic;
    DIADI : in std_logic_vector(31 downto 0);
    DIBDI : in std_logic_vector(31 downto 0);
    DIPADIP : in std_logic_vector(3 downto 0);
    DIPBDIP : in std_logic_vector(3 downto 0);
    ENARDEN : in std_ulogic;
    ENBWREN : in std_ulogic;
    INJECTDBITERR : in std_ulogic;
    INJECTSBITERR : in std_ulogic;
    REGCEAREGCE : in std_ulogic;
    REGCEB : in std_ulogic;
    RSTRAMARSTRAM : in std_ulogic;
    RSTRAMB : in std_ulogic;
    RSTREGARSTREG : in std_ulogic;
    RSTREGB : in std_ulogic;
    WEA : in std_logic_vector(3 downto 0);
    WEBWE : in std_logic_vector(7 downto 0)

  );
  end component;

begin

  gnd <= '0';
  gnd32 <= (others => '0');
  vcc <= '1';
  
  i_ramb0 : buf_bsram
    port map (
      addra => rx_addr,
      addrb => addr_in,
      clka => event_clk,
      clkb => clk,
      dina => rx_data,
      doutb => data_out,
      wea => we_A);

  databuf_strm_data <= rx_data;
  databuf_strm_addr <= rx_addr;
  databuf_strm_vld  <= we_A;

  bram_0 : RAMB36E1
    generic map (
      READ_WIDTH_A => 18,
      READ_WIDTH_B => 18,
      WRITE_WIDTH_A => 18,
      WRITE_WIDTH_B => 18)
    port map (
      DOADO => size_data_int_i,
      DOBDO => open,
      DOPADOP => open,
      DOPBDOP => open,
      ADDRARDADDR(15 downto 13) => gnd32(2 downto 0),
      ADDRARDADDR(12 downto 4) => addr_in,
      ADDRARDADDR(3 downto 0) => gnd32(3 downto 0),
      ADDRBWRADDR(15 downto 14) => gnd32(1 downto 0),
      ADDRBWRADDR(13 downto 4) => seg_addr,
      ADDRBWRADDR(3 downto 0) => gnd32(3 downto 0),
      CASCADEINA => gnd,
      CASCADEINB => gnd,
      CASCADEOUTA => open,
      CASCADEOUTB => open,
      CLKARDCLK => clk,
      CLKBWRCLK => event_clk,
      DBITERR => open,
      DIADI => gnd32(31 downto 0),
      DIBDI(15 downto 0) => rx_size,
      DIBDI(31 downto 16) => gnd32(31 downto 16),
      DIPADIP => gnd32(3 downto 0),
      DIPBDIP => gnd32(3 downto 0),
      ECCPARITY => open,
      ENARDEN => vcc,
      ENBWREN => vcc,
      INJECTDBITERR => gnd,
      INJECTSBITERR => gnd,
      RDADDRECC => open,
      REGCEAREGCE => vcc,
      REGCEB => vcc,
      RSTRAMARSTRAM => gnd,
      RSTRAMB => gnd,
      RSTREGARSTREG => gnd,
      RSTREGB => gnd,
      SBITERR => open,
      WEA => gnd32(3 downto 0),
      WEBWE(0) => wr_size,
      WEBWE(1) => wr_size,
      WEBWE(2) => gnd,
      WEBWE(3) => gnd,
      WEBWE(4) => gnd,
      WEBWE(5) => gnd,
      WEBWE(6) => gnd,
      WEBWE(7) => gnd);

  size_data_int <= size_data_int_i(size_data_int'range);

  size_data_out(31 downto 16) <= (others => '0');
  size_data_out(15 downto 0) <= size_data_int(15 downto 0);

  reception : process (event_clk, databuf_data, databuf_k, databuf_ena,
		       reset, delay_comp_cyc, rx_flag_i, cs_flag_i, ov_flag_i)
    variable data_ena       : std_logic;
    variable address_cycle  : std_logic;
    variable running        : std_logic;
    variable address        : std_logic_vector(12 downto 0);
    variable bytecnt        : std_logic_vector(11 downto 0);
    variable wordcnt        : std_logic_vector(11 downto 2);
    variable checksum       : std_logic_vector(15 downto 0);
    variable rx_checksum    : std_logic_vector(15 downto 0);
    variable addr_decode    : std_logic_vector(2 downto 0);
    variable dc_value_in    : std_logic_vector(31 downto 0);
    variable dc_status_in   : std_logic_vector(31 downto 0);
    variable topology_in    : std_logic_vector(31 downto 0);
    variable segment        : integer range 0 to 127;
    variable clear_flag_i   : std_logic_vector(0 to 127);

    attribute MARK_DEBUG of data_ena : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of address_cycle : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of running : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of address : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of bytecnt : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of addr_decode : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of dc_value_in : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of topology_in : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of rx_checksum : variable is MARK_DEBUG_ENABLE;
    attribute MARK_DEBUG of checksum : variable is MARK_DEBUG_ENABLE;

  begin
    rx_flag <= rx_flag_i;
    cs_flag <= cs_flag_i;
    ov_flag <= ov_flag_i;

    if event_clk'event and event_clk = '1' then
      we_A <= '0';
      wr_size <= '0';
      delay_comp_update <= '0';
      if databuf_ena = '1' then
	rx_data <= databuf_data;
	if databuf_k = '1' then
	  if databuf_data = X"5C" then -- K28.2 start segmented data
	    address := (others => '0');
            bytecnt := (others => '0');
	    checksum := (others => '1');
	    running := '1';
            address_cycle := '1';
	    data_ena := '1';
	  end if;
	  if databuf_data = X"3C" and running = '1' then -- K28.1 end data
	    wordcnt := address(11 downto 2);
	    address := "1000000000000";
	    data_ena := '0';
            rx_size(15 downto 12) <= (others => '0');
            rx_size(11 downto 0) <= bytecnt;
            wr_size <= '1';
	  end if;
	else
	  if running = '1' then
            if delay_comp_cyc(delay_comp_cyc'high) = '1' then
              if delay_comp_cyc(3 downto 2) = "11" then
                dc_value_in := dc_value_in(23 downto 0) & databuf_data;
              end if;
              if delay_comp_cyc(3 downto 2) = "10" then
                dc_status_in := dc_status_in(23 downto 0) & databuf_data;
              end if;
              if delay_comp_cyc(3 downto 2) = "00" then
                topology_in := topology_in(23 downto 0) & databuf_data;
              end if;
              delay_comp_cyc <= delay_comp_cyc - 1;
            end if;
            if address_cycle = '1' then
              checksum := checksum - databuf_data;
              address(10 downto 4) := databuf_data(6 downto 0);
              address(3 downto 0) := "0000";
              seg_addr <= "000" & address(10 downto 4);
              segment := conv_integer(address(10 downto 4));
              address_cycle := '0';
              if databuf_data = X"FF" then
                delay_comp_cyc <= "11111";
              end if;
            else
              rx_addr <= address(10 downto 0);
              if data_ena = '1' then
                we_A <= '1';
                bytecnt := bytecnt + 1;
                checksum := checksum - databuf_data;
                if rx_flag_i(segment) = '1' then
                  ov_flag_i(segment) <= '1';
                end if;
              end if;
              addr_decode := address(12) & address(1 downto 0);
              case addr_decode is
                when "100"  => rx_checksum(15 downto 8) := databuf_data;
                when "101"  => rx_checksum(7 downto 0) := databuf_data;
                when "110"  => running := '0';
--                               if rx_flag_i(segment) = '1' then
--                                 ov_flag_i(segment) <= '1';
--                               end if;
                               rx_flag_i(segment) <= '1';
                               if rx_checksum /= checksum then
                                 cs_flag_i(segment) <= '1';
                               else
                                 if delay_comp_cyc = "01111" then
                                   delay_comp_rx <= dc_value_in;
                                   delay_comp_status <= dc_status_in;
                                   delay_comp_cyc <= "00000";
                                   delay_comp_update <= '1';
                                   topology_addr <= topology_in;
                                 end if;
                               end if;
                when others =>
              end case;
              address := address + 1;
            end if;
	  end if;
        end if;
      end if;

      for i in clear_flag_i'low to clear_flag_i'high loop
        if clear_flag_i(i) = '1' then
          rx_flag_i(i) <= '0';
          cs_flag_i(i) <= '0';
          ov_flag_i(i) <= '0';
        end if;
      end loop;

      clear_flag_i := clear_flag;
      
      if reset = '1' then
        address_cycle := '0';
	running := '0';
	data_ena := '0';
        delay_comp_cyc <= "00000";
        rx_flag_i <= (others => '0');
        cs_flag_i <= (others => '0');
        ov_flag_i <= (others => '0');
        delay_comp_rx <= (others => '0');
        topology_addr <= (others => '0');
      end if;

    end if;
  end process;

  interrupt : process (clk, rx_flag_i, sirq_ena)
    variable irq : std_logic;
  begin
    if rising_edge(clk) then
      irq_out <= irq;
      irq := '0';
      for i in sirq_ena'low to sirq_ena'high loop
        if sirq_ena(i) = '1' and rx_flag_i(i) = '1' then
          irq := '1';
        end if;
      end loop;
    end if;
  end process;

end implementation;
