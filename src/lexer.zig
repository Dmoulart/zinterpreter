const Self = @This();

src: []const u8,

pub fn init(src: []const u8) Self {
    return Self{
        .src = src,
    };
}

pub fn scan(self: *Self) void {
    _ = self;
}
