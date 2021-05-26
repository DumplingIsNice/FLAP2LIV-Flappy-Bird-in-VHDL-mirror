-- TRACKER
-- IN: Controls, Collision
-- OUT: Generator, GUI

-- The Tracker module stores and updates game information.
-- This includes the bird's lives, the score, the time,
-- difficulty stage, active effects, game state, etc.

-- The Tracker receives pause/unpause commands from the Controller,
-- changing the game's state, and collision events from the
-- Collision module, with which it can apply damage or pickup
-- effects.

-- The Tracker then sends this information to the GUI to display,
-- and to the generator as arguments (the generator needs to know
-- the current difficulty when generating obstacles and landscapes,
-- and must be disabled to pause the game).


LIBRARY IEEE;
USE  IEEE.NUMERIC_STD.all;
USE  IEEE.STD_LOGIC_1164.all;

USE work.graphics_pkg.all;

ENTITY tracker IS
	PORT (
		clk, vert_sync					: IN STD_LOGIC;
		reset_button, pause_button	: IN STD_LOGIC;
		enable_game_start				: IN STD_LOGIC;
		select_test						: IN STD_LOGIC;
		mouse_lclick					: IN STD_LOGIC;
		mouse_rclick					: IN STD_LOGIC;	-- rclick to restart
		
		score_clk						: IN STD_LOGIC;
		collision_flag					: IN STD_LOGIC;
		collision_type					: IN OBJ_TYPE_PACKET;
		
		lives								: OUT STD_LOGIC_VECTOR(1 downto 0);
		difficulty						: OUT STD_LOGIC_VECTOR(1 downto 0)	:= "00";
		score, top_score				: OUT UNSIGNED(7 downto 0);
		is_paused						: OUT STD_LOGIC;
		is_gameover						: OUT STD_LOGIC;
		is_invulnerable				: OUT STD_LOGIC;
		is_colourshifted				: OUT STD_LOGIC;
		
		enable_mechanics				: OUT STD_LOGIC;
		reset_mechanics				: OUT STD_LOGIC;	-- signal to reset external modules
		enable_menu						: OUT STD_LOGIC	-- goes to reset on GUI
	);
END ENTITY tracker;



ARCHITECTURE behaviour OF tracker IS

	COMPONENT level_to_pulse IS
	PORT (
		clk, d	: IN STD_LOGIC;
		q			: OUT STD_LOGIC
	);
	END COMPONENT level_to_pulse;


	TYPE STATE_TYPE is 				(S0,S1,S2,S3);
	SIGNAL state, next_state		: STATE_TYPE;
	
	CONSTANT STARTING_LIVES			: UNSIGNED(1 downto 0)		:= TO_UNSIGNED(2,2);
	
	SIGNAL v_pause						: STD_LOGIC;
	SIGNAL reset_game					: STD_LOGIC;	-- signal to reset lives, score, etc at end of game
	
	SIGNAL v_lives						: UNSIGNED(1 downto 0)		:= STARTING_LIVES;
	SIGNAL v_score, v_top_score	: UNSIGNED(7 downto 0)		:= (others => '0');
	SIGNAL v_invuln_active			: STD_LOGIC;
	signal v_colourshift_active	: STD_LOGIC;
	SIGNAL fourHzFlag					: STD_LOGIC;
	SIGNAL reset_fourHzCounter		: STD_LOGIC;
	SIGNAL mouse_lclick_trigger	: STD_LOGIC	:= '0';	-- signal is a 1 clk pulse for each rising_edge(mouse_lclick)
