library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MboxSynchronizer is
   generic (
      STAGES_G      : positive := 2;
      WIDTH_A2B_G   : natural  := 8;
      WIDTH_B2A_G   : natural  := 0;
      -- instantiate registers?
      REG_INP_A_G   : boolean  := true;
      REG_OUT_A_G   : boolean  := true;
      REG_INP_B_G   : boolean  := true;
      REG_OUT_B_G   : boolean  := true;
      REG_INI_A2B_G : std_logic_vector := "";
      REG_INI_B2A_G : std_logic_vector := ""
   );
   port (
      clka         : in  std_logic;
      -- wait for ackA = reqA; then start a new transfer by setting
      -- reqA <= not ackA
      reqA         : in  std_logic;
      ackA         : out std_logic;
      -- dinA must be held stable until ackA = reqB
      dinA         : in  std_logic_vector(WIDTH_A2B_G - 1 downto 0);
      douA         : out std_logic_vector(WIDTH_B2A_G - 1 downto 0);
      

      clkb         : in  std_logic;
      -- wait for reqB /= ackB; data are then ready to be consumed;
      -- ack to A side by setting ackB <= reqB when ready
      reqB         : out std_logic;
      ackB         : in  std_logic;
      dinB         : in  std_logic_vector(WIDTH_B2A_G - 1 downto 0) := (others => '0');
      -- optional data to be returned to A side together with the ACK cycle
      douB         : out std_logic_vector(WIDTH_A2B_G - 1 downto 0)
   );
end entity MboxSynchronizer;

architecture Impl of MboxSynchronizer is
   attribute ASYNC_REG : string;

   function ite(constant c : in boolean; constant a,b: integer) return integer is
   begin
      if ( c ) then return a; else return b; end if;
   end function ite;

   signal a2b_s : std_logic_vector(STAGES_G - 1 downto 0) := (others => '0');
   signal b2a_s : std_logic_vector(STAGES_G - 1 downto 0) := (others => '0');

   attribute ASYNC_REG of a2b_s : signal is "TRUE";
   attribute ASYNC_REG of b2a_s : signal is "TRUE";

   function INI_F(constant w : in natural; constant i : in std_logic_vector) return std_logic_vector is
      variable v : std_logic_vector(w - 1 downto 0) := (others => '0');
   begin
      if ( i'length > 0 ) then
         v := i;
      end if;
      return v;
   end function INI_F;

   signal rinA         : std_logic_vector(WIDTH_A2B_G - 1 downto 0) := INI_F(WIDTH_A2B_G, REG_INI_A2B_G);
   signal rouA         : std_logic_vector(WIDTH_B2A_G - 1 downto 0) := INI_F(WIDTH_B2A_G, REG_INI_B2A_G);

   signal rinB         : std_logic_vector(WIDTH_B2A_G - 1 downto 0) := INI_F(WIDTH_B2A_G, REG_INI_B2A_G);
   signal rouB         : std_logic_vector(WIDTH_A2B_G - 1 downto 0) := INI_F(WIDTH_A2B_G, REG_INI_A2B_G);

   signal reqA_r       : std_logic := '0';
   signal reqB_r       : std_logic := '0';
   signal ackB_r       : std_logic := '0';
   signal ackA_r       : std_logic := '0';

begin

   G_REG_INP_A : if ( REG_INP_A_G ) generate
      process ( clka ) is
      begin
         if ( rising_edge( clka ) ) then
            if ( reqA /= reqA_r ) then
               rinA <= dinA;
            end if;
            reqA_r <= reqA;
         end if;
      end process;
   end generate G_REG_INP_A;

   G_NO_REG_INP_A : if ( not REG_INP_A_G ) generate
      rinA   <= dinA;
      reqA_r <= reqA;
   end generate G_NO_REG_INP_A;

   G_REG_INP_B : if ( REG_INP_B_G ) generate
      process ( clkb ) is
      begin
         if ( rising_edge( clkb ) ) then
            if ( ackB /= ackB_r ) then
               rinB <= dinB;
            end if;
            ackB_r <= ackB;
         end if;
      end process;
   end generate G_REG_INP_B;

   G_NO_REG_INP_B : if ( not REG_INP_B_G ) generate
      rinB   <= dinB;
      ackB_r <= ackB;
   end generate G_NO_REG_INP_B;

   G_REG_OUT_A : if ( REG_OUT_A_G ) generate
      process ( clka ) is
      begin
         if ( rising_edge( clka ) ) then
            if ( b2a_s(0) /= ackA_r ) then
               rouA <= rinB;
            end if;
            ackA_r <= b2a_s(0);
         end if;
      end process;
   end generate G_REG_OUT_A;

   G_NO_REG_OUT_A : if ( not REG_OUT_A_G ) generate
      rouA <= rinB;
   end generate G_NO_REG_OUT_A;

   G_REG_OUT_B : if ( REG_OUT_B_G ) generate
      process ( clkb ) is
         variable lst : std_logic := '0';
      begin
         if ( rising_edge( clkb ) ) then
            if ( a2b_s(0) /= reqB_r ) then
               rouB <= rinA;
            end if;
            reqB_r <= a2b_s(0);
         end if;
      end process;
   end generate G_REG_OUT_B;

   G_NO_REG_OUT_B : if ( not REG_OUT_B_G ) generate
      rouB <= rinA;
   end generate G_NO_REG_OUT_B;

   P_S_A2B : process ( clkb ) is
   begin
      if ( rising_edge( clkb ) ) then
         a2b_s      <= reqA_r & a2b_s(a2b_s'left downto 1);
      end if;
   end process P_S_A2B;

   P_S_B2A : process ( clka ) is
   begin
      if ( rising_edge( clka ) ) then
         b2a_s      <= ackB_r & b2a_s(b2a_s'left downto 1);
      end if;
   end process P_S_B2A;


   ackA <= b2a_s(0);
   reqB <= a2b_s(0);

   douA <= rouA;
   douB <= rouB;

end architecture Impl;
