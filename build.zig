const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("gearTracker_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const zgui_dep = b.dependency("zgui", .{
        .target = target,
    });
    const zgui_mod = zgui_dep.module("root");

    const zglfw_dep = b.dependency("zglfw", .{
        .target = target,
    });
    const zglfw_mod = zglfw_dep.module("root");

    const zopengl_dep = b.dependency("zopengl", .{
        .target = target,
    });
    const zopengl_mod = zopengl_dep.module("root");
    _ = zopengl_mod;

    const exe = b.addExecutable(.{
        .name = "gearTracker_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "gearTracker_zig", .module = mod },
                .{ .name = "zgui", .module = zgui_mod },
                .{ .name = "zglfw", .module = zglfw_mod },
            },
        }),
    });

    exe.linkSystemLibrary("sqlite3");
    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("GL");

    exe.linkLibrary(zgui_dep.artifact("imgui"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