BEGIN

	lclick_ltp: level_to_pulse PORT MAP (clk, mouse_lclick, mouse_lclick_trigger);

	lives <= STD_LOGIC_VECTOR(v_lives);
	score <= v_score;
	top_score <= v_top_score;
	
	is_colourshifted <= v_colourshift_active;
	v_invuln_active <= fourHzFlag;
	is_invulnerable <= v_invuln_active;
	
	-- GAME STATE FSM --
	SYNC_PROC: process (clk)
	BEGIN
		if (rising_edge(clk)) then
			if (reset_button = '0') then
				state <= S0;
			else
				state <= next_state;
			end if;
		end if;
	END PROCESS SYNC_PROC;
	
	OUTPUT_DECODE: process (state)
	BEGIN	
		case (state) is
			when S0 =>
				-- READY
				enable_menu			<= '0';
				enable_mechanics	<= '0';
				reset_mechanics	<= '1';
				reset_game			<= '1';
				
				is_paused			<= '0';
				is_gameover			<= '0';
			when S1 =>
				-- PLAY
				enable_menu			<= '0';
				enable_mechanics	<= '1';
				reset_mechanics	<= '0';
				reset_game			<= '0';
				
				is_paused			<= '0';
				is_gameover			<= '0';
			when S2 =>
				-- GAMEOVER
				enable_menu			<= '0';
				enable_mechanics	<= '0';
				reset_mechanics	<= '0';
				reset_game			<= '0';
				
				is_paused			<= '0';
				is_gameover			<= '1';
			when others =>
				-- PAUSE
				enable_menu			<= '0';
				enable_mechanics	<= '0';
				reset_mechanics	<= '0';
				reset_game			<= '0';
				
				is_paused			<= '1';
				is_gameover			<= '0';
		end case;
	END PROCESS OUTPUT_DECODE;
	
	NEXT_STATE_DECODE: process (state, mouse_lclick, mouse_lclick_trigger, v_pause, v_lives)
	BEGIN
		next_state <= S0;
		
		case (state) is
			when S0 =>
				-- READY
				if (mouse_lclick_trigger = '1' and enable_game_start = '1') then
					next_state <= S1;
				else
					next_state <= S0;
				end if;
			when S1 =>
				-- PLAY
				if (v_pause = '1') then
					next_state <= S3;
				elsif (v_lives = TO_UNSIGNED(0,2)) then
					next_state <= S2;
				else
					next_state <= S1;
				end if;
			when S2 =>
				-- GAMEOVER
				if (mouse_lclick_trigger = '1') then
					next_state <= S0;
				else
					next_state <= S2;
				end if;
			when others =>
				-- PAUSE
				if (v_pause = '0') then
					next_state <= S1;
				else
					next_state <= S3;
				end if;
		end case;
	END PROCESS NEXT_STATE_DECODE;
	
	
	pause_control: PROCESS (pause_button)
	BEGIN
		if (falling_edge(pause_button)) then
			-- Note: buttons are ACTIVE LOW
			if (v_pause = '0') then
				v_pause <= '1';
			else
				v_pause <= '0';
			end if;
		end if;
	END PROCESS pause_control;
	
	
	on_collision: PROCESS (collision_flag, reset_game)
	BEGIN
		if (reset_game = '1') then
			v_lives <= STARTING_LIVES;
			v_colourshift_active <= '0';
		elsif (rising_edge(collision_flag)) then
			v_colourshift_active <= '0';
			reset_fourHzCounter <= '0';
			
			case (collision_type) is
				when COLOUR_SH_TYPE =>
					-- Colour shift
					if (v_colourshift_active = '1') then
						v_colourshift_active <= '0';
					else
						v_colourshift_active <= '1';
					end if;
				when INVI_TYPE =>
					-- Invulnerability
					reset_fourHzCounter <= '1';
				when LIFE_TYPE =>
					-- Extra life
					if (v_lives < TO_UNSIGNED(3,2)) then
						v_lives <= v_lives + TO_UNSIGNED(1,2);
					end if;
				when others => 
					-- Obstacles
					if (v_lives > TO_UNSIGNED(0,2) and v_invuln_active = '0') then
						v_lives <= v_lives - TO_UNSIGNED(1,2);
					end if;	
			end case;
		end if;
	END PROCESS on_collision;
	
	
	fourHzCounter: PROCESS (vert_sync, reset_fourHzCounter)
		VARIABLE counter			: UNSIGNED(8 downto 0) := (others => '0');
		CONSTANT count_limit		: UNSIGNED(8 downto 0) := TO_UNSIGNED(239,9);
	BEGIN
		if (reset_fourHzCounter = '1') then
			counter := (others => '0');
		elsif (rising_edge(vert_sync)) then
			if (counter < count_limit) then
				counter := counter + TO_UNSIGNED(1,9);
				fourHzFlag <= '1';
			else
				fourHzFlag <= '0';
			end if;
		end if;
	END PROCESS fourHzCounter;
	
	
	score_count: PROCESS (score_clk, reset_game)
	BEGIN
		if (reset_game = '1') then
			v_score <= (others => '0');
			difficulty <= (others => '0');
		elsif (rising_edge(score_clk)) then
			v_score <= v_score + TO_UNSIGNED(1,8);
			
			if (v_score > v_top_score) then
				v_top_score <= v_score;
			end if;
			
			if (select_test = '0') then
				if (v_score > DIFFICULTY_THRESHOLD_1) then
					difficulty <= "01";
				elsif (v_score > DIFFICULTY_THRESHOLD_2) then
					difficulty <= "10";
				elsif (v_score > DIFFICULTY_THRESHOLD_3) then
					difficulty <= "11";
				end if;
			end if;
		end if;
	END PROCESS score_count;
	
	
	
