const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();
const allocator = std.heap.page_allocator;

const Operation = enum {
    create,
    list,
    remove,
};

fn createTodo(file: std.fs.File) !void {
    try stdout.writeAll("Add TODO: ");
    const new_todo = try stdin.readUntilDelimiterAlloc(allocator, '\n', 8000);
    defer allocator.free(new_todo);

    const endpos = try file.getEndPos();
    try file.seekTo(endpos);
    try file.writer().print("{s}\n", .{new_todo});

    try stdout.writeAll("TODO added successfully.\n");
}

fn listTodos(file: std.fs.File) !void {
    try file.seekTo(0);

    const content = try file.reader().readAllAlloc(allocator, 8000);
    defer allocator.free(content);

    if (content.len == 0) {
        try stdout.writeAll("No TODOs found.\n");
    } else {
        try stdout.print("TODOS:\n{s}\n", .{content});
    }
}

fn removeTodo(file: std.fs.File) !void {
    try file.seekTo(0);

    const content = try file.reader().readAllAlloc(allocator, 8000);
    defer allocator.free(content);

    var lines = std.mem.splitSequence(u8, content, "\n");
    var list = std.ArrayList([]u8).init(allocator);
    defer {
        for (list.items) |item| {
            allocator.free(item);
        }
        list.deinit();
    }

    while (lines.next()) |line| {
        if (line.len > 0) {
            // Duplicate the line into a mutable slice
            const line_copy = try allocator.dupe(u8, line);
            try list.append(line_copy);
        }
    }

    if (list.items.len == 0) {
        try stdout.writeAll("No TODOs found.\n");
        return;
    }

    try stdout.writeAll("Current TODOs:\n");
    for (list.items, 0..) |todo, i| {
        try stdout.print("{d}: {s}\n", .{ i + 1, todo });
    }

    try stdout.writeAll("Enter the number of the TODO to remove: ");
    const input = try stdin.readUntilDelimiterAlloc(allocator, '\n', 10);
    defer allocator.free(input);

    const index = std.fmt.parseInt(usize, input, 10) catch |err| {
        try stdout.print("Invalid number: {s}\n", .{@errorName(err)});
        return;
    };

    if (index < 1 or index > list.items.len) {
        try stdout.print("Invalid index. Please enter a number between 1 and {d}.\n", .{list.items.len});
        return;
    }

    // Free the memory of the removed TODO
    allocator.free(list.orderedRemove(index - 1));
    try stdout.writeAll("TODO removed successfully.\n");

    // Truncate and rewrite the file
    try file.seekTo(0);
    try file.setEndPos(0);

    for (list.items) |todo| {
        try file.writer().print("{s}\n", .{todo});
    }
}
pub fn main() !void {
    var file = std.fs.cwd().openFile("todos.txt", .{ .mode = .read_write }) catch |err| blk: {
        if (err == error.FileNotFound) {
            _ = try std.fs.cwd().createFile("todos.txt", .{});
            break :blk try std.fs.cwd().openFile("todos.txt", .{ .mode = .read_write });
        }
        return err;
    };
    defer file.close();

    try stdout.writeAll("Select Option (create, list, remove): ");
    const operation_str = try stdin.readUntilDelimiterAlloc(allocator, '\n', 2000);
    defer allocator.free(operation_str);

    const trimmed_op = std.mem.trimRight(u8, operation_str, "\r\n");
    const operation = std.meta.stringToEnum(Operation, trimmed_op) orelse {
        try stdout.print("Invalid Operation: {s}\n", .{trimmed_op});
        return;
    };

    switch (operation) {
        .create => try createTodo(file),
        .list => try listTodos(file),
        .remove => try removeTodo(file),
    }
}
