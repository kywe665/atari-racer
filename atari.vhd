----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:13:35 10/04/2012 
-- Design Name: 
-- Module Name:    paddle_top - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity paddle_top is
	port(
		clk: in std_logic;
		btn: in std_logic_vector(3 downto 0);
		sw: in std_logic_vector(3 downto 0);
		HS_OUT: out std_logic;
		VS_OUT: out std_logic;
		RED_OUT: out std_logic_vector(2 downto 0);
		GREEN_OUT: out std_logic_vector(2 downto 0);
		BLUE_OUT: out std_logic_vector(1 downto 0);
		an: out std_logic_vector(3 downto 0);
		dp: out std_logic;
		seg: out std_logic_vector(6 downto 0)
	);
end paddle_top;

architecture Behavioral of paddle_top is
	signal rst, last_column, last_row, blank,clock_pause: std_logic;
	signal pixel_x, pixel_y: unsigned(9 downto 0);
	signal pixel_xs, pixel_ys: std_logic_vector(9 downto 0);
	signal colors: std_logic_vector(7 downto 0);
	signal border_rgb : std_logic_vector(7 downto 0) := "11100000";
	signal border_out_rgb : std_logic_vector(7 downto 0) := "10010010";
	signal paddleL_rgb : std_logic_vector(7 downto 0) := "00010100"; --tree
	signal hcolor : std_logic_vector(7 downto 0) :="11111111";
	signal car_rgb : std_logic_vector(7 downto 0) := "00111111"; --yellow
	signal paddleR_rgb : std_logic_vector(7 downto 0) := "00010100"; --tree
	signal paddleR_trunk_rgb : std_logic_vector(7 downto 0) := "01101001"; --trunk
	signal car_on,paddleL_on1,paddleL_on2,paddleL_on3: std_logic;
	signal car_top, car_top_next : unsigned(9 downto 0) := "0100110001";
	signal border_on, border_out_on, paddleL_on, paddleR_on, paddleR_trunk_on, paddleL_trunk_on, treeR_on, treeL_on, move_en: std_logic;
	signal tyre_one,tyre_two,tyre_three,tyre_four,hlight,blight: std_logic;
	signal anim_counter : unsigned(19 downto 0) := (others=>'0');
	signal paddleR_top, paddleR_top_next, paddleL_top, paddleL_top_next : unsigned(8 downto 0) := "000001111";
	signal q_next, q_reg : unsigned(3 downto 0);
	signal counter_number: std_logic_vector(15 downto 0);
	signal counter_temp,counter_temp_next: unsigned(16 downto 0);
	signal trackEdge, trackEdge_next : unsigned(9 downto 0):= "0011100110";
 	type arr is array(479 downto 0) of unsigned(9 downto 0);
	signal rowEdge: arr;
	signal lfsrRL : std_logic_vector(19 downto 0);
	signal lfsrGrade : std_logic_vector(19 downto 0);
	signal lfsrTree : std_logic_vector(5 downto 0);
	signal treeR_edge: unsigned(9 downto 0);
	signal treeL_edge : unsigned(5 downto 0);
	signal TRACK_WIDTH : unsigned(7 downto 0) := "10110100";
	signal forceStatus, forceStatus_next: std_logic_vector(1 downto 0) := "00";
	signal button_ready, restart_en: std_logic;
	type state is (restart, start, run, stop);
	signal state_reg, state_next: state := restart;
	signal debounce_count: unsigned(16 downto 0);
	signal track_init: unsigned(9 downto 0):= "0011100110";
	
