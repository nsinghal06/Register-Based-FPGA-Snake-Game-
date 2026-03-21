
/*
module game(
    input wire clk, // This is CLOCK_50
    input wire reset,
    input wire [2:0] key_out,
    input wire [1:0] game_state,
    output wire snake_dead,
    
    // ------ SNAKE VARIABLES -------
    output reg [99:0] x_body,
    output reg [99:0] y_body,
    output reg [9:0] x_head,
    output reg [9:0] y_head,
    output reg [2:0] direction,
    output reg [3:0] segments,
    output reg [9:0] x_tail,
    output reg [9:0] y_tail,
    
    // ------ APPLE VARIABLES -------
    output wire [9:0] x_apple,
    output wire [9:0] y_apple,
    
    // ------ DISPLAY VARIABLES -------
    output reg [3:0] score,
    
    // ------ CLOCK/TIMER VARIABLES -------
    output reg game_tick
);

    // ------ INTERNAL SIGNALS -------
    reg ate;
    reg wall_collision;
    reg self_collision;

    reg [25:0] clk_div;
    reg slow_clk;
    reg prev_slow_clk;

    // ------ GAME STATE PARAMETERS -------
    parameter length = 20;
    parameter STATE_START = 2'b00;
    parameter STATE_PLAY  = 2'b01;
    parameter STATE_OVER  = 2'b10;

    integer i;

    always @ (posedge clk) begin
        clk_div <= clk_div + 1;
        slow_clk <= clk_div[23];
    end

    always @ (posedge clk or negedge reset) begin
        if (!reset) begin
            prev_slow_clk <= 1'b0;
            game_tick <= 1'b0;
        end else begin
            prev_slow_clk <= slow_clk;
            // Only tick if in play state
            if (game_state == STATE_PLAY) begin
                game_tick <= slow_clk && !prev_slow_clk;
            end else begin
                game_tick <= 1'b0;
            end
        end
    end

    always @ (posedge slow_clk or negedge reset) begin
         if (!reset) begin
             direction <= 3'd3; // Default right
         end
         // Reset direction on start screen
         else if (game_state == STATE_START) begin
            direction <= 3'd3;
         end
         // Only allow direction changes during PLAY
         else if (game_state == STATE_PLAY) begin
             case (key_out)
                 3'd1: if (direction != 3'd1) direction <= 3'd0; // UP
                 3'd2: if (direction != 3'd0) direction <= 3'd1; // DOWN
                 3'd3: if (direction != 3'd3) direction <= 3'd2; // LEFT
                 3'd4: if (direction != 3'd2) direction <= 3'd3; // RIGHT
             endcase
         end
    end

    reg [9:0] next_x_head;
    reg [9:0] next_y_head;

    always @(*) begin
        next_x_head = x_head;
        next_y_head = y_head;
        case (direction)
            3'd0: next_y_head = y_head - length; // Up
            3'd1: next_y_head = y_head + length; // Down
            3'd2: next_x_head = x_head - length; // Left
            3'd3: next_x_head = x_head + length; // Right
        endcase
    end

    always @(*) begin
        wall_collision = 0;
        self_collision = 0;

        if (next_x_head >= 320 || next_x_head > x_head + length || 
            next_y_head >= 240 || next_y_head > y_head + length)
            wall_collision = 1;

        for (i = 1; i < 10; i = i + 1) begin
            if (i < segments && next_x_head == x_body[i*10 +: 10] && next_y_head == y_body[i*10 +: 10])
                self_collision = 1;
        end
    end

    assign snake_dead = (wall_collision || self_collision) && (game_state == STATE_PLAY);

    always @ (posedge slow_clk or negedge reset) begin
        if (!reset) begin
            // Reset all game parameters
            x_head <= 10'd100;
            y_head <= 10'd100;
            x_body <= 0;
            y_body <= 0;
            x_tail <= 10'd100;
            y_tail <= 10'd100;
            score <= 0;
            segments <= 4'd1;
            ate <= 0;
            // Set initial body position
            x_body[9:0] <= 10'd100;
            y_body[9:0] <= 10'd100;
        end
        else begin
            case (game_state)
            
                STATE_START: begin
                    // Reset all game parameters for a new game
                    x_head <= 10'd100;
                    y_head <= 10'd100;
                    x_body <= 0;
                    y_body <= 0;
                    x_tail <= 10'd100;
                    y_tail <= 10'd100;
                    score <= 0;
                    segments <= 4'd1;
                    ate <= 0;
                    // Set initial body position
                    x_body[9:0] <= 10'd100;
                    y_body[9:0] <= 10'd100;
                end

                STATE_PLAY: begin
                    // Only move if no collision is detected
                    if (!wall_collision && !self_collision) begin
                        // Move Body
                        x_tail <= x_body[(segments - 1) * 10 +: 10];
                        y_tail <= y_body[(segments - 1) * 10 +: 10];
                       
                        for (i = 9; i > 0; i = i - 1) begin
                            x_body[i * 10 +: 10] <= x_body[(i - 1) * 10 +: 10];
                            y_body[i * 10 +: 10] <= y_body[(i - 1) * 10 +: 10];
                        end
                       
                        x_body[9:0] <= next_x_head;
                        y_body[9:0] <= next_y_head;
                        x_head <= next_x_head;
                        y_head <= next_y_head;

                        // Apple Eating Logic
                        if (next_x_head == x_apple && next_y_head == y_apple) begin
                            ate <= 1;
                            score <= score + 1;
                            if (segments < 10) segments <= segments + 1;
                        end else begin
                            ate <= 0;
                        end
                    end
                end
              
                STATE_OVER: begin
                    ate <= 0;
                end
                
            endcase
        end
    end
    
    // Pass the FAST clock (clk) to apple
    apple apple_stuff(
        .clk(clk),
        .reset(reset),
        .x_apple(x_apple),
        .y_apple(y_apple),
        .apple_eaten_signal(ate),
        .game_state(game_state) 
    );
    
endmodule

*/



