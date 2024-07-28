const std = @import("std");

const rl = @import("raylib");
const gui = @cImport({
    @cInclude("raygui.h");
});

const mg = @import("maze_gen.zig");
const lg = @import("logic.zig");

// Settings
const size: comptime_int = 50;
const screenWidth = 1400;
const screenHeight = 900;

var solved = false;

// Variables for button placement
const guiOffset = 50;
const buttonWidth = 200;
const buttonHeight = 100;

// Splits the window up into a responsive grid
const minSize: u16 = @truncate(@min(screenWidth - 3 * guiOffset - buttonWidth, screenHeight - 2 * guiOffset));
const sectorSize: u16 = minSize / size;

// Usefull pixels when drawing the maze
const midMaze = mg.Coordinates{ .x = (screenWidth - 300) / 2, .y = screenHeight / 2 };
const topLeftMaze = mg.Coordinates{ .x = midMaze.x - (sectorSize * size / 2), .y = midMaze.y - (sectorSize * size / 2) };

pub fn main() !void {

    // Initialization
    //--------------------------------------------------------------------------------------

    const allocator = std.heap.page_allocator;

    const start: *mg.Coordinates = try allocator.create(mg.Coordinates);
    const end: *mg.Coordinates = try allocator.create(mg.Coordinates);
    defer {
        allocator.destroy(start);
        allocator.destroy(end);
    }

    const rand = std.crypto.random;
    start.* = mg.Coordinates{ .x = 0, .y = rand.intRangeLessThan(u16, 1, size) };
    end.* = mg.Coordinates{ .x = size - 1, .y = rand.intRangeLessThan(u16, 1, size) };

    var maze = try mg.initMaze(allocator, size, start.*, end.*);
    defer {
        for (maze.cells) |row| {
            allocator.free(row);
        }
        allocator.free(maze.cells);
    }

    var currentCoord: mg.Coordinates = start.*;

    var gameState = lg.GameState.Menu;

    rl.initWindow(screenWidth, screenHeight, "Maze Generator");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(240); // Set our game to run at 60 frames-per-second

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update variables
        //----------------------------------------------------------------------------------

        switch (gameState) {
            .Menu => {},
            .Generating => {
                const next = gotoNext(&maze, &currentCoord);
                if (next == error.GenerationDone) {
                    // Reset visited flag for each cell in maze for solving purposes
                    for (0..maze.cells.len) |i| {
                        for (0..maze.cells.len) |j| {
                            maze.cells[i][j].is_visited = false;
                        }
                    }
                    gameState = lg.GameState.Menu;
                }
            },
            .Solving => {
                const potentialCoords = lg.solveStep(&maze, currentCoord);
                if (potentialCoords == error.Solved) {
                    gameState = lg.GameState.Menu;
                    solved = true;
                } else {
                    currentCoord = try potentialCoords;
                }
            },
        }

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        // Some simple math to place the buttons in the right place
        const genRect = gui.Rectangle{ .x = screenWidth - guiOffset - buttonWidth, .y = (screenHeight - 3 * buttonHeight) / 2 - guiOffset, .width = buttonWidth, .height = buttonHeight };
        const solvRect = gui.Rectangle{ .x = screenWidth - guiOffset - buttonWidth, .y = (screenHeight - buttonHeight) / 2, .width = buttonWidth, .height = buttonHeight };
        const exitRect = gui.Rectangle{ .x = screenWidth - guiOffset - buttonWidth, .y = (screenHeight + buttonHeight) / 2 + guiOffset, .width = buttonWidth, .height = buttonHeight };

        switch (gameState) {
            .Menu => {
                if (gui.GuiButton(genRect, "Generate") > 0) {

                    // If the maze is already generated, reset the maze and generate a new one
                    if (maze.cells[0][0].path_count != 0) {
                        const randStart = mg.Coordinates{ .x = 0, .y = rand.intRangeLessThan(u16, 1, size) };
                        const randEnd = mg.Coordinates{ .x = size - 1, .y = rand.intRangeLessThan(u16, 1, size) };

                        start.* = randStart;
                        end.* = randEnd;
                        maze = try mg.initMaze(allocator, size, start.*, end.*);
                        solved = false;
                        currentCoord = start.*;
                    }
                    gameState = lg.GameState.Generating;
                }
                if (gui.GuiButton(solvRect, "Solve") > 0) {
                    // If maze is not yet generated, print error message
                    if (maze.cells[0][0].path_count == 0) {
                        std.debug.print("Maze is not yet generated", .{});
                    } else if (!solved) {
                        gameState = lg.GameState.Solving;
                    }
                }
                if (gui.GuiButton(exitRect, "Exit") > 0) {
                    break;
                }

                drawMaze(maze, rl.Color.black);
                if (gameState == lg.GameState.Solving or solved) {
                    drawPath(maze, rl.Color.red);
                }
            },
            .Generating => {
                drawMaze(maze, rl.Color.black);

                // Draw the buttons, but they are disabled while generating
                _ = gui.GuiButton(genRect, "Generate");
                _ = gui.GuiButton(solvRect, "Solve");
                // Exit button is still enabled
                if (gui.GuiButton(exitRect, "Exit") > 0) {
                    break;
                }
            },
            .Solving => {
                drawMaze(maze, rl.Color.black);
                drawPath(maze, rl.Color.red);
                // Draw the buttons, but they are disabled while solving
                _ = gui.GuiButton(genRect, "Generate");
                _ = gui.GuiButton(solvRect, "Solve");
                // Exit button is still enabled
                if (gui.GuiButton(exitRect, "Exit") > 0) {
                    break;
                }
            },
        }
    }

    //----------------------------------------------------------------------------------
}

