library IEEE;
use IEEE.Std_logic_1164.all;
USE IEEE.STD_LOGIC_ARITH.all;

USE work.graphics_pkg.all;

entity generator_tb is
end;

architecture bench of generator_tb is

  component generator
  	PORT(
  			    vert_sync, enable, reset	    : IN STD_LOGIC;
            difficulty						        : IN STD_LOGIC_VECTOR(1 downto 0);
            rand_num						          : IN STD_LOGIC_VECTOR(4 downto 0);
      
            score_flag						        : OUT STD_LOGIC;
            obj_cols_top, obj_cols_bot		: OUT OBJ_COLS;
            obj_rows_top, obj_rows_bot		: OUT OBJ_ROWS;
            object_type						        : OUT OBJ_TYPES;
            obj_colour_r				        	: OUT OBJ_COLOURS 	:= (others => (others => '0'));
            obj_colour_g				        	: OUT OBJ_COLOURS 	:= (others => (others => '0'));
            obj_colour_b				        	: OUT OBJ_COLOURS 	:= (others => (others => '0'))
          );
  end component;

  signal vert_sync, enable, reset       : STD_LOGIC;
  signal difficulty                     : STD_LOGIC_VECTOR(1 downto 0);
  signal rand_num                       : STD_LOGIC_VECTOR(4 downto 0);
  signal score_flag						          : STD_LOGIC;
  signal obj_cols_top, obj_cols_bot		  : OBJ_COLS;
  signal obj_rows_top, obj_rows_bot		  : OBJ_ROWS;
  signal object_type				            : OBJ_TYPES;
  signal obj_colour_r					          : OBJ_COLOURS 	:= (others => (others => '0'));
  signal obj_colour_g					          : OBJ_COLOURS 	:= (others => (others => '0'));
  signal obj_colour_b					          : OBJ_COLOURS 	:= (others => (others => '0'));

begin

  uut: generator port map ( 
                            vert_sync     => vert_sync,
                            enable        => enable,
                            reset         => reset,
                            difficulty    => difficulty,
                            rand_num      => rand_num,

                            score_flag    => score_flag,

                            obj_cols_top  => obj_cols_top,
                            obj_cols_bot  => obj_cols_bot,
                            obj_rows_top  => obj_rows_top,
                            obj_rows_bot  => obj_rows_bot,

                            object_type   => object_type,
                            obj_colour_r  => obj_colour_r,
                            obj_colour_g  => obj_colour_g,
                            obj_colour_b  => obj_colour_b);

    vert_sync_gen: process
    begin
        vert_sync <= '0';
        wait for 5 ns;
        vert_sync <= '1';
        wait for 5 ns;
    end process vert_sync_gen;

    stimulus: process
    begin
        rand_num <= CONV_STD_LOGIC_VECTOR(29, 5);
        difficulty <= "00";
        enable <= '1'; --, '0' after 100 ns, '1' after 200 ns;
        reset <= '0'; --, '1' after 130 ns, '0' after 135 ns, '1' after 230 ns, '0' after 235 ns;
    wait;
    end process;


end;