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
		version:	in std_logic_vector(1 downto 0);
		mode:		in std_logic;
		key:		in std_logic;
		sbox_out:    in std_logic_vector(7 downto 0);
		sbox_port2: out std_logic_vector(7 downto 0);
		sbox_port3: out std_logic_vector(7 downto 0)
		);
end entity key_pipeline;


architecture Behavioral of key_pipeline is

-- keypipeline related signals
constant ZERO_128 : std_logic_vector(127 downto 0) := (others => 'X'); -- 0 cte for wiring AES-128
constant ZERO_192 : std_logic_vector(63 downto 0) := (others => 'X'); -- 0 cte for wiring AES-192

signal k_p, k_n: std_logic_vector(255 downto 0); 
signal k_out: std_logic;

-- Rotate the key pipeline
procedure rotate (
	variable s : inout std_logic_vector(255 downto 0);
	variable v: in std_logic_vector(1 downto 0);
	variable b:	in std_logic
	) is
begin
	-- Wire AES-128 and AES-192
	if v = "00" then
		s := s(254 downto 192) & s(63) & ZERO_128 & s(62 downto 0) & b;
	elsif v = "01" then
		s := s(254 downto 128) & s(63) & ZERO_192 & s(62 downto 0) & b;
	else
		s := s(254 downto 0) & b;	
	end if;
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
sbox_port3 <= k_p(15 downto 8);

process (clk)
begin
	if clk'event and clk = '1' then
		k_p <= k_n;
	end if;
end process;

process (k_p, version, mode, round_key, count_key, key, sbox_out)
	variable s : std_logic_vector(255 downto 0); -- Key state
	variable nextbit:	std_logic; -- Input bit
	variable round_key_i : integer range 0 to 15; -- round_key of the key pipeline
	variable count_key_i : integer range 0 to 255; -- cycle of the key pipeline
	variable ver : std_logic_vector(1 downto 0); -- version
