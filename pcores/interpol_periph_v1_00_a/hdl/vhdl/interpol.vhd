library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interpol is
   generic(
      DATA_WIDTH           : natural := 8;
      COLOR_WIDTH          : natural := 24;
      ADDR_WIDTH           : natural := 13;
      REGISTER_OFFSET      : natural := 5439;   -- 6960           -- Pointer to registers in memory map
      C_BASEADDR           : natural := 0;               -- Pointer to local memory in memory map
      REGISTER_NUMBER      : natural := 10;              -- Number of registers used for sprites
      NUM_BITS_FOR_REG_NUM : natural := 4;               -- Number of bits required for number of registers
      MAP_OFFSET           : natural := 639;            -- Pointer to start of map in memory
      OVERHEAD             : natural := 5;               -- Number of overhead bits
      SPRITE_Z             : natural := 1                -- Z coordinate of sprite
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
		i_data   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
		i_we     : in  std_logic;
		i_w_addr : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
		o_data   : out std_logic_vector(DATA_WIDTH-1 downto 0)
   );
   end component ram;

	-- Types --
   type registers_t  is array (0 to REGISTER_NUMBER-1) of unsigned (63 downto  0);
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
   constant fix_half : unsigned (15 downto 0) := "0001000000000000";

   -- Globals --
   signal registers_s      : registers_t :=                                -- Array representing registers
   --   row   |    col  |en&size|  rot  | pointer
   (( x"0130" & x"00e3" & x"8f" & x"00" & x"01FF" ),  --mario
    ( x"0170" & x"00d5" & x"8f" & x"00" & x"01BF" ),  --enemie
    ( x"0170" & x"011b" & x"8f" & x"00" & x"01BF" ),
    ( x"0170" & x"014d" & x"8f" & x"00" & x"01BF" ),
    ( x"0170" & x"01b1" & x"8f" & x"00" & x"01BF" ),
    ( x"0130" & x"01c6" & x"8f" & x"00" & x"013f" ),  --coin
    ( x"0130" & x"01d5" & x"8f" & x"00" & x"013f" ),
    ( x"0130" & x"01e4" & x"8f" & x"00" & x"013f" ),
    ( x"0130" & x"01f3" & x"8f" & x"00" & x"013f" ),
    ( x"0000" & x"0090" & x"7f" & x"00" & x"03d0" )); --brick

-- Addresses for mux --
	signal pix_A_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pix_B_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pix_C_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	signal pix_D_addr	: unsigned(ADDR_WIDTH-1 downto 0);
	
-- ram signals (data & addresses) --
	signal mem_addr_r   :  unsigned(ADDR_WIDTH-1 downto 0);
	signal mem_addr_s   :  unsigned(ADDR_WIDTH-1 downto 0);
	
--signal mem_data_r : std_logic_vector(DATA_WIDTH-1 downto 0);--
	signal mem_data_s : std_logic_vector(DATA_WIDTH-1 downto 0);

-- pixel values (taken from the ram at corresponding phase 'value')-- 
	signal pixel_A_red_r   : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_A_green_r : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_A_blue_r  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_B_red_r   : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_B_green_r : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_B_blue_r  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_C_red_r   : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_C_green_r : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_C_blue_r  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_D_red_r   : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_D_green_r : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_D_blue_r  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
-- pixel index value --
	signal index_A_tmp_s : std_logic_vector(31 downto 0);
	signal index_B_tmp_s : std_logic_vector(31 downto 0);
	signal index_C_tmp_s : std_logic_vector(31 downto 0);
	signal index_D_tmp_s : std_logic_vector(31 downto 0);

	signal index_A_s : std_logic_vector(15 downto 0); 
	signal index_B_s : std_logic_vector(15 downto 0); 
	signal index_C_s : std_logic_vector(15 downto 0);
	signal index_D_s : std_logic_vector(15 downto 0);

	signal index_A_r : std_logic_vector(15 downto 0); 
	signal index_B_r : std_logic_vector(15 downto 0); 
	signal index_C_r : std_logic_vector(15 downto 0);
	signal index_D_r : std_logic_vector(15 downto 0);

-- pixel value multip. with index --
	signal pixel_A_multip_red_s   	  : std_logic_vector(23 downto 0);
	signal pixel_A_multip_green_s 	  : std_logic_vector(23 downto 0);
	signal pixel_A_multip_blue_s  	  : std_logic_vector(23 downto 0);
	
	signal pixel_B_multip_red_s   	  : std_logic_vector(23 downto 0);
	signal pixel_B_multip_green_s 	  : std_logic_vector(23 downto 0);
	signal pixel_B_multip_blue_s  	  : std_logic_vector(23 downto 0);
	
	signal pixel_C_multip_red_s   	  : std_logic_vector(23 downto 0);
	signal pixel_C_multip_green_s 	  : std_logic_vector(23 downto 0);
	signal pixel_C_multip_blue_s  	  : std_logic_vector(23 downto 0);
	
	signal pixel_D_multip_red_s   	  : std_logic_vector(23 downto 0);
	signal pixel_D_multip_green_s 	  : std_logic_vector(23 downto 0);
	signal pixel_D_multip_blue_s  	  : std_logic_vector(23 downto 0);
	
	signal pixel_A_multip_red_shift_s   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_A_multip_green_shift_s 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_A_multip_blue_shift_s  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_B_multip_red_shift_s   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_B_multip_green_shift_s 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_B_multip_blue_shift_s  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_C_multip_red_shift_s   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_C_multip_green_shift_s 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_C_multip_blue_shift_s  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_D_multip_red_shift_s   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_D_multip_green_shift_s 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_D_multip_blue_shift_s  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