END behaviour;
		
--ENTITY tracker IS
--	PORT (
--		clk						: IN STD_LOGIC;
--		oneHz_clk				: IN STD_LOGIC;
--		reset_button			: IN STD_LOGIC;
--		pause_button			: IN STD_LOGIC;
--		
--		mouse_lclick			: IN STD_LOGIC;
--		select_test				: IN STD_LOGIC;
--		score_clk				: IN STD_LOGIC;
--		
--		collision_flag			: IN STD_LOGIC;
--		collision_type			: IN OBJ_TYPE_PACKET;
--	
--		lives						: OUT STD_LOGIC_VECTOR(1 downto 0);
--		difficulty				: OUT STD_LOGIC_VECTOR(1 downto 0)	:= "00";
--		score, top_score		: OUT UNSIGNED(7 downto 0);
--				
--		show_menu				: OUT STD_LOGIC;
--		show_pause				: OUT STD_LOGIC;
--		generator_enable		: OUT STD_LOGIC;
--		physics_enable			: OUT STD_LOGIC;
--		generator_reset		: OUT STD_LOGIC;
--		physics_reset			: OUT STD_LOGIC
--	);
--END ENTITY tracker;
--
--
--ARCHITECTURE behaviour OF tracker IS
--	SIGNAL v_score, v_top_score	: UNSIGNED(7 downto 0)	:= TO_UNSIGNED(0,8);
--	SIGNAL v_lives						: UNSIGNED(1 downto 0)	:= TO_UNSIGNED(1,2);
--	
--	SIGNAl pause						: STD_LOGIC					:= '0';		
--	SIGNAL reset_game					: STD_LOGIC;
--	
--	TYPE STATE_TYPE is 				(S0,S1,S2);
--	SIGNAL state, next_state		: STATE_TYPE;
--
--BEGIN
--
--	lives <= STD_LOGIC_VECTOR(v_lives);
--	score <= v_score;
--	top_score <= v_top_score;
--
--
--	-- GAME STATE FSM --
--	SYNC_PROC: process (clk)
--	BEGIN
--		if (rising_edge(clk)) then
--			if (reset_button = '0') then
--				-- button is ACTIVE LOW
--				state <= S0;
--			else
--				state <= next_state;
--			end if;
--		end if;
--	END PROCESS SYNC_PROC;
--
--	OUTPUT_DECODE: process (state)
--	BEGIN	
--		case (state) is
--			when S0 =>
--				-- GAMEOVER
--				show_menu				<= '1';
--				show_pause				<= '0';
--				generator_enable		<= '0';
--				physics_enable			<= '0';
--				generator_reset		<= '1';
--				physics_reset			<= '1';
--				
--				reset_game				<= '1';
--			when S1 =>
--				-- PAUSE
--				show_menu				<= '0';
--				show_pause				<= '1';
--				generator_enable		<= '0';
--				physics_enable			<= '0';
--				generator_reset		<= '0';
--				physics_reset			<= '0';
--				
--				reset_game				<= '0';
--			when others =>
--				-- RUN
--				show_menu				<= '0';
--				show_pause				<= '0';
--				generator_enable		<= '1';
--				physics_enable			<= '1';
--				generator_reset		<= '0';
--				physics_reset			<= '0';
--				
--				reset_game				<= '0';
--		end case;
--	END PROCESS OUTPUT_DECODE;
--
--	NEXT_STATE_DECODE: process (state, mouse_lclick, pause, v_lives)
--	BEGIN
--		next_state <= S0;
--		
--		case (state) is
--			when S0 =>
--				if (mouse_lclick = '1') then
--					next_state <= S1;
--				end if;
--			when S1 =>
--				if (pause = '0') then
--					next_state <= S2;
--				end if;
--			when others =>
--				if (UNSIGNED(v_lives) = TO_UNSIGNED(0,2)) then
--					next_state <= S0;
--				elsif (pause = '1') then
--					next_state <= S1;
--				end if;
--		end case;
--	END PROCESS NEXT_STATE_DECODE;
--
--	
----	pause <= not pause_button;
--	
--	pause_control: PROCESS (pause_button)
--	BEGIN
--		if (falling_edge(pause_button)) then
--			-- Note: buttons are ACTIVE LOW
--			if (pause = '0') then
--				pause <= '1';
--			else
--				pause <= '0';
--			end if;
--		end if;
--	END PROCESS pause_control;
--	
----	pause_control: PROCESS (clk, mouse_lclick)
----	BEGIN
----		if (mouse_lclick = '1') then
----			pause <= '0';
----		elsif (rising_edge(clk)) then
----			-- Note: buttons are ACTIVE LOW
----			if (pause_button = '0') then
----				pause <= '1';
----			else
----				pause <= '0';
----			end if;
----		end if;
----	END PROCESS pause_control;
--	
--	
--	score_count: PROCESS (score_clk, reset_game)
--	BEGIN
--		if (reset_game = '1') then
--			v_score <= (others => '0');
--		elsif (rising_edge(score_clk)) then
--			v_score <= v_score + TO_UNSIGNED(1,8);
--			
--			if (v_score > v_top_score) then
--				v_top_score <= v_score;
--			end if;	
--			
--			if (select_test = '0') then
--				if (v_score > DIFFICULTY_THRESHOLD_1) then
--					difficulty <= "01";
--				elsif (v_score > DIFFICULTY_THRESHOLD_2) then
--					difficulty <= "10";
--				elsif (v_score > DIFFICULTY_THRESHOLD_3) then
--					difficulty <= "11";
--				end if;
--			end if;
--		end if;
--	END PROCESS score_count;
--	
--	
--	on_collision: PROCESS (collision_flag, reset_game)
--	BEGIN
--		if (reset_game = '1') then
--			v_lives <= TO_UNSIGNED(1,2);
--		elsif (rising_edge(collision_flag)) then
--			case collision_type is
--				when "0000" =>
--					-- Obstacle (damages)
--					v_lives <= v_lives - TO_UNSIGNED(1,2);
--					--if (v_lives > TO_UNSIGNED(0,2)) then
--						-- Apply invulnerability for a short period
--					--end if;
----				when "0001" =>
----					-- Invulnerability
----				when "0010" =>
----					-- Extra life
----					v_lives <= v_lives + TO_UNSIGNED(1,2);
--				when others =>
--					-- Colour shift
--					v_lives <= v_lives + TO_UNSIGNED(1,2);
--			end case;
--		end if;
--	END PROCESS on_collision;
--
--
--END behaviour;
--
--
--





