library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity interpol is
   generic(
      DATA_WIDTH           : natural := 8;
      COLOR_WIDTH          : natural := 24;
      ADDR_WIDTH           : natural := 13
      --REGISTER_OFFSET      : natural := 5439;   -- 6960           -- Pointer to registers in memory map
      --C_BASEADDR           : natural := 0;               -- Pointer to local memory in memory map
      --REGISTER_NUMBER      : natural := 10;              -- Number of registers used for sprites
      --NUM_BITS_FOR_REG_NUM : natural := 4;               -- Number of bits required for number of registers
      --MAP_OFFSET           : natural := 639;            -- Pointer to start of map in memory
      --OVERHEAD             : natural := 5;               -- Number of overhead bits
      --SPRITE_Z             : natural := 1                -- Z coordinate of sprite
	);
	
   Port (
      clk_i          : in  std_logic;
      rst_n_i        : in  std_logic;
		-- RAM
      bus_addr_i     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Address used to point to registers
      bus_data_i     : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- Data to be writed to registers
      bus_we_i       : in  std_logic;
		--ram_clk_o		: out std_logic;											-- Same clock domain
		-- VGA --
		pixel_row_i    : in  unsigned(8 downto 0);
		pixel_col_i    : in  unsigned(9 downto 0);
		phase_i        : in  unsigned(1 downto 0);
		rgb_o          : out std_logic_vector(COLOR_WIDTH-1 downto 0)  -- Value of RGB color
   );
end entity interpol;

architecture Behavioral of interpol is

   component ram
   port
   (
		i_clk    : in  std_logic;
		i_r_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
		i_data   : in  std_logic_vector(31 downto 0);
		i_we     : in  std_logic;
		i_w_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
		o_data   : out std_logic_vector(31 downto 0)
   );
   end component ram;

	-- Types --
   --type registers_t  is array (0 to REGISTER_NUMBER-1) of unsigned (63 downto  0);
--   type coor_row_t 	 is array (0 to REGISTER_NUMBER-1) of unsigned (8 downto 0);
--   type coor_col_t   is array (0 to REGISTER_NUMBER-1) of unsigned (9 downto 0);
--   type pointer_t    is array (0 to REGISTER_NUMBER-1) of unsigned (15 downto 0);
--   type rotation_t   is array (0 to REGISTER_NUMBER-1) of unsigned (7 downto 0);
--   type size_t       is array (0 to REGISTER_NUMBER-1) of unsigned (3 downto 0);

	-- Constants --
   --constant size_8_c       : unsigned (3 downto 0) := "0111";

   --constant overhead_c     : std_logic_vector( OVERHEAD-1 downto 0 ) := ( others => '0' );
   --constant sprite_z_coor  : unsigned (7 downto 0) := "00000100";
   constant fix_one	 : unsigned (15 downto 0) := "0010000000000000";
   constant fix_half  : unsigned (15 downto 0) := "0001000000000000";

--   -- Globals --
--   signal registers_s      : registers_t :=                                -- Array representing registers
--   --   row   |    col  |en&size|  rot  | pointer
--   (( x"0130" & x"00e3" & x"8f" & x"00" & x"01FF" ),  --mario
--    ( x"0170" & x"00d5" & x"8f" & x"00" & x"01BF" ),  --enemie
--    ( x"0170" & x"011b" & x"8f" & x"00" & x"01BF" ),
--    ( x"0170" & x"014d" & x"8f" & x"00" & x"01BF" ),
--    ( x"0170" & x"01b1" & x"8f" & x"00" & x"01BF" ),
--    ( x"0130" & x"01c6" & x"8f" & x"00" & x"013f" ),  --coin
--    ( x"0130" & x"01d5" & x"8f" & x"00" & x"013f" ),
--    ( x"0130" & x"01e4" & x"8f" & x"00" & x"013f" ),
--    ( x"0130" & x"01f3" & x"8f" & x"00" & x"013f" ),
--    ( x"0000" & x"0090" & x"7f" & x"00" & x"03d0" )); --brick

	signal src_x : 	unsigned(15 downto 0);
	signal src_y : 	unsigned(15 downto 0); 
	signal src_w :  	unsigned(15 downto 0);
	signal src_h :  	unsigned(15 downto 0);
	signal dst_x :  	unsigned(15 downto 0);
	signal dst_y :  	unsigned(15 downto 0);
	signal dst_w :  	unsigned(15 downto 0);
	signal dst_h :  	unsigned(15 downto 0);
	signal zoom_x : 	unsigned(15 downto 0);
	signal zoom_y : 	unsigned(15 downto 0);
	
	signal sx : unsigned(15 downto 0);
	signal sy : unsigned(15 downto 0);
	signal py : unsigned(15 downto 0);
	signal px : unsigned(15 downto 0);
	
	signal x : unsigned(31 downto 0);
	signal y : unsigned(31 downto 0);
	
	signal tmp_x : unsigned(31 downto 0);
	signal tmp_y : unsigned(31 downto 0);
	signal tmp0_x : unsigned(15 downto 0);
	signal tmp0_y : unsigned(15 downto 0);
	signal tmp1_x : unsigned(31 downto 0);
	signal tmp1_y : unsigned(31 downto 0);
	
	signal int_x : unsigned(15 downto 0);
	signal int_y : unsigned(15 downto 0);
	signal inc_x : unsigned(7 downto 0);
	signal inc_y : unsigned(7 downto 0);
	signal src_mem_width : unsigned(15 downto 0);
	