-- pixel value multip. with index rep. reg.--
	signal pixel_A_multip_red_r   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_A_multip_green_r 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_A_multip_blue_r  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_B_multip_red_r   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_B_multip_green_r 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_B_multip_blue_r  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_C_multip_red_r   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_C_multip_green_r 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_C_multip_blue_r  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
	signal pixel_D_multip_red_r   	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_D_multip_green_r 	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pixel_D_multip_blue_r  	  : std_logic_vector(DATA_WIDTH-1 downto 0);
	
-- pixel value sums --
	signal interpol_pix_red_s		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_green_s		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_blue_s		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	
	signal interpol_pix_red_sR		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_green_sR	  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_blue_sR		  : std_logic-vector(DATA_WIDTH-1 downto 0);

-- correcting phase --
	signal interpol_pix_red_r0		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_green_r0	  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_blue_r0		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	
	signal interpol_pix_red_r1		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_green_r1	  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_blue_r1		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	
	signal interpol_pix_red_r2		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_green_r2	  : std_logic-vector(DATA_WIDTH-1 downto 0);
	signal interpol_pix_blue_r2		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	
--	signal interpol_pix_red_r3		  : std_logic-vector(DATA_WIDTH-1 downto 0);
--	signal interpol_pix_green_r3	  : std_logic-vector(DATA_WIDTH-1 downto 0);
--	signal interpol_pix_blue_r3		  : std_logic-vector(DATA_WIDTH-1 downto 0);
	
	--	Output values  --
	signal o_red	: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal o_green	: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal o_blue	: std_logic_vector(DATA_WIDTH-1 downto 0);

begin
    ---------------------
    --     GLOBAL      --
    ---------------------
	local_addr_s <= signed(bus_addr_i) - C_BASEADDR;
	reg_word_addr <= signed(local_addr_s) - REGISTER_OFFSET;
	reg_idx <= reg_word_addr(ADDR_WIDTH-1 downto 1);
	   process(clk_i) begin
		  if rising_edge(clk_i) then
			 if bus_we_i = '1' and 0 <= reg_word_addr and reg_word_addr < REGISTER_NUMBER*2 then
				if reg_word_addr(0) = '1' then
						registers_s(to_integer(reg_idx))(63 downto 32) <= unsigned(bus_data_i);
					else
						registers_s(to_integer(reg_idx))(31 downto 0) <= unsigned(bus_data_i);
					end if;
			 end if;
		  end if;
	   end process;
	   
	----------------------
	--       RAM        --
	----------------------
	with phase_i select
		mem_addr_s <=
			pix_A_addr	when "00";
			pix_B_addr	when "01";
			pix_C_addr	when "10";
			pix_D_addr	when others;
			
	process(clk_i) begin
		if rising_edge(clk_i) then
			mem_addr_r <= mem_addr_s;
		end if;
	end process;
	
	ram_i : ram
	port map(
		i_clk		=> clk_i,
		i_r_addr	=> std_logic_vector(mem_addr_r), 
		i_data		=> bus_data_i,
		i_we		=> bus_we_i,
		i_w_addr	=> bus_addr_i,
		o_data		=> mem_data_s
	);		
	
-- unos odgovarajucih vrednosti iz rama u reg --

--	mem_data_red_s <= mem_data_s(31 downto 24);
--	mem_data_green_s <= mem_data_s(23 downto 16);
--	mem_data_blue_s <= mem_data_s(15 downto 8);

	process(clk_i, phase_i) begin
		if rising_edge(clk_i) then
			case phase_i is
				when "01" =>
					pixel_A_red_r   <= mem_data_s(31 downto 24); 
					pixel_A_green_r <= mem_data_s(23 downto 16); 
					pixel_A_blue_r  <= mem_data_s(15 downto 8); 
					
				when "10" =>
					pixel_B_red_r   <= mem_data_s(31 downto 24); 
					pixel_B_green_r <= mem_data_s(23 downto 16); 
					pixel_B_blue_r  <= mem_data_s(15 downto 8); 
					
				when "11" =>
					pixel_C_red_r   <= mem_data_s(31 downto 24); 
					pixel_C_green_r <= mem_data_s(23 downto 16); 
					pixel_C_blue_r  <= mem_data_s(15 downto 8); 
			
				when "00" =>
					pixel_D_red_r   <= mem_data_s(31 downto 24); 
					pixel_D_green_r <= mem_data_s(23 downto 16); 
					pixel_D_blue_r  <= mem_data_s(15 downto 8); 
			end case;
		end if;
	end process;
	