///Draws the full maze in a raylib window.
fn drawMaze(maze: mg.Maze, wallColor: rl.Color) void {
    rl.clearBackground(rl.Color.white);

    // Draw top wall
    for (maze.cells[0]) |cell| {
        if (cell.hasWall(mg.Direction.Up)) drawWall(cell.coords, mg.Direction.Up, wallColor);
    }

    for (maze.cells) |row| {
        // Draw left wall
        if (row[0].hasWall(mg.Direction.Left)) drawWall(row[0].coords, mg.Direction.Left, wallColor);

        // Loop through all cells and draw right- and down-facing walls
        for (row) |cell| {
            if (cell.hasWall(mg.Direction.Right)) drawWall(cell.coords, mg.Direction.Right, wallColor);
            if (cell.hasWall(mg.Direction.Down)) drawWall(cell.coords, mg.Direction.Down, wallColor);
        }
    }
}

///Draws the path from the start to the end cell in a raylib window.
fn drawPath(maze: mg.Maze, color: rl.Color) void {
    for (maze.cells) |row| {
        for (row) |cell| {
            if ((cell.previous != null or std.meta.eql(cell.coords, maze.start))) {
                const startpoint = coordToPixel(cell.coords);
                const middle_x: u16 = @truncate(startpoint.x + sectorSize / 2);
                const middle_y: u16 = @truncate(startpoint.y + sectorSize / 2);

                // Draw line from outside the maze to the start cell
                if (std.meta.eql(cell.coords, maze.start)) {
                    rl.drawLine(middle_x, middle_y, middle_x - sectorSize / 2, middle_y, color);
                } else { // Draw line from the current cell to the previous cell
                    const endpoint = coordToPixel(cell.previous.?);
                    const endpoint_x: u16 = @truncate(endpoint.x + sectorSize / 2);
                    const endpoint_y: u16 = @truncate(endpoint.y + sectorSize / 2);

                    rl.drawLine(middle_x, middle_y, endpoint_x, endpoint_y, color);
                }
            }
            // Draw line from end cell the the outside of the maze. The maze is now solved.
            if (solved) {
                const endpoint = coordToPixel(maze.end);
                const middle_x: u16 = @truncate(endpoint.x + sectorSize / 2);
                const middle_y: u16 = @truncate(endpoint.y + sectorSize / 2);

                rl.drawLine(middle_x, middle_y, middle_x + sectorSize / 2, middle_y, color);
            }
        }
    }
}