-- Addresses for mux --
	signal addr_base  : unsigned(31 downto 0);
	
	signal pix_A_addr_tmp : unsigned(31 downto 0);
	signal pix_B_addr_tmp : unsigned(31 downto 0);
	signal pix_C_addr_tmp : unsigned(31 downto 0);
	signal pix_D_addr_tmp : unsigned(31 downto 0);
	
	signal pix_A_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pix_B_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pix_C_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pix_D_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	
-- ram signals (data & addresses) --
	signal mem_addr_r   :  unsigned(ADDR_WIDTH-1 downto 0);
	signal mem_addr_s   :  unsigned(ADDR_WIDTH-1 downto 0);
	
--signal mem_data_r : std_logic_vector(DATA_WIDTH-1 downto 0);--
	signal mem_data_s : unsigned(DATA_WIDTH-1 downto 0);

-- pixel values (taken from the ram at corresponding phase 'value')-- 
	signal pixel_A_red_r   : unsigned(7 downto 0);
	signal pixel_A_green_r : unsigned(7 downto 0);
	signal pixel_A_blue_r  : unsigned(7 downto 0);
	
	signal pixel_B_red_r   : unsigned(7 downto 0);
	signal pixel_B_green_r : unsigned(7 downto 0);
	signal pixel_B_blue_r  : unsigned(7 downto 0);
	
	signal pixel_C_red_r   : unsigned(7 downto 0);
	signal pixel_C_green_r : unsigned(7 downto 0);
	signal pixel_C_blue_r  : unsigned(7 downto 0);
	
	signal pixel_D_red_r   : unsigned(7 downto 0);
	signal pixel_D_green_r : unsigned(7 downto 0);
	signal pixel_D_blue_r  : unsigned(7 downto 0);
	
-- pixel index value --
	signal diff_x : unsigned(15 downto 0);
	signal diff_y : unsigned(15 downto 0);
	
	signal index_A_tmp_s : unsigned(31 downto 0);
	signal index_B_tmp_s : unsigned(31 downto 0);
	signal index_C_tmp_s : unsigned(31 downto 0);
	signal index_D_tmp_s : unsigned(31 downto 0);

	signal temp_A_s : unsigned(15 downto 0); 
	signal temp_B_s : unsigned(15 downto 0); 
	signal temp_C_s : unsigned(15 downto 0);
	signal temp_D_s : unsigned(15 downto 0);

	signal temp_A_r : unsigned(15 downto 0); 
	signal temp_B_r : unsigned(15 downto 0); 
	signal temp_C_r : unsigned(15 downto 0);
	signal temp_D_r : unsigned(15 downto 0);
	
	signal temp_1A_s : unsigned(15 downto 0);
	signal temp_2A_s : unsigned(15 downto 0);
	signal temp_3A_s : unsigned(31 downto 0);
	
	signal temp_1B_s : unsigned(15 downto 0);
	signal temp_2B_s : unsigned(15 downto 0);
	signal temp_3B_s : unsigned(31 downto 0);

	signal temp_1C_s : unsigned(15 downto 0);
	signal temp_2C_s : unsigned(15 downto 0);
	signal temp_3C_s : unsigned(31 downto 0);
	
	signal temp_1D_s : unsigned(15 downto 0);
	signal temp_2D_s : unsigned(15 downto 0);
	signal temp_3D_s : unsigned(31 downto 0);
	
