const std = @import("std");
const print = @import("std").debug.print;
const Self = @This();

name: []const u8,

before: i128 = 0,
after: i128 = 0,

var instances: *std.StringHashMap(Self) = undefined;
var is_ready = false;

// this leaks memory
// no deinit and no timer destroy for now

pub fn setup() void {
    const allocator = std.heap.page_allocator;

    var hashmap = allocator.create(std.StringHashMap(Self)) catch unreachable;
    hashmap.* = std.StringHashMap(Self).init(allocator);
    instances = hashmap;

    is_ready = true;
}

pub fn startTimer(self: *Self) void {
    self.before = std.time.nanoTimestamp();
}

pub fn start(timer_name: []const u8) void {
    if (!is_ready) {
        setup();
    }

    var timer = Self{
        .name = timer_name,
    };

    timer.startTimer();
    instances.put(timer_name, timer) catch unreachable;
}

pub fn end(timer_name: []const u8) void {
    if (!is_ready) {
        setup();
    }

    if (instances.getPtr(timer_name)) |timer| {
        timer.endTimer();
    } else {
        print("Trying to end a timer which doesn't exist. Timer name : {s}", .{timer_name});
    }
}

pub fn endTimer(self: *Self) void {
    self.after = std.time.nanoTimestamp();

    var duration = self.after - self.before;
    var ms = @as(f64, @floatFromInt(duration)) / 1_000_000;

    print("\n", .{});
    print("\n{s} Results : {d:.4} ms", .{ self.name, ms });
    print("\n", .{});
    print("\n", .{});

    self.before = 0;
    self.after = 0;
}
