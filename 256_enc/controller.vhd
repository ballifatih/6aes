library ieee;
use ieee.std_logic_1164.all;
 
use ieee.numeric_std.all;
use std.textio.all;
use work.all;

entity controller is 
port (  
        round:	    	out std_logic_vector(3 downto 0);
        count:       out std_logic_vector(6 downto 0);    
        round_key:	out std_logic_vector(3 downto 0);  
        count_key:   out std_logic_vector(7 downto 0);
        done:        out std_logic;
        last_rnd:    out std_logic;
        clk:         in std_logic;
        rst:         in std_logic
        );
end entity;

architecture Behavioral of controller is

    signal rnd_p                : std_logic_vector(3 downto 0);
    signal cnt_p                : std_logic_vector(6 downto 0);
    signal merged_counter_n     : std_logic_vector(11 downto 0);
    signal merged_counter_p     : std_logic_vector(11 downto 0);  
    signal merged_counter_plus  : std_logic_vector(11 downto 0);  

begin

   -- We should prefer synchronous rst signal
   -- it helps when we want to later use it in AEAD circuits
   
   process (clk)
   begin
      if rising_edge(clk) then
         merged_counter_p <= merged_counter_n;
      end if;
   end process;
   
   done <= '1' when cnt_p = "1111111" and rnd_p = "1101" else '0';
   last_rnd <= '1' when rnd_p = "1110" else '0';
   
   process (merged_counter_p)
      variable ctr: integer range 0 to 4095;
   begin
      ctr := (to_integer(unsigned(merged_counter_p)) + 1) mod 4096;
      merged_counter_plus <= std_logic_vector(to_unsigned(ctr, merged_counter_plus'length));
   end process;
   
   merged_counter_n <= (others => '0') when rst = '0' else merged_counter_plus;
      
   rnd_p <= merged_counter_p(10 downto 7);
   cnt_p <= merged_counter_p(6 downto 0);
   round <= rnd_p;
   count <= cnt_p;
   round_key <= merged_counter_p(11 downto 8);
   count_key <= merged_counter_p(7 downto 0);

end architecture;
