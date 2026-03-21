`default_nettype none
//The following code acts as the top file for the snake game, includes instantiations to game logic, game controller ROM and //drawing logic.

module vga_demo(
    input  wire CLOCK_50,
    input  wire [9:0]  SW,
    input  wire [3:0]  KEY,
    output wire [9:0]  LEDR,
    input  wire PS2_CLK,
    input  wire PS2_DAT,
    output wire [6:0]  HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire VGA_HS,
    output wire VGA_VS,
    output wire VGA_BLANK_N,
    output wire VGA_SYNC_N,
    output wire VGA_CLK
);

//VGA resolution parameters 
    parameter RESOLUTION   = "320x240";
    parameter COLOR_DEPTH  = 6;
    parameter nX = 9;
    parameter nY = 8;
    localparam integer BLOCK = 20; 

    // Use KEY[0] for reset
    wire Resetn = KEY[0];

    // State definitions for game_controller 
    localparam STATE_START = 2'b00;
    localparam STATE_PLAY  = 2'b01;
    localparam STATE_OVER  = 2'b10;
    localparam STATE_WIN = 2'b11;

    // ---------------------- Game Logic signals -------------------------
    wire [2:0] game_direction;
    wire [9:0] game_x_head, game_y_head;
    wire [99:0] game_x_body, game_y_body;
    wire [9:0] game_tail_x, game_tail_y;
    wire [3:0] game_segments;
    wire [9:0] x_apple, y_apple;
    wire [3:0] score;
    wire game_tick_out;

    // ---------------------- Game Controller signals ------------------
    wire [1:0] master_game_state; // main state from game_controller
    wire snake_is_dead;     // death/game over signal from game.v
    wire key_press_pulse;   // single-cycle pulse for key presses


    // ---------------------- PS/2 Decoder ---------------------
    wire PS2_CLK_S, PS2_DAT_S; //DAT: bit packet (start, data, parity, stop) that syncs with clk
    sync S_ps2c (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
    sync S_ps2d (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

    reg prev_ps2_clk;
//samples data from PS2_DAT   
 always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) prev_ps2_clk <= 1'b1;
        else prev_ps2_clk <= PS2_CLK_S;
    end
   
 // ---------------------- PS2 scancodes reading  ------------------
 wire negedge_ps2_clk = (prev_ps2_clk & ~PS2_CLK_S);
    reg [3:0]  ps2_bit_count; //tracks which bit of 11-frame bit
    reg [10:0] ps2_shift_reg; //stored bits received
    reg [7:0]  scan_code; // holds keyboard pressed value 
    reg        scan_ready; //flag to indicate whether keyboard input has been read

//reads and stores data
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            ps2_bit_count <= 0; ps2_shift_reg <= 0; scan_code <= 0; scan_ready <= 0;
        end else begin
            scan_ready <= 0;
            if (negedge_ps2_clk) begin
                if (ps2_bit_count == 0 && PS2_DAT_S == 0) ps2_bit_count <= 1;
                else if (ps2_bit_count >= 1 && ps2_bit_count <= 8) begin
                    ps2_shift_reg[ps2_bit_count-1] <= PS2_DAT_S;
                    ps2_bit_count <= ps2_bit_count + 1;
                end else if (ps2_bit_count == 9) ps2_bit_count <= 10;
                else if (ps2_bit_count == 10) begin
                    ps2_bit_count <= 0; scan_code <= ps2_shift_reg[7:0]; scan_ready <= 1;
                end
            end
        end
    end

    // create a single-cycle pulse from scan_ready for game_controller
    reg prev_scan_ready;
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if(!Resetn) prev_scan_ready <= 1'b0;
        else prev_scan_ready <= scan_ready;
    end
    assign key_press_pulse = scan_ready && !prev_scan_ready;

//mapping of scan codes to WASD
    reg [2:0] key_out;
    always @(*) begin
        case (scan_code)
            8'h1D: key_out = 3'd1; // W
            8'h1B: key_out = 3'd2; // S
            8'h1C: key_out = 3'd3; // A
            8'h23: key_out = 3'd4; // D
            default: key_out = 3'd0;
        endcase
    end
	 
 wire player_has_won = (game_segments >= 4'd10);
    
    // ----------------------  Game Controller Instantiation -------------------
    game_controller controller_inst (
        .clk(CLOCK_50),
        .reset(Resetn),
        .key_start(key_press_pulse), 
        .snake_dead(snake_is_dead),  // input from game.v
		  .player_won(player_has_won),
        .game_state(master_game_state) // master state output
    );

    // ---------------------- Game Logic Instantiation  ------------------------
    game game_inst (
        .clk      (CLOCK_50),
        .reset    (Resetn),
        .direction(game_direction),
        .key_out  (key_out),
         .game_state(master_game_state), 
 .btn_fast_n(KEY[2]),      // NEW
    .btn_slow_n(KEY[3]),      // NEW
        .snake_dead(snake_is_dead),  
        .x_head   (game_x_head),
        .y_head   (game_y_head),
        .x_body   (game_x_body),
        .y_body   (game_y_body),
        .segments (game_segments),
        .x_apple  (x_apple),
        .y_apple  (y_apple),
        .x_tail   (game_tail_x),
        .y_tail   (game_tail_y),
        .score    (score),
        .game_tick(game_tick_out)
    );

    // ---------------------- Draw Logic (Game Play) ---------------------
    // for ”PLAY” state
    reg prev_game_tick;
    reg draw_trigger;

//checks when game_tick occurs while playing -> update graphics once
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            prev_game_tick <= 0; draw_trigger <= 0;
        end else begin
            prev_game_tick <= game_tick_out;
            // Only trigger drawing if in the PLAY state
            if (master_game_state == STATE_PLAY) begin
                draw_trigger <= game_tick_out && !prev_game_tick; // Rising edge
            end else begin
                draw_trigger <= 0;
            end
        end
    end

    // capture current game coordinates
    reg [9:0] curr_head_x, curr_head_y;
    reg [9:0] curr_tail_x, curr_tail_y;
    reg [9:0] curr_apple_x, curr_apple_y;
    
    always @(posedge CLOCK_50) begin
        if (draw_trigger) begin
            curr_head_x <= game_x_head;
            curr_head_y <= game_y_head;
            curr_tail_x <= game_tail_x;
            curr_tail_y <= game_tail_y;
            curr_apple_x <= x_apple;
            curr_apple_y <= y_apple;
        end
    end

    // FSM for drawing snake parts in order 
// (in order) draw_trigger = 1 → ERASE_TAIL > DRAW_HEAD > DRAW_APPLE > DRAW_DONE
    reg [2:0] draw_state;
    localparam DRAW_IDLE  = 0, ERASE_TAIL = 1, DRAW_HEAD = 2, DRAW_APPLE = 3, DRAW_DONE = 4;

    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) draw_state <= DRAW_IDLE;
        // if not in PLAY state, reset the drawing FSM
        else if (master_game_state != STATE_PLAY) begin
            draw_state <= DRAW_IDLE;
        end
        // run the FSM as normal
        else begin
            case (draw_state)
                DRAW_IDLE: if (draw_trigger) draw_state <= ERASE_TAIL;
                ERASE_TAIL: if (tail_done) draw_state <= DRAW_HEAD;
                DRAW_HEAD: if (head_done) draw_state <= DRAW_APPLE;
                DRAW_APPLE: if (apple_draw_done) draw_state <= DRAW_DONE;
                DRAW_DONE: draw_state <= DRAW_IDLE;
            endcase
        end
    end

    // start pulses (1 cycle)
    reg [2:0] draw_state_prev;
    always @(posedge CLOCK_50) draw_state_prev <= draw_state;

    wire tail_start = (draw_state == ERASE_TAIL) && (draw_state_prev != ERASE_TAIL);
    wire head_start = (draw_state == DRAW_HEAD) && (draw_state_prev != DRAW_HEAD);
    wire apple_draw_start = (draw_state == DRAW_APPLE) && (draw_state_prev != DRAW_APPLE);

    // draw boxes
    wire [nX-1:0] head_x_pix, tail_x_pix, apple_draw_x;
    wire [nY-1:0] head_y_pix, tail_y_pix, apple_draw_y;
    wire [COLOR_DEPTH-1:0] head_color_pix, tail_color_pix, apple_draw_color;
    wire head_write, tail_write, apple_draw_write_sig;
    wire head_done, tail_done, apple_draw_done;

//drawing instantiations for snake head, segments, erase tail, draw apple
    snake_box #(.nX(nX), .nY(nY), .COLOR_DEPTH(COLOR_DEPTH), .BOX_SIZE_X(BLOCK), .BOX_SIZE_Y(BLOCK))
    draw_head_box (.Clock(CLOCK_50), .Resetn(Resetn), .start(head_start),
        .centre_x(curr_head_x[8:0] + 9'd10), .centre_y(curr_head_y[7:0] + 8'd10), .erase(1'b0),
        .VGA_x(head_x_pix), .VGA_y(head_y_pix), .VGA_color(head_color_pix), .VGA_write(head_write), .done(head_done));

    snake_box #(.nX(nX), .nY(nY), .COLOR_DEPTH(COLOR_DEPTH), .BOX_SIZE_X(BLOCK), .BOX_SIZE_Y(BLOCK))
    erase_tail_box (.Clock(CLOCK_50), .Resetn(Resetn), .start(tail_start),
        .centre_x(curr_tail_x[8:0] + 9'd10), .centre_y(curr_tail_y[7:0] + 8'd10), .erase(1'b1),
        .VGA_x(tail_x_pix), .VGA_y(tail_y_pix), .VGA_color(tail_color_pix), .VGA_write(tail_write), .done(tail_done));

    snake_box #(.nX(nX), .nY(nY), .COLOR_DEPTH(COLOR_DEPTH), .BOX_SIZE_X(BLOCK), .BOX_SIZE_Y(BLOCK))
    draw_apple_box (.Clock(CLOCK_50), .Resetn(Resetn), .start(apple_draw_start),
        .centre_x(curr_apple_x[8:0] + 9'd10), .centre_y(curr_apple_y[7:0] + 8'd10), .erase(1'b0),
        .VGA_x(apple_draw_x), .VGA_y(apple_draw_y), .VGA_color(apple_draw_color), .VGA_write(apple_draw_write_sig), .done(apple_draw_done));

    // MUX for game drawing
    reg [nX-1:0] MUX_x_play;
    reg [nY-1:0] MUX_y_play;
    reg [COLOR_DEPTH-1:0] MUX_color_play;
    reg MUX_write_play;

    always @(*) begin
        MUX_write_play = 0; MUX_x_play = 0; MUX_y_play = 0; MUX_color_play = 0;
        if (apple_draw_write_sig) begin
            MUX_x_play = apple_draw_x; MUX_y_play = apple_draw_y; MUX_color_play = 6'b11_00_00; MUX_write_play = 1;
        end else if (head_write) begin
            MUX_x_play = head_x_pix; MUX_y_play = head_y_pix; MUX_color_play = 6'b00_00_11; MUX_write_play = 1;
        end else if (tail_write) begin
            MUX_x_play = tail_x_pix; MUX_y_play = tail_y_pix; MUX_color_play = tail_color_pix; MUX_write_play = 1;
        end
    end
    
    
//—--------------------------- Background restoring logic (ROM) —-------------------------------
    
    reg [1:0] screen_draw_fsm; // FSM to control fullscreen drawing
    reg [9:0] screen_draw_x;   // 0-319
    reg [8:0] screen_draw_y;   // 0-239
    
    localparam S_DRAW_IDLE = 0;
    localparam S_DRAW_START = 1; // trigger to start drawing
    localparam S_DRAW_BUSY = 2;  // drawing pixel by pixel
    
    wire [18:0] screen_rom_addr = screen_draw_y * 320 + screen_draw_x;
    wire [COLOR_DEPTH-1:0] start_screen_pixel;
    wire [COLOR_DEPTH-1:0] end_screen_pixel;
	  wire [COLOR_DEPTH-1:0] play_screen_pixel;
	  wire [COLOR_DEPTH-1:0] win_screen_pixel;
        
    // ROM instantations
    start rom_start (
        .clock(CLOCK_50), 
        .address(screen_rom_addr), 
        .q(start_screen_pixel)
    );
    
	 
	 end_screen rom_end (
        .clock(CLOCK_50), 
        .address(screen_rom_addr), 
        .q(end_screen_pixel)
    );
	 
	 bg rom_play(
		.clock(CLOCK_50),
		.address(screen_rom_addr[16:0]),
		.q(play_screen_pixel)
	 );
    
	 win_screen rom_win (
	 .clock(CLOCK_50),
		.address(screen_rom_addr),
		.q(win_screen_pixel)
	 );
    
    // detect when state changes to a non-play state
    reg [1:0] prev_master_game_state;
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if(!Resetn) prev_master_game_state <= STATE_START;
        else prev_master_game_state <= master_game_state;
    end
    
    // trigger a redraw when we enter START or OVER
    wire state_changed = (master_game_state != prev_master_game_state);
	 wire trigger_fullscreen_draw = state_changed;


    // fullscreen draw FSM, overwrite the entire frame buffer with a MIF file
    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            screen_draw_fsm <= S_DRAW_START;
            screen_draw_x <= 0;
            screen_draw_y <= 0;
        end else begin
            case (screen_draw_fsm)
                S_DRAW_IDLE: begin
                    // wait for a trigger (entering START or OVER)
                    if (trigger_fullscreen_draw) begin
                        screen_draw_fsm <= S_DRAW_START;
                        screen_draw_x <= 0;
                        screen_draw_y <= 0;
                    end
                end
                
                S_DRAW_START: begin
                    // state ensures we start at (0,0)
                    screen_draw_fsm <= S_DRAW_BUSY;
                end
                
                S_DRAW_BUSY: begin
                    // keep drawing until we hit the end
                    if (screen_draw_x == 319 && screen_draw_y == 239) begin
                        screen_draw_fsm <= S_DRAW_IDLE; // Done
                    end
                    else if (screen_draw_x == 319) begin
                        screen_draw_x <= 0;
                        screen_draw_y <= screen_draw_y + 1;
                    end
                    else begin
                        screen_draw_x <= screen_draw_x + 1;
                    end
                end
            endcase
        end
    end
    
    // —------------------------------Final MUX: decide what to write to the VGA RAM—---------------------------- ---
    
    reg [nX-1:0] MUX_x_final;
    reg [nY-1:0] MUX_y_final;
    reg [COLOR_DEPTH-1:0] MUX_color_final;
    reg MUX_write_final;
    
    always @(*) begin
    
        // PRIORITY 1: background _→  runs when transitioning states (Start, Over, Win, or Play Init)
        if(screen_draw_fsm == S_DRAW_BUSY) begin
            MUX_write_final = 1'b1;
            MUX_x_final     = screen_draw_x;
            MUX_y_final     = screen_draw_y;
          
            case(master_game_state)
                STATE_START: MUX_color_final = start_screen_pixel;
                STATE_OVER:  MUX_color_final = end_screen_pixel;
                STATE_WIN:   MUX_color_final = win_screen_pixel; // Now this will work!
                default:     MUX_color_final = play_screen_pixel;
            endcase
        end
      
        // PRIORITY 2: game play (snake & apple drawing) → only runs if we are playing AND background is finished loading
        else if (master_game_state == STATE_PLAY) begin
            MUX_x_final     = MUX_x_play;
            MUX_y_final     = MUX_y_play;
            MUX_color_final = MUX_color_play;
            MUX_write_final = MUX_write_play;
        end
       
        // PRIORITY 3: Idle (static screens) → on the Start/Win/Lose screen and loading is done
        else begin
            MUX_write_final = 0;
            MUX_x_final     = 0;
            MUX_y_final     = 0;
            MUX_color_final = 0;
        end
    end


	 
    // —----------------------------------- Output LED/HEX —--------------------------------------
    assign LEDR[1:0] = master_game_state; // Show master state on LEDs
    assign LEDR[4:2] = key_out;
	 wire [3:0] score_ones = score % 10;
	 wire [3:0] score_tens = score / 10; // Display them on HEX0 and HEX1 
	 hex7seg hex_digit_0 (.hex(score_ones), .display(HEX0)); // '0' in '10' 
	 hex7seg hex_digit_1 (.hex(score_tens), .display(HEX1)); // '1' in '10
	assign HEX2 = 7'b1111111; assign HEX3 = 7'b1111111; assign HEX4 = 7'b1111111; assign HEX5 = 7'b1111111;

	 	 
    // —---------------------------------VGA Adapter—------------------------------------------
    vga_adapter VGA (
        .resetn(Resetn), 
		  .clock(CLOCK_50), 
        // Connect the FINAL MUX signals
        .color(MUX_color_final), 
        .x(MUX_x_final), 
        .y(MUX_y_final), 
        .write(MUX_write_final),
        // VGA physical pins
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), 
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_BLANK_N(VGA_BLANK_N), 
        .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK)
    );
    defparam VGA.RESOLUTION = RESOLUTION;
    defparam VGA.BACKGROUND_IMAGE = "./MIF/background.mif"; 
    defparam VGA.COLOR_DEPTH = COLOR_DEPTH;

endmodule



// —----------------------------------------- syncronizer for PS2 —-----------------------------------------
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;

    reg Qi; // internal node

    always @(posedge Clock)
        if (Resetn == 0) begin
            Qi <= 1'b0;
            Q <= 1'b0;
        end
        else begin
            Qi <= D;
            Q <= Qi;
        end
endmodule



// —------------------------------------------- HEX display —------------------------------
module hex7seg (hex, display);
    input wire [3:0] hex;
    output reg [6:0] display;
	  
    always @ (hex)
        case (hex)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0011000;
            4'hA: display = 7'b0001000;
            4'hB: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hD: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
        endcase
endmodule

// —--------------------------- Main Snake Game Drawer —-------------------------------
module snake_box #( 
	parameter nX = 9,
   parameter nY = 8,
   parameter COLOR_DEPTH = 6,
	parameter BOX_SIZE_X = 12,
   parameter BOX_SIZE_Y = 12
   
)(
	 input wire Resetn, 
	 input wire Clock,
	 input wire start,
	 input wire [nX-1:0] centre_x,
	 input wire [nY-1:0] centre_y,
	 input wire erase,
    output reg [nX-1:0] VGA_x,
    output reg [nY-1:0] VGA_y,
    output reg [COLOR_DEPTH-1:0] VGA_color,
    output reg VGA_write,
	 output reg done
	 );

	 //PIXEL counter inside box
	 reg[4:0] XC, YC;
	 
	 // Drawing FSM
	 reg [1:0] state;
	 localparam S_IDLE = 2'b00,
					S_RUN = 2'b01,
					S_DONE = 2'b10;
					
	//pixel coordinates 
	wire [nX-1:0] draw_x = centre_x - (BOX_SIZE_X >> 1) + XC;
	wire [nY-1:0] draw_y = centre_y - (BOX_SIZE_Y >> 1) + YC;
	
	wire [COLOR_DEPTH-1:0] bg_pixel;
	reg [COLOR_DEPTH-1:0] bg_pixel_r;
	wire [18:0] bg_address = (draw_y << 8) + (draw_y << 6) + draw_x;

	bg bg_rom (
		 .clock(Clock),
		 .address(bg_address[16:0]),
		 .q(bg_pixel)
	);
	
	//update background
	always@(posedge Clock or negedge Resetn) begin
		if(!Resetn)
			bg_pixel_r <= {COLOR_DEPTH{1'b0}};
		else
			bg_pixel_r <= bg_pixel;
	end
	
	//solid blue
	wire [COLOR_DEPTH-1:0] blue_color = 6'b00_00_11;
	
	//drawing FSM
	always @(posedge Clock or negedge Resetn) begin
			  if (!Resetn) begin
					state     <= S_IDLE;
					XC        <= 0;
					YC        <= 0;
					VGA_x     <= {nX{1'b0}};
					VGA_y     <= {nY{1'b0}};
					VGA_color <= {COLOR_DEPTH{1'b0}};
					VGA_write <= 0;
					done      <= 0;
			  end else begin
					case (state)
						 S_IDLE: begin
							  VGA_write <= 0;
							  done      <= 0;
							  XC        <= 0;
							  YC        <= 0;
							  if (start) begin

									state <= S_RUN;
								end
						 end
 
					S_RUN: begin
							  VGA_x     <= draw_x;
							  VGA_y     <= draw_y;
							  VGA_color <= erase ? bg_pixel_r : blue_color;
							  VGA_write <= 1'b1;

							  if (XC == BOX_SIZE_X-1) begin
									XC <= 0;
									if (YC == BOX_SIZE_Y-1) begin
										 YC    <= 0;
										 state <= S_DONE;
									end else begin
										 YC <= YC + 1;
									end
							  end else begin
									XC <= XC + 1;
							  end
						 end


					

						 S_DONE: begin
							  VGA_write <= 0;
							  done      <= 1'b1;
							  state     <= S_IDLE;
						 end

						 
						 default: begin
                    state     <= S_IDLE;
                    VGA_write <= 1'b0;
                    done      <= 1'b0;
                end

						 
					endcase
			  end
		 end

endmodule



