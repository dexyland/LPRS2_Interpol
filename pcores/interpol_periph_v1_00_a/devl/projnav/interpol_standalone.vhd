library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interpol_standalone is
  port
  (
		clk_24MHz_i		: in  std_logic;
		rst_in			: in  std_logic;
		
    -- Same as in interpol_periph BELOW THIS LINE ------------------
		vga_clk_o		: out std_logic;
		red_o				: out std_logic_vector(7 downto 0);
		green_o			: out std_logic_vector(7 downto 0);
		blue_o			: out std_logic_vector(7 downto 0);
		blank_on			: out std_logic;
		h_sync_on		: out std_logic;
		v_sync_on		: out std_logic;
		sync_on			: out std_logic;
		pow_save_on		: out std_logic
    -- Same as in inteprol_periph ABOVE THIS LINE ------------------
  );
end entity interpol_standalone;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of interpol_standalone is
	
	-- Same as in interpol_standalone BELOW THIS LINE ------------------
	constant ADDR_WIDTH : natural := 13;

	signal clk_100MHz			: std_logic;
	signal n_reset				: std_logic;
	
	signal rgb_s					: std_logic_vector(23 downto 0);
 	signal pixel_x_s				: unsigned(9 downto 0);
	signal pixel_y_s				: unsigned(8 downto 0);
	signal phase_s					: unsigned(1 downto 0);

	signal bus_addr		       : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal bus_data            : std_logic_vector(31 downto 0);
	signal bus_we              : std_logic;
	
begin

	vga_ctrl_i : entity work.vga_ctrl
		port map
		(
			i_clk_100MHz   => clk_100MHz,
			in_reset       => n_reset,
			
			o_phase			=> phase_s,
			o_pixel_x		=> pixel_x_s,
			o_pixel_y		=> pixel_y_s, 
			i_red				=> rgb_s(7 downto 0),
			i_green			=> rgb_s(15 downto 8),
			i_blue			=> rgb_s(23 downto 16),

			o_vga_clk		=> vga_clk_o,
			o_red				=> red_o,
			o_green			=> green_o,
			o_blue			=> blue_o,
			on_blank			=> blank_on,
			on_h_sync		=> h_sync_on,
			on_v_sync		=> v_sync_on,
			on_sync			=> sync_on,
			on_pow_save		=> pow_save_on
		);
		
	interpol_i : entity work.interpol
		port map
		(
			clk_i				=> clk_100MHz,
			rst_n_i			=> n_reset,
			pixel_row_i		=> pixel_y_s,
			pixel_col_i		=> pixel_x_s,
			bus_addr_i		=> bus_addr,
			bus_data_i		=> bus_data,
			bus_we_i			=> bus_we,
			phase_i			=> phase_s,
			rgb_o				=> rgb_s
		);
    -- Same as in interpol_periph ABOVE THIS LINE ------------------
	 

	clk_gen: entity work.clk_gen_100MHz
	port map(
		i_clk_24MHz  => clk_24MHz_i,
		in_reset     => rst_in,
		o_clk_100MHz => clk_100MHz,
		o_locked     => n_reset
	);
	

	bus_addr <= (others => '0');
	bus_data <= (others => '0');
	bus_we <= '0';
	
end IMP;