begin
	-- Assign round_key, cycle, state and version
    round_key_i := to_integer(unsigned(round_key));
    count_key_i := to_integer(unsigned(count_key));
	s := k_p;
	k_out <= 'X';
	ver := version;
	
	-- Input bit
    if round_key_i = 0 then
        nextbit := key;
    else
        nextbit := s(255);
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
			((count_key_i = 112 or count_key_i = 120) and version = "00") or 
			((count_key_i = 176 or count_key_i = 184) and version = "01") or 
			((count_key_i = 240 or count_key_i = 248) and version = "10")) then
	    s(239 downto 232) := s(239 downto 232) xor sbox_out;
	end if;
	-- Second sbox + xor AES-256
	if (round_key_i > 0) and (version = "10") and (count_key_i = 112 or count_key_i = 120 or count_key_i = 128 or count_key_i = 136) then
		s(239 downto 232) := s(239 downto 232) xor sbox_out;
	end if;
	
	-- Look up Rcon table for encryption/decryption	
	if 
			(((round_key_i=0 and mode='0') or (round_key_i=9 and mode='1')) and count_key_i=112 and version="00") or 
			(((round_key_i=1 and mode='0') or (round_key_i=8 and mode='1')) and count_key_i=111 and version="00") or 
			(((round_key_i=2 and mode='0') or (round_key_i=7 and mode='1')) and count_key_i=110 and version="00") or 
			(((round_key_i=3 and mode='0') or (round_key_i=6 and mode='1')) and count_key_i=109 and version="00") or 
			(((round_key_i=4 and mode='0') or (round_key_i=5 and mode='1')) and count_key_i=108 and version="00") or
	        (((round_key_i=5 and mode='0') or (round_key_i=4 and mode='1')) and count_key_i=107 and version="00") or
	        (((round_key_i=6 and mode='0') or (round_key_i=3 and mode='1')) and count_key_i=106 and version="00") or
	        (((round_key_i=7 and mode='0') or (round_key_i=2 and mode='1')) and count_key_i=105 and version="00") or
	        (((round_key_i=8 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=112 and version="00") or
	        (((round_key_i=8 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=111 and version="00") or
	        (((round_key_i=8 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=109 and version="00") or
	        (((round_key_i=8 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=108 and version="00") or
	        (((round_key_i=9 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=111 and version="00") or
	        (((round_key_i=9 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=110 and version="00") or
	        (((round_key_i=9 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=108 and version="00") or
			(((round_key_i=9 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=107 and version="00") or
			(((round_key_i=0 and mode='0') or (round_key_i=7 and mode='1')) and count_key_i=176 and version="01") or
	        (((round_key_i=1 and mode='0') or (round_key_i=6 and mode='1')) and count_key_i=175 and version="01") or
	        (((round_key_i=2 and mode='0') or (round_key_i=5 and mode='1')) and count_key_i=174 and version="01") or
	        (((round_key_i=3 and mode='0') or (round_key_i=4 and mode='1')) and count_key_i=173 and version="01") or
	        (((round_key_i=4 and mode='0') or (round_key_i=3 and mode='1')) and count_key_i=172 and version="01") or
	        (((round_key_i=5 and mode='0') or (round_key_i=2 and mode='1')) and count_key_i=171 and version="01") or
	        (((round_key_i=6 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=170 and version="01") or
	        (((round_key_i=7 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=169 and version="01") or
	        (((round_key_i=0 and mode='0') or (round_key_i=6 and mode='1')) and count_key_i=240 and version="10") or
	        (((round_key_i=1 and mode='0') or (round_key_i=5 and mode='1')) and count_key_i=239 and version="10") or
	        (((round_key_i=2 and mode='0') or (round_key_i=4 and mode='1')) and count_key_i=238 and version="10") or
	        (((round_key_i=3 and mode='0') or (round_key_i=3 and mode='1')) and count_key_i=237 and version="10") or
	        (((round_key_i=4 and mode='0') or (round_key_i=2 and mode='1')) and count_key_i=236 and version="10") or
	        (((round_key_i=5 and mode='0') or (round_key_i=1 and mode='1')) and count_key_i=235 and version="10") or
	        (((round_key_i=6 and mode='0') or (round_key_i=0 and mode='1')) and count_key_i=234 and version="10") then
	    s(232) := not s(232);
	end if;
			
	-- Kxor
	if (round_key_i > 0) and 
			((count_key_i <96 and version /= "01") or (count_key_i <160 and version = "01")) and 
			(mode='0')  then
	    s(223) := s(223) xor s(255);
	end if;
	if (round_key_i > 0) and 
			(count_key_i >=128) and (count_key_i <224) and (version = "10") and 
			(mode='0')  then
	    s(223) := s(223) xor s(255);
	end if;

	-- Decryption and-xors
	if (mode='1') and (version /= "10") and (count_key_i>=96) and (count_key_i<128) then
		nextbit := s(31) xor nextbit;
		s(31) := s(63) xor s(31);
		if (version = "00") then
			s(63) := s(223) xor s(63);
		end if;
	end if;
	if (mode='1') and (version = "10") and (((count_key_i>=224) and (count_key_i<256)) or ((count_key_i>=96) and (count_key_i<128) and (round_key_i > 0))) then
		s(127) := s(159) xor s(127);
		s(159) := s(191) xor s(159);
		s(191) := s(223) xor s(191);
	end if;

	-- Decryption output bit swap
	if (version = "01") and (mode = '1') then
		if (round_key_i>0) then
			if (((round_key_i*192 + count_key_i) / 128) mod 3 = 2) then
				k_out <= s(191);
			elsif (((round_key_i*192 + count_key_i) / 128) mod 3 = 1) then
				k_out <= s(63);
			else
				k_out <= s(255);
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
			k_out <= s(255);
		else 
			k_out <= key;
		end if;
	end if;

	-- Decryption and-xors AES-192
	if (version = "01") and (mode='1') and (count_key_i>=160) then
		s(191) := s(223) xor s(191);
	end if;
	if (version = "01") and (mode='1') and (count_key_i>=32) and (count_key_i < 64) and (round_key_i>0) then
		s(63) := s(159) xor s(63);
		s(159) := s(191) xor s(159);
	end if;

	-- Rotate the pipeline
	rotate(s, ver, nextbit);

	-- Assign state
	k_n <= s;
end process;

end architecture Behavioral;

