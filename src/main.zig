const std = @import("std");
const c = @cImport({
    @cInclude("io.h");
    @cInclude("fb.h");
});
const mbox = @import("mbox.zig");

const log = std.log.scoped(.main);

export fn main() void {
    // // uh oh! this doesn't work
    // // maybe try using the c code for fb_init but use my own draw
    // // FramebufferImage to make sure that's not wrong?
    // var b = mbox.Builder{};
    // const phys_wh_key = b.add(mbox.set_physical_w_h, .{ .w = 1024, .h = 768 });
    // const virt_wh_key = b.add(mbox.set_virtual_w_h, .{ .w = 1024, .h = 768 });
    // const virt_offset_key = b.add(mbox.set_virtual_offset, .{ .x = 0, .y = 0 });
    // const depth_key = b.add(mbox.set_depth, .{ .bits_per_px = 32 });
    // const pixel_order_key = b.add(mbox.set_pixel_order, .rgb);
    // const fb_key = b.add(mbox.allocate_framebuffer, .{ .alignment = 4096 });
    // const bytes_per_line_key = b.add(mbox.get_pitch, {});

    // b.exec() catch @panic("Messagebox Error");

    // const phys_wh = phys_wh_key.get() catch @panic("phys wh error");
    // const virt_wh = virt_wh_key.get() catch @panic("virt wh error");
    // const virt_offset = virt_offset_key.get() catch @panic("virt offset error");
    // const depth = depth_key.get() catch @panic("depth key error");
    // // if (depth.bits_per_px != 32) return error.UnsupportedDepth; // TODO error
    // const pixel_order = pixel_order_key.get() catch @panic("pixel order error");
    // const fb = fb_key.get() catch @panic("fb error");
    // if (fb.len == 0) @panic("No Framebuffer");
    // const bytes_per_line = bytes_per_line_key.get() catch @panic("bytes per line error");

    // log.info("Got framebuffer {}x{}:{} {}. {*}[0..{}]", .{
    //     phys_wh.w,
    //     phys_wh.h,
    //     bytes_per_line.pitch,
    //     pixel_order,
    //     fb.ptr,
    //     fb.len,
    // });

    // drawFramebufferImage(pixel_order, fb);

    // c.uart_init();
    c.fb_init();

    c.drawRect(150, 150, 400, 400, 0x03, 0);
    c.drawRect(300, 300, 350, 350, 0x2e, 1);

    c.drawCircle(960, 540, 250, 0x0e, 0);
    c.drawCircle(960, 540, 50, 0x13, 1);

    c.drawPixel(250, 250, 0x0e);

    c.drawChar('O', 500, 500, 0x05);
    c.drawString(100, 100, "Hello world!", 0x0f);

    c.drawLine(100, 500, 350, 700, 0x0c);

    drawFramebufferImage(.bgr, c.fb[0 .. c.height * c.pitch], c.pitch);
}

const fb_image_example = @embedFile("raspbian.rgba");
pub fn drawFramebufferImage(isrgb: mbox.set_pixel_order.Order, lfb: []u8, pitch: u32) void {
    const H = 256;
    const W = 256;
    const C = 4;
    for (range(H)) |_, y| {
        for (range(W)) |_, x| {
            const input_offset = (x * C) + (y * W * C);
            var offset = (y * pitch) + (x * 4);
            switch (isrgb) {
                .rgb => {
                    lfb[0 + offset] = fb_image_example[0 + input_offset];
                    lfb[2 + offset] = fb_image_example[2 + input_offset];
                },
                .bgr => {
                    lfb[2 + offset] = fb_image_example[0 + input_offset];
                    lfb[0 + offset] = fb_image_example[2 + input_offset];
                },
            }
            lfb[1 + offset] = fb_image_example[1 + input_offset];
            lfb[3 + offset] = fb_image_example[3 + input_offset];
        }
    }
}

pub fn range(max: usize) []const void {
    return @as([]const void, &[_]void{}).ptr[0..max];
}
