---------------------------------------------------------------------------
--
--  File        : buf_bsram_inferred.vhd
--
--  Title       : BSRAM for configurable size data buffer
--
--  Author      : Till Straumannn
--                PSI
--                <till.straumann@psi.ch>
--
--  Description : Vivado 2022.2 did not synthesize the original
--                (instantiating a RAMB16_S9_S36) correctly. It was
--                not obvious what went wrong but readback would always
--                produce x"000000" (not reproducible in simulation).
--                Anyhow, I like inferred structures better and this
--                seems to work fine...
--
--                I also removed the DOUTA/DINB/WEB ports so that
--                vivado may infer a SDP which consumes only a RAMB18E1
--                (a TDP which is inferred if the above ports are present,
--                however unused, would consume a RAMB36E1).
--
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity buf_bsram IS
  port (
    addra: IN std_logic_VECTOR(10 downto 0);
    addrb: IN std_logic_VECTOR(8 downto 0);
    clka: IN std_logic;
    clkb: IN std_logic;
    dina: IN std_logic_VECTOR(7 downto 0);
    doutb: OUT std_logic_VECTOR(31 downto 0);
    wea: IN std_logic);
end buf_bsram;

architecture inferred of buf_bsram is

   constant DEPTH_C : natural := 2048;
	
   subtype IdxType is natural range DEPTH_C - 1 downto 0;

   type MemArray is array( IdxType ) of std_logic_vector(7 downto 0);

   signal mem : MemArray := (others => (others => '0'));

begin

   P_WR : process ( clka ) is
   begin
      if ( rising_edge( clka ) ) then
         if ( wea = '1' ) then
            mem( to_integer( unsigned( addra ) ) ) <= dina;
         end if;
      end if;
   end process P_WR;

   P_RD : process ( clkb ) is
   begin
      if ( rising_edge( clkb ) ) then
		   for i in 3 downto 0 loop
            doutb( 8*i + 7 downto 8*i ) <= mem( to_integer( unsigned( addrb ) & to_unsigned(i, 2) ) );
         end loop;
      end if;
   end process P_RD;

end architecture inferred;
