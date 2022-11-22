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
      rxbufstatus           : std_logic_vector( 2 downto 0);
      txoutclk              : std_logic;
      txrefclk              : std_logic;
      txdlyadjen            : std_logic;
      txresetdone           : std_logic;
      usrOut                : std_logic_vector(63 downto 0);
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
      rxbufreset            : std_logic;
      rxusrrdy              : std_logic;
      rxcommaalignen        : std_logic;
      txpippmen             : std_logic;
      txpippmstepsize       : std_logic_vector(4 downto 0);

      txusrclk              : std_logic;
      gttxreset             : std_logic;
      txusrrdy              : std_logic;
      txdata                : std_logic_vector(15 downto 0);
      txcharisk             : std_logic_vector( 1 downto 0);
      usrInp                : std_logic_vector(63 downto 0);
   end record transceiver_ib_type;

end package transceiver_pkg;
