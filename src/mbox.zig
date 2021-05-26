const std = @import("std");
const mmio = @import("mmio.zig");

const mbox_max_size = 36;
pub const mbox_ptr: *align(0b1000) volatile [mbox_max_size]u32 = &(struct {
    var mbox_raw: [mbox_max_size]u32 align(0b10000) = [_]u32{undefined} ** mbox_max_size;
}).mbox_raw;

pub const MboxChannel = enum(u4) {
    ch_power = 0,
    ch_fb = 1,
    ch_vuart = 2,
    ch_vchiq = 3,
    ch_leds = 4,
    ch_btns = 5,
    ch_touch = 6,
    ch_count = 7,
    ch_prop = 8,
};

pub const mbox_response = 0x80000000;
pub const mbox_full = 0x80000000;
pub const mbox_empty = 0x40000000;

pub const Builder = struct {
    // call : copies msg to mbox_ptr : copies mbox_ptr back to msg
    message: [mbox_max_size]u32 = [_]u32{ 0xAAAAAAAA, 0 } ++ [_]u32{0xAAAAAAAA} ** (mbox_max_size - 2),
    index: u32 = 2,

    fn ArrayLen(comptime Type: type) usize {
        return @typeInfo(Type).Array.len;
    }
    fn Arg0(comptime Type: type) type {
        return @typeInfo(Type).Fn.args[0].arg_type.?;
    }
    fn ReturnType(comptime Type: type) type {
        return @typeInfo(Type).Fn.return_type.?;
    }
    fn LaterResult(comptime Tag: type) type {
        return struct {
            // could support runtime known lengths without too much difficulty
            data: *const [ArrayLen(Arg0(@TypeOf(Tag.unpack))) + 1]u32,
            pub fn get(this: @This()) !ReturnType(@TypeOf(Tag.unpack)) {
                if (this.data[0] & (0b1 << 31) == 0) return error.ResponseNotSet;
                return Tag.unpack(this.data[1..].*);
            }
        };
    }
    fn appendSlice(b: *Builder, arr: []const u32) void {
        std.mem.copy(u32, b.message[b.index..], arr);
        b.index += @intCast(u32, arr.len);
    }
    /// request: std.meta.ArgsTuple(@TypeOf(Tag.pack))
    pub fn add(b: *Builder, comptime Tag: type, request: Arg0(@TypeOf(Tag.pack))) LaterResult(Tag) {
        const req_data = Tag.pack(request);
        comptime const req_len = ArrayLen(ReturnType(@TypeOf(Tag.pack)));
        comptime const res_len = ArrayLen(Arg0(@TypeOf(Tag.unpack)));
        comptime const buffer_size = @intCast(u32, std.math.max(req_len, res_len));

        b.appendSlice(&.{ Tag.tag, buffer_size * 4 });
        const res_data = b.message[b.index..][0 .. res_len + 1];
        b.appendSlice(&.{0});
        std.mem.copy(u32, b.message[b.index..], &req_data);
        b.index += buffer_size;

        return .{ .data = res_data };
    }
    pub fn exec(b: *Builder) !void {
        b.appendSlice(&.{0});
        b.message[0] = b.index * 4;

        const channel: MboxChannel = .ch_prop;

        for (b.message[0..b.index]) |v, i| mbox_ptr[i] = v;

        // 28-bit address (MSB) and 4-bit value (LSB)
        if (@ptrToInt(mbox_ptr) & ~@as(usize, 0b1111) != @ptrToInt(mbox_ptr)) @panic("misaligned mbox pointer. must be 0b10000 aligned");
        const r = @intCast(u32, @ptrToInt(mbox_ptr)) | @enumToInt(channel);

        // Wait until we can write
        while (mmio.read(.mbox_status) & mbox_full != 0) mmio.spinHint();

        // Write the address of our buffer to the mailbox with the channel appended
        mmio.write(.mbox_write, r);

        while (true) {
            // Is there a reply?
            while (mmio.read(.mbox_status) & mbox_empty != 0) mmio.spinHint();

            // Is it a reply to our message?
            if (mmio.read(.mbox_read) == r) {
                for (mbox_ptr[0..b.message.len]) |v, i| b.message[i] = v;
                if (b.message[1] == mbox_response) return;
                return error.Failure;
            }
        }
    }
};