-- pixel value multip. with index --
	signal pixel_A_multip_red_s   	  : unsigned(23 downto 0);
	signal pixel_A_multip_green_s 	  : unsigned(23 downto 0);
	signal pixel_A_multip_blue_s  	  : unsigned(23 downto 0);
	
	signal pixel_B_multip_red_s   	  : unsigned(23 downto 0);
	signal pixel_B_multip_green_s 	  : unsigned(23 downto 0);
	signal pixel_B_multip_blue_s  	  : unsigned(23 downto 0);
	
	signal pixel_C_multip_red_s   	  : unsigned(23 downto 0);
	signal pixel_C_multip_green_s 	  : unsigned(23 downto 0);
	signal pixel_C_multip_blue_s  	  : unsigned(23 downto 0);
	
	signal pixel_D_multip_red_s   	  : unsigned(23 downto 0);
	signal pixel_D_multip_green_s 	  : unsigned(23 downto 0);
	signal pixel_D_multip_blue_s  	  : unsigned(23 downto 0);
	
	signal pixel_A_multip_red_shift_s   	  : unsigned(7 downto 0);
	signal pixel_A_multip_green_shift_s 	  : unsigned(7 downto 0);
	signal pixel_A_multip_blue_shift_s  	  : unsigned(7 downto 0);
	
	signal pixel_B_multip_red_shift_s   	  : unsigned(7 downto 0);
	signal pixel_B_multip_green_shift_s 	  : unsigned(7 downto 0);
	signal pixel_B_multip_blue_shift_s  	  : unsigned(7 downto 0);
	
	signal pixel_C_multip_red_shift_s   	  : unsigned(7 downto 0);
	signal pixel_C_multip_green_shift_s 	  : unsigned(7 downto 0);
	signal pixel_C_multip_blue_shift_s  	  : unsigned(7 downto 0);
	
	signal pixel_D_multip_red_shift_s   	  : unsigned(7 downto 0);
	signal pixel_D_multip_green_shift_s 	  : unsigned(7 downto 0);
	signal pixel_D_multip_blue_shift_s  	  : unsigned(7 downto 0);
	
-- pixel value multip. with index rep. reg.--
	signal pixel_A_multip_red_r   	  : unsigned(7 downto 0);
	signal pixel_A_multip_green_r 	  : unsigned(7 downto 0);
	signal pixel_A_multip_blue_r  	  : unsigned(7 downto 0);
	
	signal pixel_B_multip_red_r   	  : unsigned(7 downto 0);
	signal pixel_B_multip_green_r 	  : unsigned(7 downto 0);
	signal pixel_B_multip_blue_r  	  : unsigned(7 downto 0);
	
	signal pixel_C_multip_red_r   	  : unsigned(7 downto 0);
	signal pixel_C_multip_green_r 	  : unsigned(7 downto 0);
	signal pixel_C_multip_blue_r  	  : unsigned(7 downto 0);
	
	signal pixel_D_multip_red_r   	  : unsigned(7 downto 0);
	signal pixel_D_multip_green_r 	  : unsigned(7 downto 0);
	signal pixel_D_multip_blue_r  	  : unsigned(7 downto 0);
	
-- pixel value sums --
	signal interpol_pix_red_s		  : unsigned(7 downto 0);
	signal interpol_pix_green_s	  : unsigned(7 downto 0);
	signal interpol_pix_blue_s		  : unsigned(7 downto 0);

-- correcting phase --
	signal interpol_pix_red_r0		  : unsigned(7 downto 0);
	signal interpol_pix_green_r0	  : unsigned(7 downto 0);
	signal interpol_pix_blue_r0	  : unsigned(7 downto 0);
	
	signal interpol_pix_red_r1		  : unsigned(7 downto 0);
	signal interpol_pix_green_r1	  : unsigned(7 downto 0);
	signal interpol_pix_blue_r1	  : unsigned(7 downto 0);
	
	signal interpol_pix_red_r2		  	: unsigned(7 downto 0);
	signal interpol_pix_green_r2	  	: unsigned(7 downto 0);
	signal interpol_pix_blue_r2		: unsigned(7 downto 0);
	
	--	Output values  --
	signal o_red	: unsigned(7 downto 0);
	signal o_green	: unsigned(7 downto 0);
	signal o_blue	: unsigned(7 downto 0);
	
