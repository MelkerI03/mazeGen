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
    // Debugging only, should never happen.
    if (coords.x > x_size or coords.y > y_size) return error.@"Invalid coordinates";

    // The ordering of the directions comes from VIM-motions (hjkl).
    // Since this program is written in NeoVim, it is a small homage to the editor.
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
