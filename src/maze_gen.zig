const std = @import("std");
const arenaAlloc = std.heap.ArenaAllocator;

pub const Direction = enum {
    Left,
    Down,
    Up,
    Right,
};

pub const Cell = struct {
    coords: Coordinates,
    walls: u4,
    is_visited: bool,
    previous: ?Coordinates,
    paths: [4]Direction,
    path_count: usize,

    pub fn hasWall(self: Cell, comptime dir: Direction) bool {
        return switch (dir) {
            .Left => self.walls & 0b1000 != 0,
            .Down => self.walls & 0b0100 != 0,
            .Up => self.walls & 0b0010 != 0,
            .Right => self.walls & 0b0001 != 0,
        };
    }
};

pub const Coordinates = struct {
    x: usize,
    y: usize,

    pub fn cell(self: Coordinates, maze: Maze) *Cell {
        return &(maze.cells[self.y][self.x]);
    }

    pub fn toDir(self: Coordinates, dir: Direction) Coordinates {
        return switch (dir) {
            .Up => Coordinates{ .x = self.x, .y = self.y - 1 },
            .Down => Coordinates{ .x = self.x, .y = self.y + 1 },
            .Left => Coordinates{ .x = self.x - 1, .y = self.y },
            .Right => Coordinates{ .x = self.x + 1, .y = self.y },
        };
    }
};

pub const Maze = struct {
    cells: [][]Cell,
    start: Coordinates,
    end: Coordinates,

    fn at(self: Maze, coords: Coordinates) !Cell {
        return self.cells[coords.y][coords.x];
    }
};

pub fn initMaze(allocator: std.mem.Allocator, size: usize, start: Coordinates, end: Coordinates) !Maze {
    //  Default 4x4 maze, right after init,
    //  with start and end inserted.
    //
    //  # # # # # # # # #
    //  x x #   #   #   #
    //  # # # # # # # # #
    //  #   #   #   #   #
    //  # # # # # # # # #
    //  #   #   #   #
    //  # # # # # # # # #
    //  #   #   #   #   #
    //  # # # # # # # # #
    //
    //  Same maze after a cycle:
    //
    //  # # # # # # # # #
    //  x x #   #   #   #
    //  # x # # # # # # #
    //  # x #   #   #   #
    //  # # # # # # # # #
    //  #   #   #   #
    //  # # # # # # # # #
    //  #   #   #   #   #
    //  # # # # # # # # #

    // if (start.x != 0 and start.y != 0) {
    //     return error.@"Invalid start coordinates";
    // }
    // if (std.meta.eql(start, Coordinates{ .x = 0, .y = 0 })) {
    //     return error.@"Start coordinates cannot be in corner";
    // }
    //
    // if (end.x != size - 1 and end.y != size - 1) {
    //     return error.@"Invalid end coordinates";
    // }
    // if (std.meta.eql(end, Coordinates{ .x = size - 1, .y = size - 1 })) {
    //     return error.@"End coordinates cannot be in corner";
    // }

    // Allocate memory for the outer array of slices
    const cells = try allocator.alloc([]Cell, size);

    // Allocate and initialize each row
    for (0.., cells) |i, *row| {
        row.* = try allocator.alloc(Cell, size);
        for (0.., row.*) |j, *cell| {
            cell.coords = Coordinates{ .x = j, .y = i };
            cell.walls = 0b1111;
            cell.is_visited = false;
            cell.previous = null;
            cell.paths = undefined;
            cell.path_count = 0;
        }
    }

    var maze = Maze{ .cells = cells, .start = start, .end = end };

    start.cell(maze).is_visited = true;
    start.cell(maze).previous = Coordinates{ .x = size, .y = size };

    try toggleWall(&maze, start, Direction.Left);
    try toggleWall(&maze, end, Direction.Right);

    return maze;
}

pub fn toggleWall(maze: *Maze, coords: Coordinates, dir: Direction) !void {
    const x_size = maze.cells.len;
    const y_size = maze.cells[0].len;

    // Check if coordinates are in bounds.
    if (coords.x > x_size or coords.y > y_size) return error.@"Invalid coordinates";

    switch (dir) {
        Direction.Left => {
            // Not in bounds
            if (coords.x < 0) return error.@"Invalid coordinates";

            // Inverse wall state on both this and neighboring cell
            coords.cell(maze.*).walls ^= 0b1000;
            if (coords.x != 0) coords.toDir(Direction.Left).cell(maze.*).walls ^= 0b0001;
        },
        Direction.Down => {
            // Not in bounds
            if (coords.y > y_size - 1) return error.@"Invalid direction";

            // Inverse wall state on both this and neighboring cell
            coords.cell(maze.*).walls ^= 0b0100;
            if (coords.y != y_size - 1) coords.toDir(Direction.Down).cell(maze.*).walls ^= 0b0010;
        },
        Direction.Up => {
            // Not in bounds
            if (coords.y < 0) return error.@"Invalid direction";

            // Inverse wall state on both this and neighboring cell
            coords.cell(maze.*).walls ^= 0b0010;
            if (coords.y != 0) coords.toDir(Direction.Up).cell(maze.*).walls ^= 0b0100;
        },
        Direction.Right => {
            // Not in bounds
            if (coords.x > x_size - 1) return error.@"Invalid direction";

            // Inverse wall state on both this and neighboring cell
            coords.cell(maze.*).walls ^= 0b0001;
            if (coords.x != x_size - 1) coords.toDir(Direction.Right).cell(maze.*).walls ^= 0b1000;
        },
    }
}

pub fn printMaze(maze: Maze) !void {
    const stdout = std.io.getStdOut().writer();

    // Print top wall
    try stdout.print("#", .{});
    for (0..maze.cells[0].len * 2) |i| {
        const coord = Coordinates{ .y = 0, .x = i + 1 };
        const is_end = std.meta.eql(coord, maze.end);

        if (is_end) {
            try stdout.print("  ", .{});
            continue;
        }

        try stdout.print(" #", .{});
    }

    try stdout.print("\n", .{});

    var coord: Coordinates = undefined;
    var cell: Cell = undefined;

    // Every row
    for (0..maze.cells.len) |i| {
        // First wall in row
        coord = Coordinates{ .y = i, .x = 0 };
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
            coord = Coordinates{ .y = i, .x = count };

            cell = coord.cell(maze).*;
            if (cell.previous != null or std.meta.eql(coord, maze.start)) {
                try stdout.print(" o", .{});
            } else {
                try stdout.print("  ", .{});
            }

            if (cell.hasWall(Direction.Right)) {
                try stdout.print(" #", .{});
            } else if (cell.previous != null and coord.toDir(Direction.Right).cell(maze).previous != null) {
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
            coord = Coordinates{ .y = i, .x = j };
            cell = coord.cell(maze).*;

            if (i != maze.cells.len - 1) {
                const cellUnder = coord.toDir(Direction.Down).cell(maze).*;

                if (cell.previous != null and cellUnder.previous != null and !cell.hasWall(Direction.Down)) {
                    try stdout.print(" o", .{});
                    try stdout.print(" #", .{});
                    continue;
                }
            }

            if (cell.hasWall(Direction.Down)) {
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
