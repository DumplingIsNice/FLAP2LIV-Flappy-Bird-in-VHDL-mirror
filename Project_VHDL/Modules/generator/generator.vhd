-- GENERATOR

--	Authors:		Hao Lin
--	Date:			May 2021
--	Course:		CS305 Miniproject

--	In:				TRACKER		(difficulty parameters and state control 
-- 								 signals to control object generation)
-- 					RAND_NUM 	(5-bit random number for random elements)
--					VGA_SYNC	(vert_sync as object update signal)
-- 						NOTE: This module is driven by vert_sync.
--
--	Out:			GENERATOR_BUFFER (To be held constant for a screen refresh)

-- 						NOTE: q_out - An internal memory array. 
--							  Output for debugging purposes in modelsim.

--	Summary

-- The Generator module generates the background layout and obstacles
-- using simple alogorithms and RNG, and outputs a queue of the
-- composite image.

-- Output queues is in the format of OBJ_QUEUE_LENGTHx1 pixel 
-- pixel columns to be sent each frame. Where each idex position
-- corresponds to a object whihc exist. The content of each position
-- is a 10-bit value of the corner coordinates of the object's 
-- position on screen. This position (in pairs of top and bottem
-- coordinates) is phased by GRAPHICS to draw the object.

-- The colour queue take the format of OBJ_QUEUE_LENGTHxFONT_COLOUR_PACKET.
-- FOR GRAPHIC display.

-- The type queue tke the format of OBJ_QUEUE_LENGTHxTYPE_PACKET. 
-- For COLLISION calculation.

-- See GRAPHICS_PKG for more information on font queues and packets

-- TRACKER's RELATIONSHIP

-- The TRACKER module stores the current difficulty, which influences:
	-- * Background colour scheme (and perhaps pattern)
	-- * Obstacle (barrier) patterns and frequency
	-- * Obstacle (barrier) colour scheme and sprite shape
	-- * Pickup frequency and type
-- In this GENERATION module.

-- New generation begins when the screen is refreshed (vert_sync).
-- As the speed varies, generation will be irregular, and on-demand. 
-- There is a blank space between each obstacle column, so generation
-- does not have to be continuous (we have the time to repopulate the
-- buffer before each refresh).

-- NOTE: For more complex sprites it may be cheaper to have a pool of mapped,
-- pre-defined bitmaps for objects, rather than trying to generate with vectors.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.all;
USE IEEE.STD_LOGIC_ARITH.all;
USE IEEE.STD_LOGIC_UNSIGNED.all;

USE work.graphics_pkg.all;

ENTITY generator IS
	PORT(
			vert_sync, enable, reset		: IN STD_LOGIC;
			difficulty						: IN STD_LOGIC;
			rand_num						: IN STD_LOGIC_VECTOR(4 downto 0);

			obj_cols_top, obj_cols_bot		: OUT OBJ_COLS		:= (others => (others => '0'));
			obj_rows_top, obj_rows_bot		: OUT OBJ_ROWS		:= (others => (others => '0'));
			object_type						: OUT OBJ_TYPE 		:= (others => (others => '0'));
			object_colour					: OUT OBJ_COLOUR 	:= (others => (others => '0'))
        );
END ENTITY generator;