begin
    ---------------------
    --     GLOBAL      --
    ---------------------
--	local_addr_s <= signed(bus_addr_i) - C_BASEADDR;
--	reg_word_addr <= signed(local_addr_s) - REGISTER_OFFSET;
--	reg_idx <= reg_word_addr(ADDR_WIDTH-1 downto 1);
--	   process(clk_i) begin
--		  if rising_edge(clk_i) then
--			 if bus_we_i = '1' and 0 <= reg_word_addr and reg_word_addr < REGISTER_NUMBER*2 then
--				if reg_word_addr(0) = '1' then
--						registers_s(to_integer(reg_idx))(63 downto 32) <= unsigned(bus_data_i);
--					else
--						registers_s(to_integer(reg_idx))(31 downto 0) <= unsigned(bus_data_i);
--					end if;
--			 end if;
--		  end if;
--	   end process;
	   
	----------------------
	--       RAM        --
	----------------------
	-- debug stuff --
	
--	process(clk_i, rst_n_i)begin
	--	if rising_edge(clk_i)then
	--		if(rst_n_i = '0')then
			   src_mem_width <= "0000000000000010";
				src_x  <= "0000000000000000";
				src_y  <= "0000000000000000";
				src_w  <= "0000000000000100";
				src_h  <= "0000000000000100";
				dst_x  <= "0000000000000000";
				dst_y  <= "0000000000000000";
				dst_w  <= "0000000000000100";
				dst_h  <= "0000000000000100";
				zoom_x <= "0100000000000000";
				zoom_y <= "0100000000000000";
	--		end if;
	--	end if;
	--end process;
	
	with phase_i select
		mem_addr_s <=
			pix_A_addr	when "00",
			pix_B_addr	when "01",
			pix_C_addr	when "10",
			pix_D_addr	when others;
			
	process(clk_i) begin
		if rising_edge(clk_i) then
			mem_addr_r <= mem_addr_s;
		end if;
	end process;
	
	ram_i : ram
	port map(
		i_clk					=> clk_i,
		i_r_addr				=> std_logic_vector(mem_addr_r), 
		i_data				=> bus_data_i,
		i_we					=> bus_we_i,
		i_w_addr				=> bus_addr_i,
		unsigned(o_data)	=> mem_data_s
	);		
	
-- unos odgovarajucih vrednosti iz rama u reg --

--	mem_data_red_s <= mem_data_s(31 downto 24);
--	mem_data_green_s <= mem_data_s(23 downto 16);
--	mem_data_blue_s <= mem_data_s(15 downto 8);
	process(clk_i) begin
		if rising_edge(clk_i) then
			case phase_i is
				when "01" =>
					pixel_A_red_r   <= mem_data_s(7  downto 0); 
					pixel_A_green_r <= mem_data_s(15 downto 8); 
					pixel_A_blue_r  <= mem_data_s(23 downto 16);
					
				when "10" =>
					pixel_B_red_r   <= mem_data_s(7  downto 0); 
					pixel_B_green_r <= mem_data_s(15 downto 8); 
					pixel_B_blue_r  <= mem_data_s(23 downto 16); 
					
				when "11" =>
					pixel_C_red_r   <= mem_data_s(7  downto 0); 
					pixel_C_green_r <= mem_data_s(15 downto 8); 
					pixel_C_blue_r  <= mem_data_s(23 downto 16); 
			
				when others =>
					pixel_D_red_r   <= mem_data_s(7  downto 0); 
					pixel_D_green_r <= mem_data_s(15 downto 8); 
					pixel_D_blue_r  <= mem_data_s(23 downto 16); 
			end case;
		end if;
	end process;
	
---------------------------------------------
--            RACUNANJE ADRESA             --
---------------------------------------------

--	static inline u32 round_fix(u32 num, u8 shift) {
--	u32 half = 0x1 << (shift-1);
--	return (num + half) >> shift;
--}

