const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "interpreter",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
    });
    
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);

    const run = b.step("run", "Run the demo");
    const run_cmd = std.Build.addRunArtifact(b, exe);
    run.dependOn(&run_cmd.step);
}