/// Set physical (display) width/height
///
/// Note that the "physical (display)" size is the size of the allocated buffer in memory, not
/// the resolution of the video signal sent to the display device.
///
/// The response may not be the same as the request so it must be checked. May be the previous
/// width/height or 0 for unsupported.
pub const set_physical_w_h = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00048003;
    fn pack(request: WH) [2]u32 {
        return .{ request.w, request.h };
    }
    fn unpack(response: [2]u32) WH {
        return .{ .w = response[0], .h = response[1] };
    }
    const WH = struct {
        w: u32,
        h: u32,
    };
};

/// Set virtual (buffer) width/height
///
/// Note that the "virtual (buffer)" size is the portion of buffer that is sent to the display
/// device, not the resolution the buffer itself. This may be smaller than the allocated buffer
/// size in order to implement panning.
///
/// Response is the same as the request (or modified), to indicate if this configuration is
/// supported (in combination with all the other settings). Does not modify the current
/// hardware or frame buffer state.
pub const set_virtual_w_h = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00048004;
    fn pack(request: WH) [2]u32 {
        return .{ request.w, request.h };
    }
    fn unpack(response: [2]u32) WH {
        return .{ .w = response[0], .h = response[1] };
    }
    const WH = struct {
        w: u32,
        h: u32,
    };
};

/// Set virtual offset
///
/// The response may not be the same as the request so it must be checked. May be the previous
/// offset or 0 for unsupported.
pub const set_virtual_offset = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00048009;
    fn pack(request: XY) [2]u32 {
        return .{ request.x, request.y };
    }
    fn unpack(response: [2]u32) XY {
        return .{ .x = response[0], .y = response[1] };
    }
    const XY = struct {
        x: u32,
        y: u32,
    };
};

/// The response may not be the same as the request so it must be checked. May be the previous
/// depth or 0 for unsupported.
pub const set_depth = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00048005;
    fn pack(request: Request) [1]u32 {
        return .{request.bits_per_px};
    }
    fn unpack(response: [1]u32) Response {
        return .{ .bits_per_px = response[0] };
    }
    const Request = struct {
        bits_per_px: u32,
    };
    const Response = struct {
        bits_per_px: u32,
    };
};

/// The response may not be the same as the request so it must be checked
pub const set_pixel_order = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00048006;
    fn pack(request: Order) [1]u32 {
        return .{@enumToInt(request)};
    }
    fn unpack(response: [1]u32) Order {
        return std.meta.intToEnum(Order, response[0]) catch @panic("bad pixel order response");
    }
    pub const Order = enum(u1) {
        bgr = 0,
        rgb = 1,
    };
};

/// If the requested alignment is unsupported then the current base and size (which may be 0 if
/// not allocated) is returned and no change occurs.
pub const allocate_framebuffer = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00040001;
    fn pack(request: Request) [1]u32 {
        return .{request.alignment};
    }
    fn unpack(response: [2]u32) Response {
        if (response[0] == 0) return @as([*]u8, undefined)[0..0];
        // & 0x3FFFFFFF? that just cuts off the value if it goes out of memory, why would you do that?
        // better to catch the error it causes
        return @intToPtr([*]u8, response[0])[0..response[1]];
    }
    const Request = struct {
        alignment: u32,
    };
    const Response = []u8;
};

pub const get_pitch = struct {
    const channel: MboxChannel = .ch_prop;
    const tag: u32 = 0x00040008;
    fn pack(request: void) [0]u32 {
        return .{};
    }
    fn unpack(response: [1]u32) Response {
        return .{ .pitch = response[0] };
    }
    const Response = struct {
        pitch: u32,
    };
};