--#define round_fix_1(num) (((num)+1) >> 1)

	px <= "000000" & pixel_col_i;
	py <= "0000000" & pixel_row_i;
	
	sx <= px - dst_x;
	sy <= py - dst_y;
	
	tmp0_x <= src_x + sx;  
	tmp0_y <= src_y + sy;
	
	tmp1_x <= tmp0_x * zoom_x;
	tmp1_y <= tmp0_y * zoom_y;
	
	tmp_x <= tmp1_x + 1;
	tmp_y <= tmp1_y + 1;
				
	x <= '0' & tmp_x(31 downto 1);
	y <= '0' & tmp_y(31 downto 1);
	
	int_x <= x(28 downto 13) when x(28 downto 13) < src_w else
				src_w-1;
	int_y <= y(28 downto 13) when y(28 downto 13) < src_h else
				src_h-1;
	
	diff_x <= "000" & x(12 downto 0);
	diff_Y <= "000" & x(12 downto 0);
				
	inc_x <= "00000001" when int_x = src_w-1 else "00000000";
	inc_y <= src_mem_width when int_y = src_h-1 else "00000000";
				
	addr_base <= int_y*src_mem_width;
	
	pix_A_addr_tmp <= addr_base + int_x;
	pix_B_addr_tmp <= addr_base + int_x + inc_x;	
	pix_C_addr_tmp <= addr_base + int_x + inc_y;
	pix_D_addr_tmp <= addr_base + int_x + inc_x + inc_y;
	
	pix_A_addr <= pix_A_addr_tmp(ADDR_WIDTH-1 downto 0);
	pix_B_addr <= pix_B_addr_tmp(ADDR_WIDTH-1 downto 0);
	pix_C_addr <= pix_C_addr_tmp(ADDR_WIDTH-1 downto 0);
	pix_D_addr <= pix_D_addr_tmp(ADDR_WIDTH-1 downto 0);
	
-- RACUNANJE TEZINSKIH KOEFICIJENATA --
	
	temp_1A_s <= unsigned(fix_one) - diff_x;
	temp_2A_s <= unsigned(fix_one) - diff_y;
	temp_3A_s <= temp_1A_s * temp_2A_s;
	index_A_tmp_s <= temp_3A_s + unsigned(fix_half);
	
	temp_1B_s <= unsigned(fix_one) - diff_x;
	temp_2B_s <= diff_y;
	temp_3B_s <= temp_1B_s * temp_2B_s;
	index_B_tmp_s <= temp_3B_s + unsigned(fix_half);
	
	temp_1C_s <= diff_x;
	temp_2C_s <= unsigned(fix_one) - diff_y;
	temp_3C_s <= temp_1C_s * temp_2C_s;
	index_C_tmp_s <= temp_3C_s + unsigned(fix_half);
	
	temp_1D_s <= diff_x;
	temp_2D_s <= diff_y;
	temp_3D_s <= temp_1D_s * temp_2D_s;
	index_D_tmp_s <= temp_3D_s + unsigned(fix_half);
	
	temp_A_s <= index_A_tmp_s(28 downto 13);
	temp_B_s <= index_B_tmp_s(28 downto 13);
	temp_C_s <= index_C_tmp_s(28 downto 13);
	temp_D_s <= index_D_tmp_s(28 downto 13);
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			temp_A_r <= temp_A_s;
			temp_B_r <= temp_B_s;
			temp_C_r <= temp_C_s;
			temp_D_r <= temp_D_s;
		end if;
	end process;
			
--------------------------------------
		--- mnozenje sa indeksom ---