---------------------------------------------
--            RACUNANJE INDEXA             --
---------------------------------------------

--	static inline u32 round_fix(u32 num, u8 shift) {
--	u32 half = 0x1 << (shift-1);
--	return (num + half) >> shift;
--}

--#define round_fix_1(num) (((num)+1) >> 1)

	--diff_x <= x and "1111111111111";
	--diff_y <= y and "1111111111111";
	
	diff_x <= "000" & x(12 downto 0);
	diff_Y <= "000" & x(12 downto 0);
	
	index_A_tmp_s <= (fix_one - diff_x) * (fix_one - diff_y) + fix_half;
	index_B_tmp_s <= (fix_one - diff_x) * diff_y + fix_half;
	index_C_tmp_s <= diff_x * (fix_one - diff_y) + fix_half;
	index_D_tmp_s <= diff_x * diff_y + fix_half;
	
	index_A_s <= index_A_tmp_s(28 downto 13);
	index_B_s <= index_B_tmp_s(28 downto 13);
	index_C_s <= index_C_tmp_s(28 downto 13);
	index_D_s <= index_D_tmp_s(28 downto 13);
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			index_A_r <= index_A_s;
			index_B_r <= index_B_s;
			index_C_r <= index_C_s;
			index_D_r <= index_D_s;
		end if;
	end process;
			
--------------------------------------
		--- mnozenje sa indeksom ---
--------------------------------------
--8b.0b * 1b.13b = 8b.13b >> 13 = 8b.0b
	pixel_A_multip_red_s 	<= pixel_A_red_r   * index_A_r;
	pixel_A_multip_green_s 	<= pixel_A_green_r * index_A_r; 
	pixel_A_multip_blue_s 	<= pixel_A_blue_r  * index_A_r; 
	
	pixel_B_multip_red_s 	<= pixel_B_red_r   * index_B_r;   
	pixel_B_multip_green_s 	<= pixel_B_green_r * index_B_r; 
	pixel_B_multip_blue_s 	<= pixel_B_blue_r  * index_B_r;  
	
	pixel_C_multip_red_s 	<= pixel_C_red_r   * index_C_r;   
	pixel_C_multip_green_s 	<= pixel_C_green_r * index_C_r; 
	pixel_C_multip_blue_s 	<= pixel_C_blue_r  * index_C_r;  
	
	pixel_D_multip_red_s  	<= pixel_D_red_r   * index_D_r;  
	pixel_D_multip_green_s  <= pixel_D_green_r * index_D_r;
	pixel_D_multip_blue_s  	<= pixel_D_blue_r  * index_D_r; 
	
	pixel_A_multip_red_shift_s 		<= pixel_A_multip_red_s(20 downto 13);
	pixel_A_multip_green_shift_s 	<= pixel_A_multip_green_s(20 downto 13);
	pixel_A_multip_blue_shift_s 	<= pixel_A_multip_blue_s(20 downto 13);
	
	pixel_B_multip_red_shift_s 		<= pixel_B_multip_red_s(20 downto 13);
	pixel_B_multip_green_shift_s 	<= pixel_B_multip_green_s(20 downto 13);
	pixel_B_multip_blue_shift_s 	<= pixel_B_multip_blue_s(20 downto 13);
	
	pixel_C_multip_red_shift_s 		<= pixel_C_multip_red_s(20 downto 13);
	pixel_C_multip_green_shift_s 	<= pixel_C_multip_green_s(20 downto 13);
	pixel_C_multip_blue_shift_s 	<= pixel_C_multip_blue_s(20 downto 13);
	
	pixel_D_multip_red_shift_s  	<= pixel_D_multip_red_s(20 downto 13);
	pixel_D_multip_green_shift_s  	<= pixel_D_multip_green_s(20 downto 13);
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

	--interpol_pix_red_sR 	<= interpol_pix_red_s   when phase_1 = "10" else interpol_pix_red_sR;
	--interpol_pix_green_sR 	<= interpol_pix_green_s when phase_1 = "10" else interpol_pix_green_sR;
	--interpol_pix_blue_sR 	<= interpol_pix_blue_s  when phase_1 = "10" else interpol_pix_blue_sR;
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			interpol_pix_red_r0   <= interp_pix_red_s;
			interpol_pix_green_r0 <= interp_pix_green_s;
			interpol_pix_blue_r0  <= interp_pix_blue_s;
		end if;
	end process;
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			interpol_pix_red_r1   <= interp_pix_red_r0;
			interpol_pix_green_r1 <= interp_pix_green_r0;
			interpol_pix_blue_r1  <= interp_pix_blue_r0;
		end if;
	end process;
	
	process(clk_i) begin
		if rising_edge(clk_i) then
			interpol_pix_red_r2   <= interp_pix_red_r1;
			interpol_pix_green_r2 <= interp_pix_green_r1;
			interpol_pix_blue_r2  <= interp_pix_blue_r1;
		end if;
	end process;
end Behavioral;