ARCHITECTURE behaviour OF generator IS

	-- Loads a set of positon data into the next memory array
	PROCEDURE LOAD_OBJ
        (   
			VARIABLE obj_data_pos 								: IN obj_pos;
			VARIABLE obj_data_type								: IN obj_type_packet;
			VARIABLE obj_data_colour							: IN font_colour_packet;
			VARIABLE mem_index 									: INOUT INTEGER;
			SIGNAL top_cols, top_rows, bot_cols, bot_rows 		: OUT obj_cols;
			SIGNAL object_type									: OUT obj_type;
			SIGNAL object_colour 								: OUT obj_colour
        ) IS

    BEGIN 
		top_cols(mem_index) 		<= obj_data_pos(3);
		top_rows(mem_index) 		<= obj_data_pos(2);
		bot_cols(mem_index) 		<= obj_data_pos(1);
		bot_rows(mem_index) 		<= obj_data_pos(0);
		
		object_type(mem_index)		<= obj_data_type;
		object_colour(mem_index) 	<= obj_data_colour;

        IF (mem_index = 0) THEN
			mem_index := OBJ_QUEUE_LENGTH;
        ELSE
			mem_index := mem_index - 1;
        END IF;

    END PROCEDURE LOAD_OBJ;

	-- Updates the col value of all non-zero item of the memory array
	PROCEDURE UPDATE_OBJ
        (   
			VARIABLE speed 										: IN STD_LOGIC_VECTOR(9 downto 0);
			VARIABLE mem_index 									: IN INTEGER;
			SIGNAL top_cols, top_rows, bot_cols, bot_rows 		: INOUT obj_cols
        ) IS

		VARIABLE current_obj	: obj_pos := OBJ_POS_ALL_ZERO;
    BEGIN 
		FOR index IN (OBJ_QUEUE_LENGTH) downto 0 LOOP
			IF  (
					not(top_cols(index) = TEN_BIT_ALL_ZERO AND
						top_rows(index) = TEN_BIT_ALL_ZERO AND
						bot_cols(index) = TEN_BIT_ALL_ZERO AND
						bot_rows(index) = TEN_BIT_ALL_ZERO)
				) THEN

				-- From obj_pos TYPE in graphics_pkg.vhd:
				-- (3, 2) = top coordinate (col, row), (1, 0) = bot coordinate (col, row)

				-- Bin objects which have left the screen.
				IF (bot_cols(index) <= TEN_BIT_ALL_ZERO) THEN
					top_cols(index) <= TEN_BIT_ALL_ZERO;
					top_rows(index) <= TEN_BIT_ALL_ZERO;
					bot_cols(index) <= TEN_BIT_ALL_ZERO;
					bot_rows(index) <= TEN_BIT_ALL_ZERO;
				ELSE
					-- Col of top coordinate remains at SCREEN_LEFT
					-- When it has reached SCREEN_LEFT and beyond
					-- (not within 0 to SCREEN_RIGHT)
					IF (top_cols(index) /= 0 OR not(top_cols(index) <= SCREEN_RIGHT)) THEN
						top_cols(index) <= top_cols(index) - speed;
					END IF;
					-- Col of bottem coordinate remains at SCREEN_RIGHT 
					-- until PIP_WIDTH have been reached.
					IF ((SCREEN_RIGHT - top_cols(index)) >= PIPE_WIDTH) THEN
						bot_cols(index) <= bot_cols(index) - speed;
					END IF;
				END IF;
			END IF;
		END LOOP;
    END PROCEDURE UPDATE_OBJ;

	SIGNAL top_cols, top_rows, bot_cols, bot_rows 	: obj_cols 	:= 	OBJ_COLS_ALL_ZERO;
