library std;
use std.textio.all;
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use work.all;

entity tb_aes is
end tb_aes;

architecture tb of tb_aes is   

	constant clock_cycle  : time:= 100 ns;
	
	file vector_file      : TEXT;	

   signal ct             : std_logic;
   signal pt             : std_logic;
   signal clk            : std_logic;
   signal rst            : std_logic;
   signal done           : std_logic;
   signal key            : std_logic;
   signal mode           : std_logic;
   
	component AES 
       port (  
        ct:	    	out std_logic;
        done:     out std_logic;
        clk:      in std_logic;
        rst:      in std_logic;
        pt:       in std_logic;
        key:      in std_logic;		
        mode:		in std_logic);
	end component AES;

begin

	mut: AES port map (ct, done, clk, rst, pt, key, mode);

	process
	begin
		clk <= '1'; wait for clock_cycle/2;
		clk <= '0'; wait for clock_cycle/2;
	end process;

	process
		variable tmp_line            : line;
        variable mode_v              : std_logic;
        variable key192              : std_logic_vector(191 downto 0);
		  variable pt128               : std_logic_vector(127 downto 0);
        variable ct128               : std_logic_vector(127 downto 0);
        variable buffer128           : std_logic_vector(127 downto 0);
        variable test_ctr            : integer range 0 to 1000000; -- can fail if too many vectors
        variable loading_ctr         : integer range 0 to 255; -- can fail if too many vectors
        variable reading_ctr         : integer range 0 to 127; -- can fail if too many vectors
	begin
		file_open(vector_file, "test_vectors_192_enc_dec.txt", read_mode);
      test_ctr := 1;		

		while not (endfile(vector_file)) loop
            
            -- we first read a single test vector from a file
            readline(vector_file, tmp_line);     read(tmp_line, mode_v); -- read mode
            readline(vector_file, tmp_line);	    hread(tmp_line, pt128);
            readline(vector_file, tmp_line);	    hread(tmp_line, key192);
			   readline(vector_file, tmp_line);	    hread(tmp_line, ct128);
            -- reading a single test vector is done

            rst <= '0';
            mode <= mode_v;
            wait until rising_edge(clk);
            
            rst <= '1';
            loading_ctr := 0;
		      loading_loop: loop
		         if loading_ctr <= 127 then -- load pt only in the first 128 cycles always
		            pt <= pt128(127-loading_ctr);
		         end if;
		         
               key <= key192(191 - loading_ctr);
               if loading_ctr = 191 then
                  exit loading_loop;
               end if;
                  		         
		         loading_ctr := loading_ctr + 1;   
		         wait until rising_edge(clk);
		      end loop;
         
         
         waiting_loop: loop
            wait until rising_edge(clk);
            if done = '1' then -- done signals indicates that the encryption/decryption is almost over, and the result will be available during the following 128 cycles
               exit waiting_loop;
            end if;
         end loop;
         wait until rising_edge(clk); -- wait until the next rising_edge
         
         reading_ctr := 0;
         reading_loop: loop
            buffer128(127 - reading_ctr) := ct;
            if reading_ctr = 127 then 
               exit reading_loop;
            end if;
            reading_ctr := reading_ctr + 1;
            wait until rising_edge(clk);
         end loop;
			
			assert buffer128 = ct128 report "======>>> DOES NOT MATCH <<<======" severity failure;
			report "passed vector #: " & integer'image(test_ctr); 
			test_ctr := test_ctr + 1;
			
		end loop;
		assert false report ">>> ALL GOOD <<<" severity failure;
		wait;
	end process;
end tb;
