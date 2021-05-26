// void mmio_write(long reg, unsigned int val) { *(volatile unsigned int *)reg = val; }
// unsigned int mmio_read(long reg) { return *(volatile unsigned int *)reg; }

pub fn write(reg: Reg, val: u32) void {
    @intToPtr(*volatile u32, @enumToInt(reg)).* = val;
}
pub fn read(reg: Reg) u32 {
    return @intToPtr(*volatile u32, @enumToInt(reg)).*;
}
pub fn spinHint() void {
    asm volatile ("YIELD");
}

pub const peripheral_base = 0xFE000000;
pub const videocore_mbox = peripheral_base + 0x0000B880;

pub const Reg = enum(usize) {
    // mbox
    mbox_read = videocore_mbox + 0x0,
    mbox_poll = videocore_mbox + 0x10,
    mbox_sender = videocore_mbox + 0x14,
    mbox_status = videocore_mbox + 0x18,
    mbox_config = videocore_mbox + 0x1C,
    mbox_write = videocore_mbox + 0x20,
};