BEGIN
	-- Object generation
	-- Interesting problem: Results always seemed to be delayed b 1/T. Yet it scales with T.
	OBJ_CREATION: PROCESS(vert_sync, reset, enable)
		VARIABLE pipe_top, pipe_bot 				: obj_pos 						:= OBJ_POS_ALL_ZERO;
		VARIABLE gap_top, gap_bot, gap_pos			: STD_LOGIC_VECTOR(9 downto 0) 	:= CONV_STD_LOGIC_VECTOR(0, 10);
		VARIABLE pipe_top_type, pipe_bot_type		: obj_type_packet				:= PIPE_TYPE;
		VARIABLE pipe_top_colour, pipe_bot_colour	: obj_type_packet				:= PIPE_COLOUR;
		VARIABLE intermediate 						: STD_LOGIC_VECTOR(11 downto 0) := CONV_STD_LOGIC_VECTOR(0, 12);

		VARIABLE mem_index : INTEGER := OBJ_QUEUE_LENGTH;

		VARIABLE dis_counter						: STD_LOGIC_VECTOR(9 downto 0) 	:= CONV_STD_LOGIC_VECTOR(DIS_BETWEEN_PIPE, 10);
		-- pixel/ver_sync
		VARIABLE speed 								: STD_LOGIC_VECTOR(9 downto 0) 	:= CONV_STD_LOGIC_VECTOR(DEFAULT_SPEED, 10);
	BEGIN

		IF (reset = '1') THEN
			top_cols <= OBJ_COLS_ALL_ZERO;
			top_rows <= OBJ_COLS_ALL_ZERO;
			bot_cols <= OBJ_COLS_ALL_ZERO;
			bot_rows <= OBJ_COLS_ALL_ZERO;
			speed := CONV_STD_LOGIC_VECTOR(DEFAULT_SPEED, 10);
			mem_index := OBJ_QUEUE_LENGTH;
			dis_counter := CONV_STD_LOGIC_VECTOR(DIS_BETWEEN_PIPE, 10);
		END IF;

		IF (RISING_EDGE(vert_sync) AND enable = '1') THEN
			-- Update object
			-- To do: Speed change based on difficulty.
			dis_counter := dis_counter + speed;
			UPDATE_OBJ(speed, mem_index, top_cols, top_rows, bot_cols, bot_rows);

			-- Pipe Creation
			IF (dis_counter >= CONV_STD_LOGIC_VECTOR(DIS_BETWEEN_PIPE, 10)) THEN
				dis_counter := CONV_STD_LOGIC_VECTOR(0, 10);

				-- Calculate pipe gap position
				intermediate := rand_num * GAP_FACTOR; -- Intermediate mulplication container register
				gap_pos := intermediate(9 downto 0); -- Tested
				
				gap_top := gap_pos + BORDER_MARGIN;
				gap_bot := gap_top + GAP_HEIGHT;

				-- From obj_pos TYPE in graphics_pkg.vhd:
				-- (3, 2) = top coordinate (col, row), (1, 0) = bot coordinate (col, row)
				pipe_top(3) 	:= SCREEN_RIGHT; 
				pipe_top(2) 	:= SCREEN_TOP;
				pipe_top(1) 	:= SCREEN_RIGHT;
				pipe_top(0) 	:= gap_top; -- Top of gap to bottem coordinate of top pipe.
				pipe_top_type 	:= PIPE_TYPE;
				pipe_top_colour := PIPE_COLOUR;

				pipe_bot(3) 	:= SCREEN_RIGHT; 
				pipe_bot(2) 	:= gap_bot; -- Bottem of gap to top coordinate of bottem pipe.
				pipe_bot(1) 	:= SCREEN_RIGHT;
				pipe_bot(0) 	:= SCREEN_BOT; 
				pipe_bot_type 	:= "0001";
				pipe_bot_colour := "0001";

				-- Load real positional data into memory
				LOAD_OBJ(
							pipe_top, pipe_top_type, pipe_top_colour, 
							mem_index, 
							top_cols, top_rows, bot_cols, bot_rows,
							object_type, object_colour);	
				LOAD_OBJ(
							pipe_bot, pipe_bot_type, pipe_bot_colour, 
							mem_index,
							top_cols, top_rows, bot_cols, bot_rows,
							object_type, object_colour);	
			END IF;
		END IF;
	END PROCESS OBJ_CREATION;

	
	UNPACK: PROCESS(top_cols, top_rows, bot_cols, bot_rows)
	BEGIN
		FOR index IN (OBJ_QUEUE_LENGTH) downto 0 LOOP
			obj_cols_top(index) <= top_cols(index);
			obj_rows_top(index) <= top_rows(index);
			obj_cols_bot(index) <= bot_cols(index);
			obj_rows_bot(index) <= bot_rows(index);
		END LOOP;
	END PROCESS UNPACK;

END ARCHITECTURE behaviour;