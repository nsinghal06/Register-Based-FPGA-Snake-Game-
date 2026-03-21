# Snake Game — DE1-SoC FPGA (Verilog)

A fully playable Snake game implemented in Verilog and deployed on the 
DE1-SoC FPGA, featuring a custom VGA display controller, PS/2 keyboard 
input, and hardware-accelerated game logic.

## Features
- 4-state FSM game controller (Start → Play → Win / Game Over)
- 320×240 VGA display with 20×20px tile-based grid rendering
- PS/2 keyboard input with WASD scan code decoding
- Adjustable game speed via hardware buttons (KEY[2] / KEY[3]) with debounce logic
- Win condition triggers at 10 snake segments; collision detection for walls and self
- Score tracking displayed on 7-segment HEX displays

## Architecture
| Module | Description |
|---|---|
| `vga_demo.v` | Top-level module; integrates all submodules and PS/2 decoder |
| `game_controller.v` | 4-state FSM managing game flow |
| `game.v` | Snake movement, collision detection, scoring, speed control |
| `apple.v` | Apple spawning logic |

## Hardware
- **Board:** Altera DE1-SoC  
- **Clock:** 100MHz (CLOCK_50 × PLL)  
- **Input:** PS/2 keyboard (WASD) + onboard KEYs  
- **Output:** VGA display + HEX 7-segment score display  

## Controls
| Key | Action |
|---|---|
| `W / A / S / D` | Move Up / Left / Down / Right |
| `Any key` | Start / Restart game |
| `KEY[2]` | Increase speed |
| `KEY[3]` | Decrease speed |
| `KEY[0]` | Reset |

## Simulation
Control logic verified using ModelSim testbenches targeting the DE1-SoC architecture.
