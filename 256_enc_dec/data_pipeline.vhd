library ieee;
use ieee.std_logic_1164.all;
 
use ieee.numeric_std.all;
use std.textio.all;
use work.all;

entity data_pipeline is 
port (
		state_exit_bit:		out std_logic;
        clk:        in std_logic;
        round:      in std_logic_vector(3 downto 0);
		count:      in std_logic_vector(6 downto 0);
		round_key:      in std_logic_vector(3 downto 0);
		count_key:      in std_logic_vector(7 downto 0); 
		mode:		in std_logic;
		newbit:		in std_logic;
		key:		in std_logic;
		last_rnd: in std_logic
		);
end entity data_pipeline;

architecture Behavioral of data_pipeline is

-- datapipeline related
signal d_p, d_n: std_logic_vector(127 downto 0); 
signal d_out, s_nextbit: std_logic;

-- keypipeline related signals
signal keybit : std_logic;

-- mix columns related signals
signal mix_first_msb, mix_first_lsb, mix_first_out, mix_second_msb, mix_second_lsb, mix_second_out, mix_third_msb, mix_third_lsb, mix_third_out: std_logic_vector(3 downto 0);
signal mix_first_reduc, mix_first_notLSB, mix_second_reduc, mix_second_notLSB, mix_third_reduc, mix_third_notLSB: std_logic; 

signal mix_first_effs_p, mix_first_effs_n, mix_second_effs_p, mix_second_effs_n, mix_third_effs_p, mix_third_effs_n: std_logic_vector(3 downto 0);

-- sbox related signals
signal sbox_port1, sbox_port2, sbox_port3, sbox_out: std_logic_vector(7 downto 0);
signal direction: std_logic;
signal sbox_sel : std_logic_vector(1 downto 0);

-- Rotate the data pipeline
procedure rotate (
	variable s : inout std_logic_vector(127 downto 0);
	variable b:	in std_logic
	) is
begin
	s := s(126 downto 0) & b;	
end rotate;

-- Make a swap between a and b
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

state_exit_bit <= d_out; -- Output bit

sbox_port1 <= d_p(6 downto 0) & s_nextbit when mode='0' else 
	d_p(126 downto 119); -- First input of the SBOX multiplexer comming from the data pipeline

mix_first: entity mixcolumns (moradi) port map (mix_first_msb, mix_first_lsb, mix_first_effs_p, mix_first_reduc, mix_first_notLSB, mix_first_out); -- Map the forward - first inverse mixcolumns component
mix_second: entity mixcolumns (moradi) port map (mix_second_msb, mix_second_lsb, mix_second_effs_p, mix_second_reduc, mix_second_notLSB, mix_second_out); -- Map the second inverse mixcolumns component
mix_third: entity mixcolumns (moradi) port map (mix_third_msb, mix_third_lsb, mix_third_effs_p, mix_third_reduc, mix_third_notLSB, mix_third_out); -- Map the third inverse mixcolumns component
s_box:      	   entity sbox (maximov)             port map(direction, sbox_sel, sbox_port1, sbox_port2, sbox_port3, sbox_out); -- Map the sbox
k_pipe: entity key_pipeline (Behavioral) port map (keybit, clk, round_key, count_key, mode, key, sbox_out, sbox_port2, sbox_port3); -- Map the key pipeline

process (clk)
begin
	if clk'event and clk = '1' then
		d_p <= d_n;
		mix_first_effs_p <= mix_first_effs_n;
		mix_second_effs_p <= mix_second_effs_n;
		mix_third_effs_p <= mix_third_effs_n;
	end if;
end process;

process (d_p,  mix_first_effs_p, mode, mix_second_effs_p, mix_third_effs_p, round, count, count_key, newbit, key, sbox_out, mix_first_out, mix_second_out, mix_third_out, keybit, last_rnd)
	variable s : std_logic_vector(127 downto 0);
	variable m1, m2, m3 : std_logic_vector(3 downto 0);
	variable v_nextbit:	std_logic; -- nextbit
	variable round_i : integer range 0 to 15; -- round of the data pipeline
	variable count_i : integer range 0 to 127; -- cycle of the data pipeline
	variable count_key_i : integer range 0 to 255; -- cycle of the key pipeline
