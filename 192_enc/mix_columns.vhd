library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.all;

entity mixcolumns is 
    port ( 
            A: in std_logic_vector(3 downto 0);
            B: in std_logic_vector(3 downto 0);
            REG: in std_logic_vector(3 downto 0);
            modRec: in std_logic;
            notLSB: in std_logic;
            OUTP: out std_logic_vector(3 downto 0));
end entity mixcolumns;

-- Taken from Bitsling

architecture moradi of mixcolumns is 
      signal R0, R1, R2, R3: std_logic;
      signal D0, D1, D2, D3: std_logic;
      signal E0, E1, E2, E3: std_logic;
begin  

    -- AND layer
    R0 <= REG(3) and modRec;
    R1 <= REG(2) and modRec;
    R2 <= REG(1) and modRec;
    R3 <= REG(0) and modRec;

    -- XOR-AND layer
    D0 <= R0 xor (B(3) and notLSB) xor A(2);
    D1 <= R1 xor (B(2) and notLSB) xor A(1);
    D2 <= R2 xor (B(1) and notLSB) xor A(0);
    D3 <= R3 xor (B(0) and notLSB) xor A(3);

    -- XOR layer
    E0 <= D0 xor D1 xor A(0);
    E1 <= D1 xor D2 xor A(3);
    E2 <= D2 xor D3 xor A(2);
    E3 <= D3 xor D0 xor A(1);
    
    OUTP(3) <= E0;
    OUTP(2) <= E1;
    OUTP(1) <= E2;
    OUTP(0) <= E3;

end architecture;