module game(
    input wire clk, // This is CLOCK_50
    input wire reset,
    input wire [2:0] key_out,
    input wire [1:0] game_state,
    input wire btn_fast_n,   // from KEY[2] (active-low)
    input wire btn_slow_n,   // from KEY[3] (active-low)
    output wire snake_dead,
    
    // ------ SNAKE VARIABLES -------
    output reg [99:0] x_body,
    output reg [99:0] y_body,
    output reg [9:0] x_head,
    output reg [9:0] y_head,
    output reg [2:0] direction,
    output reg [3:0] segments,
    output reg [9:0] x_tail,
    output reg [9:0] y_tail,
    
    // ------ APPLE VARIABLES -------
    output wire [9:0] x_apple,
    output wire [9:0] y_apple,
    
    // ------ DISPLAY VARIABLES -------
    output reg [3:0] score,
    
    // ------ CLOCK/TIMER VARIABLES -------
    output reg game_tick
);

    // ------ INTERNAL SIGNALS -------
    reg ate;
    reg wall_collision;
    reg self_collision;

    // ------ GAME STATE PARAMETERS -------
    parameter length = 20;
    parameter STATE_START = 2'b00;
    parameter STATE_PLAY  = 2'b01;
    parameter STATE_OVER  = 2'b10;

    integer i;

    // ===============================================================
    //  SPEED CONTROL LOGIC (FIXED)
    // ===============================================================
    
    wire btn_fast_clean, btn_slow_clean;
    wire faster_sync, slower_sync;

    // 1. Debounce the buttons to prevent glitching
    debounce D_fast (
        .clk(clk),
        .reset_n(reset),
        .button_in(~btn_fast_n), // Invert active-low key
        .button_out(btn_fast_clean)
    );

    debounce D_slow (
        .clk(clk),
        .reset_n(reset),
        .button_in(~btn_slow_n), // Invert active-low key
        .button_out(btn_slow_clean)
    );

    // 2. Edge Detection for speed change pulses
    reg prev_fast, prev_slow;
    always @(posedge clk) begin
        prev_fast <= btn_fast_clean;
        prev_slow <= btn_slow_clean;
    end
    
    assign faster_sync = btn_fast_clean && !prev_fast;
    assign slower_sync = btn_slow_clean && !prev_slow;

    // 3. Speed Counter and Mask
    localparam KK = 24;
    localparam MM = 8;

    reg  [KK-1:0] slow_counter;
    wire [KK-1:0] slow;
    reg  [MM-1:0] mask;
    
    assign slow = slow_counter;

    // Free-running counter
    always @(posedge clk or negedge reset) begin
        if (!reset) slow_counter <= 0;
        else slow_counter <= slow_counter + 1;
    end

    // Mask Update Logic (With Limits)
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            // INITIAL SPEED: Moderate (approx 12-15 updates/sec)
            mask <= 8'b1100_0000; 
        end else begin
            // FASTER: Shift right (add 1s from top)
            // Guard: !mask[0] ensures we don't shift if already max speed
            if (faster_sync && !mask[0]) begin
                mask[MM-2:0] <= mask[MM-1:1];
                mask[MM-1]   <= 1'b1; 
            end 
            // SLOWER: Shift left (add 0s from bottom)
            // Guard: mask[MM-1] ensures we don't shift if already min speed
            else if (slower_sync && mask[MM-1]) begin
                mask[MM-1:1] <= mask[MM-2:0];
                mask[0]      <= 1'b0; 
            end
        end
    end

    // 4. Generate Game Tick
    wire raw_speed_tick;
    // When the masked counter rolls over, trigger a tick
    assign raw_speed_tick = ((slow | (mask << (KK-MM))) == {KK{1'b1}});

    // Final game_tick output
    always @(posedge clk or negedge reset) begin
        if (!reset)
            game_tick <= 1'b0;
        else if (game_state == STATE_PLAY)
            game_tick <= raw_speed_tick;
        else
            game_tick <= 1'b0;
    end

    // ===============================================================
    //  DIRECTION CONTROL
    // ===============================================================

    always @ (posedge clk or negedge reset) begin
         if (!reset) begin
             direction <= 3'd3; // Default right
         end
         else if (game_state == STATE_START) begin
            direction <= 3'd3;
         end
         // Only update direction on a movement tick while playing
         // This prevents the snake from turning into itself between ticks
         else if (game_state == STATE_PLAY && game_tick) begin
             case (key_out)
                 3'd1: if (direction != 3'd1) direction <= 3'd0; // UP
                 3'd2: if (direction != 3'd0) direction <= 3'd1; // DOWN
                 3'd3: if (direction != 3'd3) direction <= 3'd2; // LEFT
                 3'd4: if (direction != 3'd2) direction <= 3'd3; // RIGHT
             endcase
         end
    end

    // ===============================================================
    //  COLLISION & NEXT POSITION LOGIC
    // ===============================================================

    reg [9:0] next_x_head;
    reg [9:0] next_y_head;

    always @(*) begin
        next_x_head = x_head;
        next_y_head = y_head;
        case (direction)
            3'd0: next_y_head = y_head - length; // Up
            3'd1: next_y_head = y_head + length; // Down
            3'd2: next_x_head = x_head - length; // Left
            3'd3: next_x_head = x_head + length; // Right
        endcase
    end

    always @(*) begin
        wall_collision = 0;
        self_collision = 0;

        // Check Wall Bounds
        if (next_x_head >= 320 || next_x_head > 1000 || // >1000 catches underflow wrap-around
            next_y_head >= 240 || next_y_head > 1000)
            wall_collision = 1;

        // Check Body Collision
        for (i = 1; i < 10; i = i + 1) begin
            if (i < segments && next_x_head == x_body[i*10 +: 10] && next_y_head == y_body[i*10 +: 10])
                self_collision = 1;
        end
    end

    assign snake_dead = (wall_collision || self_collision) && (game_state == STATE_PLAY);

    // ===============================================================
    //  SNAKE MOVEMENT & UPDATE FSM
    // ===============================================================

    always @ (posedge clk or negedge reset) begin
        if (!reset) begin
            // Reset all game parameters
            x_head <= 10'd100;
            y_head <= 10'd100;
            x_body <= 0;
            y_body <= 0;
            x_tail <= 10'd100;
            y_tail <= 10'd100;
            score <= 0;
            segments <= 4'd1;
            ate <= 0;
            x_body[9:0] <= 10'd100;
            y_body[9:0] <= 10'd100;
        end
        else begin
            case (game_state)
            
                STATE_START: begin
                    // Reset all game parameters for a new game
                    x_head <= 10'd100;
                    y_head <= 10'd100;
                    x_body <= 0;
                    y_body <= 0;
                    x_tail <= 10'd100;
                    y_tail <= 10'd100;
                    score <= 0;
                    segments <= 4'd1;
                    ate <= 0;
                    x_body[9:0] <= 10'd100;
                    y_body[9:0] <= 10'd100;
                end

                STATE_PLAY: begin
                    // Only step the snake on a game_tick
                    if (game_tick) begin
                        // Only move if no collision is detected
                        if (!wall_collision && !self_collision) begin
                            // Move Body: Save tail for erasing
                            x_tail <= x_body[(segments - 1) * 10 +: 10];
                            y_tail <= y_body[(segments - 1) * 10 +: 10];
                           
                            // Shift body segments
                            for (i = 9; i > 0; i = i - 1) begin
                                x_body[i * 10 +: 10] <= x_body[(i - 1) * 10 +: 10];
                                y_body[i * 10 +: 10] <= y_body[(i - 1) * 10 +: 10];
                            end
                           
                            // Update Head
                            x_body[9:0] <= next_x_head;
                            y_body[9:0] <= next_y_head;
                            x_head <= next_x_head;
                            y_head <= next_y_head;

                            // Apple Eating Logic
                            if (next_x_head == x_apple && next_y_head == y_apple) begin
                                ate <= 1;
                                score <= score + 1;
                                if (segments < 10) segments <= segments + 1;
                            end else begin
                                ate <= 0;
                            end
                        end
                    end
                end
              
                STATE_OVER: begin
                    // Freeze game
                    ate <= 0;
                end
                
            endcase
        end
    end

    // ===============================================================
    //  APPLE INSTANCE
    // ===============================================================
    
    apple apple_stuff(
        .clk(clk),
        .reset(reset),
        .x_apple(x_apple),
        .y_apple(y_apple),
        .apple_eaten_signal(ate),
        .game_state(game_state) 
    );
    
endmodule


// ===============================================================
//  DEBOUNCE MODULE (Helper)
// ===============================================================
module debounce (
    input wire clk,
    input wire reset_n,
    input wire button_in,
    output reg button_out
);
    reg [19:0] count;
    reg state;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= 0;
            state <= 0;
            button_out <= 0;
        end else begin
            if (button_in !== state) begin
                count <= 0;
                state <= button_in;
            end else if (count < 20'd999_999) begin // ~20ms delay
                count <= count + 1;
            end else begin
                button_out <= state;
            end
        end
    end
endmodule
