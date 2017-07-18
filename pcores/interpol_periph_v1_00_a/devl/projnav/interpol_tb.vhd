-- TestBench Template 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

library std;
use std.textio.all;

library interpol_periph_v1_00_a;
	use interpol_periph_v1_00_a.vga_ctrl;
	use interpol_periph_v1_00_a.interpol;

ENTITY interpol_tb IS
END interpol_tb;

ARCHITECTURE behavior OF interpol_tb IS 

	constant clk_period : time := 10 ns;
	signal clk          : std_logic;
	signal rst_n        : std_logic;
	signal bus_addr     : std_logic_vector(12 downto 0) := (others => '0');  -- Address used to point to registers
	signal bus_data     : std_logic_vector(31 downto 0) := (others => '0');  -- Data to be writed to registers
	signal bus_we       : std_logic := '0';
	signal pixel_row    : unsigned(8 downto 0) := (others => '0');
	signal pixel_col    : unsigned(9 downto 0) := (others => '0');
	signal phase        : unsigned(1 downto 0) := "00";
	signal rgb          : std_logic_vector(23 downto 0);

BEGIN
  -- Component Instantiation
	  clk_gen : process
	  begin
		 clk <= '1';
		 wait for 5 ns;
		 clk <= '0';
		 wait for 5 ns;
	  end process clk_gen;
	  
	 uut: entity interpol 
	 GENERIC MAP(
				DATA_WIDTH           => 32,
				COLOR_WIDTH          => 24,
				ADDR_WIDTH           => 13
				--REGISTER_OFFSET      => 6224,            -- Pointer to registers in memory map
				--C_BASEADDR           => 0,               -- Pointer to local memory in memory map
				--REGISTER_NUMBER      => 10,              -- Number of registers used for sprites
				--NUM_BITS_FOR_REG_NUM => 4,               -- Number of bits required for number of registers
				--MAP_OFFSET           => 1424,            -- Pointer to start of map in memory
				--OVERHEAD             => 5,               -- Number of overhead bits
				--SPRITE_Z             => 1                -- Z coordinate of sprite
	 )
	 PORT MAP(
				clk_i  => clk,
				rst_n_i => rst_n,
				bus_addr_i => bus_addr, 
				bus_data_i => bus_data,
				bus_we_i => bus_we, 
				pixel_row_i => pixel_row,
				pixel_col_i => pixel_col, 
				phase_i => phase,
				rgb_o => rgb
	 );

  tb : process	begin
  
		rst_n <= '0';
		wait for 10 ns;
  
		rst_n <= '1';
		wait for 10 ns;
		
		loop
			phase <= phase + 1;
			
			if phase = "11" then
				if pixel_col < 640-1 then
					pixel_col <= pixel_col + 1;
				else
					pixel_col <= (others => '0');
					if pixel_row < 480-1 then
						pixel_row <= pixel_row + 1;
					else
						pixel_row <= (others => '0');
					end if;
				end if;
			end if;
			
			wait for 10 ns;
		end loop;
		
		wait;
	end process tb;

		
	ppm_file : process
		file ppm_file : TEXT;
		variable l_handle : line ;
		variable P6    : string(1 to 2 ) := "P3";
		variable name  : string(1 to 12) := "# vga output";
		variable size  : string (1 to 7) := "640 480";
		variable space : string (1 to 1) := " ";
		variable scope : string (1 to 3) := "255";
		VARIABLE char  : integer:= 0;
		variable red   : integer;
		variable green : integer;
		variable blue  : integer;
	begin

		file_open(ppm_file, "out.ppm", write_mode);

		write(l_handle,P6);
		writeline(ppm_file,l_handle);
		write(l_handle,name);
		writeline(ppm_file,l_handle);
		write(l_handle,size);
		writeline(ppm_file,l_handle);
		write(l_handle,scope);
		writeline(ppm_file,l_handle);

		wait for 120 ns;
		
		for i in 1 to 640*480 loop
			wait until(rising_edge(clk));
			if phase = 0 then
				red   := to_integer(unsigned(rgb( 7 downto  0)));
				green := to_integer(unsigned(rgb(15 downto  8)));
				blue  := to_integer(unsigned(rgb(23 downto 16)));

				write(l_handle, integer'image(red));   write(l_handle, space);
				write(l_handle, integer'image(green)); write(l_handle, space);
				write(l_handle, integer'image(blue));  write(l_handle, space);

				writeline(ppm_file, l_handle);
			end if;
		end loop;
		file_close(ppm_file);
		wait;
	end process ppm_file;
END;