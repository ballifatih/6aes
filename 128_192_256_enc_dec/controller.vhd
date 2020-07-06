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
        rst:         in std_logic;
        version: 	   in std_logic_vector(1 downto 0)
        );
end entity;

architecture Behavioral of controller is

    signal cnt_p                : integer range 0 to 127;
    signal rnd_p                : integer range 0 to 15;

    signal cnt_key_p, cnt_key_n : integer range 0 to 255;
    signal rnd_key_p, rnd_key_n : integer range 0 to 15;
    

begin

   -- We should prefer synchronous rst signal
   -- it helps when we want to later use it in AEAD circuits
   
   process (clk)
   begin
      if rising_edge(clk) then
         cnt_key_p <= cnt_key_n;
         rnd_key_p <= rnd_key_n;
      end if;
   end process;
   
   done <= '1' when cnt_p = 127 and ((version="00" and rnd_p = 9) or (version="01" and rnd_p = 11) or (version="10" and rnd_p = 13)) else '0';
   last_rnd <= '1' when (version="00" and rnd_p = 10) or (version="01" and rnd_p = 12) or (version="10" and rnd_p = 14) else '0';
   
   process (rst, version, cnt_key_p, rnd_key_p)
   begin

      rnd_key_n <= rnd_key_p;
      cnt_key_n <= cnt_key_p;
      
      
      if version = "00" then
         cnt_key_n <= (cnt_key_p + 1) mod 128;
      elsif version = "01" then
         cnt_key_n <= (cnt_key_p + 1) mod 192;
      else 
         cnt_key_n <= (cnt_key_p + 1) mod 256;
      end if;

      if version = "00" and cnt_key_p = 127 then
         rnd_key_n <= (rnd_key_p + 1) mod 16;
      elsif version = "01" and cnt_key_p = 191 then
         rnd_key_n <= (rnd_key_p + 1) mod 16;
      elsif cnt_key_p = 255 then
         rnd_key_n <= (rnd_key_p + 1) mod 16;
      end if;
   
      -- of course if reset signal is low-active, it should overwrite everything
      if rst = '0' then
         cnt_key_n <= 0;
         rnd_key_n <= 0;
      end if;
   end process;
   
   process (version, cnt_key_p, rnd_key_p)
      variable total_cycles  : integer range 0 to 8191; -- should never take more than ~2k clock cycles anyway
   begin

      if version = "00" then
         total_cycles := (rnd_key_p*128 + cnt_key_p) mod 2048;
      elsif version = "01" then
         total_cycles := (rnd_key_p*192 + cnt_key_p) mod 2048;
      else
         total_cycles := (rnd_key_p*256 + cnt_key_p) mod 2048;
      end if;
      
      rnd_p <= total_cycles / 128;
      cnt_p <= total_cycles mod 128;

   end process;
   
   round <= std_logic_vector(to_unsigned(rnd_p, 4));
   count <= std_logic_vector(to_unsigned(cnt_p, 7));
   round_key <= std_logic_vector(to_unsigned(rnd_key_p, 4));
   count_key <= std_logic_vector(to_unsigned(cnt_key_p, 8));

end architecture;
