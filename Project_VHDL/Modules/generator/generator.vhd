-- GENERATOR
-- IN: Tracker
-- OUT: Graphics

-- The Generator module generates the background layout and obstacles
-- using simple alogorithms and RNG, and outputs a raster of the
-- composite image.
-- Output is in the format of 480xNx4 columns, where N is the number of
-- pixel columns to be sent each frame. N increases with speed. The 4
-- layers take the form of RGB and a one-bit collision flag layer.

-- The Tracker module stores the current difficulty, which influences:
-- * Background colour scheme (and perhaps pattern)
-- * Obstacle (barrier) patterns and frequency
-- * Obstacle (barrier) colour scheme and sprite shape
-- * Pickup frequency and type

-- New generation begins when the previous buffer clears (is shifted out).
-- As the speed varies, generation will be irregular, and on-demand. 
-- There is a blank space between each obstacle column, so generation
-- does not have to be continuous (we have the time to repopulate the
-- buffer before needing to shift it out again).

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
			object_type						: OUT obj_type 		:= (others => (others => '0'));
			object_colour					: OUT obj_colour 	:= (others => (others => '0'));
			q_out							: OUT obj_mem		:= (others => OBJ_POS_ALL_ZERO)
        );
END ENTITY generator;

ARCHITECTURE behaviour OF generator IS

	-- Loads a set of positon data into the next memory array
	PROCEDURE LOAD_OBJ
        (   
			VARIABLE obj_data_pos 		: IN obj_pos;
			VARIABLE obj_data_type		: IN obj_type_packet;
			VARIABLE obj_data_colour	: IN font_colour_packet;
			VARIABLE mem_index 			: INOUT INTEGER;
			SIGNAL object_pos_mem 		: OUT obj_mem;
			SIGNAL object_type			: OUT obj_type;
			SIGNAL object_colour 		: OUT obj_colour
        ) IS

    BEGIN 
		object_pos_mem(mem_index) 	<= obj_data_pos;
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
			VARIABLE speed 			: IN STD_LOGIC_VECTOR(9 downto 0);
			VARIABLE mem_index 		: IN INTEGER;
			SIGNAL object_pos_mem 	: INOUT obj_mem
        ) IS

		VARIABLE current_obj	: obj_pos := OBJ_POS_ALL_ZERO;
    BEGIN 
		FOR index IN (object_pos_mem'length - 1) downto 0 LOOP
			IF (object_pos_mem(index) /= OBJ_POS_ALL_ZERO) THEN
				current_obj := object_pos_mem(index);

				-- Bin objects which have left the screen.
				IF (current_obj(1) <= 0) THEN
					current_obj := OBJ_POS_ALL_ZERO;
				ELSE
					-- Col of top coordinate remains at SCREEN_LEFT
					-- When it has reached SCREEN_LEFT and beyond
					-- (not within 0 to SCREEN_RIGHT)
					IF (current_obj(3) /= 0 OR not(current_obj(3) <= SCREEN_RIGHT)) THEN
						current_obj(3) := current_obj(3) - speed;
					END IF;
					-- Col of bottem coordinate remains at SCREEN_RIGHT 
					-- until PIP_WIDTH have been reached.
					IF (SCREEN_RIGHT - current_obj(3) > PIPE_WIDTH) THEN
						current_obj(1) := current_obj(1) - speed;
					END IF;
				END IF;
				object_pos_mem(index) <= current_obj;
			END IF;
		END LOOP;
    END PROCEDURE UPDATE_OBJ;

	SIGNAL object_pos_mem 						: obj_mem 	:= (others => OBJ_POS_ALL_ZERO);
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

		VARIABLE dis_counter					: STD_LOGIC_VECTOR(9 downto 0) := CONV_STD_LOGIC_VECTOR(DIS_BETWEEN_PIPE, 10);
		-- pixel/ver_sync
		VARIABLE speed 							: STD_LOGIC_VECTOR(9 downto 0) := CONV_STD_LOGIC_VECTOR(DEFAULT_SPEED, 10);
	BEGIN

		IF (reset = '1') THEN
			object_pos_mem <= (others => OBJ_POS_ALL_ZERO);
			speed := CONV_STD_LOGIC_VECTOR(DEFAULT_SPEED, 10);
		END IF;

		IF (RISING_EDGE(vert_sync) AND enable = '1') THEN
			-- Update object
			-- To do: Speed change based on difficulty.
			dis_counter := dis_counter + speed;
			UPDATE_OBJ(speed, mem_index, object_pos_mem);

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
							object_pos_mem, object_type, object_colour);	
				LOAD_OBJ(
							pipe_bot, pipe_bot_type, pipe_bot_colour, 
							mem_index,
							object_pos_mem, object_type, object_colour);	
			END IF;
		END IF;

		q_out <= object_pos_mem;

	END PROCESS OBJ_CREATION;

	
	UNPACK: PROCESS(object_pos_mem)
	BEGIN
		FOR index IN (object_pos_mem'length - 1) downto 0 LOOP
			obj_cols_top(index) <= object_pos_mem(index)(3);
			obj_rows_top(index) <= object_pos_mem(index)(2);
			obj_cols_bot(index) <= object_pos_mem(index)(1);
			obj_rows_bot(index) <= object_pos_mem(index)(0);
		END LOOP;
	END PROCESS UNPACK;

END ARCHITECTURE behaviour;