begin
	U1 : entity work.vga_timing
	port map(
		clk => clk,
		rst => rst,
		HS => HS_OUT,
		VS => VS_OUT,
		pixel_x => pixel_xs,
		pixel_y => pixel_ys,
		last_column => last_column,
		last_row => last_row,
		blank => blank
	);
	
	U2: entity work.seven_segment_display
		port map
		(
			clk => clk,
			data_in => counter_number,
			dp_in => "0000",
			blank =>"0000",
			dp => dp,
			an=>an,
			seg=> seg
		);
		
	process(clk)
	begin
		if (clk'event and clk='1') then
			if clock_pause ='0' then 
				q_reg <= q_next;
				counter_temp <= counter_temp_next;
				
			end if;
		end if;
	end process;		
		
	q_next <= q_reg + 1 when last_column ='1' and last_row ='1' else
				q_reg;
	counter_temp_next <= counter_temp+1 when ((q_reg = "1111") and (state_reg = run)) else
								(others=>'0') when (state_reg = restart) else
								counter_temp;
					
	counter_number <= std_logic_vector(counter_temp(16 downto 1));
	
	pixel_x <= unsigned(pixel_xs);
	pixel_y <= unsigned(pixel_ys);
	
	--DEFAULT TRACK WIDTH BASED ON LEVEL
	TRACK_WIDTH <= "10110100" - counter_temp/4;
	track_init <= "0011100110" + unsigned(sw);
	
	border_rgb <= "11000000";
	
	--DEBOUNCE ALL BUTTONS
	process(clk, btn, debounce_count, move_en)
	begin
		if(clk'event and clk='1') then
			if(btn(0)='1' or btn(1)='1' or btn(2)='1' or btn(3)='1') then
				if(move_en='1') then
					debounce_count <= debounce_count + 1;
				end if;
			else
				debounce_count <= (others => '0');
				button_ready <= '0';
			end if;
			if(debounce_count > 4 and debounce_count < 6) then
				button_ready <= '1';
			elsif(debounce_count > 6) then
				debounce_count <= (others => '0');
				button_ready <= '0';
			end if;
		end if;
	end process;
	
	--draw process
	process(pixel_x, pixel_y, blank, border_on, border_out_on, border_rgb, paddleR_on, paddleR_rgb, paddleL_on, paddleL_rgb, paddleL_trunk_on, paddleR_trunk_on, car_on,hlight, blight, car_rgb, paddleR_trunk_rgb, border_out_rgb)
	begin
		rst <= '0';
		if blank='0' then
			if (paddleR_on = '1') then
				colors <= paddleR_rgb;
			elsif (paddleR_trunk_on = '1' or paddleL_trunk_on = '1') then
				colors <= paddleR_trunk_rgb;
			elsif (paddleL_on = '1') then
				colors <= paddleL_rgb;
			elsif (border_out_on = '1') then
				colors <= border_out_rgb;
			elsif (car_on = '1') then
				colors <= car_rgb;
			elsif(hlight='1') then
				colors <=hcolor;
			elsif(blight='1') then
				colors<="11100000";
			elsif (border_on = '1') then
				colors <= border_rgb;
			else
				colors <= "00000000";
			end if;
		else
			colors <= "00000000";
		end if;
	end process;
	
	--counter for moving
	process(clk)
	begin
		if (clk'event and clk = '1') then
			if(anim_counter = 80000) then
				move_en <= '1';--move pixel
				anim_counter <= (others => '0');
			else
				anim_counter <= anim_counter + 1;
				move_en <= '0';
			end if;
		end if;
	end process;
	
	--watch STATE
	process(btn, button_ready, state_reg, clock_pause, rowEdge, track_init)
	begin
		state_next <= state_reg;
		restart_en <= '0';
		car_rgb <= "11111100";
		hcolor<="11111111";
		case state_reg is
			when start =>
				if(btn(0)='1' and button_ready='1') then
					state_next <= run;
				end if;
			when run =>
				if(clock_pause='1') then
					state_next <= stop;
				end if;
					
			when stop =>
				car_rgb <= "11111111";
				hcolor<="11100000";
				
				----change the shape of the car--------
				if(btn(0)='1' and button_ready='1') then
					state_next <= start;
				end if;
				if(btn(1)='1' and button_ready='1') then
					state_next <= restart;
				end if;
			when restart =>
				restart_en <= '1';
				if(rowEdge(479) = track_init and rowEdge(239) = track_init and rowEdge(478) = track_init) then
					state_next <= start;
					restart_en <= '0';
				end if;
		end case;
	end process;
	----crashed car------
	
	--flip flop for moving
	process(clk, state_reg, move_en, restart_en, track_init)
	begin
		if (clk'event and clk = '1') then
			if (state_reg = run or restart_en = '1') then
				if (move_en = '1') then
					if(restart_en = '1') then
						trackEdge <= track_init;
					else
						trackEdge <= trackEdge_next;
					end if;
					rowEdge(0) <= trackEdge;
					forceStatus <= forceStatus_next;
					---car stuff----
					car_top <= car_top_next;
					--loop for all rowEdges to get value from previous row
					for i in 1 to 479 loop
						rowEdge(i) <= rowEdge(i-1);
					end loop;
					--LFSR for R/L movement
					lfsrRL <= lfsrRL(18 downto 0) & (lfsrRL(19) xnor lfsrRL(0));
					lfsrGrade <= lfsrGrade(18 downto 0) & (lfsrGrade(19) xnor lfsrGrade(0));
					lfsrTree <= lfsrTree(4 downto 0) & (lfsrTree(5) xnor lfsrTree(0));
					--tree movement
					if(treeR_on = '1') then
						paddleR_top <= paddleR_top_next;
					end if;
					if(treeL_on = '1') then
						paddleL_top <= paddleL_top_next;
					end if;
				end if;
			else
				if(move_en = '1') then
					car_top <= car_top_next;
				end if;
			end if;
			--UPDATE STATE on CLOCK
			state_reg <= state_next;
		end if;
	end process;
	----movement of the car-----
	process(car_top, btn, button_ready, TRACK_WIDTH, rowEdge)
		begin
		if (((btn(3)='1' and button_ready='1') and (car_top > rowEdge(428)))) then 
			car_top_next <= car_top - 1;
			
		elsif ((btn(2)='1' and button_ready='1') and (car_top  <=  rowEdge(428)+TRACK_WIDTH-23)) then 
			car_top_next <= car_top + 1;
			
		else
			car_top_next <= car_top;
			
		end if;
	end process;
	----------change color of the car after border----
	
	process(car_top, TRACK_WIDTH, rowEdge)		
	begin
		clock_pause<='0';
		if (car_top <rowEdge(428) or car_top > rowEdge(428)+TRACK_WIDTH-23) then
			clock_pause <='1'; -------stops clock after game over
		end if;
	end process;

----drawing of the car------

	car_on <= '1' when ((paddleL_on1 or paddleL_on2 or paddleL_on3)='1') else
				'0';
	paddleL_on1 <= '1' when (pixel_x >= car_top and pixel_x < car_top + 15) and
								  (pixel_y <= 459 and pixel_y > 451) else
					  '0';
	paddleL_on2 <= '1' when (pixel_x >= car_top-8 and pixel_x < car_top+23) and
								  (pixel_y <= 451 and pixel_y > 433) else
					  '0';
	paddleL_on3 <= '1' when (pixel_x >= car_top and pixel_x < car_top+15) and
								  (pixel_y <= 433 and pixel_y > 425) else
					  '0';
	tyre_one <='1' when (pixel_x>= car_top-8 and pixel_x< car_top-1) and 
								  (pixel_y <= 459 and pixel_y > 452) else
					'0';
	tyre_two <='1' when (pixel_x>= car_top+16 and pixel_x< car_top+22) and 
								  (pixel_y <= 459 and pixel_y > 452) else
					'0';
	tyre_three <='1' when (pixel_x>= car_top-8 and pixel_x< car_top-1) and 
								  (pixel_y <= 432 and pixel_y > 425) else
					'0';
	tyre_four <='1' when (pixel_x>= car_top+16 and pixel_x< car_top+22) and 
								  (pixel_y <= 432 and pixel_y > 425) else
					'0';
    blight <='1' when (tyre_one='1' or tyre_two='1') else
					'0';
	hlight <='1' when(tyre_three='1' or tyre_four='1') else
				'0';
--Keep the track in bounds and move as dictated by random numbers
	process(lfsrRL, lfsrGrade, forceStatus, trackEdge, TRACK_WIDTH)
		variable temp_edge: unsigned(9 downto 0) := trackEdge;
	begin
		forceStatus_next <= "00";
		if(unsigned(lfsrGrade) < 1048) then
			if(unsigned(lfsrRL) > 520200) then
				temp_edge := trackEdge + 5;
			else
				temp_edge := trackEdge - 5;
			end if;
		else
			if(unsigned(lfsrRL) > 520200) then
				temp_edge := trackEdge + 1;
			else
				temp_edge := trackEdge - 1;
			end if;
		end if;
		if(forceStatus = "10") then
			if (temp_edge > 230) then
				temp_edge := temp_edge - 1;
				forceStatus_next <= "10";
			end if;
		elsif(forceStatus = "01") then
			if (temp_edge < 230) then
				temp_edge := temp_edge + 1;
				forceStatus_next <= "01";
			end if;
		end if;
		if(temp_edge > 539 or temp_edge < 100 or temp_edge+TRACK_WIDTH > 539) then
			if(unsigned(lfsrRL) > 520200) then
				--force left
				forceStatus_next <= "10";
			else
				--force right
				forceStatus_next <= "01";
			end if;
			trackEdge_next <= trackEdge;
		else
			trackEdge_next <= temp_edge;
		end if;
	end process;
	
--send trees randomly
	process(clk, lfsrGrade, lfsrTree, paddleL_top)
	begin
		if(clk'event and clk='1') then
			treeR_on <= treeR_on;
			if(unsigned(lfsrGrade) < 1048) then
				if(treeR_on = '0') then
					treeR_edge <= ("1000110000" + unsigned(lfsrTree));
				end if;
				treeR_on <= '1';
			elsif(paddleR_top = 480) then
				treeR_on <= '0';
			end if;
			treeL_on <= treeL_on;
			if(unsigned(lfsrGrade) < 1000000 and unsigned(lfsrGrade) > 998951) then
				if(treeL_on = '0') then
					treeL_edge <= ("1010" + unsigned(lfsrTree));
				end if;
				treeL_on <= '1';
			elsif(paddleL_top = 480) then
				treeL_on <= '0';
			end if;
		end if;
	end process;
	
	paddleL_top_next <= paddleL_top + 1;
							  
	paddleR_top_next <= paddleR_top + 1;
	
	RED_OUT <= colors(7 downto 5);
	GREEN_OUT <= colors(4 downto 2);
	BLUE_OUT <= colors(1 downto 0);
	
	paddleL_on <= '1' when (pixel_x >= treeL_edge+8 and pixel_x < treeL_edge+12) and
								  (pixel_y >= paddleL_top and pixel_y < paddleL_top+4) else
					  '1' when (pixel_x >= treeL_edge+4 and pixel_x < treeL_edge+16) and
								  (pixel_y >= paddleL_top+4 and pixel_y < paddleL_top+8) else
					  '1' when (pixel_x >= treeL_edge and pixel_x < treeL_edge+20) and
								  (pixel_y >= paddleL_top+8 and pixel_y < paddleL_top+12) else
					  '0';
	paddleL_trunk_on <= '1' when (pixel_x >= (treeL_edge+6) and pixel_x < (treeL_edge+14)) and
										  (pixel_y >= paddleL_top+12 and pixel_y < paddleL_top+18) else
							  '0';
	
	paddleR_on <= '1' when (pixel_x >= treeR_edge+8 and pixel_x < treeR_edge+12) and
								  (pixel_y >= paddleR_top and pixel_y < paddleR_top+4) else
					  '1' when (pixel_x >= treeR_edge+4 and pixel_x < treeR_edge+16) and
								  (pixel_y >= paddleR_top+4 and pixel_y < paddleR_top+8) else
					  '1' when (pixel_x >= treeR_edge and pixel_x < treeR_edge+20) and
								  (pixel_y >= paddleR_top+8 and pixel_y < paddleR_top+12) else
					  '0';
					  
					  
	paddleR_trunk_on <= '1' when (pixel_x >= (treeR_edge+6) and pixel_x < (treeR_edge+14)) and
										  (pixel_y >= paddleR_top+12 and pixel_y < paddleR_top+18) else
							  '0';
	
	process(pixel_x, pixel_y, TRACK_WIDTH, rowEdge)
	begin
		border_out_on <= '0';
		border_on <= '0';
		if(pixel_y <= 479) then
			if((pixel_x > 100 and pixel_x < 108) or (pixel_x > 540 and pixel_x < 548)) then
				border_on <= '0';
			elsif(pixel_x <= 100 or pixel_x >= 548) then
				border_out_on <= '1';
			elsif(pixel_x < rowEdge(to_integer(pixel_y)) or	(pixel_x > (rowEdge(to_integer(pixel_y))+TRACK_WIDTH) and pixel_x < 540)) then
				border_on <= '1';
			else
				border_on <= '0';
				border_out_on <= '0';
			end if;
		else
			border_on <= '0';
			border_out_on <= '0';
		end if;
	end process;

	
end Behavioral;