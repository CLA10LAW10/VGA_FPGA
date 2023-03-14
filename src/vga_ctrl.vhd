library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_unsigned.all;

entity vga_ctrl is
  port (
    CLK_I    : in std_logic;
    VGA_HS_O : out std_logic;
    VGA_VS_O : out std_logic;
    VGA_R    : out std_logic_vector (3 downto 0);
    VGA_B    : out std_logic_vector (3 downto 0);
    VGA_G    : out std_logic_vector (3 downto 0));
end vga_ctrl;

architecture Behavioral of vga_ctrl is

  component clk_wiz_0
    port (-- Clock in ports
      CLK_IN1 : in std_logic;
      -- Clock out ports
      CLK_OUT1 : out std_logic
    );
  end component;

  --Sync Generation constants

  --***1920x1080@60Hz***-- Requires 148.5 MHz pxl_clk
  constant FRAME_WIDTH  : natural := 1920;
  constant FRAME_HEIGHT : natural := 1080;

  constant H_FP  : natural := 88;   --H front porch width (pixels)
  constant H_PW  : natural := 44;   --H sync pulse width (pixels)
  constant H_MAX : natural := 2200; --H total period (pixels)

  constant V_FP  : natural := 4;    --V front porch width (lines)
  constant V_PW  : natural := 5;    --V sync pulse width (lines)
  constant V_MAX : natural := 1125; --V total period (lines)

  constant H_POL : std_logic := '1';
  constant V_POL : std_logic := '1';

  --Moving Box constants
  constant BOX_WIDTH   : natural := 8;
  constant BOX_CLK_DIV : natural := 1000000; --MAX=(2^25 - 1)

  constant BOX_X_MAX : natural := (512 - BOX_WIDTH);
  constant BOX_Y_MAX : natural := (FRAME_HEIGHT - BOX_WIDTH);

  constant BOX_X_MIN : natural := 0;
  constant BOX_Y_MIN : natural := 256;

  constant BOX_X_INIT : std_logic_vector(11 downto 0) := x"000";
  constant BOX_Y_INIT : std_logic_vector(11 downto 0) := x"190"; --400

  signal pxl_clk : std_logic;
  signal active  : std_logic;

  signal h_cntr_reg : std_logic_vector(11 downto 0) := (others => '0');
  signal v_cntr_reg : std_logic_vector(11 downto 0) := (others => '0');

  signal h_sync_reg : std_logic := not(H_POL);
  signal v_sync_reg : std_logic := not(V_POL);

  signal h_sync_dly_reg : std_logic := not(H_POL);
  signal v_sync_dly_reg : std_logic := not(V_POL);

  signal vga_red_reg   : std_logic_vector(3 downto 0) := (others => '0');
  signal vga_green_reg : std_logic_vector(3 downto 0) := (others => '0');
  signal vga_blue_reg  : std_logic_vector(3 downto 0) := (others => '0');

  signal vga_red   : std_logic_vector(3 downto 0);
  signal vga_green : std_logic_vector(3 downto 0);
  signal vga_blue  : std_logic_vector(3 downto 0);

  signal box_x_reg    : std_logic_vector(11 downto 0) := BOX_X_INIT;
  signal box_x_dir    : std_logic                     := '1';
  signal box_y_reg    : std_logic_vector(11 downto 0) := BOX_Y_INIT;
  signal box_y_dir    : std_logic                     := '1';
  signal box_cntr_reg : std_logic_vector(24 downto 0) := (others => '0');

  signal update_box   : std_logic;
  signal pixel_in_box : std_logic;
begin
  clk_div_inst : clk_wiz_0
  port map
  (-- Clock in ports
    CLK_IN1 => CLK_I,
    -- Clock out ports
    CLK_OUT1 => pxl_clk);
  ----------------------------------------------------
  -------         TEST PATTERN LOGIC           -------
  ----------------------------------------------------

  process (active, h_cntr_reg, v_cntr_reg, sw)
  begin
    if active = '1'then
      case sw is
        when "0000" =>
          --do something
        when "0001" =>
          --do something
        when "0010" =>
          --do something
        when "0011" =>
          --do something
        when "0100" =>
          --do something
        when others
          vga_red   <= (others => '0');
          vga_green <= (others => '0');
          vga_blue  <= (others => '0');
      end case;
    else
      vga_red   <= (others => '0');
      vga_green <= (others => '0');
      vga_blue  <= (others => '0');
    end if;
  end process;

  ------------------------------------------------------
  -------         SYNC GENERATION                 ------
  ------------------------------------------------------

  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (h_cntr_reg = (H_MAX - 1)) then
        h_cntr_reg <= (others => '0');
      else
        h_cntr_reg <= h_cntr_reg + 1;
      end if;
    end if;
  end process;

  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if ((h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1))) then
        v_cntr_reg <= (others => '0');
      elsif (h_cntr_reg = (H_MAX - 1)) then
        v_cntr_reg <= v_cntr_reg + 1;
      end if;
    end if;
  end process;

  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) and (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) then
        h_sync_reg <= H_POL;
      else
        h_sync_reg <= not(H_POL);
      end if;
    end if;
  end process;
  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) and (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) then
        v_sync_reg <= V_POL;
      else
        v_sync_reg <= not(V_POL);
      end if;
    end if;
  end process;
  active <= '1' when ((h_cntr_reg < FRAME_WIDTH) and (v_cntr_reg < FRAME_HEIGHT))else
    '0';

  process (pxl_clk)
  begin
    if (rising_edge(pxl_clk)) then
      v_sync_dly_reg <= v_sync_reg;
      h_sync_dly_reg <= h_sync_reg;
      vga_red_reg    <= vga_red;
      vga_green_reg  <= vga_green;
      vga_blue_reg   <= vga_blue;
    end if;
  end process;

  VGA_HS_O <= h_sync_dly_reg;
  VGA_VS_O <= v_sync_dly_reg;
  VGA_R    <= vga_red_reg;
  VGA_G    <= vga_green_reg;
  VGA_B    <= vga_blue_reg;

end Behavioral;