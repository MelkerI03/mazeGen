// raylib-zig (c) Nikolas Wipper 2023

const std = @import("std");
const mg = @import("maze_gen.zig");
const rl = @import("raylib");
const lg = @import("logic.zig");
const draw = @import("draw.zig");

const allocator = std.heap.page_allocator;
const size: comptime_int = 25;
const start = mg.Coordinates{ .x = 0, .y = 1 };
const end = mg.Coordinates{ .x = size - 1, .y = size - 2 };
var maze_done = false;
var current_coords: mg.Coordinates = start;

const screenWidth = 1920;
const screenHeight = 1080;

const sectors = size + 2;
const minSize: u16 = @min(screenWidth, screenHeight);
const sectorSize: u16 = minSize / sectors;

const middle = mg.Coordinates{ .x = screenWidth / 2, .y = screenHeight / 2 };
const zeroPosition = mg.Coordinates{ .x = middle.x - (sectorSize * size / 2), .y = middle.y - (sectorSize * size / 2) };
pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------

    var maze = try mg.initMaze(allocator, size, start, end);
    defer allocator.free(maze.cells);

    rl.initWindow(screenWidth, screenHeight, "Maze Generator");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        if (!maze_done) {
            const next = gotoNext(&maze);
            if (next == error.@"Done!") {
                std.debug.print("Done!\n", .{});

                // Reset visited flag for each cell in maze
                for (0..maze.cells.len) |i| {
                    for (0..maze.cells.len) |j| {
                        maze.cells[i][j].is_visited = false;
                    }
                }
                maze_done = true;
            }
        }

        if (maze_done) {
            const potential_coords = lg.solveStep(&maze, current_coords);
            if (potential_coords == error.@"Were Done") {
                std.debug.print("ITS OVER\n\n", .{});
                break;
            } else {
                current_coords = try potential_coords;
            }
        }

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        // Should not be needed in the end
        // const stdout = std.io.getStdOut().writer();

        // Print top wall
        for (maze.cells[0]) |cell| {
            if (cell.hasWall(mg.Direction.Up)) drawWall(cell.coords, mg.Direction.Up);
        }

        for (maze.cells) |row| {
            // Draw left wall
            if (row[0].hasWall(mg.Direction.Left)) drawWall(row[0].coords, mg.Direction.Left);

            // Loop through all cells and draw right- and down-facing walls
            for (row) |cell| {
                // Draw walls
                if (cell.hasWall(mg.Direction.Right)) drawWall(cell.coords, mg.Direction.Right);
                if (cell.hasWall(mg.Direction.Down)) drawWall(cell.coords, mg.Direction.Down);

                // Draw path
                if ((cell.previous != null or std.meta.eql(cell.coords, maze.start)) and maze_done) {
                    const startpoint = coordToPixel(cell.coords);
                    const middle_x: u16 = @truncate(startpoint.x + sectorSize / 2);
                    const middle_y: u16 = @truncate(startpoint.y + sectorSize / 2);

                    // TODO: Draw path
                    if (std.meta.eql(cell.coords, maze.start)) {
                        rl.drawLine(middle_x, middle_y, middle_x - sectorSize / 2, middle_y, rl.Color.red);
                    } else {
                        const endpoint = coordToPixel(cell.previous.?);
                        const endpoint_x: u16 = @truncate(endpoint.x + sectorSize / 2);
                        const endpoint_y: u16 = @truncate(endpoint.y + sectorSize / 2);

                        rl.drawLine(middle_x, middle_y, endpoint_x, endpoint_y, rl.Color.red);
                    }
                }
            }
        }

        //
        // Console Maze Printing starts here!
        //

        //         try stdout.print("#", .{});
        //         for (0..maze.cells[0].len * 2) |i| {
        //             const coord = mg.Coordinates{ .y = 0, .x = i + 1 };
        //             const is_end = std.meta.eql(coord, maze.end);
        //
        //             if (is_end) {
        //                 try stdout.print("  ", .{});
        //                 continue;
        //             }
        //
        //             try stdout.print(" #", .{});
        //         }
        //
        //         try stdout.print("\n", .{});
        //
        //         var coord: mg.Coordinates = undefined;
        //         var cell: mg.Cell = undefined;
        //
        //         // Every row
        //         for (0..maze.cells.len) |i| {
        //             // First wall in row
        //             coord = mg.Coordinates{ .y = i, .x = 0 };
        //             cell = coord.cell(maze).*;
        //
        //             const is_start_or_end = std.meta.eql(coord, maze.start) or std.meta.eql(coord, maze.end);
        //             if (is_start_or_end) {
        //                 try stdout.print(" ", .{});
        //             } else {
        //                 try stdout.print("#", .{});
        //             }
        //
        //             // Every cell and wall in row
        //             for (0..maze.cells[0].len, 0..) |j, count| {
        //                 _ = j;
        //                 coord = mg.Coordinates{ .y = i, .x = count };
        //
        //                 cell = coord.cell(maze).*;
        //                 if ((cell.previous != null or std.meta.eql(coord, maze.start)) and maze_done) {
        //                     try stdout.print(" o", .{});
        //                 } else {
        //                     try stdout.print("  ", .{});
        //                 }
        //
        //                 if (cell.hasWall(mg.Direction.Right)) {
        //                     try stdout.print(" #", .{});
        //                 } else if (cell.previous != null and coord.toDir(mg.Direction.Right).cell(maze).previous != null) {
        //                     try stdout.print(" o", .{});
        //                 } else {
        //                     try stdout.print("  ", .{});
        //                 }
        //             }
        //
        //             // New row
        //             try stdout.print("\n", .{});
        //
        //             // Row with no cells
        //             try stdout.print("#", .{});
        //             for (0..maze.cells[0].len) |j| {
        //                 coord = mg.Coordinates{ .y = i, .x = j };
        //                 cell = coord.cell(maze).*;
        //
        //                 if (i != maze.cells.len - 1) {
        //                     const cellUnder = coord.toDir(mg.Direction.Down).cell(maze).*;
        //
        //                     if (cell.previous != null and cellUnder.previous != null and !cell.hasWall(mg.Direction.Down)) {
        //                         try stdout.print(" o", .{});
        //                         try stdout.print(" #", .{});
        //                         continue;
        //                     }
        //                 }
        //
        //                 if (cell.hasWall(mg.Direction.Down)) {
        //                     try stdout.print(" #", .{});
        //                 } else {
        //                     try stdout.print("  ", .{});
        //                 }
        //                 try stdout.print(" #", .{});
        //             }
        //
        //             try stdout.print("\n", .{});
        //         }
        //
        //         try stdout.print("\n", .{});
        //         for (0..maze.cells.len * 4 + 1) |i| {
        //             _ = i;
        //             try stdout.print("-", .{});
        //         }
        //         try stdout.print("\n\n", .{});
        //
        //         // End of console maze printing
    }

    //----------------------------------------------------------------------------------
}

