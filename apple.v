module apple(clk, reset, x_apple, y_apple, apple_eaten_signal, game_state);
    input wire clk; // 50MHz clock
    input wire reset;
    input wire apple_eaten_signal;
    input wire [1:0] game_state;
   
    output reg [9:0] x_apple;
    output reg [9:0] y_apple;
   
    parameter length = 20;

    // Linear Feedback Shift Register
    reg [15:0] lfsr;
    wire feedback_bit;

    assign feedback_bit = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
   
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
           // Hexadecimal number
           lfsr <= 16'hACE1;
        end else begin
            lfsr[15:1] <= lfsr[14:0];
            lfsr[0] <= feedback_bit;
        end
    end
   
    wire [3:0] rand_x;
    wire [3:0] rand_y_raw;
   
    assign rand_x = lfsr[3:0];
    assign rand_y_raw = lfsr[7:4];

    reg [3:0] rand_y;
   
    always @(*) begin
        if (rand_y_raw > 11)
            rand_y = rand_y_raw - 12;
        else
            rand_y = rand_y_raw;
    end

    // Detect rising edge of eat signal
    reg prev_ate;
    always @ (posedge clk or negedge reset) begin
        if (!reset) prev_ate <= 0;
        else prev_ate <= apple_eaten_signal;
    end
    wire ate_trigger = apple_eaten_signal && !prev_ate;

    reg [9:0] extended_rand_x;
    reg [9:0] extended_rand_y;
    reg [9:0] candidate_x;
    reg [9:0] candidate_y;


    always @(*) begin
        extended_rand_x = rand_x;
        extended_rand_y = rand_y;

        candidate_x = extended_rand_x * length;
        candidate_y = extended_rand_y * length;
    end


    always @ (posedge clk or negedge reset) begin
        if (!reset) begin
            x_apple <= 10'd200;  
            y_apple <= 10'd120;  
        end
        else if (ate_trigger) begin
            // Check if the new random spot is the same as the old spot
            if (candidate_x == x_apple && candidate_y == y_apple) begin
                // If it landed on itself, force a move
                if (x_apple < (300)) // If not at right edge
                    x_apple <= x_apple + length;
                else
                    x_apple <= 10'd0; // Wrap to left
            end
            else begin
                // Normal random update
                x_apple <= candidate_x;
                y_apple <= candidate_y;
            end
        end
    end


endmodule