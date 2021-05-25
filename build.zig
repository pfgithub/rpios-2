const std = @import("std");

const Model = struct {
    target: std.zig.CrossTarget,
    machine: []const u8,
};

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("kernel8.elf", "src/main.zig");

    const model: Model = .{
        .target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "aarch64-freestanding", .cpu_features = "cortex_a72" }) catch unreachable,
        .machine = "raspi4",
    };

    // zig build-exe -target aarch64-freestanding src/boot.s src/main.zig --script src/linkerscript.ld -femit-bin=zig-cache/bin/app
    // qemu-system-aarch64 -M raspi3 -serial stdio -kernel zig-cache/bin/kernel8.img

    exe.addAssemblyFile("src/boot.s");
    inline for (.{ "src/fb.c", "src/io.c", "src/main.c", "src/mb.c" }) |src| {
        exe.addCSourceFile(src, &.{});
    }

    exe.setTarget(model.target);
    exe.setBuildMode(mode);
    exe.setLinkerScriptPath("src/linkerscript.ld");
    // exe.install();
    exe.installRaw("kernel8.img");

    // const syscmd = b.addSystemCommand(&[_][]const u8{ "llvm-objcopy", "-O", "binary", "zig-out/bin/kernel8.elf", "zig-out/bin/kernel8.img" });
    // syscmd.step.dependOn(&exe.install_step.?.step);
    // b.getInstallStep().dependOn(&syscmd.step);
}