fn gotoNext(maze: *mg.Maze) !void {
    const current_cell = maze.cells[current_coords.y][current_coords.x];
    const next_dir = try lg.nextCell(maze.*, current_coords);
    // std.debug.print("current_cell = {?}\ndirection = {?}\n", .{ current_coords, next_dir });

    if (next_dir == null or std.meta.eql(current_coords, end)) {
        if (std.meta.eql(current_coords, start)) return error.@"Done!";
        const dir = current_cell.paths[0];
        switch (dir) {
            .Up => current_coords = .{ .y = current_coords.y - 1, .x = current_coords.x },
            .Down => current_coords = .{ .y = current_coords.y + 1, .x = current_coords.x },
            .Left => current_coords = .{ .y = current_coords.y, .x = current_coords.x - 1 },
            .Right => current_coords = .{ .y = current_coords.y, .x = current_coords.x + 1 },
        }
        return gotoNext(maze);
    }

    try mg.toggleWall(maze, current_coords, next_dir.?);

    // Previous coordinates
    const x0 = current_coords.x;
    const y0 = current_coords.y;

    // New coordinates
    var x1: usize = undefined;
    var y1: usize = undefined;

    switch (next_dir.?) {
        .Up => {
            x1 = current_coords.x;
            y1 = current_coords.y - 1;
        },
        .Down => {
            x1 = current_coords.x;
            y1 = current_coords.y + 1;
        },
        .Left => {
            x1 = current_coords.x - 1;
            y1 = current_coords.y;
        },
        .Right => {
            x1 = current_coords.x + 1;
            y1 = current_coords.y;
        },
    }

    // Change cooedinates
    current_coords = mg.Coordinates{ .x = x1, .y = y1 };

    // Save paths between the cells
    maze.cells[y0][x0].paths[maze.cells[y0][x0].path_count] = next_dir.?;
    maze.cells[y0][x0].path_count += 1;

    maze.cells[y1][x1].paths[maze.cells[y1][x1].path_count] = lg.reverseDir(next_dir.?);
    maze.cells[y1][x1].path_count += 1;

    // Set new cell to visited
    maze.cells[current_coords.y][current_coords.x].is_visited = true;
}

fn coordToPixel(mazeCoord: mg.Coordinates) mg.Coordinates {
    const pixelCoord: mg.Coordinates = .{ .x = zeroPosition.x + mazeCoord.x * sectorSize, .y = zeroPosition.y + mazeCoord.y * sectorSize };

    return pixelCoord;
}

fn drawWall(coord: mg.Coordinates, dir: mg.Direction) void {
    const startpoint = coordToPixel(coord);
    const startpoint_x: u16 = @truncate(startpoint.x);
    const startpoint_y: u16 = @truncate(startpoint.y);

    const line_color = rl.Color.black;

    switch (dir) {
        .Up => rl.drawLine(startpoint_x, startpoint_y, startpoint_x + sectorSize, startpoint_y, line_color),
        .Down => rl.drawLine(startpoint_x, startpoint_y + sectorSize, startpoint_x + sectorSize, startpoint_y + sectorSize, line_color),
        .Left => rl.drawLine(startpoint_x, startpoint_y, startpoint_x, startpoint_y + sectorSize, line_color),
        .Right => rl.drawLine(startpoint_x + sectorSize, startpoint_y, startpoint_x + sectorSize, startpoint_y + sectorSize, line_color),
    }
}