begin
	
	-- Set the state
	s := d_p;
	m1 := mix_first_effs_p;
	m2 := mix_second_effs_p;
	m3 := mix_third_effs_p;
	sbox_sel <= "XX";
	direction <= 'X';
	mix_first_notLSB <= 'X';
	mix_second_notLSB <= 'X';
	mix_third_notLSB <= 'X';
	mix_first_lsb <= (others => 'X');
	mix_second_lsb <= (others => 'X');
	mix_third_lsb <= (others => 'X');
	mix_first_msb <= (others => 'X');
	mix_second_msb <= (others => 'X');
	mix_third_msb <= (others => 'X');
	mix_first_reduc <= 'X';
	mix_second_reduc <= 'X';
	mix_third_reduc <= 'X';

	-- Get the current round/cycle as int
	count_key_i := to_integer(unsigned(count_key));
	round_i := to_integer(unsigned(round));
   count_i := to_integer(unsigned(count));
	
	-- Modify the sbox selection input and selection forward - inverse depending on the cycle and the mode
	if count_i mod 8 = 7 then
		if mode='1' then
			direction <= '0';
		elsif mode='0' then
			direction <= '1';
		end if;
		sbox_sel <= "00";
	elsif count_i mod 8 = 0 then
		direction <= '1';
		sbox_sel <= "01";
	end if;

	-- Modify the sbox selection input depending on the version and the cycle
	if count_key_i < 184 and count_key_i >= 64 and count_key_i mod 8 = 0 then
		sbox_sel <= "10";
	elsif count_key_i mod 8 = 0 then
		sbox_sel <= "01";
	end if;
	
	-- Input bit
    if round_i = 0 then
		v_nextbit := newbit xor keybit;
    else
    	v_nextbit := s(127) xor keybit;
	end if;
	
	-- XORed input bit
	s_nextbit <= v_nextbit;
    
	-- SubByte
	if (count_i mod 8 = 7) and (count_i /= 7) and (count_i /= 39) and (count_i /= 71) and (count_i /= 103) then
		if mode='0' then
			s(6 downto 0) := sbox_out(7 downto 1);
			v_nextbit := sbox_out(0);
		else
			s(126 downto 119) := sbox_out;
		end if;
	end if;
	
	-- ShiftRows
	-- Swap d-96
	if count_i = 127 or (count_i < 7 and round_i /= 0) then
		if mode='0' then
			swap(s(6), s(102));
		else 
			swap(s(118), s(22));
		end if;
	end if;
	-- Swap d-64
	if (count_i >= 112 and count_i < 120) or (count_i >= 16 and count_i < 24 and round_i /= 0) or 
		(count_i >= 24 and count_i < 32 and round_i /= 0 and mode = '0') or
		(count_i >= 8 and count_i < 16 and round_i /= 0 and mode = '1') then
		swap(s(95), s(31));
	end if;
	-- Swap d-32
	if (((count_i>= 72 and count_i < 80) or (count_i >= 104 and count_i < 112) or (count_i >= 8 and count_i < 16 and round_i /= 0) or 
		(count_i >= 24 and count_i < 32 and round_i /= 0)) and mode = '0') or
		(((count_i>=88 and count_i < 96) or (count_i >= 120) or (count_i>=8 and count_i<16 and round_i/=0) or
		(count_i>=24 and count_i<32 and round_i /= 0)) and mode = '1') then
		swap(s(63), s(31));
	end if;

	-- Forward MixColumns / First for Inverse MixColumns
	if (((count_i >= 0 and count_i < 8) or (count_i >= 32 and count_i < 40) or (count_i >= 64 and count_i < 72) or 
		(count_i >= 96 and count_i < 104)) and round_i /= 0 and last_rnd /= '1' and mode = '0') or
		(((count_i >= 26 and count_i<34) or (count_i>=58 and count_i<66) or (count_i>=90 and count_i<98) or (count_i>=122) or 
		(count_i>=0 and count_i<2 and round_i > 1)) and round_i /= 0 and mode = '1') then

		if mode='0' then
			mix_first_msb <= s(127) & s(119) & s(111) & s(103);
			mix_first_lsb <= s(126) & s(118) & s(110) & s(102);
		else
			mix_first_msb <= s(25) & s(17) & s(9) & s(1);
			mix_first_lsb <= s(24) & s(16) & s(8) & s(0);
		end if;

		if (((count_i mod 8 = 3) or (count_i mod 8 = 4) or (count_i mod 8 = 6) or (count_i mod 8 = 7)) and mode='0') or
			(((count_i mod 8 = 0) or (count_i mod 8 = 1) or (count_i mod 8 = 5) or (count_i mod 8 = 6)) and mode='1') then
			mix_first_reduc <= '1';
		else
			mix_first_reduc <= '0';
		end if;

		if (count_i mod 8 = 7 and mode='0') or (count_i mod 8 = 1 and mode='1') then
			mix_first_notLSB <= '0';
		else
			mix_first_notLSB <= '1';
		end if;

		if (count_i mod 8 = 0 and mode='0') then
			m1 := s(127) & s(119) & s(111) & s(103);
		elsif (count_i mod 8 = 2 and mode='1') then
			m1 := s(25) & s(17) & s(9) & s(1);
		end if;

		if mode = '0' then
			s(127) := mix_first_out(3);
			s(119) := mix_first_out(2);
			s(111) := mix_first_out(1);
			s(103) := mix_first_out(0);

			v_nextbit := s(127) xor keybit;
			s_nextbit <= v_nextbit;
		else 
			s(25) := mix_first_out(3);
			s(17) := mix_first_out(2);
			s(9) := mix_first_out(1);
			s(1) := mix_first_out(0);
		end if;
	end if;
	
	-- Second for Inverse MixColumns
	if((count_i >= 28 and count_i < 36) or (count_i>=60 and count_i<68) or (count_i>=92 and count_i < 100) or 
		(count_i>=124) or (count_i>=0 and count_i<4 and round_i > 1)) and round_i /= 0 and mode='1' then
		
		mix_second_msb <= s(27) & s(19) & s(11) & s(3);
		mix_second_lsb <= s(26) & s(18) & s(10) & s(2);
		
		if (count_i mod 8 = 0) or (count_i mod 8 = 2) or (count_i mod 8 = 3) or (count_i mod 8 = 7) then
			mix_second_reduc <= '1';
		else
			mix_second_reduc <= '0';
		end if;

		if count_i mod 8 = 3 then
			mix_second_notLSB <= '0';
		else
			mix_second_notLSB <= '1';
		end if;

		if count_i mod 8 = 4 then
			m2 := s(27) & s(19) & s(11) & s(3);
		end if;

		s(27) := mix_second_out(3);
		s(19) := mix_second_out(2);
		s(11) := mix_second_out(1);
		s(3) := mix_second_out(0);
	end if;

	-- Third for Inverse MixColumns
	if((count_i >= 30 and count_i < 38) or (count_i>=62 and count_i<70) or (count_i>=94 and count_i < 102) or 
		(count_i>=126) or (count_i>=0 and count_i<6 and round_i > 1)) and round_i /= 0 and mode='1' then
		
		mix_third_msb <= s(29) & s(21) & s(13) & s(5);
		mix_third_lsb <= s(28) & s(20) & s(12) & s(4);
		
		if (count_i mod 8 = 1) or (count_i mod 8 = 2) or (count_i mod 8 = 4) or (count_i mod 8 = 5) then
			mix_third_reduc <= '1';
		else
			mix_third_reduc <= '0';
		end if;

		if count_i mod 8 = 5 then
			mix_third_notLSB <= '0';
		else
			mix_third_notLSB <= '1';
		end if;

		if count_i mod 8 = 6 then
			m3 := s(29) & s(21) & s(13) & s(5);
		end if;

		s(29) := mix_third_out(3);
		s(21) := mix_third_out(2);
		s(13) := mix_third_out(1);
		s(5) := mix_third_out(0);
	end if;

	-- SubByte
	if count_i mod 8 = 7 and (count_i = 7 or count_i = 39 or count_i = 71 or count_i = 103) then
		if mode='0' then
			s(6 downto 0) := sbox_out(7 downto 1);
			v_nextbit := sbox_out(0);
		else
			s(126 downto 119) := sbox_out;
		end if;
	end if;

	-- Output bit assignment
	if (round_i>0) then
		d_out <= s(127) xor keybit;
	else 
		d_out <= newbit xor keybit;
	end if;

	-- Rotation of the pipeline
	rotate(s, v_nextbit);

	-- State assignment
	d_n <= s;
	
	mix_first_effs_n <= m1;
	mix_second_effs_n <= m2;
	mix_third_effs_n <= m3;

end process;

end architecture Behavioral;
