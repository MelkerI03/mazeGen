const std = @import("std");
const mg = @import("maze_gen.zig");

pub fn nextCell(maze: mg.Maze, cell: mg.Coordinates) !?mg.Direction {
    const rand = std.crypto.random;

    // Allocate memory for neighbors
    var neighbors = try std.mem.Allocator.alloc(std.heap.page_allocator, struct { coords: mg.Coordinates, dir: mg.Direction }, 3);

    getNeighbors(maze, cell, &neighbors);

    var neighbor_count: u3 = 0;

    for (neighbors) |neighbor| {
        if (isValidCoordinate(maze, neighbor.coords)) neighbor_count += 1;
    }

    const realNeighbors = neighbors[0..neighbor_count];

    if (realNeighbors.len == 0) return null;

    const randint = rand.uintLessThan(usize, realNeighbors.len);

    std.debug.print("randint: {}\n", .{randint});
    std.debug.print("next coords: {}\n", .{realNeighbors[randint].coords});

    return realNeighbors[randint].dir;
}

fn getNeighbors(maze: mg.Maze, cell: mg.Coordinates, neighbors: anytype) void {
    var count: u2 = 0;

    // if (cell.x < 0 or cell.x >= maze.cells.len or cell.y < 0 or cell.y >= maze.cells.len) {
    std.debug.print("Current Cell: ({}, {})\n", .{ cell.x, cell.y });
    // return error.@"Cell out of bounds.";
    // }

    if (cell.x > 0) {
        const left = maze.cells[cell.y][cell.x - 1];
        if (left.is_visited == false) {
            const dir = mg.Direction.Left;
            neighbors.*[count] = .{ .coords = cell.toDir(dir), .dir = dir };
            count += 1;
            std.debug.print("left with coordinates: {}\n", .{cell.toDir(dir)});
        }
    }

    if (cell.x < maze.cells.len - 1) {
        const right = maze.cells[cell.y][cell.x + 1];
        if (right.is_visited == false) {
            const dir = mg.Direction.Right;
            neighbors.*[count] = .{ .coords = cell.toDir(dir), .dir = dir };
            count += 1;
            std.debug.print("right with coordinates: {}\n", .{cell.toDir(dir)});
        }
    }

    if (cell.y < maze.cells[0].len - 1) {
        const down = maze.cells[cell.y + 1][cell.x];
        if (down.is_visited == false) {
            const dir = mg.Direction.Down;
            neighbors.*[count] = .{ .coords = cell.toDir(dir), .dir = dir };
            count += 1;
            std.debug.print("down with coordinates: {}\n", .{cell.toDir(dir)});
        }
    }

    if (cell.y > 0) {
        const up = maze.cells[cell.y - 1][cell.x];
        if (up.is_visited == false) {
            const dir = mg.Direction.Up;
            neighbors.*[count] = .{ .coords = cell.toDir(dir), .dir = dir };
            count += 1;
            std.debug.print("up with coordinates: {}\n", .{cell.toDir(dir)});
        }
    }
}

pub fn solveStep(maze: *mg.Maze, current: mg.Coordinates) !mg.Coordinates {
    const cell = current.cell(maze.*);
    const start = maze.start;
    const end = maze.end;
    std.debug.print("paths: {any}\n", .{cell.paths[0..cell.path_count]});
    for (0.., cell.paths[0..cell.path_count]) |i, path| {
        // Discard first path since it is to the previous cell.
        if (i == 0 and !std.meta.eql(current, start)) continue;

        const cellOnPath = cell.coords.toDir(path).cell(maze.*);

        if (cellOnPath.is_visited) continue;
        cellOnPath.is_visited = true;
        if (std.meta.eql(cellOnPath.coords, end)) return error.@"Were Done";
        cellOnPath.previous = current;
        return cellOnPath.coords;
    }
    defer cell.previous = null;
    return solveStep(maze, current.cell(maze.*).previous.?);
}

fn isValidCoordinate(maze: mg.Maze, coords: mg.Coordinates) bool {
    return coords.x >= 0 and coords.x < maze.cells.len and coords.y >= 0 and coords.y < maze.cells.len;
}

pub fn reverseDir(dir: mg.Direction) mg.Direction {
    return switch (dir) {
        .Up => .Down,
        .Down => .Up,
        .Left => .Right,
        .Right => .Left,
    };
}
