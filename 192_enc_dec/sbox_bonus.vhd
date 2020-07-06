library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.all;

entity sbox is 
    port ( 
            INV: in std_logic; -- ZF=1 forward ZF=0 inverse
            SEL: in std_logic;
            INP1: in std_logic_vector(7 downto 0);
            INP2: in std_logic_vector(7 downto 0);
            OUP : out std_logic_vector(7 downto 0));
end entity sbox;

-- Taken from Maximov's CHES 2019 paper
-- The "bonus" version

architecture maximov of sbox is 
    signal A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12: std_logic;
    signal Q15, Q4, Q0, Q14, Q3, Q1, Q6, Q8, Q9, Q2, Q10, Q7, Q12, Q11, Q5, Q13, Q17, Q16: std_logic; 
    signal H0, H1, H2, H4, H6, H7, H20, H8, H9, H10, H12, H15, H16, H19: std_logic;
    signal S4, S2, S14, S1, S0, S5, S11, S6, S12, S7, S3, S15, S13: std_logic;
    signal R0, R1, R2, R3, R4, R5, R6, R7: std_logic;
    signal T0, T1, T2, T3, T4, T10, T11, T12, T13, T20, T21, T22, X0, X1, X2, X3, Y0, Y1, Y2, Y3 : std_logic;
    signal Y00, Y01, Y02, Y13, Y23, N0, N1, N2, N3, N4, N5, N6, N7, N8, N9, N10, N11, N12, N13, N14, N15, N16, N17 : std_logic;
    signal U0, U1, U2, U3, U4, U5, U6, U7 : std_logic;
    signal ZF: std_logic;
