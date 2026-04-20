package game

import rl "vendor:raylib"

main :: proc() 
{
    rl.InitWindow(1280, 720, "My Odin + Raylib game")

    for !rl.WindowShouldClose()
    {
        rl.BeginDrawing()
        rl.ClearBackground({160, 200, 255, 255})
        rl.EndDrawing()
    }

    rl.CloseWindow()
}