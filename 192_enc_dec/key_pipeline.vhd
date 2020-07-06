library ieee;
use ieee.std_logic_1164.all;
 
use ieee.numeric_std.all;
use std.textio.all;
use work.all;

entity key_pipeline is 
port (
		keybit:		out std_logic;
        clk:        in std_logic;
        round_key:      in std_logic_vector(3 downto 0);
		count_key:      in std_logic_vector(7 downto 0);
		mode:		in std_logic;
		key:		in std_logic;
		sbox_out:    in std_logic_vector(7 downto 0);
		sbox_port2: out std_logic_vector(7 downto 0)
		);
end entity key_pipeline;


architecture Behavioral of key_pipeline is

-- keypipeline related signals

signal k_p, k_n: std_logic_vector(191 downto 0); 
signal k_out: std_logic;

-- Rotate the key pipeline
procedure rotate (
	variable s : inout std_logic_vector(191 downto 0);
	variable b:	in std_logic
	) is
begin
	-- Wire AES-128 and AES-192
	s := s(190 downto 0) & b;
end rotate;

-- Swap between a and b
procedure swap (
	variable a: 	inout std_logic; 
	variable b:		inout std_logic
	) is
		variable tmp : std_logic;
begin
	tmp := a;
	a := b;
	b := tmp;
end swap;

begin

-- Output key assigment
keybit <= k_out;
sbox_port2 <= k_p(7 downto 0);

process (clk)
begin
	if clk'event and clk = '1' then
		k_p <= k_n;
	end if;
end process;

process (k_p, mode, round_key, count_key, key, sbox_out)
	variable s : std_logic_vector(191 downto 0); -- Key state
	variable nextbit:	std_logic; -- Input bit
	variable round_key_i : integer range 0 to 15; -- round_key of the key pipeline
	variable count_key_i : integer range 0 to 255; -- cycle of the key pipeline
begin
	-- Assign round_key, cycle, state and version
    round_key_i := to_integer(unsigned(round_key));
    count_key_i := to_integer(unsigned(count_key));
	s := k_p;
	k_out <= 'X';
	
	-- Input bit
    if round_key_i = 0 then
        nextbit := key;
    else
        nextbit := s(191);
    end if;
    
	-- Swap/Unswap
	if (count_key_i >= 0 and count_key_i < 8) and (round_key_i > 0) then
	    swap(s(31), nextbit);
	end if;
	if count_key_i >= 16 and count_key_i < 24 and (round_key_i > 0) then
	    swap(s(15), s(47));
	end if;
	
	-- Sbox + xor
	if not (round_key_i = 0 and count_key_i <= 8) and 
			(count_key_i = 0 or count_key_i = 8 or 
			((count_key_i = 176 or count_key_i = 184))) then
	    s(175 downto 168) := s(175 downto 168) xor sbox_out;
	end if;
	
	-- Look up Rcon table for encryption/decryption	
	if 
			(((round_key_i=0 and mode='0') or (round_key_i=7 and mode='1')) and count_key_i=176) or
	        (((round_key_i=1 and mode='0') or (round_key_i=6 and mode='1')) and count_key_i=175) or
	        (((round_key_i=2 and mode='0') or (round_key_i=5 and mode='1')) and count_key_i=174) or
	        (((round_key_i=3 and mode='0') or (round_key_i=4 and mode='1')) and count_key_i=173) or
	        (((round_key_i=4 and mode='0') or (round_key_i=3 and mode='1')) and count_key_i=172) or
	        (((round_key_i=5 and mode='0') or (round_key_i=2 and mode='1')) and count_key_i=171) or
	        (((round_key_i=6 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=170) or
	        (((round_key_i=7 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=169) then
	    s(168) := not s(168);
	end if;
			
	-- Kxor
	if (round_key_i > 0) and 
			((count_key_i <160)) and 
			(mode='0')  then
	    s(159) := s(159) xor s(191);
	end if;

	-- Decryption and-xors
	if (mode='1') and (count_key_i>=96) and (count_key_i<128) then
		nextbit := s(31) xor nextbit;
		s(31) := s(63) xor s(31);
	end if;

	-- Decryption output bit swap
	if (mode = '1') then
		if (round_key_i>0) then
			if (((round_key_i*192 + count_key_i) / 128) mod 3 = 2) then
				k_out <= s(127);
			elsif (((round_key_i*192 + count_key_i) / 128) mod 3 = 1) then
				k_out <= s(63);
			else
				k_out <= s(191);
			end if;
		else
			if (count_key_i >= 128) then
				k_out <= s(63);
			else
				k_out <= key;
			end if;
		end if;
	else
		if (round_key_i>0) then
			k_out <= s(191);
		else 
			k_out <= key;
		end if;
	end if;

	-- Decryption and-xors AES-192
	if (mode='1') and (count_key_i>=160) then
		s(127) := s(159) xor s(127);
	end if;
	if (mode='1') and (count_key_i>=32) and (count_key_i < 64) and (round_key_i>0) then
		s(63) := s(95) xor s(63);
		s(95) := s(127) xor s(95);
	end if;

	-- Rotate the pipeline
	rotate(s, nextbit);

	-- Assign state
	k_n <= s;
end process;

end architecture Behavioral;

