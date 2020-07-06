library ieee;
use ieee.std_logic_1164.all;
 
use ieee.numeric_std.all;
use std.textio.all;
use work.all;

entity AES is 
port (  ct:	    	out std_logic;
        done:     out std_logic;
        clk:      in std_logic;
        rst:      in std_logic;
        pt:       in std_logic;
        key:      in std_logic;		
        mode:		in std_logic;
		version: 	in std_logic_vector(1 downto 0)
    );
end entity;

architecture Behavioral of AES is

    -- pipeline related signals		
    signal state_exit_bit, last_rnd : std_logic;
    signal round, round_key         :   std_logic_vector(3 downto 0);
    signal count                    :   std_logic_vector(6 downto 0);
    signal count_key                :   std_logic_vector(7 downto 0);

begin

    ct <= state_exit_bit;

    data_pipeline0:	entity data_pipeline (Behavioral) port map(state_exit_bit, clk, round, count, round_key, count_key, mode, version, pt, key, last_rnd);
    controller0:     entity controller (Behavioral)    port map(round, count, round_key, count_key, done, last_rnd, clk, rst, version);

end architecture;
