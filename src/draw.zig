const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const Maze = @import("maze.zig").Maze; // Import the maze generation code

pub fn main() void {
    // Initialization
    const screenWidth = 800;
    const screenHeight = 450;
    const cellSize = 20;

    c.InitWindow(screenWidth, screenHeight, "Maze in Zig + raylib");

    const mazeWidth = @intCast(usize, screenWidth / cellSize);
    const mazeHeight = @intCast(usize, screenHeight / cellSize);

    var maze: Maze = undefined;
    maze.init(mazeWidth, mazeHeight);
    maze.generateMaze(0, 0);

    // Main game loop
    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        for (maze.cells) |cell, idx| {
            const x = @intCast(i32, (idx % maze.width) * cellSize);
            const y = @intCast(i32, (idx / maze.width) * cellSize);

            if (cell.walls[Maze.Direction.Up]) {
                c.DrawLine(x, y, x + cellSize, y, c.BLACK);
            }
            if (cell.walls[Maze.Direction.Down]) {
                c.DrawLine(x, y + cellSize, x + cellSize, y + cellSize, c.BLACK);
            }
            if (cell.walls[Maze.Direction.Left]) {
                c.DrawLine(x, y, x, y + cellSize, c.BLACK);
            }
            if (cell.walls[Maze.Direction.Right]) {
                c.DrawLine(x + cellSize, y, x + cellSize, y + cellSize, c.BLACK);
            }
        }

        c.EndDrawing();
    }

    // De-Initialization
    c.CloseWindow();
}
