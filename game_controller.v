module game_controller(
    input wire clk,
    input wire reset,
    input wire key_start,
    input wire snake_dead,
    input wire player_won,
    output reg [1:0] game_state
);

    localparam S_START = 2'b00;
    localparam S_PLAY  = 2'b01;
    localparam S_OVER  = 2'b10;
    localparam S_WIN   = 2'b11;

    reg [1:0] next_state;

    always @(posedge clk or negedge reset) begin
        if(!reset) game_state <= S_START;
        else game_state <= next_state;
    end

    always @(*) begin
        next_state = game_state;
        case(game_state)
            S_START: begin
                if(key_start) next_state = S_PLAY;
            end
            
            S_PLAY: begin
                if (player_won) 
                    next_state = S_WIN;
                else if (snake_dead) 
                    next_state = S_OVER;
            end
            
            S_OVER: begin
                // Wait for key press to restart
                if(key_start) next_state = S_START;
            end
            
            S_WIN: begin
                // Wait for key press to restart
                if(key_start) next_state = S_START;
            end
        endcase
    end
endmodule
