const std = @import("std");
const rl = @import("raylib");
const gui = @cImport({
    @cInclude("raygui.h");
});

const mg = @import("maze_gen.zig");
const lg = @import("logic.zig");
// const draw = @import("draw.zig");

const size: comptime_int = 25;
const start = mg.Coordinates{ .x = 0, .y = 1 };
const end = mg.Coordinates{ .x = size - 1, .y = size - 2 };

var gameState = lg.GameState.Menu;
var solved = false;

const screenWidth = 1400;
const screenHeight = 900;

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
    var maze = try mg.initMaze(allocator, size, start, end);
    defer allocator.free(maze.cells);

    var currentCoord: mg.Coordinates = start;

    const genRect = gui.Rectangle{ .x = screenWidth - guiOffset - buttonWidth, .y = (screenHeight - 3 * buttonHeight) / 2 - guiOffset, .width = buttonWidth, .height = buttonHeight };
    const solvRect = gui.Rectangle{ .x = screenWidth - guiOffset - buttonWidth, .y = (screenHeight - buttonHeight) / 2, .width = buttonWidth, .height = buttonHeight };
    const exitRect = gui.Rectangle{ .x = screenWidth - guiOffset - buttonWidth, .y = (screenHeight + buttonHeight) / 2 + guiOffset, .width = buttonWidth, .height = buttonHeight };

    rl.initWindow(screenWidth, screenHeight, "Maze Generator");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(240); // Set our game to run at 60 frames-per-second

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------

        switch (gameState) {
            .Menu => {},
            .Generating => {
                const next = gotoNext(&maze, &currentCoord);
                if (next == error.GenerationDone) {
                    // Reset visited flag for each cell in maze
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
            .Done => {
                std.debug.print("Done!\n", .{});
                std.time.sleep(1000000000);
                break;
            },
        }

        if (gameState == lg.GameState.Solving) {}

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        switch (gameState) {
            .Menu => {
                if (gui.GuiButton(genRect, "Generate") > 0) {
                    // If the maze is already generated, reset the maze and generate a new one
                    if (maze.cells[0][0].path_count != 0) {
                        maze = try mg.initMaze(allocator, size, start, end);
                        solved = false;
                        currentCoord = start;
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

                _ = gui.GuiButton(genRect, "Generate");
                _ = gui.GuiButton(solvRect, "Solve");
                if (gui.GuiButton(exitRect, "Exit") > 0) {
                    break;
                }
            },
            .Solving => {
                drawMaze(maze, rl.Color.black);
                drawPath(maze, rl.Color.red);
                _ = gui.GuiButton(genRect, "Generate");
                _ = gui.GuiButton(solvRect, "Solve");
                if (gui.GuiButton(exitRect, "Exit") > 0) {
                    break;
                }
            },
            .Done => {},
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

                if (std.meta.eql(cell.coords, maze.start)) {
                    rl.drawLine(middle_x, middle_y, middle_x - sectorSize / 2, middle_y, color);
                } else {
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

    if (next_dir == null or std.meta.eql(currentCoord.*, end)) {
        if (std.meta.eql(currentCoord.*, start)) return error.GenerationDone;

        const toPrev = current_cell.paths[0];
        switch (toPrev) {
            .Up => currentCoord.* = .{ .y = currentCoord.y - 1, .x = currentCoord.x },
            .Down => currentCoord.* = .{ .y = currentCoord.y + 1, .x = currentCoord.x },
            .Left => currentCoord.* = .{ .y = currentCoord.y, .x = currentCoord.x - 1 },
            .Right => currentCoord.* = .{ .y = currentCoord.y, .x = currentCoord.x + 1 },
        }
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

///Debugging function to print the maze to the console using ascii characters.
///It was a pain in the ass to write.
fn printMaze(maze: *mg.Maze) void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("#", .{});
    for (0..maze.cells[0].len * 2) |i| {
        const coord = mg.Coordinates{ .y = 0, .x = i + 1 };
        const is_end = std.meta.eql(coord, maze.end);

        if (is_end) {
            try stdout.print("  ", .{});
            continue;
        }

        try stdout.print(" #", .{});
    }

    try stdout.print("\n", .{});

    var coord: mg.Coordinates = undefined;
    var cell: mg.Cell = undefined;

    // Every row
    for (0..maze.cells.len) |i| {
        // First wall in row
        coord = mg.Coordinates{ .y = i, .x = 0 };
        cell = coord.cell(maze).*;

        const is_start_or_end = std.meta.eql(coord, maze.start) or std.meta.eql(coord, maze.end);
        if (is_start_or_end) {
            try stdout.print(" ", .{});
        } else {
            try stdout.print("#", .{});
        }

        // Every cell and wall in row
        for (0..maze.cells[0].len, 0..) |j, count| {
            _ = j;
            coord = mg.Coordinates{ .y = i, .x = count };

            cell = coord.cell(maze).*;
            if ((cell.previous != null or std.meta.eql(coord, maze.start)) and gameState != lg.GameState.Generating) {
                try stdout.print(" o", .{});
            } else {
                try stdout.print("  ", .{});
            }

            if (cell.hasWall(mg.Direction.Right)) {
                try stdout.print(" #", .{});
            } else if (cell.previous != null and coord.toDir(mg.Direction.Right).cell(maze).previous != null) {
                try stdout.print(" o", .{});
            } else {
                try stdout.print("  ", .{});
            }
        }

        // New row
        try stdout.print("\n", .{});

        // Row with no cells
        try stdout.print("#", .{});
        for (0..maze.cells[0].len) |j| {
            coord = mg.Coordinates{ .y = i, .x = j };
            cell = coord.cell(maze).*;

            if (i != maze.cells.len - 1) {
                const cellUnder = coord.toDir(mg.Direction.Down).cell(maze).*;

                if (cell.previous != null and cellUnder.previous != null and !cell.hasWall(mg.Direction.Down)) {
                    try stdout.print(" o", .{});
                    try stdout.print(" #", .{});
                    continue;
                }
            }

            if (cell.hasWall(mg.Direction.Down)) {
                try stdout.print(" #", .{});
            } else {
                try stdout.print("  ", .{});
            }
            try stdout.print(" #", .{});
        }

        try stdout.print("\n", .{});
    }

    try stdout.print("\n", .{});
    for (0..maze.cells.len * 4 + 1) |i| {
        _ = i;
        try stdout.print("-", .{});
    }
    try stdout.print("\n\n", .{});
}