--------------------------------------
--8b.0b * 1b.13b = 8b.13b >> 13 = 8b.0b
	pixel_A_multip_red_s 	<= pixel_A_red_r   * temp_A_r;
	pixel_A_multip_green_s 	<= pixel_A_green_r * temp_A_r; 
	pixel_A_multip_blue_s 	<= pixel_A_blue_r  * temp_A_r; 
	
	pixel_B_multip_red_s 	<= pixel_B_red_r   * temp_B_r;   
	pixel_B_multip_green_s 	<= pixel_B_green_r * temp_B_r; 
	pixel_B_multip_blue_s 	<= pixel_B_blue_r  * temp_B_r;  
	
	pixel_C_multip_red_s 	<= pixel_C_red_r   * temp_C_r;   
	pixel_C_multip_green_s 	<= pixel_C_green_r * temp_C_r; 
	pixel_C_multip_blue_s 	<= pixel_C_blue_r  * temp_C_r;  
	
	pixel_D_multip_red_s  	<= pixel_D_red_r   * temp_D_r;  
	pixel_D_multip_green_s  <= pixel_D_green_r * temp_D_r;
	pixel_D_multip_blue_s  	<= pixel_D_blue_r  * temp_D_r; 
	
	pixel_A_multip_red_shift_s 	<= pixel_A_multip_red_s(20 downto 13);
	pixel_A_multip_green_shift_s 	<= pixel_A_multip_green_s(20 downto 13);
	pixel_A_multip_blue_shift_s 	<= pixel_A_multip_blue_s(20 downto 13);
	
	pixel_B_multip_red_shift_s 	<= pixel_B_multip_red_s(20 downto 13);
	pixel_B_multip_green_shift_s 	<= pixel_B_multip_green_s(20 downto 13);
	pixel_B_multip_blue_shift_s 	<= pixel_B_multip_blue_s(20 downto 13);
	
	pixel_C_multip_red_shift_s 	<= pixel_C_multip_red_s(20 downto 13);
	pixel_C_multip_green_shift_s 	<= pixel_C_multip_green_s(20 downto 13);
	pixel_C_multip_blue_shift_s 	<= pixel_C_multip_blue_s(20 downto 13);
	
	pixel_D_multip_red_shift_s  	<= pixel_D_multip_red_s(20 downto 13);
	pixel_D_multip_green_shift_s  <= pixel_D_multip_green_s(20 downto 13);
	pixel_D_multip_blue_shift_s  	<= pixel_D_multip_blue_s(20 downto 13);

	process(clk_i) begin
		if rising_edge(clk_i) then
			pixel_A_multip_red_r 	<= pixel_A_multip_red_shift_s;
			pixel_A_multip_green_r 	<= pixel_A_multip_green_shift_s;
			pixel_A_multip_blue_r 	<= pixel_A_multip_blue_shift_s;
	
			pixel_B_multip_red_r 	<= pixel_B_multip_red_shift_s;
			pixel_B_multip_green_r 	<= pixel_B_multip_green_shift_s;
			pixel_B_multip_blue_r 	<= pixel_B_multip_blue_shift_s;
			
			pixel_C_multip_red_r 	<= pixel_C_multip_red_shift_s;
			pixel_C_multip_green_r 	<= pixel_C_multip_green_shift_s;
			pixel_C_multip_blue_r 	<= pixel_C_multip_blue_shift_s;
			
			pixel_D_multip_red_r  	<= pixel_D_multip_red_shift_s;
			pixel_D_multip_green_r  <= pixel_D_multip_green_shift_s;
			pixel_D_multip_blue_r  	<= pixel_D_multip_blue_shift_s;
		end if;
	end process;

	interpol_pix_red_s		<= pixel_A_multip_red_r   + pixel_B_multip_red_r   + pixel_C_multip_red_r   + pixel_D_multip_red_r;
	interpol_pix_green_s	<= pixel_A_multip_green_r + pixel_B_multip_green_r + pixel_C_multip_green_r + pixel_D_multip_green_r;	  
	interpol_pix_blue_s		<= pixel_A_multip_blue_r  + pixel_B_multip_blue_r  + pixel_C_multip_blue_r  + pixel_D_multip_blue_r;
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			interpol_pix_red_r0   <= interpol_pix_red_s;
			interpol_pix_green_r0 <= interpol_pix_green_s;
			interpol_pix_blue_r0  <= interpol_pix_blue_s;
		end if;
	end process;
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			interpol_pix_red_r1   <= interpol_pix_red_r0;
			interpol_pix_green_r1 <= interpol_pix_green_r0;
			interpol_pix_blue_r1  <= interpol_pix_blue_r0;
		end if;
	end process;
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			interpol_pix_red_r2   <= interpol_pix_red_r1;
			interpol_pix_green_r2 <= interpol_pix_green_r1;
			interpol_pix_blue_r2  <= interpol_pix_blue_r1;
		end if;
	end process;
	
	o_red	  <= interpol_pix_red_r2;
	o_green <= interpol_pix_green_r2;
	o_blue  <= interpol_pix_blue_r2;
	
	rgb_o <= std_logic_vector(o_blue & o_green & o_red);
	
end Behavioral;