---------------------------------------------------------------------------
--
--  File        : transceiver_pkg.vhd
--
--  Title       : Event Transceiver Multi-Gigabit Transceiver Interface Package
--
--  Author      : Jukka Pietarinen
--                Micro-Research Finland Oy
--                <jukka.pietarinen@mrf.fi>
--
---------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

package transceiver_pkg is

   -- bundle signals that originate in the transceiver module
   type transceiver_ob_type is record
      -- PLL
      cpll_locked           : std_logic;
      drpclk                : std_logic;
      drpdo                 : std_logic_vector(15 downto 0);
      drprdy                : std_logic;
      drpbsy                : std_logic;

      rxdata                : std_logic_vector(15 downto 0);
      rxcharisk             : std_logic_vector( 1 downto 0);
      rxdisperr             : std_logic_vector( 1 downto 0);
      rxnotintable          : std_logic_vector( 1 downto 0);
      rxcdrlocked           : std_logic;
      rxresetdone           : std_logic;
      rxrecclk              : std_logic;

      txbufstatus           : std_logic_vector( 1 downto 0);
      txusrclk              : std_logic;
      txdlyadjen            : std_logic;
   end record transceiver_ob_type;

   -- bundle signals that go into the transceiver module
   type transceiver_ib_type is record
      mgtreset              : std_logic;
      cpll_reset            : std_logic;

      drpaddr               : std_logic_vector(8 downto 0);
      drpdi                 : std_logic_vector(15 downto 0);
      drpen                 : std_logic;
      drpwe                 : std_logic;

      gtrxreset             : std_logic;
      rxusrrdy              : std_logic;

      gttxreset             : std_logic;
      txusrrdy              : std_logic;
      txdata                : std_logic_vector(15 downto 0);
      txcharisk             : std_logic_vector( 1 downto 0);
   end record transceiver_ib_type;
end package transceiver_pkg;

