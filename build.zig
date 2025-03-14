const std = @import("std");

const ModuleMap = std.meta.Tuple(&[_]type{ []const u8, *std.Build.Module });
const Example = struct {
    name: []const u8,
    path: []const u8,
};

const examples = [_]Example {
    .{ .name = "layout", .path = "examples/layout.zig",  },
    .{ .name = "text", .path = "examples/text.zig",  },
    .{ .name = "bars", .path = "examples/bars.zig",  },
    .{ .name = "container", .path = "examples/container.zig",  },
    .{ .name = "readme", .path = "examples/readme.zig",  },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const zerm_mod = b.dependency("zerm", .{}).module("zerm");

    const module = b.addModule("zuit", .{ .root_source_file = b.path("src/root.zig") });
    module.addImport("zerm", zerm_mod);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.root_module.addImport("zuit", module);
    lib_unit_tests.root_module.addImport("zerm", zerm_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    inline for (examples) |example| {
        addExample(b, target, optimize, example, &[_]ModuleMap{
            .{ "zuit", module },
            .{ "zerm", zerm_mod },
        });
    }
}

pub fn addExample(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    comptime example: Example,
    modules: []const ModuleMap,
) void {
    const exe = b.addExecutable(.{
        .name = example.name,
        .root_source_file = b.path(example.path),
        .target = target,
        .optimize = optimize,
    });

    for (modules) |module| {
        exe.root_module.addImport(module[0], module[1]);
    }

    const ecmd = b.addRunArtifact(exe);
    ecmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        ecmd.addArgs(args);
    }

    const estep = b.step("example-" ++ example.name, "Run example-" ++ example.name);
    estep.dependOn(&ecmd.step);
}