begin  

    -- multiplexer input
    U0 <= INP1(7) when SEL = '0' else
          INP2(7);
    U1 <= INP1(6) when SEL = '0' else
          INP2(6);
    U2 <= INP1(5) when SEL = '0' else
          INP2(5);
    U3 <= INP1(4) when SEL = '0' else
          INP2(4);
    U4 <= INP1(3) when SEL = '0' else
          INP2(3);
    U5 <= INP1(2) when SEL = '0' else
          INP2(2);
    U6 <= INP1(1) when SEL = '0' else
          INP2(1);
    U7 <= INP1(0) when SEL = '0' else
          INP2(0);

    ZF <= INV;
    
    -- below: edited and pasted from the paper

    -- ctop.b
    A0 <= U3 xnor U6;
    Q15 <= U1 xnor ZF;
    A1 <= U5 xor Q15;
    A2 <= U2 xor A0;
    A3 <= U4 xor A1;
    A4 <= U4 xor U6;
    A5 <= A2 when ZF = '1' else A4; -- MUX(ZF, A2, A4)
    Q4 <= A3 xnor A5;
    Q0 <= U0 xor Q4;
    Q14 <= Q15 xor Q0;
    A6 <= U0 xnor U2;
    Q3 <= ZF xor A6;
    Q1 <= Q4 xor Q3;
    A7 <= U1 when ZF = '1' else Q0; -- MUX(ZF, U1, Q0)
    Q6 <= A5 xnor A7;
    Q8 <= Q3 xor Q6;
    A8 <= Q1 when ZF = '1' else A4; -- MUX(ZF, Q1, A4)
    Q9 <= U6 xor A8;
    Q2 <= Q8 xor Q9;
    Q10 <= Q4 xor Q9;
    Q7 <= Q6 xor Q10;
    A9 <= A0 when ZF = '1' else U4; -- MUX(ZF, A0, U4)
    Q12 <= U7 xnor A9;
    Q11 <= Q0 xor Q12;
    A10 <= A6 when ZF = '1' else Q12; -- MUX(ZF, A6, Q12)
    A11 <= A2 xor A10;
    A12 <= A4 xor A11;
    Q5 <= Q0 xor A12;
    Q13 <= Q11 xor A12;
    Q17 <= Q14 xor A12;
    Q16 <= Q14 xor Q13;

    -- mulx.a
    T20 <= Q6 nand Q12;
    T21 <= Q3 nand Q14;
    T22 <= Q1 nand Q16;
    T10 <= (Q3 nor Q14) xor (Q0 nand Q7);
    T11 <= (Q4 nor Q13) xor (Q10 nand Q11);
    T12 <= (Q2 nor Q17) xor (Q5 nand Q9);
    T13 <= (Q8 nor Q15) xor (Q2 nand Q17);

    X0 <= T10 xor (T20 xor T22);
    X1 <= T11 xor (T21 xor T20);
    X2 <= T12 xor (T21 xor T22);
    X3 <= T13 xor (T21 xor (Q4 nand Q13));


    -- inv.a
    T0 <= X0 nand X2;
    T1 <= X1 nor X3;
    T2 <= T0 xnor T1;

    Y0 <= T2 when X2 = '1' else X3; -- MUX(X2, T2, X3);
    Y2 <= T2 when X0 = '1' else X1; -- MUX(X0, T2, X1);
    T3 <= X2 when X1 = '1' else '1'; -- MUX(X1, X2, 1);
    Y1 <= X3 when T2 = '1' else T3; -- MUX(T2, X3, T3);
    T4 <= X0 when X3 = '1' else '1'; -- MUX(X3, X0, 1);
    Y3 <= X1 when T2 = '1' else T4; -- MUX(T2, X1, T4)

    -- s0. a
        -- calls inv.a;
    Y02 <= Y2 xor Y0;
    Y13 <= Y3 xor Y1;
    Y23 <= Y3 xor Y2;
    Y01 <= Y1 xor Y0;
    Y00 <= Y02 xor Y13;


    -- File: muln.a;
    N0 <= Y01 nand Q11;
    N1 <= Y0 nand Q12;
    N2 <= Y1 nand Q0;
    N3 <= Y23 nand Q17;
    N4 <= Y2 nand Q5;
    N5 <= Y3 nand Q15;
    N6 <= Y13 nand Q14;

    N7  <= Y00 nand Q16;
    N8  <= Y02 nand Q13;
    N9  <= Y01 nand Q7;
    N10 <= Y0 nand Q10;
    N11 <= Y1 nand Q6;
    N12 <= Y23 nand Q2;
    N13 <= Y2 nand Q9;
    N14 <= Y3 nand Q8;

    N15 <= Y13 nand Q3;
    N16 <= Y00 nand Q1;
    N17 <= Y02 nand Q4;

    -- cbot.b;
    H0 <= N9 xor N10;
    H1 <= N16 xor H0;
    H2 <= N4 xor N5;
    S4 <= N7 xor (N8 xor H2);
    H4 <= N0 xor N2;
    H6 <= N15 xor H1;
    H7 <= H4 xor (N3 xor N5);
    H20 <= H6 xor ZF;
    S2 <= H20 xor H7;
    S14 <= S4 xor H7;
    H8 <= N13 xor H0;
    H9 <= N12 xor H8;
    S1 <= H20 xor H9;
    H10 <= N17 xor H1;
    H12 <= H2 xor (N1 xor N2);
    S0 <= H6 xor H12;
    S5 <= N6 xor (H9 xor (N8 xor H4));
    S11 <= H12 xor S5;
    S6 <= S1 xor S11;
    H15 <= N14 xor H10;
    H16 <= H8 xor H15;
    S12 <= S5 xor H16;
    S7 <= S4 xnor (H10 xor (N9 xor N11));
    H19 <= H7 xnor S7;
    S3 <= H16 xor H19;
    S15 <= S11 xor H19;
    S13 <= S4 xor (N12 xor H15);
    R0 <= S0;
    R1 <= S1;
    R2 <= S2;
    R3 <= S3 when ZF = '1' else S11; -- MUX(ZF, S3, S11)
    R4 <= S4 when ZF = '1' else S12; -- MUX(ZF, S4, S12)
    R5 <= S5 when ZF = '1' else S13; -- MUX(ZF, S5, S13)
    R6 <= S6 when ZF = '1' else S14; -- MUX(ZF, S6, S14)
    R7 <= S7 when ZF = '1' else S15; -- MUX(ZF, S7, S15)

    -- end of copying
    
    
    OUP(7) <= R0;
    OUP(6) <= R1;
    OUP(5) <= R2;
    OUP(4) <= R3;
    OUP(3) <= R4;
    OUP(2) <= R5;
    OUP(1) <= R6;
    OUP(0) <= R7;

end architecture;