///Moves the current cell to the next cell in the maze.
///If the current cell is the end cell, the function will return an error.
fn gotoNext(maze: *mg.Maze, currentCoord: *mg.Coordinates) !void {
    const current_cell = maze.cells[currentCoord.y][currentCoord.x];
    const next_dir = try lg.nextCell(maze.*, currentCoord.*);

    if (next_dir == null or std.meta.eql(currentCoord.*, maze.end)) {
        // Base case for the recursive function
        // If the current cell is the start cell,
        // the generation has recurred back through the whole maze.
        if (std.meta.eql(currentCoord.*, maze.start)) return error.GenerationDone;

        const toPrev = current_cell.paths[0];
        switch (toPrev) {
            .Up => currentCoord.* = .{ .y = currentCoord.y - 1, .x = currentCoord.x },
            .Down => currentCoord.* = .{ .y = currentCoord.y + 1, .x = currentCoord.x },
            .Left => currentCoord.* = .{ .y = currentCoord.y, .x = currentCoord.x - 1 },
            .Right => currentCoord.* = .{ .y = currentCoord.y, .x = currentCoord.x + 1 },
        }
        // recursive call to go back to the previous cell
        return gotoNext(maze, currentCoord);
    }

    try mg.toggleWall(maze, currentCoord.*, next_dir.?);

    // Previous coordinates
    const x0 = currentCoord.x;
    const y0 = currentCoord.y;

    // New coordinates
    var x1: usize = undefined;
    var y1: usize = undefined;

    switch (next_dir.?) {
        .Up => {
            x1 = currentCoord.x;
            y1 = currentCoord.y - 1;
        },
        .Down => {
            x1 = currentCoord.x;
            y1 = currentCoord.y + 1;
        },
        .Left => {
            x1 = currentCoord.x - 1;
            y1 = currentCoord.y;
        },
        .Right => {
            x1 = currentCoord.x + 1;
            y1 = currentCoord.y;
        },
    }

    // Change cooedinates
    currentCoord.* = mg.Coordinates{ .x = x1, .y = y1 };

    // Save paths between the cells
    maze.cells[y0][x0].paths[maze.cells[y0][x0].path_count] = next_dir.?;
    maze.cells[y0][x0].path_count += 1;

    maze.cells[y1][x1].paths[maze.cells[y1][x1].path_count] = lg.reverseDir(next_dir.?);
    maze.cells[y1][x1].path_count += 1;

    // Set new cell to visited
    maze.cells[currentCoord.y][currentCoord.x].is_visited = true;
}

///Transforms maze coordinates to a pixel position in a raylib window.
fn coordToPixel(mazeCoord: mg.Coordinates) mg.Coordinates {
    const pixelCoord: mg.Coordinates = .{ .x = topLeftMaze.x + mazeCoord.x * sectorSize, .y = topLeftMaze.y + mazeCoord.y * sectorSize };

    return pixelCoord;
}

///Draws a wall at the given coordinates and direction in a raylib window.
fn drawWall(coord: mg.Coordinates, dir: mg.Direction, color: rl.Color) void {
    const startpoint = coordToPixel(coord);
    const startpoint_x: u16 = @truncate(startpoint.x);
    const startpoint_y: u16 = @truncate(startpoint.y);

    switch (dir) {
        .Up => rl.drawLine(startpoint_x, startpoint_y, startpoint_x + sectorSize, startpoint_y, color),
        .Down => rl.drawLine(startpoint_x, startpoint_y + sectorSize, startpoint_x + sectorSize, startpoint_y + sectorSize, color),
        .Left => rl.drawLine(startpoint_x, startpoint_y, startpoint_x, startpoint_y + sectorSize, color),
        .Right => rl.drawLine(startpoint_x + sectorSize, startpoint_y, startpoint_x + sectorSize, startpoint_y + sectorSize, color),
    }
}
