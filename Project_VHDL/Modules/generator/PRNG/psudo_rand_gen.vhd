-- This componet is a Pseudo Random Number Generator (PRNG) implemented as a Galois Linear Feedback Shift Register (LFSR)
-- Input:
    -- seed - A non-zero value as the intial input value.
    -- gen - Control signal for shift register to shift right. Generates new output values.
    -- enable - When high, RNG commences.
    --        - When low, holds current output q.
    -- reset - Asynchronous reset to seed value.
-- Output: 
    -- q - Must uses the (0) feedback value as the most random output.


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

ENTITY psudo_rand_gen IS
	PORT(   seed	                :	IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		    enable, gen, reset	    : 	IN STD_LOGIC;
            q                       :	OUT STD_LOGIC
	    );
END psudo_rand_gen;

ARCHITECTURE beh OF psudo_rand_gen IS
    SIGNAL q_i : STD_LOGIC_VECTOR (9 DOWNTO 0)  := CONV_STD_LOGIC_VECTOR(0, 10);
BEGIN

    q <= q_i(0);

    shift: PROCESS (gen, enable, reset, seed) is
        VARIABLE temp_tap1 : STD_LOGIC;
    BEGIN

        IF (RISING_EDGE(gen)) THEN
            IF (reset = '1') THEN
                q_i <= seed;
            END IF;

            IF (enable = '1') THEN
                
                -- 10bit right shift register, tap[7, 0]=tapmask=0010000001, with 1023 Cycle period.
                    q_i(9) <= q_i(0);
                    temp_tap1 := q_i(7) xor q_i(0);

                    q_i(8 downto 0) <= q_i(9 downto 1);
                    q_i(6) <= temp_tap1;

                -- Zero value protection
                IF (q_i = CONV_STD_LOGIC_VECTOR(0, q_i'length)) THEN
                    IF (seed = CONV_STD_LOGIC_VECTOR(0, q_i'length)) THEN
                        q_i <= "1001000000"; -- Arbitary seed value;
                    ELSE
                        q_i <= seed;
                    END IF;
                END IF;            
            END IF;
        END IF;
    END PROCESS;

END beh; 