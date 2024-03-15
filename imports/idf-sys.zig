// esp-idf headers 'zig translate-c' v0.12.0 for xtensa target (re-edited by @kassane)

const std = @import("std");
const builtin = @import("builtin");

// Alocator for use with raw_heap_caps_allocator
pub const HeapCapsAllocator = struct {
    caps: Caps = .MALLOC_CAP_DEFAULT,

    const Self = @This();
    pub fn init(cap: u32) Self {
        return .{
            .caps = @enumFromInt(cap),
        };
    }
    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = rawHeapCapsAlloc,
                .resize = rawHeapCapsResize,
                .free = rawHeapCapsFree,
            },
        };
    }
    fn rawHeapCapsAlloc(
        ctx: *anyopaque,
        len: usize,
        log2_ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        std.debug.assert(log2_ptr_align <= comptime std.math.log2_int(
            usize,
            @alignOf(std.c.max_align_t),
        ));
        return @as(?[*]u8, @ptrCast(
            heap_caps_malloc(
                len,
                @intFromEnum(self.caps),
            ),
        ));
    }

    fn rawHeapCapsResize(
        _: *anyopaque,
        buf: []u8,
        log2_old_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        _ = log2_old_align;
        _ = ret_addr;

        if (new_len <= buf.len)
            return true;

        const full_len = if (@TypeOf(heap_caps_get_allocated_size) != void)
            heap_caps_get_allocated_size(buf.ptr);
        if (new_len <= full_len) return true;

        return false;
    }

    fn rawHeapCapsFree(
        _: *anyopaque,
        buf: []u8,
        log2_old_align: u8,
        ret_addr: usize,
    ) void {
        _ = log2_old_align;
        _ = ret_addr;
        std.debug.assert(heap_caps_check_integrity_all(true));
        heap_caps_free(buf.ptr);
    }
};

// Alocator for use with raw_multi_heap_allocator
pub const MultiHeapAllocator = struct {
    multi_heap_alloc: multi_heap_handle_t = null,

    const Self = @This();
    pub fn init() Self {
        return .{};
    }
    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = rawMultiHeapAlloc,
                .resize = rawMultiHeapResize,
                .free = rawMultiHeapFree,
            },
        };
    }
    fn rawMultiHeapAlloc(
        ctx: *anyopaque,
        len: usize,
        log2_ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        std.debug.assert(log2_ptr_align <= comptime std.math.log2_int(
            usize,
            @alignOf(std.c.max_align_t),
        ));
        return @as(?[*]u8, @ptrCast(
            multi_heap_malloc(self.multi_heap_alloc, multi_heap_free_size(self.multi_heap_alloc) * len),
        ));
    }

    fn rawMultiHeapResize(
        _: *anyopaque,
        buf: []u8,
        log2_old_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        _ = log2_old_align;
        _ = ret_addr;
        const self: Self = .{};

        if (new_len <= buf.len)
            return true;

        if (@TypeOf(multi_heap_get_allocated_size) != void)
            if (new_len <= multi_heap_get_allocated_size(self.multi_heap_alloc, buf.ptr))
                return true;

        return false;
    }

    fn rawMultiHeapFree(
        _: *anyopaque,
        buf: []u8,
        log2_old_align: u8,
        ret_addr: usize,
    ) void {
        _ = log2_old_align;
        _ = ret_addr;
        const self: Self = .{};
        defer std.debug.assert(multi_heap_check(self.multi_heap_alloc, true));
        multi_heap_free(self.multi_heap_alloc, buf.ptr);
    }
};

// C error
pub const esp_err_t = enum(c_int) {
    ESP_OK = 0,
    ESP_FAIL = -1,
    ESP_ERR_NO_MEM = 0x101,
    ESP_ERR_INVALID_ARG = 0x102,
    ESP_ERR_INVALID_STATE = 0x103,
    ESP_ERR_INVALID_SIZE = 0x104,
    ESP_ERR_NOT_FOUND = 0x105,
    ESP_ERR_NOT_SUPPORTED = 0x106,
    ESP_ERR_TIMEOUT = 0x107,
    ESP_ERR_INVALID_RESPONSE = 0x108,
    ESP_ERR_INVALID_CRC = 0x109,
    ESP_ERR_INVALID_VERSION = 0x10A,
    ESP_ERR_INVALID_MAC = 0x10B,
    ESP_ERR_NOT_FINISHED = 0x10C,
    ESP_ERR_NOT_ALLOWED = 0x10D,
    ESP_ERR_WIFI_BASE = 0x3000,
    ESP_ERR_MESH_BASE = 0x4000,
    ESP_ERR_FLASH_BASE = 0x6000,
    ESP_ERR_HW_CRYPTO_BASE = 0xc000,
    ESP_ERR_MEMPROT_BASE = 0xd000,
};

// Zig error
const esp_error = error{
    Fail,
    ErrorNoMem,
    ErrorInvalidArg,
    ErrorInvalidState,
    ErrorInvalidSize,
    ErrorNotFound,
    ErrorNotSupported,
    ErrorTimeout,
    ErrorInvalidResponse,
    ErrorInvalidCRC,
    ErrorInvalidVersion,
    ErrorInvalidMAC,
    ErrorNotFinished,
    ErrorNotAllowed,
    ErrorWiFiBase,
    ErrorMeshBase,
    ErrorFlashBase,
    ErrorHWCryptoBase,
    ErrorMemProtectBase,
};

// C to Zig error
pub fn espError(err: esp_err_t) esp_error!esp_err_t {
    return switch (err) {
        .ESP_FAIL => esp_error.Fail,
        .ESP_ERR_NO_MEM => esp_error.ErrorNoMem,
        .ESP_ERR_INVALID_ARG => esp_error.ErrorInvalidArg,
        .ESP_ERR_INVALID_STATE => esp_error.ErrorInvalidState,
        .ESP_ERR_INVALID_SIZE => esp_error.ErrorInvalidSize,
        .ESP_ERR_NOT_FOUND => esp_error.ErrorNotFound,
        .ESP_ERR_NOT_SUPPORTED => esp_error.ErrorNotSupported,
        .ESP_ERR_TIMEOUT => esp_error.ErrorTimeout,
        .ESP_ERR_INVALID_RESPONSE => esp_error.ErrorInvalidResponse,
        .ESP_ERR_INVALID_CRC => esp_error.ErrorInvalidCRC,
        .ESP_ERR_INVALID_VERSION => esp_error.ErrorInvalidVersion,
        .ESP_ERR_INVALID_MAC => esp_error.ErrorInvalidMAC,
        .ESP_ERR_NOT_FINISHED => esp_error.ErrorNotFinished,
        .ESP_ERR_NOT_ALLOWED => esp_error.ErrorNotAllowed,
        .ESP_ERR_WIFI_BASE => esp_error.ErrorWiFiBase,
        .ESP_ERR_MESH_BASE => esp_error.ErrorMeshBase,
        .ESP_ERR_FLASH_BASE => esp_error.ErrorFlashBase,
        .ESP_ERR_HW_CRYPTO_BASE => esp_error.ErrorHWCryptoBase,
        .ESP_ERR_MEMPROT_BASE => esp_error.ErrorMemProtectBase,
        else => .ESP_OK,
    };
}

pub fn espCheckError(errc: esp_err_t) esp_error!void {
    if (try espError(errc) == esp_err_t.ESP_OK)
        return;
}
pub extern fn esp_err_to_name(code: esp_err_t) [*:0]const u8;
pub extern fn esp_err_to_name_r(code: esp_err_t, buf: [*:0]u8, buflen: usize) [*:0]const u8;
pub extern fn _esp_error_check_failed(rc: esp_err_t, file: [*:0]const u8, line: c_int, function: [*:0]const u8, expression: [*:0]const u8) noreturn;
pub extern fn _esp_error_check_failed_without_abort(rc: esp_err_t, file: [*:0]const u8, line: c_int, function: [*:0]const u8, expression: [*:0]const u8) void;
pub extern fn esp_get_idf_version() [*:0]const u8;
pub const esp_reset_reason_t = enum(c_uint) {
    ESP_RST_UNKNOWN = 0,
    ESP_RST_POWERON = 1,
    ESP_RST_EXT = 2,
    ESP_RST_SW = 3,
    ESP_RST_PANIC = 4,
    ESP_RST_INT_WDT = 5,
    ESP_RST_TASK_WDT = 6,
    ESP_RST_WDT = 7,
    ESP_RST_DEEPSLEEP = 8,
    ESP_RST_BROWNOUT = 9,
    ESP_RST_SDIO = 10,
    ESP_RST_USB = 11,
    ESP_RST_JTAG = 12,
};
pub const shutdown_handler_t = ?*const fn () callconv(.C) void;
extern fn esp_register_shutdown_handler(handle: shutdown_handler_t) esp_err_t;
pub fn espRegisterShutdownHandler(handle: shutdown_handler_t) !void {
    try espCheckError(esp_register_shutdown_handler(handle));
}
extern fn esp_unregister_shutdown_handler(handle: shutdown_handler_t) esp_err_t;
pub fn espUnregisterShutdownHandler(handle: shutdown_handler_t) !void {
    try espCheckError(esp_unregister_shutdown_handler(handle));
}
// fixme: need to find a way to get the esp_chip_info_t
// pub const esp_chip_model_t = enum(c_uint) {
//     CHIP_ESP32 = 1,
//     CHIP_ESP32S2 = 2,
//     CHIP_ESP32S3 = 9,
//     CHIP_ESP32C3 = 5,
//     CHIP_ESP32C2 = 12,
//     CHIP_ESP32C6 = 13,
//     CHIP_ESP32H2 = 16,
//     CHIP_ESP32C5 = 17,
//     CHIP_ESP32P4 = 18,
//     CHIP_POSIX_LINUX = 999,
// };
// pub const esp_chip_info_t = extern struct {
//     model: esp_chip_model_t = std.mem.zeroes(esp_chip_model_t),
//     features: u32 = std.mem.zeroes(u32),
//     revision: u16 = std.mem.zeroes(u16),
//     cores: u8 = std.mem.zeroes(u8),
// };
// pub const CHIP_FEATURE_EMB_FLASH = BIT(@as(c_int, 0));
// pub const CHIP_FEATURE_WIFI_BGN = BIT(@as(c_int, 1));
// pub const CHIP_FEATURE_BLE = BIT(@as(c_int, 4));
// pub const CHIP_FEATURE_BT = BIT(@as(c_int, 5));
// pub const CHIP_FEATURE_IEEE802154 = BIT(@as(c_int, 6));
// pub const CHIP_FEATURE_EMB_PSRAM = BIT(@as(c_int, 7));
// pub inline fn BIT(nr: anytype) @TypeOf(@as(c_ulong, 1) << nr) {
//     _ = &nr;
//     return @as(c_ulong, 1) << nr;
// }
// pub extern fn esp_chip_info(out_info: [*c]esp_chip_info_t) void;
pub extern fn esp_restart() noreturn;
pub extern fn esp_reset_reason() esp_reset_reason_t;
pub extern fn esp_get_free_heap_size() u32;
pub extern fn esp_get_free_internal_heap_size() u32;
pub extern fn esp_get_minimum_free_heap_size() u32;
pub extern fn esp_system_abort(details: [*:0]const u8) noreturn;
pub fn esp_rom_crc32(crc: u32, buf: [*:0]const u8, len: u32) u32 {
    return switch (builtin.cpu.arch.endian()) {
        .little => esp_rom_crc32_le(crc, buf, len),
        else => esp_rom_crc32_be(crc, buf, len),
    };
}
extern fn esp_rom_crc32_be(crc: u32, buf: [*:0]const u8, len: u32) u32;
extern fn esp_rom_crc32_le(crc: u32, buf: [*:0]const u8, len: u32) u32;
pub fn esp_rom_crc16(crc: u32, buf: [*:0]const u8, len: u32) u32 {
    return switch (builtin.cpu.arch.endian()) {
        .little => esp_rom_crc16_le(crc, buf, len),
        else => esp_rom_crc16_be(crc, buf, len),
    };
}
extern fn esp_rom_crc16_le(crc: u16, buf: [*:0]const u8, len: u32) u16;
extern fn esp_rom_crc16_be(crc: u16, buf: [*:0]const u8, len: u32) u16;
pub fn esp_rom_crc8(crc: u32, buf: [*:0]const u8, len: u32) u32 {
    return switch (builtin.cpu.arch.endian()) {
        .little => esp_rom_crc8_le(crc, buf, len),
        else => esp_rom_crc8_be(crc, buf, len),
    };
}
extern fn esp_rom_crc8_le(crc: u8, buf: [*:0]const u8, len: u32) u8;
extern fn esp_rom_crc8_be(crc: u8, buf: [*:0]const u8, len: u32) u8;
pub const soc_reset_reason_t = enum(c_uint) {
    RESET_REASON_CHIP_POWER_ON = 1,
    RESET_REASON_CORE_SW = 3,
    RESET_REASON_CORE_DEEP_SLEEP = 5,
    RESET_REASON_CORE_SDIO = 6,
    RESET_REASON_CORE_MWDT0 = 7,
    RESET_REASON_CORE_MWDT1 = 8,
    RESET_REASON_CORE_RTC_WDT = 9,
    RESET_REASON_CPU0_MWDT0 = 11,
    RESET_REASON_CPU1_MWDT1 = 11,
    RESET_REASON_CPU0_SW = 12,
    RESET_REASON_CPU1_SW = 12,
    RESET_REASON_CPU0_RTC_WDT = 13,
    RESET_REASON_CPU1_RTC_WDT = 13,
    RESET_REASON_CPU1_CPU0 = 14,
    RESET_REASON_SYS_BROWN_OUT = 15,
    RESET_REASON_SYS_RTC_WDT = 16,
};
pub extern fn esp_rom_software_reset_system() void;
pub extern fn esp_rom_software_reset_cpu(cpu_no: c_int) void;
pub extern fn esp_rom_printf(fmt: [*:0]const u8, ...) c_int;
pub extern fn esp_rom_delay_us(us: u32) void;
pub extern fn esp_rom_install_channel_putc(channel: c_int, putc: ?*const fn (u8) callconv(.C) void) void;
pub extern fn esp_rom_install_uart_printf() void;
pub extern fn esp_rom_get_reset_reason(cpu_no: c_int) soc_reset_reason_t;
pub extern fn esp_rom_route_intr_matrix(cpu_core: c_int, periph_intr_id: u32, cpu_intr_num: u32) void;
pub extern fn esp_rom_get_cpu_ticks_per_us() u32;
pub extern fn esp_rom_set_cpu_ticks_per_us(ticks_per_us: u32) void;
pub const esp_log_level_t = enum(c_uint) {
    ESP_LOG_NONE = 0,
    ESP_LOG_ERROR = 1,
    ESP_LOG_WARN = 2,
    ESP_LOG_INFO = 3,
    ESP_LOG_DEBUG = 4,
    ESP_LOG_VERBOSE = 5,
};
const default_level: esp_log_level_t = switch (builtin.mode) {
    .Debug => .ESP_LOG_DEBUG,
    .ReleaseSafe => .ESP_LOG_INFO,
    .ReleaseFast, .ReleaseSmall => .ESP_LOG_ERROR,
};
pub fn ESP_LOGI(allocator: std.mem.Allocator, comptime tag: [*:0]const u8, comptime fmt: []const u8, args: anytype) void {
    const buffer = std.fmt.allocPrintZ(allocator, fmt, args) catch |err| @panic(@errorName(err));
    esp_log_write(default_level, tag, buffer, esp_log_timestamp(), tag);
}
pub const LOG_COLOR_BLACK = "30";
pub const LOG_COLOR_RED = "31";
pub const LOG_COLOR_GREEN = "32";
pub const LOG_COLOR_BROWN = "33";
pub const LOG_COLOR_BLUE = "34";
pub const LOG_COLOR_PURPLE = "35";
pub const LOG_COLOR_CYAN = "36";
pub inline fn LOG_COLOR(COLOR: anytype) @TypeOf("\x1b[0;" ++ COLOR ++ "m") {
    _ = &COLOR;
    return "\x1b[0;" ++ COLOR ++ "m";
}
pub inline fn LOG_BOLD(COLOR: anytype) @TypeOf("\x1b[1;" ++ COLOR ++ "m") {
    _ = &COLOR;
    return "\x1b[1;" ++ COLOR ++ "m";
}
pub const LOG_RESET_COLOR = "\x1b[0m";
pub const LOG_COLOR_E = LOG_COLOR(LOG_COLOR_RED);
pub const LOG_COLOR_W = LOG_COLOR(LOG_COLOR_BROWN);
pub const LOG_COLOR_I = LOG_COLOR(LOG_COLOR_GREEN);
pub const vprintf_like_t = ?*const fn ([*:0]const u8, va_list) callconv(.C) c_int;
pub extern var esp_log_default_level: esp_log_level_t;
pub extern fn esp_log_level_set(tag: [*:0]const u8, level: esp_log_level_t) void;
pub extern fn esp_log_level_get(tag: [*:0]const u8) esp_log_level_t;
pub extern fn esp_log_set_vprintf(func: vprintf_like_t) vprintf_like_t;
pub extern fn esp_log_timestamp() u32;
pub extern fn esp_log_system_timestamp() [*:0]u8;
pub extern fn esp_log_early_timestamp() u32;
pub extern fn esp_log_write(level: esp_log_level_t, tag: [*:0]const u8, format: [*:0]const u8, ...) void;
pub extern fn esp_log_writev(level: esp_log_level_t, tag: [*:0]const u8, format: [*:0]const u8, args: va_list) void;
pub extern fn esp_log_buffer_hex_internal(tag: [*:0]const u8, buffer: ?*const anyopaque, buff_len: u16, level: esp_log_level_t) void;
pub extern fn esp_log_buffer_char_internal(tag: [*:0]const u8, buffer: ?*const anyopaque, buff_len: u16, level: esp_log_level_t) void;
pub extern fn esp_log_buffer_hexdump_internal(tag: [*:0]const u8, buffer: ?*const anyopaque, buff_len: u16, log_level: esp_log_level_t) void;
pub const periph_interrput_t = enum(c_uint) {
    ETS_WIFI_MAC_INTR_SOURCE = 0,
    ETS_WIFI_MAC_NMI_SOURCE = 1,
    ETS_WIFI_BB_INTR_SOURCE = 2,
    ETS_BT_MAC_INTR_SOURCE = 3,
    ETS_BT_BB_INTR_SOURCE = 4,
    ETS_BT_BB_NMI_SOURCE = 5,
    ETS_RWBT_INTR_SOURCE = 6,
    ETS_RWBLE_INTR_SOURCE = 7,
    ETS_RWBT_NMI_SOURCE = 8,
    ETS_RWBLE_NMI_SOURCE = 9,
    ETS_SLC0_INTR_SOURCE = 10,
    ETS_SLC1_INTR_SOURCE = 11,
    ETS_UHCI0_INTR_SOURCE = 12,
    ETS_UHCI1_INTR_SOURCE = 13,
    ETS_TG0_T0_LEVEL_INTR_SOURCE = 14,
    ETS_TG0_T1_LEVEL_INTR_SOURCE = 15,
    ETS_TG0_WDT_LEVEL_INTR_SOURCE = 16,
    ETS_TG0_LACT_LEVEL_INTR_SOURCE = 17,
    ETS_TG1_T0_LEVEL_INTR_SOURCE = 18,
    ETS_TG1_T1_LEVEL_INTR_SOURCE = 19,
    ETS_TG1_WDT_LEVEL_INTR_SOURCE = 20,
    ETS_TG1_LACT_LEVEL_INTR_SOURCE = 21,
    ETS_GPIO_INTR_SOURCE = 22,
    ETS_GPIO_NMI_SOURCE = 23,
    ETS_FROM_CPU_INTR0_SOURCE = 24,
    ETS_FROM_CPU_INTR1_SOURCE = 25,
    ETS_FROM_CPU_INTR2_SOURCE = 26,
    ETS_FROM_CPU_INTR3_SOURCE = 27,
    ETS_SPI0_INTR_SOURCE = 28,
    ETS_SPI1_INTR_SOURCE = 29,
    ETS_SPI2_INTR_SOURCE = 30,
    ETS_SPI3_INTR_SOURCE = 31,
    ETS_I2S0_INTR_SOURCE = 32,
    ETS_I2S1_INTR_SOURCE = 33,
    ETS_UART0_INTR_SOURCE = 34,
    ETS_UART1_INTR_SOURCE = 35,
    ETS_UART2_INTR_SOURCE = 36,
    ETS_SDIO_HOST_INTR_SOURCE = 37,
    ETS_ETH_MAC_INTR_SOURCE = 38,
    ETS_PWM0_INTR_SOURCE = 39,
    ETS_PWM1_INTR_SOURCE = 40,
    ETS_LEDC_INTR_SOURCE = 43,
    ETS_EFUSE_INTR_SOURCE = 44,
    ETS_TWAI_INTR_SOURCE = 45,
    ETS_RTC_CORE_INTR_SOURCE = 46,
    ETS_RMT_INTR_SOURCE = 47,
    ETS_PCNT_INTR_SOURCE = 48,
    ETS_I2C_EXT0_INTR_SOURCE = 49,
    ETS_I2C_EXT1_INTR_SOURCE = 50,
    ETS_RSA_INTR_SOURCE = 51,
    ETS_SPI1_DMA_INTR_SOURCE = 52,
    ETS_SPI2_DMA_INTR_SOURCE = 53,
    ETS_SPI3_DMA_INTR_SOURCE = 54,
    ETS_WDT_INTR_SOURCE = 55,
    ETS_TIMER1_INTR_SOURCE = 56,
    ETS_TIMER2_INTR_SOURCE = 57,
    ETS_TG0_T0_EDGE_INTR_SOURCE = 58,
    ETS_TG0_T1_EDGE_INTR_SOURCE = 59,
    ETS_TG0_WDT_EDGE_INTR_SOURCE = 60,
    ETS_TG0_LACT_EDGE_INTR_SOURCE = 61,
    ETS_TG1_T0_EDGE_INTR_SOURCE = 62,
    ETS_TG1_T1_EDGE_INTR_SOURCE = 63,
    ETS_TG1_WDT_EDGE_INTR_SOURCE = 64,
    ETS_TG1_LACT_EDGE_INTR_SOURCE = 65,
    ETS_MMU_IA_INTR_SOURCE = 66,
    ETS_MPU_IA_INTR_SOURCE = 67,
    ETS_CACHE_IA_INTR_SOURCE = 68,
    ETS_MAX_INTR_SOURCE = 69,
};
pub extern const esp_isr_names: [69][*c]const u8;
pub extern const Xthal_rev_no: c_uint;
pub extern fn xthal_save_extra(base: ?*anyopaque) void;
pub extern fn xthal_restore_extra(base: ?*anyopaque) void;
pub extern fn xthal_save_cpregs(base: ?*anyopaque, c_int) void;
pub extern fn xthal_restore_cpregs(base: ?*anyopaque, c_int) void;
pub extern fn xthal_save_cp0(base: ?*anyopaque) void;
pub extern fn xthal_save_cp1(base: ?*anyopaque) void;
pub extern fn xthal_save_cp2(base: ?*anyopaque) void;
pub extern fn xthal_save_cp3(base: ?*anyopaque) void;
pub extern fn xthal_save_cp4(base: ?*anyopaque) void;
pub extern fn xthal_save_cp5(base: ?*anyopaque) void;
pub extern fn xthal_save_cp6(base: ?*anyopaque) void;
pub extern fn xthal_save_cp7(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp0(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp1(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp2(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp3(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp4(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp5(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp6(base: ?*anyopaque) void;
pub extern fn xthal_restore_cp7(base: ?*anyopaque) void;
pub extern var Xthal_cpregs_save_fn: [8]?*anyopaque;
pub extern var Xthal_cpregs_restore_fn: [8]?*anyopaque;
pub extern var Xthal_cpregs_save_nw_fn: [8]?*anyopaque;
pub extern var Xthal_cpregs_restore_nw_fn: [8]?*anyopaque;
pub extern const Xthal_extra_size: c_uint;
pub extern const Xthal_extra_align: c_uint;
pub extern const Xthal_cpregs_size: [8]c_uint;
pub extern const Xthal_cpregs_align: [8]c_uint;
pub extern const Xthal_all_extra_size: c_uint;
pub extern const Xthal_all_extra_align: c_uint;
pub extern const Xthal_cp_names: [8][*c]const u8;
pub extern fn xthal_init_mem_extra(?*anyopaque) void;
pub extern fn xthal_init_mem_cp(?*anyopaque, c_int) void;
pub extern const Xthal_num_coprocessors: c_uint;
pub extern const Xthal_cp_num: u8;
pub extern const Xthal_cp_max: u8;
pub extern const Xthal_cp_mask: c_uint;
pub extern const Xthal_num_aregs: c_uint;
pub extern const Xthal_num_aregs_log2: u8;
pub extern const Xthal_icache_linewidth: u8;
pub extern const Xthal_dcache_linewidth: u8;
pub extern const Xthal_icache_linesize: c_ushort;
pub extern const Xthal_dcache_linesize: c_ushort;
pub extern const Xthal_icache_size: c_uint;
pub extern const Xthal_dcache_size: c_uint;
pub extern const Xthal_dcache_is_writeback: u8;
pub extern fn xthal_icache_region_invalidate(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_region_invalidate(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_region_writeback(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_region_writeback_inv(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_icache_line_invalidate(addr: ?*anyopaque) void;
pub extern fn xthal_dcache_line_invalidate(addr: ?*anyopaque) void;
pub extern fn xthal_dcache_line_writeback(addr: ?*anyopaque) void;
pub extern fn xthal_dcache_line_writeback_inv(addr: ?*anyopaque) void;
pub extern fn xthal_icache_sync() void;
pub extern fn xthal_dcache_sync() void;
pub extern fn xthal_icache_get_ways() c_uint;
pub extern fn xthal_icache_set_ways(ways: c_uint) void;
pub extern fn xthal_dcache_get_ways() c_uint;
pub extern fn xthal_dcache_set_ways(ways: c_uint) void;
pub extern fn xthal_cache_coherence_on() void;
pub extern fn xthal_cache_coherence_off() void;
pub extern fn xthal_cache_coherence_optin() void;
pub extern fn xthal_cache_coherence_optout() void;
pub extern fn xthal_get_cache_prefetch() c_int;
pub extern fn xthal_set_cache_prefetch(c_int) c_int;
pub extern fn xthal_set_cache_prefetch_long(c_ulonglong) c_int;
pub extern const Xthal_debug_configured: c_int;
pub extern fn xthal_set_soft_break(addr: ?*anyopaque) c_uint;
pub extern fn xthal_remove_soft_break(addr: ?*anyopaque, c_uint) void;
pub extern fn xthal_disassemble(instr_buf: [*:0]u8, tgt_addr: ?*anyopaque, buffer: [*:0]u8, buflen: c_uint, options: c_uint) c_int;
pub extern fn xthal_disassemble_size(instr_buf: [*:0]u8) c_int;
pub extern fn xthal_memcpy(dst: ?*anyopaque, src: ?*const anyopaque, len: c_uint) ?*anyopaque;
pub extern fn xthal_bcopy(src: ?*const anyopaque, dst: ?*anyopaque, len: c_uint) ?*anyopaque;
pub extern fn xthal_compare_and_set(addr: [*c]c_int, test_val: c_int, compare_val: c_int) c_int;
pub extern const Xthal_release_major: c_uint;
pub extern const Xthal_release_minor: c_uint;
pub extern const Xthal_release_name: [*:0]const u8;
pub extern const Xthal_release_internal: [*:0]const u8;
pub extern const Xthal_memory_order: u8;
pub extern const Xthal_have_windowed: u8;
pub extern const Xthal_have_density: u8;
pub extern const Xthal_have_booleans: u8;
pub extern const Xthal_have_loops: u8;
pub extern const Xthal_have_nsa: u8;
pub extern const Xthal_have_minmax: u8;
pub extern const Xthal_have_sext: u8;
pub extern const Xthal_have_clamps: u8;
pub extern const Xthal_have_mac16: u8;
pub extern const Xthal_have_mul16: u8;
pub extern const Xthal_have_fp: u8;
pub extern const Xthal_have_speculation: u8;
pub extern const Xthal_have_threadptr: u8;
pub extern const Xthal_have_pif: u8;
pub extern const Xthal_num_writebuffer_entries: c_ushort;
pub extern const Xthal_build_unique_id: c_uint;
pub extern const Xthal_hw_configid0: c_uint;
pub extern const Xthal_hw_configid1: c_uint;
pub extern const Xthal_hw_release_major: c_uint;
pub extern const Xthal_hw_release_minor: c_uint;
pub extern const Xthal_hw_release_name: [*:0]const u8;
pub extern const Xthal_hw_release_internal: [*:0]const u8;
pub extern fn xthal_clear_regcached_code() void;
pub extern fn xthal_window_spill() void;
pub extern fn xthal_validate_cp(c_int) void;
pub extern fn xthal_invalidate_cp(c_int) void;
pub extern fn xthal_set_cpenable(c_uint) void;
pub extern fn xthal_get_cpenable() c_uint;
pub extern const Xthal_num_intlevels: u8;
pub extern const Xthal_num_interrupts: u8;
pub extern const Xthal_excm_level: u8;
pub extern const Xthal_intlevel_mask: [16]c_uint;
pub extern const Xthal_intlevel_andbelow_mask: [16]c_uint;
pub extern const Xthal_intlevel: [32]u8;
pub extern const Xthal_inttype: [32]u8;
pub extern const Xthal_inttype_mask: [11]c_uint;
pub extern const Xthal_timer_interrupt: [4]c_int;
pub extern fn xthal_get_intenable() c_uint;
pub extern fn xthal_set_intenable(c_uint) void;
pub extern fn xthal_get_interrupt() c_uint;
pub extern fn xthal_set_intset(c_uint) void;
pub extern fn xthal_set_intclear(c_uint) void;
pub extern const Xthal_num_ibreak: c_int;
pub extern const Xthal_num_dbreak: c_int;
pub extern const Xthal_have_ccount: u8;
pub extern const Xthal_num_ccompare: u8;
pub extern fn xthal_get_ccount() c_uint;
pub extern fn xthal_set_ccompare(c_int, c_uint) void;
pub extern fn xthal_get_ccompare(c_int) c_uint;
pub extern const Xthal_have_prid: u8;
pub extern const Xthal_have_exceptions: u8;
pub extern const Xthal_xea_version: u8;
pub extern const Xthal_have_interrupts: u8;
pub extern const Xthal_have_highlevel_interrupts: u8;
pub extern const Xthal_have_nmi: u8;
pub extern fn xthal_get_prid() c_uint;
pub extern fn xthal_vpri_to_intlevel(vpri: c_uint) c_uint;
pub extern fn xthal_intlevel_to_vpri(intlevel: c_uint) c_uint;
pub extern fn xthal_int_enable(c_uint) c_uint;
pub extern fn xthal_int_disable(c_uint) c_uint;
pub extern fn xthal_set_int_vpri(intnum: c_int, vpri: c_int) c_int;
pub extern fn xthal_get_int_vpri(intnum: c_int) c_int;
pub extern fn xthal_set_vpri_locklevel(intlevel: c_uint) void;
pub extern fn xthal_get_vpri_locklevel() c_uint;
pub extern fn xthal_set_vpri(vpri: c_uint) c_uint;
pub extern fn xthal_get_vpri() c_uint;
pub extern fn xthal_set_vpri_intlevel(intlevel: c_uint) c_uint;
pub extern fn xthal_set_vpri_lock() c_uint;
pub const XtHalVoidFunc = fn () callconv(.C) void;
pub extern var Xthal_tram_pending: c_uint;
pub extern var Xthal_tram_enabled: c_uint;
pub extern var Xthal_tram_sync: c_uint;
pub extern fn xthal_tram_pending_to_service() c_uint;
pub extern fn xthal_tram_done(serviced_mask: c_uint) void;
pub extern fn xthal_tram_set_sync(intnum: c_int, sync: c_int) c_int;
pub extern fn xthal_set_tram_trigger_func(trigger_fn: ?*const XtHalVoidFunc) ?*const XtHalVoidFunc;
pub extern const Xthal_num_instrom: u8;
pub extern const Xthal_num_instram: u8;
pub extern const Xthal_num_datarom: u8;
pub extern const Xthal_num_dataram: u8;
pub extern const Xthal_num_xlmi: u8;
pub const Xthal_instrom_vaddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_instrom_vaddr",
});
pub const Xthal_instrom_paddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_instrom_paddr",
});
pub const Xthal_instrom_size: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_instrom_size",
});
pub const Xthal_instram_vaddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_instram_vaddr",
});
pub const Xthal_instram_paddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_instram_paddr",
});
pub const Xthal_instram_size: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_instram_size",
});
pub const Xthal_datarom_vaddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_datarom_vaddr",
});
pub const Xthal_datarom_paddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_datarom_paddr",
});
pub const Xthal_datarom_size: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_datarom_size",
});
pub const Xthal_dataram_vaddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_dataram_vaddr",
});
pub const Xthal_dataram_paddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_dataram_paddr",
});
pub const Xthal_dataram_size: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_dataram_size",
});
pub const Xthal_xlmi_vaddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_xlmi_vaddr",
});
pub const Xthal_xlmi_paddr: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_xlmi_paddr",
});
pub const Xthal_xlmi_size: [*c]const c_uint = @extern([*c]const c_uint, .{
    .name = "Xthal_xlmi_size",
});
pub extern const Xthal_icache_setwidth: u8;
pub extern const Xthal_dcache_setwidth: u8;
pub extern const Xthal_icache_ways: c_uint;
pub extern const Xthal_dcache_ways: c_uint;
pub extern const Xthal_icache_line_lockable: u8;
pub extern const Xthal_dcache_line_lockable: u8;
pub extern fn xthal_get_cacheattr() c_uint;
pub extern fn xthal_get_icacheattr() c_uint;
pub extern fn xthal_get_dcacheattr() c_uint;
pub extern fn xthal_set_cacheattr(c_uint) void;
pub extern fn xthal_set_icacheattr(c_uint) void;
pub extern fn xthal_set_dcacheattr(c_uint) void;
pub extern fn xthal_set_region_attribute(addr: ?*anyopaque, size: c_uint, cattr: c_uint, flags: c_uint) c_int;
pub extern fn xthal_icache_enable() void;
pub extern fn xthal_dcache_enable() void;
pub extern fn xthal_icache_disable() void;
pub extern fn xthal_dcache_disable() void;
pub extern fn xthal_icache_all_invalidate() void;
pub extern fn xthal_dcache_all_invalidate() void;
pub extern fn xthal_dcache_all_writeback() void;
pub extern fn xthal_dcache_all_writeback_inv() void;
pub extern fn xthal_icache_all_unlock() void;
pub extern fn xthal_dcache_all_unlock() void;
pub extern fn xthal_icache_region_lock(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_region_lock(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_icache_region_unlock(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_region_unlock(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_icache_hugerange_invalidate(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_icache_hugerange_unlock(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_hugerange_invalidate(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_hugerange_unlock(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_hugerange_writeback(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_dcache_hugerange_writeback_inv(addr: ?*anyopaque, size: c_uint) void;
pub extern fn xthal_icache_line_lock(addr: ?*anyopaque) void;
pub extern fn xthal_dcache_line_lock(addr: ?*anyopaque) void;
pub extern fn xthal_icache_line_unlock(addr: ?*anyopaque) void;
pub extern fn xthal_dcache_line_unlock(addr: ?*anyopaque) void;
pub extern fn xthal_memep_inject_error(addr: ?*anyopaque, size: c_int, flags: c_int) void;
pub extern const Xthal_have_spanning_way: u8;
pub extern const Xthal_have_identity_map: u8;
pub extern const Xthal_have_mimic_cacheattr: u8;
pub extern const Xthal_have_xlt_cacheattr: u8;
pub extern const Xthal_have_cacheattr: u8;
pub extern const Xthal_have_tlbs: u8;
pub extern const Xthal_mmu_asid_bits: u8;
pub extern const Xthal_mmu_asid_kernel: u8;
pub extern const Xthal_mmu_rings: u8;
pub extern const Xthal_mmu_ring_bits: u8;
pub extern const Xthal_mmu_sr_bits: u8;
pub extern const Xthal_mmu_ca_bits: u8;
pub extern const Xthal_mmu_max_pte_page_size: c_uint;
pub extern const Xthal_mmu_min_pte_page_size: c_uint;
pub extern const Xthal_itlb_way_bits: u8;
pub extern const Xthal_itlb_ways: u8;
pub extern const Xthal_itlb_arf_ways: u8;
pub extern const Xthal_dtlb_way_bits: u8;
pub extern const Xthal_dtlb_ways: u8;
pub extern const Xthal_dtlb_arf_ways: u8;
pub extern fn xthal_static_v2p(vaddr: c_uint, paddrp: [*c]c_uint) c_int;
pub extern fn xthal_static_p2v(paddr: c_uint, vaddrp: [*c]c_uint, cached: c_uint) c_int;
pub extern fn xthal_set_region_translation(vaddr: ?*anyopaque, paddr: ?*anyopaque, size: c_uint, cache_atr: c_uint, flags: c_uint) c_int;
pub extern fn xthal_v2p(?*anyopaque, [*c]?*anyopaque, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn xthal_invalidate_region(addr: ?*anyopaque) c_int;
pub extern fn xthal_set_region_translation_raw(vaddr: ?*anyopaque, paddr: ?*anyopaque, cattr: c_uint) c_int;
pub const xthal_MPU_entry = extern struct {
    as: u32 = std.mem.zeroes(u32),
    at: u32 = std.mem.zeroes(u32),
};
pub const Xthal_mpu_bgmap: [*c]const xthal_MPU_entry = @extern([*c]const xthal_MPU_entry, .{
    .name = "Xthal_mpu_bgmap",
});
pub extern fn xthal_is_kernel_readable(accessRights: u32) i32;
pub extern fn xthal_is_kernel_writeable(accessRights: u32) i32;
pub extern fn xthal_is_kernel_executable(accessRights: u32) i32;
pub extern fn xthal_is_user_readable(accessRights: u32) i32;
pub extern fn xthal_is_user_writeable(accessRights: u32) i32;
pub extern fn xthal_is_user_executable(accessRights: u32) i32;
pub extern fn xthal_encode_memory_type(x: u32) c_int;
pub extern fn xthal_is_cacheable(memoryType: u32) i32;
pub extern fn xthal_is_writeback(memoryType: u32) i32;
pub extern fn xthal_is_device(memoryType: u32) i32;
pub extern fn xthal_read_map(entries: [*c]xthal_MPU_entry) i32;
pub extern fn xthal_write_map(entries: [*c]const xthal_MPU_entry, n: u32) void;
pub extern fn xthal_check_map(entries: [*c]const xthal_MPU_entry, n: u32) c_int;
pub extern fn xthal_get_entry_for_address(vaddr: ?*anyopaque, infgmap: [*c]i32) xthal_MPU_entry;
pub extern fn xthal_calc_cacheadrdis(e: [*c]const xthal_MPU_entry, n: u32) u32;
pub extern fn xthal_mpu_set_region_attribute(vaddr: ?*anyopaque, size: usize, accessRights: i32, memoryType: i32, flags: u32) c_int;
pub extern fn xthal_read_background_map(entries: [*c]xthal_MPU_entry) i32;
pub extern const Xthal_cp_id_FPU: u8;
pub extern const Xthal_cp_mask_FPU: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP1_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP1_IDENT: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP2_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP2_IDENT: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP3_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP3_IDENT: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP4_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP4_IDENT: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP5_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP5_IDENT: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP6_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP6_IDENT: c_uint;
pub extern const Xthal_cp_id_XCHAL_CP7_IDENT: u8;
pub extern const Xthal_cp_mask_XCHAL_CP7_IDENT: c_uint;
pub const KernelFrame = extern struct {
    pc: c_long = std.mem.zeroes(c_long),
    ps: c_long = std.mem.zeroes(c_long),
    areg: [4]c_long = std.mem.zeroes([4]c_long),
    sar: c_long = std.mem.zeroes(c_long),
    lcount: c_long = std.mem.zeroes(c_long),
    lbeg: c_long = std.mem.zeroes(c_long),
    lend: c_long = std.mem.zeroes(c_long),
    acclo: c_long = std.mem.zeroes(c_long),
    acchi: c_long = std.mem.zeroes(c_long),
    mr: [4]c_long = std.mem.zeroes([4]c_long),
};
pub const UserFrame = extern struct {
    pc: c_long = std.mem.zeroes(c_long),
    ps: c_long = std.mem.zeroes(c_long),
    sar: c_long = std.mem.zeroes(c_long),
    vpri: c_long = std.mem.zeroes(c_long),
    a0: c_long = std.mem.zeroes(c_long),
    a2: c_long = std.mem.zeroes(c_long),
    a3: c_long = std.mem.zeroes(c_long),
    a4: c_long = std.mem.zeroes(c_long),
    a5: c_long = std.mem.zeroes(c_long),
    a6: c_long = std.mem.zeroes(c_long),
    a7: c_long = std.mem.zeroes(c_long),
    a8: c_long = std.mem.zeroes(c_long),
    a9: c_long = std.mem.zeroes(c_long),
    a10: c_long = std.mem.zeroes(c_long),
    a11: c_long = std.mem.zeroes(c_long),
    a12: c_long = std.mem.zeroes(c_long),
    a13: c_long = std.mem.zeroes(c_long),
    a14: c_long = std.mem.zeroes(c_long),
    a15: c_long = std.mem.zeroes(c_long),
    exccause: c_long = std.mem.zeroes(c_long),
    lcount: c_long = std.mem.zeroes(c_long),
    lbeg: c_long = std.mem.zeroes(c_long),
    lend: c_long = std.mem.zeroes(c_long),
    acclo: c_long = std.mem.zeroes(c_long),
    acchi: c_long = std.mem.zeroes(c_long),
    mr: [4]c_long = std.mem.zeroes([4]c_long),
    pad: [3]c_long = std.mem.zeroes([3]c_long),
};
pub const XtExcFrame = extern struct {
    exit: c_long = std.mem.zeroes(c_long),
    pc: c_long = std.mem.zeroes(c_long),
    ps: c_long = std.mem.zeroes(c_long),
    a0: c_long = std.mem.zeroes(c_long),
    a1: c_long = std.mem.zeroes(c_long),
    a2: c_long = std.mem.zeroes(c_long),
    a3: c_long = std.mem.zeroes(c_long),
    a4: c_long = std.mem.zeroes(c_long),
    a5: c_long = std.mem.zeroes(c_long),
    a6: c_long = std.mem.zeroes(c_long),
    a7: c_long = std.mem.zeroes(c_long),
    a8: c_long = std.mem.zeroes(c_long),
    a9: c_long = std.mem.zeroes(c_long),
    a10: c_long = std.mem.zeroes(c_long),
    a11: c_long = std.mem.zeroes(c_long),
    a12: c_long = std.mem.zeroes(c_long),
    a13: c_long = std.mem.zeroes(c_long),
    a14: c_long = std.mem.zeroes(c_long),
    a15: c_long = std.mem.zeroes(c_long),
    sar: c_long = std.mem.zeroes(c_long),
    exccause: c_long = std.mem.zeroes(c_long),
    excvaddr: c_long = std.mem.zeroes(c_long),
    lbeg: c_long = std.mem.zeroes(c_long),
    lend: c_long = std.mem.zeroes(c_long),
    lcount: c_long = std.mem.zeroes(c_long),
};
pub const XtSolFrame = extern struct {
    exit: c_long = std.mem.zeroes(c_long),
    pc: c_long = std.mem.zeroes(c_long),
    ps: c_long = std.mem.zeroes(c_long),
    threadptr: c_long = std.mem.zeroes(c_long),
    a12: c_long = std.mem.zeroes(c_long),
    a13: c_long = std.mem.zeroes(c_long),
    a14: c_long = std.mem.zeroes(c_long),
    a15: c_long = std.mem.zeroes(c_long),
};
pub const xt_handler = ?*const fn (?*anyopaque) callconv(.C) void;
pub const xt_exc_handler = ?*const fn ([*c]XtExcFrame) callconv(.C) void;
pub extern fn xt_set_exception_handler(n: c_int, f: xt_exc_handler) xt_exc_handler;
pub extern fn xt_set_interrupt_handler(n: c_int, f: xt_handler, arg: ?*anyopaque) xt_handler;
pub extern fn xt_ints_on(mask: c_uint) void;
pub extern fn xt_ints_off(mask: c_uint) void;
pub fn xt_set_intset(arg_arg: c_uint) callconv(.C) void {
    var arg = arg_arg;
    _ = &arg;
    xthal_set_intset(arg);
}
pub fn xt_set_intclear(arg_arg: c_uint) callconv(.C) void {
    var arg = arg_arg;
    _ = &arg;
    xthal_set_intclear(arg);
}
pub extern fn xt_get_interrupt_handler_arg(n: c_int) ?*anyopaque;
pub extern fn xt_int_has_handler(intr: c_int, cpu: c_int) bool;
pub const XtosCoreState = extern struct {
    signature: c_long = std.mem.zeroes(c_long),
    restore_label: c_long = std.mem.zeroes(c_long),
    aftersave_label: c_long = std.mem.zeroes(c_long),
    areg: [64]c_long = std.mem.zeroes([64]c_long),
    caller_regs: [16]c_long = std.mem.zeroes([16]c_long),
    caller_regs_saved: c_long = std.mem.zeroes(c_long),
    windowbase: c_long = std.mem.zeroes(c_long),
    windowstart: c_long = std.mem.zeroes(c_long),
    sar: c_long = std.mem.zeroes(c_long),
    epc1: c_long = std.mem.zeroes(c_long),
    ps: c_long = std.mem.zeroes(c_long),
    excsave1: c_long = std.mem.zeroes(c_long),
    depc: c_long = std.mem.zeroes(c_long),
    epc: [6]c_long = std.mem.zeroes([6]c_long),
    eps: [6]c_long = std.mem.zeroes([6]c_long),
    excsave: [6]c_long = std.mem.zeroes([6]c_long),
    lcount: c_long = std.mem.zeroes(c_long),
    lbeg: c_long = std.mem.zeroes(c_long),
    lend: c_long = std.mem.zeroes(c_long),
    vecbase: c_long = std.mem.zeroes(c_long),
    atomctl: c_long = std.mem.zeroes(c_long),
    memctl: c_long = std.mem.zeroes(c_long),
    ccount: c_long = std.mem.zeroes(c_long),
    ccompare: [3]c_long = std.mem.zeroes([3]c_long),
    intenable: c_long = std.mem.zeroes(c_long),
    interrupt: c_long = std.mem.zeroes(c_long),
    icount: c_long = std.mem.zeroes(c_long),
    icountlevel: c_long = std.mem.zeroes(c_long),
    debugcause: c_long = std.mem.zeroes(c_long),
    dbreakc: [2]c_long = std.mem.zeroes([2]c_long),
    dbreaka: [2]c_long = std.mem.zeroes([2]c_long),
    ibreaka: [2]c_long = std.mem.zeroes([2]c_long),
    ibreakenable: c_long = std.mem.zeroes(c_long),
    misc: [4]c_long = std.mem.zeroes([4]c_long),
    cpenable: c_long = std.mem.zeroes(c_long),
    tlbs: [16]c_long = std.mem.zeroes([16]c_long),
    ncp: [48]u8 align(4) = std.mem.zeroes([48]u8),
    cp0: [72]u8 align(4) = std.mem.zeroes([72]u8),
};
pub const _xtos_handler_func = fn () callconv(.C) void;
pub const _xtos_handler = ?*const _xtos_handler_func;
pub extern fn _xtos_ints_off(mask: c_uint) c_uint;
pub extern fn _xtos_ints_on(mask: c_uint) c_uint;
pub fn _xtos_interrupt_enable(arg_intnum: c_uint) callconv(.C) void {
    var intnum = arg_intnum;
    _ = &intnum;
    _ = _xtos_ints_on(@as(c_uint, 1) << @intCast(intnum));
}
pub fn _xtos_interrupt_disable(arg_intnum: c_uint) callconv(.C) void {
    var intnum = arg_intnum;
    _ = &intnum;
    _ = _xtos_ints_off(@as(c_uint, 1) << @intCast(intnum));
}
pub extern fn _xtos_set_intlevel(intlevel: c_int) c_uint;
pub extern fn _xtos_set_min_intlevel(intlevel: c_int) c_uint;
pub extern fn _xtos_restore_intlevel(restoreval: c_uint) c_uint;
pub extern fn _xtos_restore_just_intlevel(restoreval: c_uint) c_uint;
pub extern fn _xtos_set_interrupt_handler(n: c_int, f: _xtos_handler) _xtos_handler;
pub extern fn _xtos_set_interrupt_handler_arg(n: c_int, f: _xtos_handler, arg: ?*anyopaque) _xtos_handler;
pub extern fn _xtos_set_exception_handler(n: c_int, f: _xtos_handler) _xtos_handler;
pub extern fn _xtos_memep_initrams() void;
pub extern fn _xtos_memep_enable(flags: c_int) void;
pub extern fn _xtos_dispatch_level1_interrupts() void;
pub extern fn _xtos_dispatch_level2_interrupts() void;
pub extern fn _xtos_dispatch_level3_interrupts() void;
pub extern fn _xtos_dispatch_level4_interrupts() void;
pub extern fn _xtos_dispatch_level5_interrupts() void;
pub extern fn _xtos_dispatch_level6_interrupts() void;
pub extern fn _xtos_read_ints() c_uint;
pub extern fn _xtos_clear_ints(mask: c_uint) void;
pub extern fn _xtos_core_shutoff(flags: c_uint) c_int;
pub extern fn _xtos_core_save(flags: c_uint, savearea: [*c]XtosCoreState, code: ?*anyopaque) c_int;
pub extern fn _xtos_core_restore(retvalue: c_uint, savearea: [*c]XtosCoreState) void;
pub extern fn _xtos_timer_0_delta(cycles: c_int) void;
pub extern fn _xtos_timer_1_delta(cycles: c_int) void;
pub extern fn _xtos_timer_2_delta(cycles: c_int) void; // esp-idf/components/xtensa/include/xt_utils.h:37:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:28:50: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_get_core_id() u32; // esp-idf/components/xtensa/include/xt_utils.h:52:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:47:50: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_get_raw_core_id() u32; // esp-idf/components/xtensa/include/xt_utils.h:64:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:61:25: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_get_sp() ?*anyopaque; // esp-idf/components/xtensa/include/xt_instr_macros.h:11:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:68:28: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_get_cycle_count() u32; // esp-idf/components/xtensa/include/xt_instr_macros.h:12:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:75:20: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_set_cycle_count(arg_ccount: u32) callconv(.C) void; // esp-idf/components/xtensa/include/xt_utils.h:82:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:80:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_wait_for_intr() void; // esp-idf/components/xtensa/include/xt_utils.h:95:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:93:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_set_vecbase(arg_vecbase: u32) void; // esp-idf/components/xtensa/include/xt_instr_macros.h:11:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:100:28: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_intr_get_enabled_mask() u32; // esp-idf/components/xtensa/include/xt_instr_macros.h:12:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:117:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_set_breakpoint(arg_bp_num: c_int, arg_bp_addr: u32) void; // esp-idf/components/xtensa/include/xt_instr_macros.h:11:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:132:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_clear_breakpoint(arg_bp_num: c_int) void; // esp-idf/components/xtensa/include/xt_utils.h:156:35: warning: TODO implement function '__builtin_ffsll' in std.zig.c_builtins
// esp-idf/components/xtensa/include/xt_utils.h:148:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_set_watchpoint(arg_wp_num: c_int, arg_wp_addr: u32, arg_size: usize, arg_on_read: bool, arg_on_write: bool) void; // esp-idf/components/xtensa/include/xt_instr_macros.h:12:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:174:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_clear_watchpoint(arg_wp_num: c_int) void; // esp-idf/components/xtensa/include/xt_instr_macros.h:15:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:188:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_dbgr_is_attached() bool; // esp-idf/components/xtensa/include/xt_utils.h:198:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:196:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_dbgr_break() void; // esp-idf/components/xtensa/include/xt_utils.h:216:5: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/xtensa/include/xt_utils.h:205:24: warning: unable to translate function, demoted to extern
pub extern fn xt_utils_compare_and_set(arg_addr: [*c]volatile u32, arg_compare_value: u32, arg_new_value: u32) bool;
pub const intr_handler_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub const intr_handle_data_t = opaque {};
pub const intr_handle_t = ?*intr_handle_data_t;
pub const esp_intr_cpu_affinity_t = enum(c_uint) {
    ESP_INTR_CPU_AFFINITY_AUTO = 0,
    ESP_INTR_CPU_AFFINITY_0 = 1,
    ESP_INTR_CPU_AFFINITY_1 = 2,
};
pub extern fn esp_intr_mark_shared(intno: c_int, cpu: c_int, is_in_iram: bool) esp_err_t;
pub extern fn esp_intr_reserve(intno: c_int, cpu: c_int) esp_err_t;
pub extern fn esp_intr_alloc(source: c_int, flags: c_int, handler: intr_handler_t, arg: ?*anyopaque, ret_handle: [*c]intr_handle_t) esp_err_t;
pub extern fn esp_intr_alloc_intrstatus(source: c_int, flags: c_int, intrstatusreg: u32, intrstatusmask: u32, handler: intr_handler_t, arg: ?*anyopaque, ret_handle: [*c]intr_handle_t) esp_err_t;
pub extern fn esp_intr_free(handle: intr_handle_t) esp_err_t;
pub extern fn esp_intr_get_cpu(handle: intr_handle_t) c_int;
pub extern fn esp_intr_get_intno(handle: intr_handle_t) c_int;
pub extern fn esp_intr_disable(handle: intr_handle_t) esp_err_t;
pub extern fn esp_intr_enable(handle: intr_handle_t) esp_err_t;
pub extern fn esp_intr_set_in_iram(handle: intr_handle_t, is_in_iram: bool) esp_err_t;
pub extern fn esp_intr_noniram_disable() void;
pub extern fn esp_intr_noniram_enable() void;
pub extern fn esp_intr_enable_source(inum: c_int) void;
pub extern fn esp_intr_disable_source(inum: c_int) void;
// esp-idf/components/esp_hw_support/include/esp_intr_alloc.h:300:12: warning: TODO implement function '__builtin_ffs' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/esp_intr_alloc.h:298:19: warning: unable to translate function, demoted to extern
pub extern fn esp_intr_flags_to_level(arg_flags: c_int) callconv(.C) c_int;
pub fn esp_intr_level_to_flags(level: c_int) callconv(.C) c_int {
    return if (level > @as(c_int, 0)) (@as(c_int, 1) << @intCast(level)) & (((((((@as(c_int, 1) << @intCast(1)) | (@as(c_int, 1) << @intCast(2))) | (@as(c_int, 1) << @intCast(3))) | (@as(c_int, 1) << @intCast(4))) | (@as(c_int, 1) << @intCast(5))) | (@as(c_int, 1) << @intCast(6))) | (@as(c_int, 1) << @intCast(7))) else @as(c_int, 0);
}
pub extern fn esp_intr_dump(stream: std.c.FILE) esp_err_t;
pub const esp_cpu_cycle_count_t = u32;
pub const esp_cpu_intr_type_t = enum(c_uint) {
    ESP_CPU_INTR_TYPE_LEVEL = 0,
    ESP_CPU_INTR_TYPE_EDGE = 1,
    ESP_CPU_INTR_TYPE_NA = 2,
};
pub const esp_cpu_intr_desc_t = extern struct {
    priority: c_int = std.mem.zeroes(c_int),
    type: esp_cpu_intr_type_t = std.mem.zeroes(esp_cpu_intr_type_t),
    flags: u32 = std.mem.zeroes(u32),
};
pub const esp_cpu_intr_handler_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub const esp_cpu_watchpoint_trigger_t = enum(c_uint) {
    ESP_CPU_WATCHPOINT_LOAD = 0,
    ESP_CPU_WATCHPOINT_STORE = 1,
    ESP_CPU_WATCHPOINT_ACCESS = 2,
};
pub extern fn esp_cpu_stall(core_id: c_int) void;
pub extern fn esp_cpu_unstall(core_id: c_int) void;
pub extern fn esp_cpu_reset(core_id: c_int) void;
pub extern fn esp_cpu_wait_for_intr() void;
pub inline fn esp_cpu_get_core_id() c_int {
    return @as(c_int, @bitCast(xt_utils_get_core_id()));
}
pub inline fn esp_cpu_get_sp() ?*anyopaque {
    return xt_utils_get_sp();
}
pub inline fn esp_cpu_get_cycle_count() esp_cpu_cycle_count_t {
    return @as(esp_cpu_cycle_count_t, @bitCast(xt_utils_get_cycle_count()));
}
pub inline fn esp_cpu_set_cycle_count(arg_cycle_count: esp_cpu_cycle_count_t) void {
    var cycle_count = arg_cycle_count;
    _ = &cycle_count;
    xt_utils_set_cycle_count(@as(u32, @bitCast(cycle_count)));
}
pub inline fn esp_cpu_pc_to_addr(arg_pc: u32) ?*anyopaque {
    var pc = arg_pc;
    _ = &pc;
    return @as(?*anyopaque, @ptrFromInt((pc & @as(c_uint, 1073741823)) | @as(c_uint, 1073741824)));
}
pub extern fn esp_cpu_intr_get_desc(core_id: c_int, intr_num: c_int, intr_desc_ret: [*c]esp_cpu_intr_desc_t) void;
pub inline fn esp_cpu_intr_set_ivt_addr(arg_ivt_addr: ?*const anyopaque) void {
    var ivt_addr = arg_ivt_addr;
    _ = &ivt_addr;
    xt_utils_set_vecbase(@as(u32, @intCast(@intFromPtr(ivt_addr))));
}
// esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/esp_cpu.h:324:24: warning: unable to translate function, demoted to extern
pub extern fn esp_cpu_intr_has_handler(arg_intr_num: c_int) bool;
// esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/esp_cpu.h:348:24: warning: unable to translate function, demoted to extern
pub extern fn esp_cpu_intr_set_handler(arg_intr_num: c_int, arg_handler: esp_cpu_intr_handler_t, arg_handler_arg: ?*anyopaque) void; // esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/esp_cpu.h:366:25: warning: unable to translate function, demoted to extern
pub extern fn esp_cpu_intr_get_handler_arg(arg_intr_num: c_int) ?*anyopaque;
pub inline fn esp_cpu_intr_enable(intr_mask: u32) void {
    xt_ints_on(intr_mask);
}
pub inline fn esp_cpu_intr_disable(intr_mask: u32) void {
    xt_ints_off(intr_mask);
}
pub inline fn esp_cpu_intr_get_enabled_mask() u32 {
    return xt_utils_intr_get_enabled_mask();
} // esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/esp_cpu.h:427:24: warning: unable to translate function, demoted to extern
pub extern fn esp_cpu_intr_edge_ack(arg_intr_num: c_int) void;
pub extern fn esp_cpu_configure_region_protection() void;
pub extern fn esp_cpu_set_breakpoint(bp_num: c_int, bp_addr: ?*const anyopaque) esp_err_t;
pub extern fn esp_cpu_clear_breakpoint(bp_num: c_int) esp_err_t;
pub extern fn esp_cpu_set_watchpoint(wp_num: c_int, wp_addr: ?*const anyopaque, size: usize, trigger: esp_cpu_watchpoint_trigger_t) esp_err_t;
pub extern fn esp_cpu_clear_watchpoint(wp_num: c_int) esp_err_t;
pub inline fn esp_cpu_dbgr_is_attached() bool {
    return xt_utils_dbgr_is_attached();
}
pub inline fn esp_cpu_dbgr_break() void {
    xt_utils_dbgr_break();
}
pub inline fn esp_cpu_get_call_addr(return_address: isize) isize {
    return return_address - @as(c_int, 3);
}
pub extern fn esp_cpu_compare_and_set(addr: [*c]volatile u32, compare_value: u32, new_value: u32) bool;
pub const esp_backtrace_frame_t = extern struct {
    pc: u32 = std.mem.zeroes(u32),
    sp: u32 = std.mem.zeroes(u32),
    next_pc: u32 = std.mem.zeroes(u32),
    exc_frame: ?*const anyopaque = std.mem.zeroes(?*const anyopaque),
};
pub extern fn esp_set_breakpoint_if_jtag(@"fn": ?*anyopaque) void;
pub extern fn esp_backtrace_get_start(pc: [*c]u32, sp: [*c]u32, next_pc: [*c]u32) void;
pub extern fn esp_backtrace_get_next_frame(frame: [*c]esp_backtrace_frame_t) bool;
pub extern fn esp_backtrace_print_from_frame(depth: c_int, frame: [*c]const esp_backtrace_frame_t, panic: bool) esp_err_t;
pub extern fn esp_backtrace_print(depth: c_int) esp_err_t;
pub extern fn esp_backtrace_print_all_tasks(depth: c_int) esp_err_t;
pub fn esp_set_watchpoint(arg_no: c_int, arg_adr: ?*anyopaque, arg_size: c_int, arg_flags: c_int) callconv(.C) esp_err_t {
    var no = arg_no;
    _ = &no;
    var adr = arg_adr;
    _ = &adr;
    var size = arg_size;
    _ = &size;
    var flags = arg_flags;
    _ = &flags;
    return esp_cpu_set_watchpoint(no, adr, @as(usize, @bitCast(size)), @as(c_uint, @bitCast(flags)));
}
pub fn esp_clear_watchpoint(arg_no: c_int) callconv(.C) void {
    var no = arg_no;
    _ = &no;
    _ = esp_cpu_clear_watchpoint(no);
}

pub const touch_pad_t = enum(c_uint) {
    TOUCH_PAD_NUM0 = 0,
    TOUCH_PAD_NUM1 = 1,
    TOUCH_PAD_NUM2 = 2,
    TOUCH_PAD_NUM3 = 3,
    TOUCH_PAD_NUM4 = 4,
    TOUCH_PAD_NUM5 = 5,
    TOUCH_PAD_NUM6 = 6,
    TOUCH_PAD_NUM7 = 7,
    TOUCH_PAD_NUM8 = 8,
    TOUCH_PAD_NUM9 = 9,
    TOUCH_PAD_MAX = 10,
};
pub const touch_high_volt_t = enum(c_int) {
    TOUCH_HVOLT_KEEP = -1,
    TOUCH_HVOLT_2V4 = 0,
    TOUCH_HVOLT_2V5 = 1,
    TOUCH_HVOLT_2V6 = 2,
    TOUCH_HVOLT_2V7 = 3,
    TOUCH_HVOLT_MAX = 4,
};
pub const touch_low_volt_t = enum(c_int) {
    TOUCH_LVOLT_KEEP = -1,
    TOUCH_LVOLT_0V5 = 0,
    TOUCH_LVOLT_0V6 = 1,
    TOUCH_LVOLT_0V7 = 2,
    TOUCH_LVOLT_0V8 = 3,
    TOUCH_LVOLT_MAX = 4,
};
pub const touch_volt_atten_t = enum(c_int) {
    TOUCH_HVOLT_ATTEN_KEEP = -1,
    TOUCH_HVOLT_ATTEN_1V5 = 0,
    TOUCH_HVOLT_ATTEN_1V = 1,
    TOUCH_HVOLT_ATTEN_0V5 = 2,
    TOUCH_HVOLT_ATTEN_0V = 3,
    TOUCH_HVOLT_ATTEN_MAX = 4,
};
pub const touch_cnt_slope_t = enum(c_uint) {
    TOUCH_PAD_SLOPE_0 = 0,
    TOUCH_PAD_SLOPE_1 = 1,
    TOUCH_PAD_SLOPE_2 = 2,
    TOUCH_PAD_SLOPE_3 = 3,
    TOUCH_PAD_SLOPE_4 = 4,
    TOUCH_PAD_SLOPE_5 = 5,
    TOUCH_PAD_SLOPE_6 = 6,
    TOUCH_PAD_SLOPE_7 = 7,
    TOUCH_PAD_SLOPE_MAX = 8,
};

pub const touch_tie_opt_t = enum(c_uint) {
    TOUCH_PAD_TIE_OPT_LOW = 0,
    TOUCH_PAD_TIE_OPT_HIGH = 1,
    TOUCH_PAD_TIE_OPT_MAX = 2,
};
pub const touch_fsm_mode_t = enum(c_uint) {
    TOUCH_FSM_MODE_TIMER = 0,
    TOUCH_FSM_MODE_SW = 1,
    TOUCH_FSM_MODE_MAX = 2,
};
pub const touch_trigger_mode_t = enum(c_uint) {
    TOUCH_TRIGGER_BELOW = 0,
    TOUCH_TRIGGER_ABOVE = 1,
    TOUCH_TRIGGER_MAX = 2,
};
pub const touch_trigger_src_t = enum(c_uint) {
    TOUCH_TRIGGER_SOURCE_BOTH = 0,
    TOUCH_TRIGGER_SOURCE_SET1 = 1,
    TOUCH_TRIGGER_SOURCE_MAX = 2,
};
pub const gpio_num_t = enum(c_int) {
    GPIO_NUM_NC = -1,
    GPIO_NUM_0 = 0,
    GPIO_NUM_1 = 1,
    GPIO_NUM_2 = 2,
    GPIO_NUM_3 = 3,
    GPIO_NUM_4 = 4,
    GPIO_NUM_5 = 5,
    GPIO_NUM_6 = 6,
    GPIO_NUM_7 = 7,
    GPIO_NUM_8 = 8,
    GPIO_NUM_9 = 9,
    GPIO_NUM_10 = 10,
    GPIO_NUM_11 = 11,
    GPIO_NUM_12 = 12,
    GPIO_NUM_13 = 13,
    GPIO_NUM_14 = 14,
    GPIO_NUM_15 = 15,
    GPIO_NUM_16 = 16,
    GPIO_NUM_17 = 17,
    GPIO_NUM_18 = 18,
    GPIO_NUM_19 = 19,
    GPIO_NUM_20 = 20,
    GPIO_NUM_21 = 21,
    GPIO_NUM_22 = 22,
    GPIO_NUM_23 = 23,
    GPIO_NUM_25 = 25,
    GPIO_NUM_26 = 26,
    GPIO_NUM_27 = 27,
    GPIO_NUM_28 = 28,
    GPIO_NUM_29 = 29,
    GPIO_NUM_30 = 30,
    GPIO_NUM_31 = 31,
    GPIO_NUM_32 = 32,
    GPIO_NUM_33 = 33,
    GPIO_NUM_34 = 34,
    GPIO_NUM_35 = 35,
    GPIO_NUM_36 = 36,
    GPIO_NUM_37 = 37,
    GPIO_NUM_38 = 38,
    GPIO_NUM_39 = 39,
    GPIO_NUM_MAX = 40,
};
pub const gpio_port_t = enum(c_uint) {
    GPIO_PORT_0 = 0,
    GPIO_PORT_MAX = 1,
};
pub const gpio_int_type_t = enum(c_uint) {
    GPIO_INTR_DISABLE = 0,
    GPIO_INTR_POSEDGE = 1,
    GPIO_INTR_NEGEDGE = 2,
    GPIO_INTR_ANYEDGE = 3,
    GPIO_INTR_LOW_LEVEL = 4,
    GPIO_INTR_HIGH_LEVEL = 5,
    GPIO_INTR_MAX = 6,
};
pub const gpio_mode_t = enum(c_uint) {
    GPIO_MODE_DISABLE = 0,
    GPIO_MODE_INPUT = 1,
    GPIO_MODE_OUTPUT = 2,
    GPIO_MODE_OUTPUT_OD = 6,
    GPIO_MODE_INPUT_OUTPUT_OD = 7,
    GPIO_MODE_INPUT_OUTPUT = 3,
};
pub const gpio_pullup_t = enum(c_uint) {
    GPIO_PULLUP_DISABLE = 0,
    GPIO_PULLUP_ENABLE = 1,
};
pub const gpio_pulldown_t = enum(c_uint) {
    GPIO_PULLDOWN_DISABLE = 0,
    GPIO_PULLDOWN_ENABLE = 1,
};
pub const gpio_pull_mode_t = enum(c_uint) {
    GPIO_PULLUP_ONLY = 0,
    GPIO_PULLDOWN_ONLY = 1,
    GPIO_PULLUP_PULLDOWN = 2,
    GPIO_FLOATING = 3,
};
pub const gpio_drive_cap_t = enum(c_uint) {
    GPIO_DRIVE_CAP_0 = 0,
    GPIO_DRIVE_CAP_1 = 1,
    GPIO_DRIVE_CAP_2 = 2,
    GPIO_DRIVE_CAP_DEFAULT = 2,
    GPIO_DRIVE_CAP_3 = 3,
    GPIO_DRIVE_CAP_MAX = 4,
};
pub const esp_deep_sleep_cb_t = ?*const fn () callconv(.C) void;
pub const esp_sleep_ext1_wakeup_mode_t = enum(c_uint) {
    ESP_EXT1_WAKEUP_ALL_LOW = 0,
    ESP_EXT1_WAKEUP_ANY_HIGH = 1,
};
pub const esp_sleep_pd_domain_t = enum(c_uint) {
    ESP_PD_DOMAIN_RTC_PERIPH = 0,
    ESP_PD_DOMAIN_RTC_SLOW_MEM = 1,
    ESP_PD_DOMAIN_RTC_FAST_MEM = 2,
    ESP_PD_DOMAIN_XTAL = 3,
    ESP_PD_DOMAIN_RC_FAST = 4,
    ESP_PD_DOMAIN_VDDSDIO = 5,
    ESP_PD_DOMAIN_MODEM = 6,
    ESP_PD_DOMAIN_MAX = 7,
};
pub const esp_sleep_pd_option_t = enum(c_uint) {
    ESP_PD_OPTION_OFF = 0,
    ESP_PD_OPTION_ON = 1,
    ESP_PD_OPTION_AUTO = 2,
};
pub const esp_sleep_source_t = enum(c_uint) {
    ESP_SLEEP_WAKEUP_UNDEFINED = 0,
    ESP_SLEEP_WAKEUP_ALL = 1,
    ESP_SLEEP_WAKEUP_EXT0 = 2,
    ESP_SLEEP_WAKEUP_EXT1 = 3,
    ESP_SLEEP_WAKEUP_TIMER = 4,
    ESP_SLEEP_WAKEUP_TOUCHPAD = 5,
    ESP_SLEEP_WAKEUP_ULP = 6,
    ESP_SLEEP_WAKEUP_GPIO = 7,
    ESP_SLEEP_WAKEUP_UART = 8,
    ESP_SLEEP_WAKEUP_WIFI = 9,
    ESP_SLEEP_WAKEUP_COCPU = 10,
    ESP_SLEEP_WAKEUP_COCPU_TRAP_TRIG = 11,
    ESP_SLEEP_WAKEUP_BT = 12,
};
pub const esp_sleep_mode_t = enum(c_uint) {
    ESP_SLEEP_MODE_LIGHT_SLEEP = 0,
    ESP_SLEEP_MODE_DEEP_SLEEP = 1,
};
pub const esp_sleep_wakeup_cause_t = esp_sleep_source_t;
const enum_unnamed_3 = enum(c_uint) {
    ESP_ERR_SLEEP_REJECT = 259,
    ESP_ERR_SLEEP_TOO_SHORT_SLEEP_DURATION = 258,
};
pub extern fn esp_sleep_disable_wakeup_source(source: esp_sleep_source_t) esp_err_t;
pub extern fn esp_sleep_enable_ulp_wakeup() esp_err_t;
pub extern fn esp_sleep_enable_timer_wakeup(time_in_us: u64) esp_err_t;
pub extern fn esp_sleep_enable_touchpad_wakeup() esp_err_t;
pub extern fn esp_sleep_get_touchpad_wakeup_status() touch_pad_t;
pub extern fn esp_sleep_is_valid_wakeup_gpio(gpio_num: gpio_num_t) bool;
pub extern fn esp_sleep_enable_ext0_wakeup(gpio_num: gpio_num_t, level: c_int) esp_err_t;
pub extern fn esp_sleep_enable_ext1_wakeup(io_mask: u64, level_mode: esp_sleep_ext1_wakeup_mode_t) esp_err_t;
pub extern fn esp_sleep_enable_ext1_wakeup_io(io_mask: u64, level_mode: esp_sleep_ext1_wakeup_mode_t) esp_err_t;
pub extern fn esp_sleep_disable_ext1_wakeup_io(io_mask: u64) esp_err_t;
pub extern fn esp_sleep_enable_gpio_wakeup() esp_err_t;
pub extern fn esp_sleep_enable_uart_wakeup(uart_num: c_int) esp_err_t;
pub extern fn esp_sleep_enable_bt_wakeup() esp_err_t;
pub extern fn esp_sleep_disable_bt_wakeup() esp_err_t;
pub extern fn esp_sleep_enable_wifi_wakeup() esp_err_t;
pub extern fn esp_sleep_disable_wifi_wakeup() esp_err_t;
pub extern fn esp_sleep_enable_wifi_beacon_wakeup() esp_err_t;
pub extern fn esp_sleep_disable_wifi_beacon_wakeup() esp_err_t;
pub extern fn esp_sleep_get_ext1_wakeup_status() u64;
pub extern fn esp_sleep_pd_config(domain: esp_sleep_pd_domain_t, option: esp_sleep_pd_option_t) esp_err_t;
pub extern fn esp_deep_sleep_try_to_start() esp_err_t;
pub extern fn esp_deep_sleep_start() noreturn;
pub extern fn esp_light_sleep_start() esp_err_t;
pub extern fn esp_deep_sleep_try(time_in_us: u64) esp_err_t;
pub extern fn esp_deep_sleep(time_in_us: u64) noreturn;
pub extern fn esp_deep_sleep_register_hook(new_dslp_cb: esp_deep_sleep_cb_t) esp_err_t;
pub extern fn esp_deep_sleep_deregister_hook(old_dslp_cb: esp_deep_sleep_cb_t) void;
pub extern fn esp_sleep_get_wakeup_cause() esp_sleep_wakeup_cause_t;
pub extern fn esp_wake_deep_sleep() void;
pub const esp_deep_sleep_wake_stub_fn_t = ?*const fn () callconv(.C) void;
pub extern fn esp_set_deep_sleep_wake_stub(new_stub: esp_deep_sleep_wake_stub_fn_t) void;
pub extern fn esp_set_deep_sleep_wake_stub_default_entry() void;
pub extern fn esp_get_deep_sleep_wake_stub() esp_deep_sleep_wake_stub_fn_t;
pub extern fn esp_default_wake_deep_sleep() void;
pub extern fn esp_deep_sleep_disable_rom_logging() void;
pub extern fn esp_sleep_config_gpio_isolate() void;
pub extern fn esp_sleep_enable_gpio_switch(enable: bool) void;
pub const TaskFunction_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub const spinlock_t = extern struct {
    owner: u32 = std.mem.zeroes(u32),
    count: u32 = std.mem.zeroes(u32),
}; // esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/spinlock.h:51:51: warning: unable to translate function, demoted to extern
pub extern fn spinlock_initialize(arg_lock: [*c]spinlock_t) void; // esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/spinlock.h:74:51: warning: unable to translate function, demoted to extern
pub extern fn spinlock_acquire(arg_lock: [*c]spinlock_t, arg_timeout: i32) bool; // esp-idf/components/newlib/platform_include/assert.h:30:23: warning: TODO implement function '__builtin_strrchr' in std.zig.c_builtins
// esp-idf/components/esp_hw_support/include/spinlock.h:172:51: warning: unable to translate function, demoted to extern
pub extern fn spinlock_release(arg_lock: [*c]spinlock_t) void;
pub extern fn esp_crosscore_int_init() void;
pub extern fn esp_crosscore_int_send_yield(core_id: c_int) void;
pub extern fn esp_crosscore_int_send_freq_switch(core_id: c_int) void;
pub extern fn esp_crosscore_int_send_gdb_call(core_id: c_int) void;
pub extern fn esp_crosscore_int_send_print_backtrace(core_id: c_int) void;
pub extern fn esp_crosscore_int_send_twdt_abort(core_id: c_int) void; // /.espressif/tools/xtensa-esp-elf/esp-13.2.0_20230928/xtensa-esp-elf/xtensa-esp-elf/include/assert.h:45:24: warning: ignoring StaticAssert declaration
// /.espressif/tools/xtensa-esp-elf/esp-13.2.0_20230928/xtensa-esp-elf/xtensa-esp-elf/include/assert.h:45:24: warning: ignoring StaticAssert declaration
pub inline fn esp_dram_match_iram() bool {
    return (@as(c_int, 1073405952) == @as(c_int, 1074266112)) and (@as(c_int, 1073741824) == @as(c_int, 1074438144));
}
pub inline fn esp_ptr_in_iram(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1074266112)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1074438144));
}
pub inline fn esp_ptr_in_dram(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1073405952)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1073741824));
}
pub inline fn esp_ptr_in_diram_dram(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1073610752)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1073741824));
}
pub inline fn esp_ptr_in_diram_iram(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1074397184)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1074528256));
}
pub inline fn esp_ptr_in_rtc_iram_fast(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1074528256)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1074536448));
}
pub inline fn esp_ptr_in_rtc_dram_fast(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1073217536)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1073225728));
}
pub inline fn esp_ptr_in_rtc_slow(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1342177280)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1342185472));
}
pub inline fn esp_ptr_diram_dram_to_iram(arg_p: ?*const anyopaque) ?*anyopaque {
    var p = arg_p;
    _ = &p;
    return @as(?*anyopaque, @ptrFromInt((@as(c_int, 1074397184) + (@as(c_int, 1073741824) - @as(isize, @intCast(@intFromPtr(p))))) - @as(c_int, 4)));
}
pub inline fn esp_ptr_diram_iram_to_dram(arg_p: ?*const anyopaque) ?*anyopaque {
    var p = arg_p;
    _ = &p;
    return @as(?*anyopaque, @ptrFromInt((@as(c_int, 1073610752) + (@as(c_int, 1074528256) - @as(isize, @intCast(@intFromPtr(p))))) - @as(c_int, 4)));
}
pub inline fn esp_ptr_dma_capable(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1073405952)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1073741824));
}
pub extern fn esp_ptr_dma_ext_capable(p: ?*const anyopaque) bool;
pub inline fn esp_ptr_word_aligned(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    return std.zig.c_translation.signedRemainder(@as(isize, @intCast(@intFromPtr(p))), @as(c_int, 4)) == @as(c_int, 0);
}
pub inline fn esp_ptr_executable(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    var ip: isize = @as(isize, @intCast(@intFromPtr(p)));
    _ = &ip;
    return ((((ip >= @as(c_int, 1074593792)) and (ip < @as(c_int, 1077936128))) or ((ip >= @as(c_int, 1074266112)) and (ip < @as(c_int, 1074438144)))) or ((ip >= @as(c_int, 1073741824)) and (ip < @as(c_int, 1074200576)))) or ((ip >= @as(c_int, 1074528256)) and (ip < @as(c_int, 1074536448)));
}
pub extern fn esp_ptr_byte_accessible(p: ?*const anyopaque) bool;
pub inline fn esp_ptr_internal(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    var r: bool = undefined;
    _ = &r;
    r = (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1073283072)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1074536448));
    r |= @as(bool, (@as(isize, @intCast(@intFromPtr(p))) >= @as(c_int, 1342177280)) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1342185472)));
    return r;
}
pub extern fn esp_ptr_external_ram(p: ?*const anyopaque) bool;
pub inline fn esp_ptr_in_drom(arg_p: ?*const anyopaque) bool {
    var p = arg_p;
    _ = &p;
    var drom_start_addr: i32 = 1061158912;
    _ = &drom_start_addr;
    return (@as(isize, @intCast(@intFromPtr(p))) >= drom_start_addr) and (@as(isize, @intCast(@intFromPtr(p))) < @as(c_int, 1065353216));
}
pub inline fn esp_stack_ptr_in_dram(sp: u32) bool {
    return !(((sp < @as(u32, @bitCast(@as(c_int, 1073405952) + @as(c_int, 16)))) or (sp > @as(u32, @bitCast(@as(c_int, 1073741824) - @as(c_int, 16))))) or ((sp & @as(u32, @bitCast(@as(c_int, 15)))) != @as(u32, @bitCast(@as(c_int, 0)))));
}
pub inline fn esp_stack_ptr_is_sane(sp: u32) bool {
    return esp_stack_ptr_in_dram(sp);
}
pub extern fn esp_newlib_time_init() void;
pub const _reent = opaque {};
pub extern fn esp_reent_init(r: ?*_reent) void;
pub extern fn esp_newlib_init_global_stdio(stdio_dev: [*:0]const u8) void;
pub extern fn esp_reent_cleanup() void;
pub extern fn esp_newlib_init() void;
pub extern fn esp_setup_syscall_table() void;
pub extern fn esp_set_time_from_rtc() void;
pub extern fn esp_sync_timekeeping_timers() void;
pub extern fn esp_newlib_locks_init() void;
pub const multi_heap_info = extern struct {
    lock: ?*anyopaque = null,
    free_bytes: usize = std.mem.zeroes(usize),
    minimum_free_bytes: usize = std.mem.zeroes(usize),
    pool_size: usize = std.mem.zeroes(usize),
    heap_data: ?*anyopaque = null,
};
pub const multi_heap_handle_t = ?*multi_heap_info;
pub extern fn multi_heap_aligned_alloc(heap: multi_heap_handle_t, size: usize, alignment: usize) ?*anyopaque;
pub extern fn multi_heap_malloc(heap: multi_heap_handle_t, size: usize) ?*anyopaque;
pub extern fn multi_heap_aligned_free(heap: multi_heap_handle_t, p: ?*anyopaque) void;
pub extern fn multi_heap_free(heap: multi_heap_handle_t, p: ?*anyopaque) void;
pub extern fn multi_heap_realloc(heap: multi_heap_handle_t, p: ?*anyopaque, size: usize) ?*anyopaque;
pub extern fn multi_heap_get_allocated_size(heap: multi_heap_handle_t, p: ?*anyopaque) usize;
pub extern fn multi_heap_register(start: ?*anyopaque, size: usize) multi_heap_handle_t;
pub extern fn multi_heap_set_lock(heap: multi_heap_handle_t, lock: ?*anyopaque) void;
pub extern fn multi_heap_dump(heap: multi_heap_handle_t) void;
pub extern fn multi_heap_check(heap: multi_heap_handle_t, print_errors: bool) bool;
pub extern fn multi_heap_free_size(heap: multi_heap_handle_t) usize;
pub extern fn multi_heap_minimum_free_size(heap: multi_heap_handle_t) usize;
pub const multi_heap_info_t = extern struct {
    total_free_bytes: usize = std.mem.zeroes(usize),
    total_allocated_bytes: usize = std.mem.zeroes(usize),
    largest_free_block: usize = std.mem.zeroes(usize),
    minimum_free_bytes: usize = std.mem.zeroes(usize),
    allocated_blocks: usize = std.mem.zeroes(usize),
    free_blocks: usize = std.mem.zeroes(usize),
    total_blocks: usize = std.mem.zeroes(usize),
};
pub extern fn multi_heap_get_info(heap: multi_heap_handle_t, info: [*c]multi_heap_info_t) void;
pub extern fn multi_heap_aligned_alloc_offs(heap: multi_heap_handle_t, size: usize, alignment: usize, offset: usize) ?*anyopaque;
pub extern fn multi_heap_reset_minimum_free_bytes(heap: multi_heap_handle_t) usize;
pub extern fn multi_heap_restore_minimum_free_bytes(heap: multi_heap_handle_t, new_minimum_free_bytes_value: usize) void;
pub const esp_alloc_failed_hook_t = ?*const fn (usize, u32, [*:0]const u8) callconv(.C) void;
pub const Caps = enum(u32) {
    MALLOC_CAP_EXEC = (1 << 0), //< Memory must be able to run executable code
    MALLOC_CAP_32BIT = (1 << 1), //< Memory must allow for aligned 32-bit data accesses
    MALLOC_CAP_8BIT = (1 << 2), //< Memory must allow for 8/16/...-bit data accesses
    MALLOC_CAP_DMA = (1 << 3), //< Memory must be able to accessed by DMA
    MALLOC_CAP_PID2 = (1 << 4), //< Memory must be mapped to PID2 memory space (PIDs are not currently used)
    MALLOC_CAP_PID3 = (1 << 5), //< Memory must be mapped to PID3 memory space (PIDs are not currently used)
    MALLOC_CAP_PID4 = (1 << 6), //< Memory must be mapped to PID4 memory space (PIDs are not currently used)
    MALLOC_CAP_PID5 = (1 << 7), //< Memory must be mapped to PID5 memory space (PIDs are not currently used)
    MALLOC_CAP_PID6 = (1 << 8), //< Memory must be mapped to PID6 memory space (PIDs are not currently used)
    MALLOC_CAP_PID7 = (1 << 9), //< Memory must be mapped to PID7 memory space (PIDs are not currently used)
    MALLOC_CAP_SPIRAM = (1 << 10), //< Memory must be in SPI RAM
    MALLOC_CAP_INTERNAL = (1 << 11), //< Memory must be internal; specifically it should not disappear when flash/spiram cache is switched off
    MALLOC_CAP_DEFAULT = (1 << 12), //< Memory can be returned in a non-capability-specific memory allocation (e.g. malloc(), calloc()) call
    MALLOC_CAP_IRAM_8BIT = (1 << 13), //< Memory must be in IRAM and allow unaligned access
    MALLOC_CAP_RETENTION = (1 << 14), //< Memory must be able to accessed by retention DMA
    MALLOC_CAP_RTCRAM = (1 << 15), //< Memory must be in RTC fast memory
    MALLOC_CAP_TCM = (1 << 16), //< Memory must be in TCM memory

    MALLOC_CAP_INVALID = (1 << 31), //< Memory can't be used / list end marker
};
pub extern fn heap_caps_register_failed_alloc_callback(callback: esp_alloc_failed_hook_t) esp_err_t;
pub extern fn heap_caps_malloc(size: usize, caps: u32) ?*anyopaque;
pub extern fn heap_caps_free(ptr: ?*anyopaque) void;
pub extern fn heap_caps_realloc(ptr: ?*anyopaque, size: usize, caps: u32) ?*anyopaque;
pub extern fn heap_caps_aligned_alloc(alignment: usize, size: usize, caps: u32) ?*anyopaque;
pub extern fn heap_caps_aligned_free(ptr: ?*anyopaque) void;
pub extern fn heap_caps_aligned_calloc(alignment: usize, n: usize, size: usize, caps: u32) ?*anyopaque;
pub extern fn heap_caps_calloc(n: usize, size: usize, caps: u32) ?*anyopaque;
pub extern fn heap_caps_get_total_size(caps: u32) usize;
pub extern fn heap_caps_get_free_size(caps: u32) usize;
pub extern fn heap_caps_get_minimum_free_size(caps: u32) usize;
pub extern fn heap_caps_get_largest_free_block(caps: u32) usize;
pub extern fn heap_caps_monitor_local_minimum_free_size_start() esp_err_t;
pub extern fn heap_caps_monitor_local_minimum_free_size_stop() esp_err_t;
pub extern fn heap_caps_get_info(info: [*c]multi_heap_info_t, caps: u32) void;
pub extern fn heap_caps_print_heap_info(caps: u32) void;
pub extern fn heap_caps_check_integrity_all(print_errors: bool) bool;
pub extern fn heap_caps_check_integrity(caps: u32, print_errors: bool) bool;
pub extern fn heap_caps_check_integrity_addr(addr: isize, print_errors: bool) bool;
pub extern fn heap_caps_malloc_extmem_enable(limit: usize) void;
pub extern fn heap_caps_malloc_prefer(size: usize, num: usize, ...) ?*anyopaque;
pub extern fn heap_caps_realloc_prefer(ptr: ?*anyopaque, size: usize, num: usize, ...) ?*anyopaque;
pub extern fn heap_caps_calloc_prefer(n: usize, size: usize, num: usize, ...) ?*anyopaque;
pub extern fn heap_caps_dump(caps: u32) void;
pub extern fn heap_caps_dump_all() void;
pub extern fn heap_caps_get_allocated_size(ptr: ?*anyopaque) usize;
pub const StackType_t = u8;
pub const BaseType_t = c_int;
pub const UBaseType_t = c_uint;
pub const TickType_t = u32;
pub extern fn xPortInIsrContext() BaseType_t;
pub extern fn vPortAssertIfInISR() void;
pub extern fn xPortInterruptedFromISRContext() BaseType_t;
// esp-idf/components/xtensa/include/xtensa/xtruntime.h:92:4: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/freertos/FreeRTOS-Kernel/portable/xtensa/include/freertos/portmacro.h:554:58: warning: unable to translate function, demoted to extern
pub extern fn xPortSetInterruptMaskFromISR() UBaseType_t;
pub inline fn vPortClearInterruptMaskFromISR(prev_level: UBaseType_t) void {
    _ = _xtos_set_intlevel(@as(c_int, @bitCast(prev_level)));
}
pub const portMUX_TYPE = spinlock_t;
pub extern fn xPortEnterCriticalTimeout(mux: [*c]portMUX_TYPE, timeout: BaseType_t) BaseType_t;
pub inline fn vPortEnterCritical(arg_mux: [*c]portMUX_TYPE) void {
    var mux = arg_mux;
    _ = &mux;
    _ = xPortEnterCriticalTimeout(mux, -@as(c_int, 1));
}
pub extern fn vPortExitCritical(mux: [*c]portMUX_TYPE) void;
pub extern fn xPortEnterCriticalTimeoutCompliance(mux: [*c]portMUX_TYPE, timeout: BaseType_t) BaseType_t;
pub inline fn vPortEnterCriticalCompliance(arg_mux: [*c]portMUX_TYPE) void {
    var mux = arg_mux;
    _ = &mux;
    _ = xPortEnterCriticalTimeoutCompliance(mux, -@as(c_int, 1));
}
pub extern fn vPortExitCriticalCompliance(mux: [*c]portMUX_TYPE) void;
pub inline fn xPortEnterCriticalTimeoutSafe(arg_mux: [*c]portMUX_TYPE, arg_timeout: BaseType_t) BaseType_t {
    var mux = arg_mux;
    _ = &mux;
    var timeout = arg_timeout;
    _ = &timeout;
    var ret: BaseType_t = undefined;
    _ = &ret;
    if (xPortInIsrContext() != 0) {
        ret = xPortEnterCriticalTimeout(mux, timeout);
    } else {
        ret = xPortEnterCriticalTimeout(mux, timeout);
    }
    return ret;
}
pub inline fn vPortEnterCriticalSafe(arg_mux: [*c]portMUX_TYPE) void {
    var mux = arg_mux;
    _ = &mux;
    _ = xPortEnterCriticalTimeoutSafe(mux, -@as(c_int, 1));
}
pub inline fn vPortExitCriticalSafe(arg_mux: [*c]portMUX_TYPE) void {
    var mux = arg_mux;
    _ = &mux;
    if (xPortInIsrContext() != 0) {
        vPortExitCritical(mux);
    } else {
        vPortExitCritical(mux);
    }
}
pub extern fn vPortYield() void;
pub extern fn vPortYieldOtherCore(coreid: BaseType_t) void; // esp-idf/components/xtensa/include/xt_instr_macros.h:11:30: warning: TODO implement translation of stmt class GCCAsmStmtClass
// esp-idf/components/freertos/FreeRTOS-Kernel/portable/xtensa/include/freertos/portmacro.h:606:24: warning: unable to translate function, demoted to extern
pub extern fn xPortCanYield() bool;
pub extern fn vApplicationSleep(xExpectedIdleTime: TickType_t) void;
pub extern fn xPortGetTickRateHz() u32;
pub extern fn vPortSetStackWatchpoint(pxStackStart: ?*anyopaque) void;
pub inline fn xPortGetCoreID() BaseType_t {
    return @as(BaseType_t, @bitCast(esp_cpu_get_core_id()));
}
pub extern fn vPortTCBPreDeleteHook(pxTCB: ?*anyopaque) void;
pub extern fn _frxt_setup_switch() void;
pub extern fn xPortCheckValidListMem(ptr: ?*const anyopaque) bool;
pub extern fn xPortCheckValidTCBMem(ptr: ?*const anyopaque) bool;
pub extern fn xPortcheckValidStackMem(ptr: ?*const anyopaque) bool;
pub extern fn pxPortInitialiseStack(pxTopOfStack: [*c]StackType_t, pxCode: TaskFunction_t, pvParameters: ?*anyopaque) [*c]StackType_t;
pub const HeapRegion = extern struct {
    pucStartAddress: [*:0]u8 = std.mem.zeroes([*:0]u8),
    xSizeInBytes: usize = std.mem.zeroes(usize),
};
pub const HeapRegion_t = HeapRegion;
pub const xHeapStats = extern struct {
    xAvailableHeapSpaceInBytes: usize = std.mem.zeroes(usize),
    xSizeOfLargestFreeBlockInBytes: usize = std.mem.zeroes(usize),
    xSizeOfSmallestFreeBlockInBytes: usize = std.mem.zeroes(usize),
    xNumberOfFreeBlocks: usize = std.mem.zeroes(usize),
    xMinimumEverFreeBytesRemaining: usize = std.mem.zeroes(usize),
    xNumberOfSuccessfulAllocations: usize = std.mem.zeroes(usize),
    xNumberOfSuccessfulFrees: usize = std.mem.zeroes(usize),
};
pub const HeapStats_t = xHeapStats;
pub extern fn vPortDefineHeapRegions(pxHeapRegions: [*c]const HeapRegion_t) void;
pub extern fn vPortGetHeapStats(pxHeapStats: [*c]HeapStats_t) void;
pub extern fn pvPortMalloc(xSize: usize) ?*anyopaque;
pub extern fn vPortFree(pv: ?*anyopaque) void;
pub extern fn vPortInitialiseBlocks() void;
pub extern fn xPortGetFreeHeapSize() usize;
pub extern fn xPortGetMinimumEverFreeHeapSize() usize;
pub extern fn xPortStartScheduler() BaseType_t;
pub extern fn vPortEndScheduler() void;
pub const stat = opaque {};
pub const tms = opaque {};
pub const timezone = opaque {};
pub const xSTATIC_LIST_ITEM = extern struct {
    xDummy2: TickType_t = std.mem.zeroes(TickType_t),
    pvDummy3: [4]?*anyopaque = std.mem.zeroes([4]?*anyopaque),
};
pub const StaticListItem_t = xSTATIC_LIST_ITEM;
pub const xSTATIC_MINI_LIST_ITEM = extern struct {
    xDummy2: TickType_t = std.mem.zeroes(TickType_t),
    pvDummy3: [2]?*anyopaque = std.mem.zeroes([2]?*anyopaque),
};
pub const StaticMiniListItem_t = xSTATIC_MINI_LIST_ITEM;
pub const xSTATIC_LIST = extern struct {
    uxDummy2: UBaseType_t = std.mem.zeroes(UBaseType_t),
    pvDummy3: ?*anyopaque = null,
    xDummy4: StaticMiniListItem_t = std.mem.zeroes(StaticMiniListItem_t),
};
pub const StaticList_t = xSTATIC_LIST;
pub const xSTATIC_TCB = extern struct {
    pxDummy1: ?*anyopaque = null,
    xDummy3: [2]StaticListItem_t = std.mem.zeroes([2]StaticListItem_t),
    uxDummy5: UBaseType_t = std.mem.zeroes(UBaseType_t),
    pxDummy6: ?*anyopaque = null,
    xDummy23: [2]BaseType_t = std.mem.zeroes([2]BaseType_t),
    ucDummy7: [16]u8 = std.mem.zeroes([16]u8),
    pxDummy8: ?*anyopaque = null,
    uxDummy12: [2]UBaseType_t = std.mem.zeroes([2]UBaseType_t),
    pvDummy15: [2]?*anyopaque = std.mem.zeroes([2]?*anyopaque),
    xDummy17: opaque {},
    ulDummy18: [1]u32 = std.mem.zeroes([1]u32),
    ucDummy19: [1]u8 = std.mem.zeroes([1]u8),
    uxDummy20: u8 = std.mem.zeroes(u8),
    ucDummy21: u8 = std.mem.zeroes(u8),
};
pub const StaticTask_t = xSTATIC_TCB;
const union_unnamed_4 = extern union {
    pvDummy2: ?*anyopaque,
    uxDummy2: UBaseType_t,
};
pub const xSTATIC_QUEUE = extern struct {
    pvDummy1: [3]?*anyopaque = std.mem.zeroes([3]?*anyopaque),
    u: union_unnamed_4 = std.mem.zeroes(union_unnamed_4),
    xDummy3: [2]StaticList_t = std.mem.zeroes([2]StaticList_t),
    uxDummy4: [3]UBaseType_t = std.mem.zeroes([3]UBaseType_t),
    ucDummy5: [2]u8 = std.mem.zeroes([2]u8),
    ucDummy6: u8 = std.mem.zeroes(u8),
    pvDummy7: ?*anyopaque = null,
};
pub const StaticQueue_t = xSTATIC_QUEUE;
pub const StaticSemaphore_t = StaticQueue_t;
pub const xSTATIC_EVENT_GROUP = extern struct {
    xDummy1: TickType_t = std.mem.zeroes(TickType_t),
    xDummy2: StaticList_t = std.mem.zeroes(StaticList_t),
    ucDummy4: u8 = std.mem.zeroes(u8),
};
pub const StaticEventGroup_t = xSTATIC_EVENT_GROUP;
pub const xSTATIC_TIMER = extern struct {
    pvDummy1: ?*anyopaque = null,
    xDummy2: StaticListItem_t = std.mem.zeroes(StaticListItem_t),
    xDummy3: TickType_t = std.mem.zeroes(TickType_t),
    pvDummy5: ?*anyopaque = null,
    pvDummy6: TaskFunction_t = std.mem.zeroes(TaskFunction_t),
    ucDummy8: u8 = std.mem.zeroes(u8),
};
pub const StaticTimer_t = xSTATIC_TIMER;
pub const xSTATIC_STREAM_BUFFER = extern struct {
    uxDummy1: [4]usize = std.mem.zeroes([4]usize),
    pvDummy2: [3]?*anyopaque = std.mem.zeroes([3]?*anyopaque),
    ucDummy3: u8 = std.mem.zeroes(u8),
};
pub const StaticStreamBuffer_t = xSTATIC_STREAM_BUFFER;
pub const StaticMessageBuffer_t = StaticStreamBuffer_t;
pub const xLIST_ITEM = extern struct {
    xItemValue: TickType_t = std.mem.zeroes(TickType_t),
    pxNext: [*c]xLIST_ITEM = std.mem.zeroes([*c]xLIST_ITEM),
    pxPrevious: [*c]xLIST_ITEM = std.mem.zeroes([*c]xLIST_ITEM),
    pvOwner: ?*anyopaque = null,
    pxContainer: [*c]xLIST = std.mem.zeroes([*c]xLIST),
};
pub const ListItem_t = xLIST_ITEM;
pub const xMINI_LIST_ITEM = extern struct {
    xItemValue: TickType_t = std.mem.zeroes(TickType_t),
    pxNext: [*c]xLIST_ITEM = std.mem.zeroes([*c]xLIST_ITEM),
    pxPrevious: [*c]xLIST_ITEM = std.mem.zeroes([*c]xLIST_ITEM),
};
pub const MiniListItem_t = xMINI_LIST_ITEM;
pub const xLIST = extern struct {
    uxNumberOfItems: UBaseType_t = std.mem.zeroes(UBaseType_t),
    pxIndex: [*c]ListItem_t = std.mem.zeroes([*c]ListItem_t),
    xListEnd: MiniListItem_t = std.mem.zeroes(MiniListItem_t),
};
pub const List_t = xLIST;
pub extern fn vListInitialise(pxList: [*c]List_t) void;
pub extern fn vListInitialiseItem(pxItem: [*c]ListItem_t) void;
pub extern fn vListInsert(pxList: [*c]List_t, pxNewListItem: [*c]ListItem_t) void;
pub extern fn vListInsertEnd(pxList: [*c]List_t, pxNewListItem: [*c]ListItem_t) void;
pub extern fn uxListRemove(pxItemToRemove: [*c]ListItem_t) UBaseType_t;
pub const tskTaskControlBlock = opaque {};
pub const TaskHandle_t = ?*tskTaskControlBlock;
pub const TaskHookFunction_t = ?*const fn (?*anyopaque) callconv(.C) BaseType_t;
pub const eTaskState = enum(c_uint) {
    eRunning = 0,
    eReady = 1,
    eBlocked = 2,
    eSuspended = 3,
    eDeleted = 4,
    eInvalid = 5,
};
pub const eNotifyAction = enum(c_uint) {
    eNoAction = 0,
    eSetBits = 1,
    eIncrement = 2,
    eSetValueWithOverwrite = 3,
    eSetValueWithoutOverwrite = 4,
};
pub const xTIME_OUT = extern struct {
    xOverflowCount: BaseType_t = std.mem.zeroes(BaseType_t),
    xTimeOnEntering: TickType_t = std.mem.zeroes(TickType_t),
};
pub const TimeOut_t = xTIME_OUT;
pub const xMEMORY_REGION = extern struct {
    pvBaseAddress: ?*anyopaque = null,
    ulLengthInBytes: u32 = std.mem.zeroes(u32),
    ulParameters: u32 = std.mem.zeroes(u32),
};
pub const MemoryRegion_t = xMEMORY_REGION;
pub const xTASK_PARAMETERS = extern struct {
    pvTaskCode: TaskFunction_t = std.mem.zeroes(TaskFunction_t),
    pcName: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    usStackDepth: u32 = std.mem.zeroes(u32),
    pvParameters: ?*anyopaque = null,
    uxPriority: UBaseType_t = std.mem.zeroes(UBaseType_t),
    puxStackBuffer: [*c]StackType_t = std.mem.zeroes([*c]StackType_t),
    xRegions: [1]MemoryRegion_t = std.mem.zeroes([1]MemoryRegion_t),
};
pub const TaskParameters_t = xTASK_PARAMETERS;
pub const xTASK_STATUS = extern struct {
    xHandle: TaskHandle_t = std.mem.zeroes(TaskHandle_t),
    pcTaskName: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    xTaskNumber: UBaseType_t = std.mem.zeroes(UBaseType_t),
    eCurrentState: eTaskState = std.mem.zeroes(eTaskState),
    uxCurrentPriority: UBaseType_t = std.mem.zeroes(UBaseType_t),
    uxBasePriority: UBaseType_t = std.mem.zeroes(UBaseType_t),
    ulRunTimeCounter: u32 = std.mem.zeroes(u32),
    pxStackBase: [*c]StackType_t = std.mem.zeroes([*c]StackType_t),
    usStackHighWaterMark: u32 = std.mem.zeroes(u32),
};
pub const TaskStatus_t = xTASK_STATUS;
pub const eSleepModeStatus = enum(c_uint) {
    eAbortSleep = 0,
    eStandardSleep = 1,
    eNoTasksWaitingTimeout = 2,
};
pub extern fn xTaskCreatePinnedToCore(pxTaskCode: TaskFunction_t, pcName: [*:0]const u8, usStackDepth: u32, pvParameters: ?*anyopaque, uxPriority: UBaseType_t, pvCreatedTask: [*c]TaskHandle_t, xCoreID: BaseType_t) BaseType_t;
pub inline fn xTaskCreate(pxTaskCode: TaskFunction_t, pcName: [*:0]const u8, usStackDepth: u32, pvParameters: ?*anyopaque, uxPriority: UBaseType_t, pxCreatedTask: [*c]TaskHandle_t) BaseType_t {
    return xTaskCreatePinnedToCore(pxTaskCode, pcName, usStackDepth, pvParameters, uxPriority, pxCreatedTask, @as(BaseType_t, @bitCast(@as(c_int, 2147483647))));
}
pub extern fn xTaskCreateStaticPinnedToCore(pxTaskCode: TaskFunction_t, pcName: [*:0]const u8, ulStackDepth: u32, pvParameters: ?*anyopaque, uxPriority: UBaseType_t, pxStackBuffer: [*c]StackType_t, pxTaskBuffer: [*c]StaticTask_t, xCoreID: BaseType_t) TaskHandle_t;
pub inline fn xTaskCreateStatic(pxTaskCode: TaskFunction_t, pcName: [*:0]const u8, ulStackDepth: u32, pvParameters: ?*anyopaque, uxPriority: UBaseType_t, puxStackBuffer: [*c]StackType_t, pxTaskBuffer: [*c]StaticTask_t) TaskHandle_t {
    return xTaskCreateStaticPinnedToCore(pxTaskCode, pcName, ulStackDepth, pvParameters, uxPriority, puxStackBuffer, pxTaskBuffer, @as(BaseType_t, @bitCast(@as(c_int, 2147483647))));
}
pub extern fn vTaskAllocateMPURegions(xTask: TaskHandle_t, pxRegions: [*c]const MemoryRegion_t) void;
pub extern fn vTaskDelete(xTaskToDelete: TaskHandle_t) void;
pub extern fn vTaskDelay(xTicksToDelay: TickType_t) void;
pub extern fn xTaskDelayUntil(pxPreviousWakeTime: [*c]TickType_t, xTimeIncrement: TickType_t) BaseType_t;
pub extern fn xTaskAbortDelay(xTask: TaskHandle_t) BaseType_t;
pub extern fn uxTaskPriorityGet(xTask: TaskHandle_t) UBaseType_t;
pub extern fn uxTaskPriorityGetFromISR(xTask: TaskHandle_t) UBaseType_t;
pub extern fn eTaskGetState(xTask: TaskHandle_t) eTaskState;
pub extern fn vTaskGetInfo(xTask: TaskHandle_t, pxTaskStatus: [*c]TaskStatus_t, xGetFreeStackSpace: BaseType_t, eState: eTaskState) void;
pub extern fn vTaskPrioritySet(xTask: TaskHandle_t, uxNewPriority: UBaseType_t) void;
pub extern fn vTaskSuspend(xTaskToSuspend: TaskHandle_t) void;
pub extern fn vTaskResume(xTaskToResume: TaskHandle_t) void;
pub extern fn xTaskResumeFromISR(xTaskToResume: TaskHandle_t) BaseType_t;
pub extern fn vTaskPreemptionDisable(xTask: TaskHandle_t) void;
pub extern fn vTaskPreemptionEnable(xTask: TaskHandle_t) void;
pub extern fn vTaskStartScheduler() void;
pub extern fn vTaskEndScheduler() void;
pub extern fn vTaskSuspendAll() void;
pub extern fn xTaskResumeAll() BaseType_t;
pub extern fn xTaskGetTickCount() TickType_t;
pub extern fn xTaskGetTickCountFromISR() TickType_t;
pub extern fn uxTaskGetNumberOfTasks() UBaseType_t;
pub extern fn pcTaskGetName(xTaskToQuery: TaskHandle_t) [*:0]u8;
pub extern fn xTaskGetHandle(pcNameToQuery: [*:0]const u8) TaskHandle_t;
pub extern fn xTaskGetStaticBuffers(xTask: TaskHandle_t, ppuxStackBuffer: [*c][*c]StackType_t, ppxTaskBuffer: [*c][*c]StaticTask_t) BaseType_t;
pub extern fn uxTaskGetStackHighWaterMark(xTask: TaskHandle_t) UBaseType_t;
pub extern fn uxTaskGetStackHighWaterMark2(xTask: TaskHandle_t) u32;
pub extern fn vTaskSetThreadLocalStoragePointer(xTaskToSet: TaskHandle_t, xIndex: BaseType_t, pvValue: ?*anyopaque) void;
pub extern fn pvTaskGetThreadLocalStoragePointer(xTaskToQuery: TaskHandle_t, xIndex: BaseType_t) ?*anyopaque;
pub extern fn vApplicationStackOverflowHook(xTask: TaskHandle_t, pcTaskName: [*:0]u8) void;
pub extern fn vApplicationGetIdleTaskMemory(ppxIdleTaskTCBBuffer: [*c][*c]StaticTask_t, ppxIdleTaskStackBuffer: [*c][*c]StackType_t, pulIdleTaskStackSize: [*c]u32) void;
pub extern fn xTaskCallApplicationTaskHook(xTask: TaskHandle_t, pvParameter: ?*anyopaque) BaseType_t;
pub extern fn xTaskGetIdleTaskHandle() [*c]TaskHandle_t;
pub extern fn uxTaskGetSystemState(pxTaskStatusArray: [*c]TaskStatus_t, uxArraySize: UBaseType_t, pulTotalRunTime: [*c]u32) UBaseType_t;
pub extern fn vTaskList(pcWriteBuffer: [*:0]u8) void;
pub extern fn vTaskGetRunTimeStats(pcWriteBuffer: [*:0]u8) void;
pub extern fn ulTaskGetIdleRunTimeCounter() u32;
pub extern fn xTaskGenericNotify(xTaskToNotify: TaskHandle_t, uxIndexToNotify: UBaseType_t, ulValue: u32, eAction: eNotifyAction, pulPreviousNotificationValue: [*c]u32) BaseType_t;
pub extern fn xTaskGenericNotifyFromISR(xTaskToNotify: TaskHandle_t, uxIndexToNotify: UBaseType_t, ulValue: u32, eAction: eNotifyAction, pulPreviousNotificationValue: [*c]u32, pxHigherPriorityTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xTaskGenericNotifyWait(uxIndexToWaitOn: UBaseType_t, ulBitsToClearOnEntry: u32, ulBitsToClearOnExit: u32, pulNotificationValue: [*c]u32, xTicksToWait: TickType_t) BaseType_t;
pub extern fn vTaskGenericNotifyGiveFromISR(xTaskToNotify: TaskHandle_t, uxIndexToNotify: UBaseType_t, pxHigherPriorityTaskWoken: [*c]BaseType_t) void;
pub extern fn ulTaskGenericNotifyTake(uxIndexToWaitOn: UBaseType_t, xClearCountOnExit: BaseType_t, xTicksToWait: TickType_t) u32;
pub extern fn xTaskGenericNotifyStateClear(xTask: TaskHandle_t, uxIndexToClear: UBaseType_t) BaseType_t;
pub extern fn ulTaskGenericNotifyValueClear(xTask: TaskHandle_t, uxIndexToClear: UBaseType_t, ulBitsToClear: u32) u32;
pub extern fn vTaskSetTimeOutState(pxTimeOut: [*c]TimeOut_t) void;
pub extern fn xTaskCheckForTimeOut(pxTimeOut: [*c]TimeOut_t, pxTicksToWait: [*c]TickType_t) BaseType_t;
pub extern fn xTaskCatchUpTicks(xTicksToCatchUp: TickType_t) BaseType_t;
pub extern fn xTaskIncrementTick() BaseType_t;
pub extern fn vTaskPlaceOnEventList(pxEventList: [*c]List_t, xTicksToWait: TickType_t) void;
pub extern fn vTaskPlaceOnUnorderedEventList(pxEventList: [*c]List_t, xItemValue: TickType_t, xTicksToWait: TickType_t) void;
pub extern fn vTaskPlaceOnEventListRestricted(pxEventList: [*c]List_t, xTicksToWait: TickType_t, xWaitIndefinitely: BaseType_t) void;
pub extern fn xTaskRemoveFromEventList(pxEventList: [*c]const List_t) BaseType_t;
pub extern fn vTaskRemoveFromUnorderedEventList(pxEventListItem: [*c]ListItem_t, xItemValue: TickType_t) void;
pub extern fn vTaskSwitchContext(xCoreID: BaseType_t) void;
pub extern fn uxTaskResetEventItemValue() TickType_t;
pub extern fn xTaskGetCurrentTaskHandle() TaskHandle_t;
pub extern fn xTaskGetCurrentTaskHandleCPU(xCoreID: UBaseType_t) TaskHandle_t;
pub extern fn vTaskMissedYield() void;
pub extern fn xTaskGetSchedulerState() BaseType_t;
pub extern fn xTaskPriorityInherit(pxMutexHolder: TaskHandle_t) BaseType_t;
pub extern fn xTaskPriorityDisinherit(pxMutexHolder: TaskHandle_t) BaseType_t;
pub extern fn vTaskPriorityDisinheritAfterTimeout(pxMutexHolder: TaskHandle_t, uxHighestPriorityWaitingTask: UBaseType_t) void;
pub extern fn uxTaskGetTaskNumber(xTask: TaskHandle_t) UBaseType_t;
pub extern fn vTaskSetTaskNumber(xTask: TaskHandle_t, uxHandle: UBaseType_t) void;
pub extern fn vTaskStepTick(xTicksToJump: TickType_t) void;
pub extern fn eTaskConfirmSleepModeStatus() eSleepModeStatus;
pub extern fn pvTaskIncrementMutexHeldCount() TaskHandle_t;
pub extern fn vTaskInternalSetTimeOutState(pxTimeOut: [*c]TimeOut_t) void;
pub extern fn vTaskYieldWithinAPI() void;
pub const esp_task_wdt_config_t = extern struct {
    timeout_ms: u32 = std.mem.zeroes(u32),
    idle_core_mask: u32 = std.mem.zeroes(u32),
    trigger_panic: bool = std.mem.zeroes(bool),
};
pub const esp_task_wdt_user_handle_s = opaque {};
pub const esp_task_wdt_user_handle_t = ?*esp_task_wdt_user_handle_s;
pub extern fn esp_task_wdt_init(config: [*c]const esp_task_wdt_config_t) esp_err_t;
pub extern fn esp_task_wdt_reconfigure(config: [*c]const esp_task_wdt_config_t) esp_err_t;
pub extern fn esp_task_wdt_deinit() esp_err_t;
pub extern fn esp_task_wdt_add(task_handle: TaskHandle_t) esp_err_t;
pub extern fn esp_task_wdt_add_user(user_name: [*:0]const u8, user_handle_ret: [*c]esp_task_wdt_user_handle_t) esp_err_t;
pub extern fn esp_task_wdt_reset() esp_err_t;
pub extern fn esp_task_wdt_reset_user(user_handle: esp_task_wdt_user_handle_t) esp_err_t;
pub extern fn esp_task_wdt_delete(task_handle: TaskHandle_t) esp_err_t;
pub extern fn esp_task_wdt_delete_user(user_handle: esp_task_wdt_user_handle_t) esp_err_t;
pub extern fn esp_task_wdt_status(task_handle: TaskHandle_t) esp_err_t;
pub extern fn esp_task_wdt_isr_user_handler() void;
pub const task_wdt_msg_handler = ?*const fn (?*anyopaque, [*:0]const u8) callconv(.C) void;
pub extern fn esp_task_wdt_print_triggered_tasks(msg_handler: task_wdt_msg_handler, @"opaque": ?*anyopaque, cpus_fail: [*c]c_int) esp_err_t;
pub const esp_interface_t = enum(c_uint) {
    ESP_IF_WIFI_STA = 0,
    ESP_IF_WIFI_AP = 1,
    ESP_IF_WIFI_NAN = 2,
    ESP_IF_ETH = 3,
    ESP_IF_MAX = 4,
};
pub const esp_ipc_func_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub extern fn esp_ipc_call(cpu_id: u32, func: esp_ipc_func_t, arg: ?*anyopaque) esp_err_t;
pub extern fn esp_ipc_call_blocking(cpu_id: u32, func: esp_ipc_func_t, arg: ?*anyopaque) esp_err_t;
pub const esp_mac_type_t = enum(c_uint) {
    ESP_MAC_WIFI_STA = 0,
    ESP_MAC_WIFI_SOFTAP = 1,
    ESP_MAC_BT = 2,
    ESP_MAC_ETH = 3,
    ESP_MAC_IEEE802154 = 4,
    ESP_MAC_BASE = 5,
    ESP_MAC_EFUSE_FACTORY = 6,
    ESP_MAC_EFUSE_CUSTOM = 7,
    ESP_MAC_EFUSE_EXT = 8,
};
pub extern fn esp_base_mac_addr_set(mac: [*:0]const u8) esp_err_t;
pub extern fn esp_base_mac_addr_get(mac: [*:0]u8) esp_err_t;
pub extern fn esp_efuse_mac_get_custom(mac: [*:0]u8) esp_err_t;
pub extern fn esp_efuse_mac_get_default(mac: [*:0]u8) esp_err_t;
pub extern fn esp_read_mac(mac: [*:0]u8, @"type": esp_mac_type_t) esp_err_t;
pub extern fn esp_derive_local_mac(local_mac: [*:0]u8, universal_mac: [*:0]const u8) esp_err_t;
pub extern fn esp_iface_mac_addr_set(mac: [*:0]const u8, @"type": esp_mac_type_t) esp_err_t;
pub extern fn esp_mac_addr_len_get(@"type": esp_mac_type_t) usize;
pub const esp_freertos_idle_cb_t = ?*const fn () callconv(.C) bool;
pub const esp_freertos_tick_cb_t = ?*const fn () callconv(.C) void;
pub extern fn esp_register_freertos_idle_hook_for_cpu(new_idle_cb: esp_freertos_idle_cb_t, cpuid: UBaseType_t) esp_err_t;
pub extern fn esp_register_freertos_idle_hook(new_idle_cb: esp_freertos_idle_cb_t) esp_err_t;
pub extern fn esp_register_freertos_tick_hook_for_cpu(new_tick_cb: esp_freertos_tick_cb_t, cpuid: UBaseType_t) esp_err_t;
pub extern fn esp_register_freertos_tick_hook(new_tick_cb: esp_freertos_tick_cb_t) esp_err_t;
pub extern fn esp_deregister_freertos_idle_hook_for_cpu(old_idle_cb: esp_freertos_idle_cb_t, cpuid: UBaseType_t) void;
pub extern fn esp_deregister_freertos_idle_hook(old_idle_cb: esp_freertos_idle_cb_t) void;
pub extern fn esp_deregister_freertos_tick_hook_for_cpu(old_tick_cb: esp_freertos_tick_cb_t, cpuid: UBaseType_t) void;
pub extern fn esp_deregister_freertos_tick_hook(old_tick_cb: esp_freertos_tick_cb_t) void;
pub fn Atomic_CompareAndSwap_u32(arg_pulDestination: [*c]volatile u32, arg_ulExchange: u32, arg_ulComparand: u32) callconv(.C) u32 {
    var pulDestination = arg_pulDestination;
    _ = &pulDestination;
    var ulExchange = arg_ulExchange;
    _ = &ulExchange;
    var ulComparand = arg_ulComparand;
    _ = &ulComparand;
    var ulReturnValue: u32 = undefined;
    _ = &ulReturnValue;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        if (pulDestination.* == ulComparand) {
            pulDestination.* = ulExchange;
            ulReturnValue = 1;
        } else {
            ulReturnValue = 0;
        }
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulReturnValue;
}
pub fn Atomic_SwapPointers_p32(arg_ppvDestination: [*c]volatile ?*anyopaque, arg_pvExchange: ?*anyopaque) callconv(.C) ?*anyopaque {
    var ppvDestination = arg_ppvDestination;
    _ = &ppvDestination;
    var pvExchange = arg_pvExchange;
    _ = &pvExchange;
    var pReturnValue: ?*anyopaque = undefined;
    _ = &pReturnValue;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        pReturnValue = ppvDestination.*;
        ppvDestination.* = pvExchange;
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return pReturnValue;
}
pub fn Atomic_CompareAndSwapPointers_p32(arg_ppvDestination: [*c]volatile ?*anyopaque, arg_pvExchange: ?*anyopaque, arg_pvComparand: ?*anyopaque) callconv(.C) u32 {
    var ppvDestination = arg_ppvDestination;
    _ = &ppvDestination;
    var pvExchange = arg_pvExchange;
    _ = &pvExchange;
    var pvComparand = arg_pvComparand;
    _ = &pvComparand;
    var ulReturnValue: u32 = 0;
    _ = &ulReturnValue;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        if (ppvDestination.* == pvComparand) {
            ppvDestination.* = pvExchange;
            ulReturnValue = 1;
        }
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulReturnValue;
}
pub fn Atomic_Add_u32(arg_pulAddend: [*c]volatile u32, arg_ulCount: u32) callconv(.C) u32 {
    var pulAddend = arg_pulAddend;
    _ = &pulAddend;
    var ulCount = arg_ulCount;
    _ = &ulCount;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulAddend.*;
        pulAddend.* +%= @as(u32, @bitCast(ulCount));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_Subtract_u32(arg_pulAddend: [*c]volatile u32, arg_ulCount: u32) callconv(.C) u32 {
    var pulAddend = arg_pulAddend;
    _ = &pulAddend;
    var ulCount = arg_ulCount;
    _ = &ulCount;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulAddend.*;
        pulAddend.* -%= @as(u32, @bitCast(ulCount));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_Increment_u32(arg_pulAddend: [*c]volatile u32) callconv(.C) u32 {
    var pulAddend = arg_pulAddend;
    _ = &pulAddend;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulAddend.*;
        pulAddend.* +%= @as(u32, @bitCast(@as(u32, @bitCast(@as(c_int, 1)))));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_Decrement_u32(arg_pulAddend: [*c]volatile u32) callconv(.C) u32 {
    var pulAddend = arg_pulAddend;
    _ = &pulAddend;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulAddend.*;
        pulAddend.* -%= @as(u32, @bitCast(@as(u32, @bitCast(@as(c_int, 1)))));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_OR_u32(arg_pulDestination: [*c]volatile u32, arg_ulValue: u32) callconv(.C) u32 {
    var pulDestination = arg_pulDestination;
    _ = &pulDestination;
    var ulValue = arg_ulValue;
    _ = &ulValue;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulDestination.*;
        pulDestination.* |= @as(u32, @bitCast(ulValue));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_AND_u32(arg_pulDestination: [*c]volatile u32, arg_ulValue: u32) callconv(.C) u32 {
    var pulDestination = arg_pulDestination;
    _ = &pulDestination;
    var ulValue = arg_ulValue;
    _ = &ulValue;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulDestination.*;
        pulDestination.* &= @as(u32, @bitCast(ulValue));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_NAND_u32(arg_pulDestination: [*c]volatile u32, arg_ulValue: u32) callconv(.C) u32 {
    var pulDestination = arg_pulDestination;
    _ = &pulDestination;
    var ulValue = arg_ulValue;
    _ = &ulValue;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulDestination.*;
        pulDestination.* = ~(ulCurrent & ulValue);
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub fn Atomic_XOR_u32(arg_pulDestination: [*c]volatile u32, arg_ulValue: u32) callconv(.C) u32 {
    var pulDestination = arg_pulDestination;
    _ = &pulDestination;
    var ulValue = arg_ulValue;
    _ = &ulValue;
    var ulCurrent: u32 = undefined;
    _ = &ulCurrent;
    var uxCriticalSectionType: UBaseType_t = xPortSetInterruptMaskFromISR();
    _ = &uxCriticalSectionType;
    {
        ulCurrent = pulDestination.*;
        pulDestination.* ^= @as(u32, @bitCast(ulValue));
    }
    vPortClearInterruptMaskFromISR(uxCriticalSectionType);
    return ulCurrent;
}
pub const tmrTimerControl = opaque {};
pub const TimerHandle_t = ?*tmrTimerControl;
pub const TimerCallbackFunction_t = ?*const fn (TimerHandle_t) callconv(.C) void;
pub const PendedFunction_t = ?*const fn (?*anyopaque, u32) callconv(.C) void;
pub extern fn xTimerCreate(pcTimerName: [*:0]const u8, xTimerPeriodInTicks: TickType_t, uxAutoReload: UBaseType_t, pvTimerID: ?*anyopaque, pxCallbackFunction: TimerCallbackFunction_t) TimerHandle_t;
pub extern fn xTimerCreateStatic(pcTimerName: [*:0]const u8, xTimerPeriodInTicks: TickType_t, uxAutoReload: UBaseType_t, pvTimerID: ?*anyopaque, pxCallbackFunction: TimerCallbackFunction_t, pxTimerBuffer: [*c]StaticTimer_t) TimerHandle_t;
pub extern fn pvTimerGetTimerID(xTimer: TimerHandle_t) ?*anyopaque;
pub extern fn vTimerSetTimerID(xTimer: TimerHandle_t, pvNewID: ?*anyopaque) void;
pub extern fn xTimerIsTimerActive(xTimer: TimerHandle_t) BaseType_t;
pub extern fn xTimerGetTimerDaemonTaskHandle() TaskHandle_t;
pub extern fn xTimerPendFunctionCallFromISR(xFunctionToPend: PendedFunction_t, pvParameter1: ?*anyopaque, ulParameter2: u32, pxHigherPriorityTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xTimerPendFunctionCall(xFunctionToPend: PendedFunction_t, pvParameter1: ?*anyopaque, ulParameter2: u32, xTicksToWait: TickType_t) BaseType_t;
pub extern fn pcTimerGetName(xTimer: TimerHandle_t) [*:0]const u8;
pub extern fn vTimerSetReloadMode(xTimer: TimerHandle_t, uxAutoReload: UBaseType_t) void;
pub extern fn uxTimerGetReloadMode(xTimer: TimerHandle_t) UBaseType_t;
pub extern fn xTimerGetPeriod(xTimer: TimerHandle_t) TickType_t;
pub extern fn xTimerGetExpiryTime(xTimer: TimerHandle_t) TickType_t;
pub extern fn xTimerGetStaticBuffer(xTimer: TimerHandle_t, ppxTimerBuffer: [*c][*c]StaticTimer_t) BaseType_t;
pub extern fn xTimerCreateTimerTask() BaseType_t;
pub extern fn xTimerGenericCommandFromTask(xTimer: TimerHandle_t, xCommandID: BaseType_t, xOptionalValue: TickType_t, pxHigherPriorityTaskWoken: [*c]BaseType_t, xTicksToWait: TickType_t) BaseType_t;
pub extern fn xTimerGenericCommandFromISR(xTimer: TimerHandle_t, xCommandID: BaseType_t, xOptionalValue: TickType_t, pxHigherPriorityTaskWoken: [*c]BaseType_t, xTicksToWait: TickType_t) BaseType_t;
pub extern fn vApplicationGetTimerTaskMemory(ppxTimerTaskTCBBuffer: [*c][*c]StaticTask_t, ppxTimerTaskStackBuffer: [*c][*c]StackType_t, pulTimerTaskStackSize: [*c]u32) void;
pub const EventGroupDef_t = opaque {};
pub const EventGroupHandle_t = ?*EventGroupDef_t;
pub const EventBits_t = TickType_t;
pub extern fn xEventGroupCreate() EventGroupHandle_t;
pub extern fn xEventGroupCreateStatic(pxEventGroupBuffer: [*c]StaticEventGroup_t) EventGroupHandle_t;
pub extern fn xEventGroupWaitBits(xEventGroup: EventGroupHandle_t, uxBitsToWaitFor: EventBits_t, xClearOnExit: BaseType_t, xWaitForAllBits: BaseType_t, xTicksToWait: TickType_t) EventBits_t;
pub extern fn xEventGroupClearBits(xEventGroup: EventGroupHandle_t, uxBitsToClear: EventBits_t) EventBits_t;
pub extern fn xEventGroupSetBits(xEventGroup: EventGroupHandle_t, uxBitsToSet: EventBits_t) EventBits_t;
pub extern fn xEventGroupSync(xEventGroup: EventGroupHandle_t, uxBitsToSet: EventBits_t, uxBitsToWaitFor: EventBits_t, xTicksToWait: TickType_t) EventBits_t;
pub extern fn xEventGroupGetBitsFromISR(xEventGroup: EventGroupHandle_t) EventBits_t;
pub extern fn vEventGroupDelete(xEventGroup: EventGroupHandle_t) void;
pub extern fn xEventGroupGetStaticBuffer(xEventGroup: EventGroupHandle_t, ppxEventGroupBuffer: [*c][*c]StaticEventGroup_t) BaseType_t;
pub extern fn vEventGroupSetBitsCallback(pvEventGroup: ?*anyopaque, ulBitsToSet: u32) void;
pub extern fn vEventGroupClearBitsCallback(pvEventGroup: ?*anyopaque, ulBitsToClear: u32) void;
pub const StreamBufferDef_t = opaque {};
pub const StreamBufferHandle_t = ?*StreamBufferDef_t;
pub extern fn xStreamBufferGetStaticBuffers(xStreamBuffer: StreamBufferHandle_t, ppucStreamBufferStorageArea: [*c][*c]u8, ppxStaticStreamBuffer: [*c][*c]StaticStreamBuffer_t) BaseType_t;
pub extern fn xStreamBufferSend(xStreamBuffer: StreamBufferHandle_t, pvTxData: ?*const anyopaque, xDataLengthBytes: usize, xTicksToWait: TickType_t) usize;
pub extern fn xStreamBufferSendFromISR(xStreamBuffer: StreamBufferHandle_t, pvTxData: ?*const anyopaque, xDataLengthBytes: usize, pxHigherPriorityTaskWoken: [*c]BaseType_t) usize;
pub extern fn xStreamBufferReceive(xStreamBuffer: StreamBufferHandle_t, pvRxData: ?*anyopaque, xBufferLengthBytes: usize, xTicksToWait: TickType_t) usize;
pub extern fn xStreamBufferReceiveFromISR(xStreamBuffer: StreamBufferHandle_t, pvRxData: ?*anyopaque, xBufferLengthBytes: usize, pxHigherPriorityTaskWoken: [*c]BaseType_t) usize;
pub extern fn vStreamBufferDelete(xStreamBuffer: StreamBufferHandle_t) void;
pub extern fn xStreamBufferIsFull(xStreamBuffer: StreamBufferHandle_t) BaseType_t;
pub extern fn xStreamBufferIsEmpty(xStreamBuffer: StreamBufferHandle_t) BaseType_t;
pub extern fn xStreamBufferReset(xStreamBuffer: StreamBufferHandle_t) BaseType_t;
pub extern fn xStreamBufferSpacesAvailable(xStreamBuffer: StreamBufferHandle_t) usize;
pub extern fn xStreamBufferBytesAvailable(xStreamBuffer: StreamBufferHandle_t) usize;
pub extern fn xStreamBufferSetTriggerLevel(xStreamBuffer: StreamBufferHandle_t, xTriggerLevel: usize) BaseType_t;
pub extern fn xStreamBufferSendCompletedFromISR(xStreamBuffer: StreamBufferHandle_t, pxHigherPriorityTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xStreamBufferReceiveCompletedFromISR(xStreamBuffer: StreamBufferHandle_t, pxHigherPriorityTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xStreamBufferGenericCreate(xBufferSizeBytes: usize, xTriggerLevelBytes: usize, xIsMessageBuffer: BaseType_t) StreamBufferHandle_t;
pub extern fn xStreamBufferGenericCreateStatic(xBufferSizeBytes: usize, xTriggerLevelBytes: usize, xIsMessageBuffer: BaseType_t, pucStreamBufferStorageArea: [*:0]u8, pxStaticStreamBuffer: [*c]StaticStreamBuffer_t) StreamBufferHandle_t;
pub extern fn xStreamBufferNextMessageLengthBytes(xStreamBuffer: StreamBufferHandle_t) usize;
pub const MessageBufferHandle_t = ?*anyopaque;
pub const QueueDefinition = opaque {};
pub const QueueHandle_t = ?*QueueDefinition;
pub const QueueSetHandle_t = ?*QueueDefinition;
pub const QueueSetMemberHandle_t = ?*QueueDefinition;
pub extern fn xQueueGenericSend(xQueue: QueueHandle_t, pvItemToQueue: ?*const anyopaque, xTicksToWait: TickType_t, xCopyPosition: BaseType_t) BaseType_t;
pub extern fn xQueuePeek(xQueue: QueueHandle_t, pvBuffer: ?*anyopaque, xTicksToWait: TickType_t) BaseType_t;
pub extern fn xQueuePeekFromISR(xQueue: QueueHandle_t, pvBuffer: ?*anyopaque) BaseType_t;
pub extern fn xQueueReceive(xQueue: QueueHandle_t, pvBuffer: ?*anyopaque, xTicksToWait: TickType_t) BaseType_t;
pub extern fn uxQueueMessagesWaiting(xQueue: QueueHandle_t) UBaseType_t;
pub extern fn uxQueueSpacesAvailable(xQueue: QueueHandle_t) UBaseType_t;
pub extern fn vQueueDelete(xQueue: QueueHandle_t) void;
pub extern fn xQueueGenericSendFromISR(xQueue: QueueHandle_t, pvItemToQueue: ?*const anyopaque, pxHigherPriorityTaskWoken: [*c]BaseType_t, xCopyPosition: BaseType_t) BaseType_t;
pub extern fn xQueueGiveFromISR(xQueue: QueueHandle_t, pxHigherPriorityTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xQueueReceiveFromISR(xQueue: QueueHandle_t, pvBuffer: ?*anyopaque, pxHigherPriorityTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xQueueIsQueueEmptyFromISR(xQueue: QueueHandle_t) BaseType_t;
pub extern fn xQueueIsQueueFullFromISR(xQueue: QueueHandle_t) BaseType_t;
pub extern fn uxQueueMessagesWaitingFromISR(xQueue: QueueHandle_t) UBaseType_t;
pub extern fn xQueueCRSendFromISR(xQueue: QueueHandle_t, pvItemToQueue: ?*const anyopaque, xCoRoutinePreviouslyWoken: BaseType_t) BaseType_t;
pub extern fn xQueueCRReceiveFromISR(xQueue: QueueHandle_t, pvBuffer: ?*anyopaque, pxTaskWoken: [*c]BaseType_t) BaseType_t;
pub extern fn xQueueCRSend(xQueue: QueueHandle_t, pvItemToQueue: ?*const anyopaque, xTicksToWait: TickType_t) BaseType_t;
pub extern fn xQueueCRReceive(xQueue: QueueHandle_t, pvBuffer: ?*anyopaque, xTicksToWait: TickType_t) BaseType_t;
pub extern fn xQueueCreateMutex(ucQueueType: u8) QueueHandle_t;
pub extern fn xQueueCreateMutexStatic(ucQueueType: u8, pxStaticQueue: [*c]StaticQueue_t) QueueHandle_t;
pub extern fn xQueueCreateCountingSemaphore(uxMaxCount: UBaseType_t, uxInitialCount: UBaseType_t) QueueHandle_t;
pub extern fn xQueueCreateCountingSemaphoreStatic(uxMaxCount: UBaseType_t, uxInitialCount: UBaseType_t, pxStaticQueue: [*c]StaticQueue_t) QueueHandle_t;
pub extern fn xQueueSemaphoreTake(xQueue: QueueHandle_t, xTicksToWait: TickType_t) BaseType_t;
pub extern fn xQueueGetMutexHolder(xSemaphore: QueueHandle_t) TaskHandle_t;
pub extern fn xQueueGetMutexHolderFromISR(xSemaphore: QueueHandle_t) TaskHandle_t;
pub extern fn xQueueTakeMutexRecursive(xMutex: QueueHandle_t, xTicksToWait: TickType_t) BaseType_t;
pub extern fn xQueueGiveMutexRecursive(xMutex: QueueHandle_t) BaseType_t;
pub extern fn xQueueGenericCreate(uxQueueLength: UBaseType_t, uxItemSize: UBaseType_t, ucQueueType: u8) QueueHandle_t;
pub extern fn xQueueGenericCreateStatic(uxQueueLength: UBaseType_t, uxItemSize: UBaseType_t, pucQueueStorage: [*:0]u8, pxStaticQueue: [*c]StaticQueue_t, ucQueueType: u8) QueueHandle_t;
pub extern fn xQueueGenericGetStaticBuffers(xQueue: QueueHandle_t, ppucQueueStorage: [*c][*c]u8, ppxStaticQueue: [*c][*c]StaticQueue_t) BaseType_t;
pub extern fn xQueueCreateSet(uxEventQueueLength: UBaseType_t) QueueSetHandle_t;
pub extern fn xQueueAddToSet(xQueueOrSemaphore: QueueSetMemberHandle_t, xQueueSet: QueueSetHandle_t) BaseType_t;
pub extern fn xQueueRemoveFromSet(xQueueOrSemaphore: QueueSetMemberHandle_t, xQueueSet: QueueSetHandle_t) BaseType_t;
pub extern fn xQueueSelectFromSet(xQueueSet: QueueSetHandle_t, xTicksToWait: TickType_t) QueueSetMemberHandle_t;
pub extern fn xQueueSelectFromSetFromISR(xQueueSet: QueueSetHandle_t) QueueSetMemberHandle_t;
pub extern fn vQueueWaitForMessageRestricted(xQueue: QueueHandle_t, xTicksToWait: TickType_t, xWaitIndefinitely: BaseType_t) void;
pub extern fn xQueueGenericReset(xQueue: QueueHandle_t, xNewQueue: BaseType_t) BaseType_t;
pub extern fn vQueueSetQueueNumber(xQueue: QueueHandle_t, uxQueueNumber: UBaseType_t) void;
pub extern fn uxQueueGetQueueNumber(xQueue: QueueHandle_t) UBaseType_t;
pub extern fn ucQueueGetQueueType(xQueue: QueueHandle_t) u8;
pub const SemaphoreHandle_t = QueueHandle_t;
pub const xTASK_SNAPSHOT = extern struct {
    pxTCB: ?*anyopaque = null,
    pxTopOfStack: [*c]StackType_t = std.mem.zeroes([*c]StackType_t),
    pxEndOfStack: [*c]StackType_t = std.mem.zeroes([*c]StackType_t),
};
pub const TaskSnapshot_t = xTASK_SNAPSHOT;
pub const TaskIterator = extern struct {
    uxCurrentListIndex: UBaseType_t = std.mem.zeroes(UBaseType_t),
    pxNextListItem: [*c]ListItem_t = std.mem.zeroes([*c]ListItem_t),
    pxTaskHandle: TaskHandle_t = std.mem.zeroes(TaskHandle_t),
};
pub const TaskIterator_t = TaskIterator;
pub extern fn xTaskGetNext(xIterator: [*c]TaskIterator_t) c_int;
pub extern fn vTaskGetSnapshot(pxTask: TaskHandle_t, pxTaskSnapshot: [*c]TaskSnapshot_t) BaseType_t;
pub extern fn uxTaskGetSnapshotAll(pxTaskSnapshotArray: [*c]TaskSnapshot_t, uxArrayLength: UBaseType_t, pxTCBSize: [*c]UBaseType_t) UBaseType_t;
pub extern fn pvTaskGetCurrentTCBForCore(xCoreID: BaseType_t) ?*anyopaque;
pub extern fn esp_int_wdt_init() void;
pub extern fn esp_int_wdt_cpu_init() void;
pub const portTICK_PERIOD_MS: TickType_t = @as(TickType_t, @divExact(@as(c_int, 1000), configTICK_RATE_HZ));
pub const configTICK_RATE_HZ: c_int = 100;

pub const esp_event_base_t = [*c]const u8;
pub const esp_event_loop_handle_t = ?*anyopaque;
pub const esp_event_handler_t = ?*const fn (?*anyopaque, esp_event_base_t, i32, ?*anyopaque) callconv(.C) void;
pub const esp_event_handler_instance_t = ?*anyopaque;
pub const esp_event_loop_args_t = extern struct {
    queue_size: i32 = std.mem.zeroes(i32),
    task_name: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    task_priority: UBaseType_t = std.mem.zeroes(UBaseType_t),
    task_stack_size: u32 = std.mem.zeroes(u32),
    task_core_id: BaseType_t = std.mem.zeroes(BaseType_t),
};
pub extern fn esp_event_loop_create(event_loop_args: [*c]const esp_event_loop_args_t, event_loop: [*c]esp_event_loop_handle_t) esp_err_t;
pub extern fn esp_event_loop_delete(event_loop: esp_event_loop_handle_t) esp_err_t;
pub extern fn esp_event_loop_create_default() esp_err_t;
pub extern fn esp_event_loop_delete_default() esp_err_t;
pub extern fn esp_event_loop_run(event_loop: esp_event_loop_handle_t, ticks_to_run: TickType_t) esp_err_t;
pub extern fn esp_event_handler_register(event_base: esp_event_base_t, event_id: i32, event_handler: esp_event_handler_t, event_handler_arg: ?*anyopaque) esp_err_t;
pub extern fn esp_event_handler_register_with(event_loop: esp_event_loop_handle_t, event_base: esp_event_base_t, event_id: i32, event_handler: esp_event_handler_t, event_handler_arg: ?*anyopaque) esp_err_t;
pub extern fn esp_event_handler_instance_register_with(event_loop: esp_event_loop_handle_t, event_base: esp_event_base_t, event_id: i32, event_handler: esp_event_handler_t, event_handler_arg: ?*anyopaque, instance: [*c]esp_event_handler_instance_t) esp_err_t;
pub extern fn esp_event_handler_instance_register(event_base: esp_event_base_t, event_id: i32, event_handler: esp_event_handler_t, event_handler_arg: ?*anyopaque, instance: [*c]esp_event_handler_instance_t) esp_err_t;
pub extern fn esp_event_handler_unregister(event_base: esp_event_base_t, event_id: i32, event_handler: esp_event_handler_t) esp_err_t;
pub extern fn esp_event_handler_unregister_with(event_loop: esp_event_loop_handle_t, event_base: esp_event_base_t, event_id: i32, event_handler: esp_event_handler_t) esp_err_t;
pub extern fn esp_event_handler_instance_unregister_with(event_loop: esp_event_loop_handle_t, event_base: esp_event_base_t, event_id: i32, instance: esp_event_handler_instance_t) esp_err_t;
pub extern fn esp_event_handler_instance_unregister(event_base: esp_event_base_t, event_id: i32, instance: esp_event_handler_instance_t) esp_err_t;
pub extern fn esp_event_post(event_base: esp_event_base_t, event_id: i32, event_data: ?*const anyopaque, event_data_size: usize, ticks_to_wait: TickType_t) esp_err_t;
pub extern fn esp_event_post_to(event_loop: esp_event_loop_handle_t, event_base: esp_event_base_t, event_id: i32, event_data: ?*const anyopaque, event_data_size: usize, ticks_to_wait: TickType_t) esp_err_t;
pub extern fn esp_event_isr_post(event_base: esp_event_base_t, event_id: i32, event_data: ?*const anyopaque, event_data_size: usize, task_unblocked: [*c]BaseType_t) esp_err_t;
pub extern fn esp_event_isr_post_to(event_loop: esp_event_loop_handle_t, event_base: esp_event_base_t, event_id: i32, event_data: ?*const anyopaque, event_data_size: usize, task_unblocked: [*c]BaseType_t) esp_err_t;
pub extern fn esp_event_dump(file: std.c.FILE) esp_err_t;
pub const nvs_handle_t = u32;
pub const nvs_handle = nvs_handle_t;
pub const nvs_open_mode_t = enum(c_uint) {
    NVS_READONLY = 0,
    NVS_READWRITE = 1,
};
pub const nvs_open_mode = nvs_open_mode_t;
pub const nvs_type_t = enum(c_uint) {
    NVS_TYPE_U8 = 1,
    NVS_TYPE_I8 = 17,
    NVS_TYPE_U16 = 2,
    NVS_TYPE_I16 = 18,
    NVS_TYPE_U32 = 4,
    NVS_TYPE_I32 = 20,
    NVS_TYPE_U64 = 8,
    NVS_TYPE_I64 = 24,
    NVS_TYPE_STR = 33,
    NVS_TYPE_BLOB = 66,
    NVS_TYPE_ANY = 255,
};
pub const nvs_entry_info_t = extern struct {
    namespace_name: [16]u8 = std.mem.zeroes([16]u8),
    key: [16]u8 = std.mem.zeroes([16]u8),
    type: nvs_type_t = std.mem.zeroes(nvs_type_t),
};
pub const nvs_opaque_iterator_t = opaque {};
pub const nvs_iterator_t = ?*nvs_opaque_iterator_t;
pub extern fn nvs_open(namespace_name: [*:0]const u8, open_mode: nvs_open_mode_t, out_handle: [*c]nvs_handle_t) esp_err_t;
pub extern fn nvs_open_from_partition(part_name: [*:0]const u8, namespace_name: [*:0]const u8, open_mode: nvs_open_mode_t, out_handle: [*c]nvs_handle_t) esp_err_t;
pub extern fn nvs_set_i8(handle: nvs_handle_t, key: [*:0]const u8, value: i8) esp_err_t;
pub extern fn nvs_set_u8(handle: nvs_handle_t, key: [*:0]const u8, value: u8) esp_err_t;
pub extern fn nvs_set_i16(handle: nvs_handle_t, key: [*:0]const u8, value: i16) esp_err_t;
pub extern fn nvs_set_u16(handle: nvs_handle_t, key: [*:0]const u8, value: u16) esp_err_t;
pub extern fn nvs_set_i32(handle: nvs_handle_t, key: [*:0]const u8, value: i32) esp_err_t;
pub extern fn nvs_set_u32(handle: nvs_handle_t, key: [*:0]const u8, value: u32) esp_err_t;
pub extern fn nvs_set_i64(handle: nvs_handle_t, key: [*:0]const u8, value: i64) esp_err_t;
pub extern fn nvs_set_u64(handle: nvs_handle_t, key: [*:0]const u8, value: u64) esp_err_t;
pub extern fn nvs_set_str(handle: nvs_handle_t, key: [*:0]const u8, value: [*:0]const u8) esp_err_t;
pub extern fn nvs_set_blob(handle: nvs_handle_t, key: [*:0]const u8, value: ?*const anyopaque, length: usize) esp_err_t;
pub extern fn nvs_get_i8(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]i8) esp_err_t;
pub extern fn nvs_get_u8(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]u8) esp_err_t;
pub extern fn nvs_get_i16(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]i16) esp_err_t;
pub extern fn nvs_get_u16(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]u16) esp_err_t;
pub extern fn nvs_get_i32(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]i32) esp_err_t;
pub extern fn nvs_get_u32(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]u32) esp_err_t;
pub extern fn nvs_get_i64(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]i64) esp_err_t;
pub extern fn nvs_get_u64(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]u64) esp_err_t;
pub extern fn nvs_get_str(handle: nvs_handle_t, key: [*:0]const u8, out_value: [*c]u8, length: [*c]usize) esp_err_t;
pub extern fn nvs_get_blob(handle: nvs_handle_t, key: [*:0]const u8, out_value: ?*anyopaque, length: [*c]usize) esp_err_t;
pub extern fn nvs_find_key(handle: nvs_handle_t, key: [*:0]const u8, out_type: [*c]nvs_type_t) esp_err_t;
pub extern fn nvs_erase_key(handle: nvs_handle_t, key: [*:0]const u8) esp_err_t;
pub extern fn nvs_erase_all(handle: nvs_handle_t) esp_err_t;
pub extern fn nvs_commit(handle: nvs_handle_t) esp_err_t;
pub extern fn nvs_close(handle: nvs_handle_t) void;
pub const nvs_stats_t = extern struct {
    used_entries: usize = std.mem.zeroes(usize),
    free_entries: usize = std.mem.zeroes(usize),
    available_entries: usize = std.mem.zeroes(usize),
    total_entries: usize = std.mem.zeroes(usize),
    namespace_count: usize = std.mem.zeroes(usize),
};
pub extern fn nvs_get_stats(part_name: [*:0]const u8, nvs_stats: [*c]nvs_stats_t) esp_err_t;
pub extern fn nvs_get_used_entry_count(handle: nvs_handle_t, used_entries: [*c]usize) esp_err_t;
pub extern fn nvs_entry_find(part_name: [*:0]const u8, namespace_name: [*:0]const u8, @"type": nvs_type_t, output_iterator: [*c]nvs_iterator_t) esp_err_t;
pub extern fn nvs_entry_find_in_handle(handle: nvs_handle_t, @"type": nvs_type_t, output_iterator: [*c]nvs_iterator_t) esp_err_t;
pub extern fn nvs_entry_next(iterator: [*c]nvs_iterator_t) esp_err_t;
pub extern fn nvs_entry_info(iterator: nvs_iterator_t, out_info: [*c]nvs_entry_info_t) esp_err_t;
pub extern fn nvs_release_iterator(iterator: nvs_iterator_t) void;
pub const esp_flash_t = opaque {};
pub const esp_partition_mmap_memory_t = enum(c_uint) {
    ESP_PARTITION_MMAP_DATA = 0,
    ESP_PARTITION_MMAP_INST = 1,
};
pub const esp_partition_mmap_handle_t = u32;
pub const esp_partition_type_t = enum(c_uint) {
    ESP_PARTITION_TYPE_APP = 0,
    ESP_PARTITION_TYPE_DATA = 1,
    ESP_PARTITION_TYPE_ANY = 255,
};
pub const esp_partition_subtype_t = enum(c_uint) {
    ESP_PARTITION_SUBTYPE_APP_FACTORY = 0,
    ESP_PARTITION_SUBTYPE_APP_OTA_MIN = 16,
    ESP_PARTITION_SUBTYPE_APP_OTA_0 = 16,
    ESP_PARTITION_SUBTYPE_APP_OTA_1 = 17,
    ESP_PARTITION_SUBTYPE_APP_OTA_2 = 18,
    ESP_PARTITION_SUBTYPE_APP_OTA_3 = 19,
    ESP_PARTITION_SUBTYPE_APP_OTA_4 = 20,
    ESP_PARTITION_SUBTYPE_APP_OTA_5 = 21,
    ESP_PARTITION_SUBTYPE_APP_OTA_6 = 22,
    ESP_PARTITION_SUBTYPE_APP_OTA_7 = 23,
    ESP_PARTITION_SUBTYPE_APP_OTA_8 = 24,
    ESP_PARTITION_SUBTYPE_APP_OTA_9 = 25,
    ESP_PARTITION_SUBTYPE_APP_OTA_10 = 26,
    ESP_PARTITION_SUBTYPE_APP_OTA_11 = 27,
    ESP_PARTITION_SUBTYPE_APP_OTA_12 = 28,
    ESP_PARTITION_SUBTYPE_APP_OTA_13 = 29,
    ESP_PARTITION_SUBTYPE_APP_OTA_14 = 30,
    ESP_PARTITION_SUBTYPE_APP_OTA_15 = 31,
    ESP_PARTITION_SUBTYPE_APP_OTA_MAX = 32,
    ESP_PARTITION_SUBTYPE_APP_TEST = 32,
    ESP_PARTITION_SUBTYPE_DATA_OTA = 0,
    ESP_PARTITION_SUBTYPE_DATA_PHY = 1,
    ESP_PARTITION_SUBTYPE_DATA_NVS = 2,
    ESP_PARTITION_SUBTYPE_DATA_COREDUMP = 3,
    ESP_PARTITION_SUBTYPE_DATA_NVS_KEYS = 4,
    ESP_PARTITION_SUBTYPE_DATA_EFUSE_EM = 5,
    ESP_PARTITION_SUBTYPE_DATA_UNDEFINED = 6,
    ESP_PARTITION_SUBTYPE_DATA_ESPHTTPD = 128,
    ESP_PARTITION_SUBTYPE_DATA_FAT = 129,
    ESP_PARTITION_SUBTYPE_DATA_SPIFFS = 130,
    ESP_PARTITION_SUBTYPE_DATA_LITTLEFS = 131,
    ESP_PARTITION_SUBTYPE_ANY = 255,
};
pub const esp_partition_iterator_opaque_ = opaque {};
pub const esp_partition_iterator_t = ?*esp_partition_iterator_opaque_;
pub const esp_partition_t = extern struct {
    flash_chip: ?*esp_flash_t = std.mem.zeroes(?*esp_flash_t),
    type: esp_partition_type_t = std.mem.zeroes(esp_partition_type_t),
    subtype: esp_partition_subtype_t = std.mem.zeroes(esp_partition_subtype_t),
    address: u32 = std.mem.zeroes(u32),
    size: u32 = std.mem.zeroes(u32),
    erase_size: u32 = std.mem.zeroes(u32),
    label: [17]u8 = std.mem.zeroes([17]u8),
    encrypted: bool = std.mem.zeroes(bool),
    readonly: bool = std.mem.zeroes(bool),
};
pub extern fn esp_partition_find(@"type": esp_partition_type_t, subtype: esp_partition_subtype_t, label: [*:0]const u8) esp_partition_iterator_t;
pub extern fn esp_partition_find_first(@"type": esp_partition_type_t, subtype: esp_partition_subtype_t, label: [*:0]const u8) [*c]const esp_partition_t;
pub extern fn esp_partition_get(iterator: esp_partition_iterator_t) [*c]const esp_partition_t;
pub extern fn esp_partition_next(iterator: esp_partition_iterator_t) esp_partition_iterator_t;
pub extern fn esp_partition_iterator_release(iterator: esp_partition_iterator_t) void;
pub extern fn esp_partition_verify(partition: [*c]const esp_partition_t) [*c]const esp_partition_t;
pub extern fn esp_partition_read(partition: [*c]const esp_partition_t, src_offset: usize, dst: ?*anyopaque, size: usize) esp_err_t;
pub extern fn esp_partition_write(partition: [*c]const esp_partition_t, dst_offset: usize, src: ?*const anyopaque, size: usize) esp_err_t;
pub extern fn esp_partition_read_raw(partition: [*c]const esp_partition_t, src_offset: usize, dst: ?*anyopaque, size: usize) esp_err_t;
pub extern fn esp_partition_write_raw(partition: [*c]const esp_partition_t, dst_offset: usize, src: ?*const anyopaque, size: usize) esp_err_t;
pub extern fn esp_partition_erase_range(partition: [*c]const esp_partition_t, offset: usize, size: usize) esp_err_t;
pub extern fn esp_partition_mmap(partition: [*c]const esp_partition_t, offset: usize, size: usize, memory: esp_partition_mmap_memory_t, out_ptr: [*c]?*const anyopaque, out_handle: [*c]esp_partition_mmap_handle_t) esp_err_t;
pub extern fn esp_partition_munmap(handle: esp_partition_mmap_handle_t) void;
pub extern fn esp_partition_get_sha256(partition: [*c]const esp_partition_t, sha_256: [*c]u8) esp_err_t;
pub extern fn esp_partition_check_identity(partition_1: [*c]const esp_partition_t, partition_2: [*c]const esp_partition_t) bool;
pub extern fn esp_partition_register_external(flash_chip: ?*esp_flash_t, offset: usize, size: usize, label: [*:0]const u8, @"type": esp_partition_type_t, subtype: esp_partition_subtype_t, out_partition: [*c][*c]const esp_partition_t) esp_err_t;
pub extern fn esp_partition_deregister_external(partition: [*c]const esp_partition_t) esp_err_t;
pub extern fn esp_partition_unload_all() void;
pub const nvs_sec_cfg_t = extern struct {
    eky: [32]u8 = std.mem.zeroes([32]u8),
    tky: [32]u8 = std.mem.zeroes([32]u8),
};
pub const nvs_flash_generate_keys_t = ?*const fn (?*const anyopaque, [*c]nvs_sec_cfg_t) callconv(.C) esp_err_t;
pub const nvs_flash_read_cfg_t = ?*const fn (?*const anyopaque, [*c]nvs_sec_cfg_t) callconv(.C) esp_err_t;
pub const nvs_sec_scheme_t = extern struct {
    scheme_id: c_int = std.mem.zeroes(c_int),
    scheme_data: ?*anyopaque = null,
    nvs_flash_key_gen: nvs_flash_generate_keys_t = std.mem.zeroes(nvs_flash_generate_keys_t),
    nvs_flash_read_cfg: nvs_flash_read_cfg_t = std.mem.zeroes(nvs_flash_read_cfg_t),
};
pub extern fn nvs_flash_init() esp_err_t;
pub extern fn nvs_flash_init_partition(partition_label: [*:0]const u8) esp_err_t;
pub extern fn nvs_flash_init_partition_ptr(partition: [*c]const esp_partition_t) esp_err_t;
pub extern fn nvs_flash_deinit() esp_err_t;
pub extern fn nvs_flash_deinit_partition(partition_label: [*:0]const u8) esp_err_t;
pub extern fn nvs_flash_erase() esp_err_t;
pub extern fn nvs_flash_erase_partition(part_name: [*:0]const u8) esp_err_t;
pub extern fn nvs_flash_erase_partition_ptr(partition: [*c]const esp_partition_t) esp_err_t;
pub extern fn nvs_flash_secure_init(cfg: [*c]nvs_sec_cfg_t) esp_err_t;
pub extern fn nvs_flash_secure_init_partition(partition_label: [*:0]const u8, cfg: [*c]nvs_sec_cfg_t) esp_err_t;
pub extern fn nvs_flash_generate_keys(partition: [*c]const esp_partition_t, cfg: [*c]nvs_sec_cfg_t) esp_err_t;
pub extern fn nvs_flash_read_security_cfg(partition: [*c]const esp_partition_t, cfg: [*c]nvs_sec_cfg_t) esp_err_t;
pub extern fn nvs_flash_register_security_scheme(scheme_cfg: [*c]nvs_sec_scheme_t) esp_err_t;
pub extern fn nvs_flash_get_default_security_scheme() [*c]nvs_sec_scheme_t;
pub extern fn nvs_flash_generate_keys_v2(scheme_cfg: [*c]nvs_sec_scheme_t, cfg: [*c]nvs_sec_cfg_t) esp_err_t;
pub extern fn nvs_flash_read_security_cfg_v2(scheme_cfg: [*c]nvs_sec_scheme_t, cfg: [*c]nvs_sec_cfg_t) esp_err_t;

pub const esp_bt_mode_t = enum(c_uint) {
    ESP_BT_MODE_IDLE = 0,
    ESP_BT_MODE_BLE = 1,
    ESP_BT_MODE_CLASSIC_BT = 2,
    ESP_BT_MODE_BTDM = 3,
};
pub const esp_bt_ctrl_hci_tl_t = enum(c_uint) {
    ESP_BT_CTRL_HCI_TL_UART = 0,
    ESP_BT_CTRL_HCI_TL_VHCI = 1,
};
pub const esp_ble_ce_len_t = enum(c_uint) {
    ESP_BLE_CE_LEN_TYPE_ORIG = 0,
    ESP_BLE_CE_LEN_TYPE_CE = 1,
    ESP_BLE_CE_LEN_TYPE_SD = 1,
};
pub const esp_bt_sleep_mode_t = enum(c_uint) {
    ESP_BT_SLEEP_MODE_NONE = 0,
    ESP_BT_SLEEP_MODE_1 = 1,
};
pub const esp_bt_sleep_clock_t = enum(c_uint) {
    ESP_BT_SLEEP_CLOCK_NONE = 0,
    ESP_BT_SLEEP_CLOCK_MAIN_XTAL = 1,
    ESP_BT_SLEEP_CLOCK_EXT_32K_XTAL = 2,
    ESP_BT_SLEEP_CLOCK_RTC_SLOW = 3,
    ESP_BT_SLEEP_CLOCK_FPGA_32K = 4,
};
const enum_unnamed_15 = enum(c_uint) {
    ESP_BT_ANT_IDX_0 = 0,
    ESP_BT_ANT_IDX_1 = 1,
};
const enum_unnamed_16 = enum(c_uint) {
    ESP_BT_COEX_PHY_CODED_TX_RX_TIME_LIMIT_FORCE_DISABLE = 0,
    ESP_BT_COEX_PHY_CODED_TX_RX_TIME_LIMIT_FORCE_ENABLE = 1,
};
pub const esp_bt_hci_tl_callback_t = ?*const fn (?*anyopaque, u8) callconv(.C) void;
pub const esp_bt_hci_tl_t = extern struct {
    _magic: u32 = std.mem.zeroes(u32),
    _version: u32 = std.mem.zeroes(u32),
    _reserved: u32 = std.mem.zeroes(u32),
    _open: ?*const fn () callconv(.C) c_int = std.mem.zeroes(?*const fn () callconv(.C) c_int),
    _close: ?*const fn () callconv(.C) void = std.mem.zeroes(?*const fn () callconv(.C) void),
    _finish_transfers: ?*const fn () callconv(.C) void = std.mem.zeroes(?*const fn () callconv(.C) void),
    _recv: ?*const fn ([*c]u8, u32, esp_bt_hci_tl_callback_t, ?*anyopaque) callconv(.C) void = std.mem.zeroes(?*const fn ([*c]u8, u32, esp_bt_hci_tl_callback_t, ?*anyopaque) callconv(.C) void),
    _send: ?*const fn ([*c]u8, u32, esp_bt_hci_tl_callback_t, ?*anyopaque) callconv(.C) void = std.mem.zeroes(?*const fn ([*c]u8, u32, esp_bt_hci_tl_callback_t, ?*anyopaque) callconv(.C) void),
    _flow_off: ?*const fn () callconv(.C) bool = std.mem.zeroes(?*const fn () callconv(.C) bool),
    _flow_on: ?*const fn () callconv(.C) void = std.mem.zeroes(?*const fn () callconv(.C) void),
};
pub const esp_bt_controller_config_t = extern struct {
    magic: u32 = std.mem.zeroes(u32),
    version: u32 = std.mem.zeroes(u32),
    controller_task_stack_size: u16 = std.mem.zeroes(u16),
    controller_task_prio: u8 = std.mem.zeroes(u8),
    controller_task_run_cpu: u8 = std.mem.zeroes(u8),
    bluetooth_mode: u8 = std.mem.zeroes(u8),
    ble_max_act: u8 = std.mem.zeroes(u8),
    sleep_mode: u8 = std.mem.zeroes(u8),
    sleep_clock: u8 = std.mem.zeroes(u8),
    ble_st_acl_tx_buf_nb: u8 = std.mem.zeroes(u8),
    ble_hw_cca_check: u8 = std.mem.zeroes(u8),
    ble_adv_dup_filt_max: u16 = std.mem.zeroes(u16),
    coex_param_en: bool = std.mem.zeroes(bool),
    ce_len_type: u8 = std.mem.zeroes(u8),
    coex_use_hooks: bool = std.mem.zeroes(bool),
    hci_tl_type: u8 = std.mem.zeroes(u8),
    hci_tl_funcs: [*c]esp_bt_hci_tl_t = std.mem.zeroes([*c]esp_bt_hci_tl_t),
    txant_dft: u8 = std.mem.zeroes(u8),
    rxant_dft: u8 = std.mem.zeroes(u8),
    txpwr_dft: u8 = std.mem.zeroes(u8),
    cfg_mask: u32 = std.mem.zeroes(u32),
    scan_duplicate_mode: u8 = std.mem.zeroes(u8),
    scan_duplicate_type: u8 = std.mem.zeroes(u8),
    normal_adv_size: u16 = std.mem.zeroes(u16),
    mesh_adv_size: u16 = std.mem.zeroes(u16),
    coex_phy_coded_tx_rx_time_limit: u8 = std.mem.zeroes(u8),
    hw_target_code: u32 = std.mem.zeroes(u32),
    slave_ce_len_min: u8 = std.mem.zeroes(u8),
    hw_recorrect_en: u8 = std.mem.zeroes(u8),
    cca_thresh: u8 = std.mem.zeroes(u8),
    scan_backoff_upperlimitmax: u16 = std.mem.zeroes(u16),
    dup_list_refresh_period: u16 = std.mem.zeroes(u16),
    ble_50_feat_supp: bool = std.mem.zeroes(bool),
    ble_cca_mode: u8 = std.mem.zeroes(u8),
    ble_data_lenth_zero_aux: u8 = std.mem.zeroes(u8),
};
pub const esp_bt_controller_status_t = enum(c_uint) {
    ESP_BT_CONTROLLER_STATUS_IDLE = 0,
    ESP_BT_CONTROLLER_STATUS_INITED = 1,
    ESP_BT_CONTROLLER_STATUS_ENABLED = 2,
    ESP_BT_CONTROLLER_STATUS_NUM = 3,
};
pub const esp_ble_power_type_t = enum(c_uint) {
    ESP_BLE_PWR_TYPE_CONN_HDL0 = 0,
    ESP_BLE_PWR_TYPE_CONN_HDL1 = 1,
    ESP_BLE_PWR_TYPE_CONN_HDL2 = 2,
    ESP_BLE_PWR_TYPE_CONN_HDL3 = 3,
    ESP_BLE_PWR_TYPE_CONN_HDL4 = 4,
    ESP_BLE_PWR_TYPE_CONN_HDL5 = 5,
    ESP_BLE_PWR_TYPE_CONN_HDL6 = 6,
    ESP_BLE_PWR_TYPE_CONN_HDL7 = 7,
    ESP_BLE_PWR_TYPE_CONN_HDL8 = 8,
    ESP_BLE_PWR_TYPE_ADV = 9,
    ESP_BLE_PWR_TYPE_SCAN = 10,
    ESP_BLE_PWR_TYPE_DEFAULT = 11,
    ESP_BLE_PWR_TYPE_NUM = 12,
};
pub const esp_power_level_t = enum(c_uint) {
    ESP_PWR_LVL_N24 = 0,
    ESP_PWR_LVL_N21 = 1,
    ESP_PWR_LVL_N18 = 2,
    ESP_PWR_LVL_N15 = 3,
    ESP_PWR_LVL_N12 = 4,
    ESP_PWR_LVL_N9 = 5,
    ESP_PWR_LVL_N6 = 6,
    ESP_PWR_LVL_N3 = 7,
    ESP_PWR_LVL_N0 = 8,
    ESP_PWR_LVL_P3 = 9,
    ESP_PWR_LVL_P6 = 10,
    ESP_PWR_LVL_P9 = 11,
    ESP_PWR_LVL_P12 = 12,
    ESP_PWR_LVL_P15 = 13,
    ESP_PWR_LVL_P18 = 14,
    ESP_PWR_LVL_P21 = 15,
    ESP_PWR_LVL_INVALID = 255,
};
pub extern fn esp_ble_tx_power_set(power_type: esp_ble_power_type_t, power_level: esp_power_level_t) esp_err_t;
pub extern fn esp_ble_tx_power_get(power_type: esp_ble_power_type_t) esp_power_level_t;
pub extern fn esp_bt_controller_init(cfg: [*c]esp_bt_controller_config_t) esp_err_t;
pub extern fn esp_bt_controller_deinit() esp_err_t;
pub extern fn esp_bt_controller_enable(mode: esp_bt_mode_t) esp_err_t;
pub extern fn esp_bt_controller_disable() esp_err_t;
pub extern fn esp_bt_controller_get_status() esp_bt_controller_status_t;
pub extern fn esp_bt_get_tx_buf_num() u16;
pub const esp_vhci_host_callback = extern struct {
    notify_host_send_available: ?*const fn () callconv(.C) void = std.mem.zeroes(?*const fn () callconv(.C) void),
    notify_host_recv: ?*const fn ([*c]u8, u16) callconv(.C) c_int = std.mem.zeroes(?*const fn ([*c]u8, u16) callconv(.C) c_int),
};
pub const esp_vhci_host_callback_t = esp_vhci_host_callback;
pub extern fn esp_vhci_host_check_send_available() bool;
pub extern fn esp_vhci_host_send_packet(data: [*c]u8, len: u16) void;
pub extern fn esp_vhci_host_register_callback(callback: [*c]const esp_vhci_host_callback_t) esp_err_t;
pub extern fn esp_bt_controller_mem_release(mode: esp_bt_mode_t) esp_err_t;
pub extern fn esp_bt_mem_release(mode: esp_bt_mode_t) esp_err_t;
pub extern fn esp_bt_sleep_enable() esp_err_t;
pub extern fn esp_bt_sleep_disable() esp_err_t;
pub extern fn esp_bt_controller_is_sleeping() bool;
pub extern fn esp_bt_controller_wakeup_request() void;
pub extern fn esp_bt_h4tl_eif_io_event_notify(event: c_int) c_int;
pub extern fn esp_wifi_bt_power_domain_on() void;
pub extern fn esp_wifi_bt_power_domain_off() void;
pub const esp_bluedroid_status_t = enum(c_uint) {
    ESP_BLUEDROID_STATUS_UNINITIALIZED = 0,
    ESP_BLUEDROID_STATUS_INITIALIZED = 1,
    ESP_BLUEDROID_STATUS_ENABLED = 2,
};
pub const esp_bluedroid_config_t = extern struct {
    ssp_en: bool = std.mem.zeroes(bool),
};
pub extern fn esp_bluedroid_get_status() esp_bluedroid_status_t;
pub extern fn esp_bluedroid_enable() esp_err_t;
pub extern fn esp_bluedroid_disable() esp_err_t;
pub extern fn esp_bluedroid_init() esp_err_t;
pub extern fn esp_bluedroid_init_with_cfg(cfg: [*c]esp_bluedroid_config_t) esp_err_t;
pub extern fn esp_bluedroid_deinit() esp_err_t;
pub const esp_bt_status_t = enum(c_uint) {
    ESP_BT_STATUS_SUCCESS = 0,
    ESP_BT_STATUS_FAIL = 1,
    ESP_BT_STATUS_NOT_READY = 2,
    ESP_BT_STATUS_NOMEM = 3,
    ESP_BT_STATUS_BUSY = 4,
    ESP_BT_STATUS_DONE = 5,
    ESP_BT_STATUS_UNSUPPORTED = 6,
    ESP_BT_STATUS_PARM_INVALID = 7,
    ESP_BT_STATUS_UNHANDLED = 8,
    ESP_BT_STATUS_AUTH_FAILURE = 9,
    ESP_BT_STATUS_RMT_DEV_DOWN = 10,
    ESP_BT_STATUS_AUTH_REJECTED = 11,
    ESP_BT_STATUS_INVALID_STATIC_RAND_ADDR = 12,
    ESP_BT_STATUS_PENDING = 13,
    ESP_BT_STATUS_UNACCEPT_CONN_INTERVAL = 14,
    ESP_BT_STATUS_PARAM_OUT_OF_RANGE = 15,
    ESP_BT_STATUS_TIMEOUT = 16,
    ESP_BT_STATUS_PEER_LE_DATA_LEN_UNSUPPORTED = 17,
    ESP_BT_STATUS_CONTROL_LE_DATA_LEN_UNSUPPORTED = 18,
    ESP_BT_STATUS_ERR_ILLEGAL_PARAMETER_FMT = 19,
    ESP_BT_STATUS_MEMORY_FULL = 20,
    ESP_BT_STATUS_EIR_TOO_LARGE = 21,
    ESP_BT_STATUS_HCI_SUCCESS = 256,
    ESP_BT_STATUS_HCI_ILLEGAL_COMMAND = 257,
    ESP_BT_STATUS_HCI_NO_CONNECTION = 258,
    ESP_BT_STATUS_HCI_HW_FAILURE = 259,
    ESP_BT_STATUS_HCI_PAGE_TIMEOUT = 260,
    ESP_BT_STATUS_HCI_AUTH_FAILURE = 261,
    ESP_BT_STATUS_HCI_KEY_MISSING = 262,
    ESP_BT_STATUS_HCI_MEMORY_FULL = 263,
    ESP_BT_STATUS_HCI_CONNECTION_TOUT = 264,
    ESP_BT_STATUS_HCI_MAX_NUM_OF_CONNECTIONS = 265,
    ESP_BT_STATUS_HCI_MAX_NUM_OF_SCOS = 266,
    ESP_BT_STATUS_HCI_CONNECTION_EXISTS = 267,
    ESP_BT_STATUS_HCI_COMMAND_DISALLOWED = 268,
    ESP_BT_STATUS_HCI_HOST_REJECT_RESOURCES = 269,
    ESP_BT_STATUS_HCI_HOST_REJECT_SECURITY = 270,
    ESP_BT_STATUS_HCI_HOST_REJECT_DEVICE = 271,
    ESP_BT_STATUS_HCI_HOST_TIMEOUT = 272,
    ESP_BT_STATUS_HCI_UNSUPPORTED_VALUE = 273,
    ESP_BT_STATUS_HCI_ILLEGAL_PARAMETER_FMT = 274,
    ESP_BT_STATUS_HCI_PEER_USER = 275,
    ESP_BT_STATUS_HCI_PEER_LOW_RESOURCES = 276,
    ESP_BT_STATUS_HCI_PEER_POWER_OFF = 277,
    ESP_BT_STATUS_HCI_CONN_CAUSE_LOCAL_HOST = 278,
    ESP_BT_STATUS_HCI_REPEATED_ATTEMPTS = 279,
    ESP_BT_STATUS_HCI_PAIRING_NOT_ALLOWED = 280,
    ESP_BT_STATUS_HCI_UNKNOWN_LMP_PDU = 281,
    ESP_BT_STATUS_HCI_UNSUPPORTED_REM_FEATURE = 282,
    ESP_BT_STATUS_HCI_SCO_OFFSET_REJECTED = 283,
    ESP_BT_STATUS_HCI_SCO_INTERVAL_REJECTED = 284,
    ESP_BT_STATUS_HCI_SCO_AIR_MODE = 285,
    ESP_BT_STATUS_HCI_INVALID_LMP_PARAM = 286,
    ESP_BT_STATUS_HCI_UNSPECIFIED = 287,
    ESP_BT_STATUS_HCI_UNSUPPORTED_LMP_PARAMETERS = 288,
    ESP_BT_STATUS_HCI_ROLE_CHANGE_NOT_ALLOWED = 289,
    ESP_BT_STATUS_HCI_LMP_RESPONSE_TIMEOUT = 290,
    ESP_BT_STATUS_HCI_LMP_ERR_TRANS_COLLISION = 291,
    ESP_BT_STATUS_HCI_LMP_PDU_NOT_ALLOWED = 292,
    ESP_BT_STATUS_HCI_ENCRY_MODE_NOT_ACCEPTABLE = 293,
    ESP_BT_STATUS_HCI_UNIT_KEY_USED = 294,
    ESP_BT_STATUS_HCI_QOS_NOT_SUPPORTED = 295,
    ESP_BT_STATUS_HCI_INSTANT_PASSED = 296,
    ESP_BT_STATUS_HCI_PAIRING_WITH_UNIT_KEY_NOT_SUPPORTED = 297,
    ESP_BT_STATUS_HCI_DIFF_TRANSACTION_COLLISION = 298,
    ESP_BT_STATUS_HCI_UNDEFINED_0x2B = 299,
    ESP_BT_STATUS_HCI_QOS_UNACCEPTABLE_PARAM = 300,
    ESP_BT_STATUS_HCI_QOS_REJECTED = 301,
    ESP_BT_STATUS_HCI_CHAN_CLASSIF_NOT_SUPPORTED = 302,
    ESP_BT_STATUS_HCI_INSUFFCIENT_SECURITY = 303,
    ESP_BT_STATUS_HCI_PARAM_OUT_OF_RANGE = 304,
    ESP_BT_STATUS_HCI_UNDEFINED_0x31 = 305,
    ESP_BT_STATUS_HCI_ROLE_SWITCH_PENDING = 306,
    ESP_BT_STATUS_HCI_UNDEFINED_0x33 = 307,
    ESP_BT_STATUS_HCI_RESERVED_SLOT_VIOLATION = 308,
    ESP_BT_STATUS_HCI_ROLE_SWITCH_FAILED = 309,
    ESP_BT_STATUS_HCI_INQ_RSP_DATA_TOO_LARGE = 310,
    ESP_BT_STATUS_HCI_SIMPLE_PAIRING_NOT_SUPPORTED = 311,
    ESP_BT_STATUS_HCI_HOST_BUSY_PAIRING = 312,
    ESP_BT_STATUS_HCI_REJ_NO_SUITABLE_CHANNEL = 313,
    ESP_BT_STATUS_HCI_CONTROLLER_BUSY = 314,
    ESP_BT_STATUS_HCI_UNACCEPT_CONN_INTERVAL = 315,
    ESP_BT_STATUS_HCI_DIRECTED_ADVERTISING_TIMEOUT = 316,
    ESP_BT_STATUS_HCI_CONN_TOUT_DUE_TO_MIC_FAILURE = 317,
    ESP_BT_STATUS_HCI_CONN_FAILED_ESTABLISHMENT = 318,
    ESP_BT_STATUS_HCI_MAC_CONNECTION_FAILED = 319,
};
pub const esp_bt_octet16_t = [16]u8;
pub const esp_bt_octet8_t = [8]u8;
pub const esp_link_key = [16]u8;
const union_unnamed_17 = extern union {
    uuid16: u16,
    uuid32: u32,
    uuid128: [16]u8,
};
pub const esp_bt_uuid_t = extern struct {
    len: u16 align(1) = std.mem.zeroes(u16),
    uuid: union_unnamed_17 align(1) = std.mem.zeroes(union_unnamed_17),
};
pub const esp_bt_dev_type_t = enum(c_uint) {
    ESP_BT_DEVICE_TYPE_BREDR = 1,
    ESP_BT_DEVICE_TYPE_BLE = 2,
    ESP_BT_DEVICE_TYPE_DUMO = 3,
};
pub const esp_bd_addr_t = [6]u8;
pub const esp_ble_addr_type_t = enum(c_uint) {
    BLE_ADDR_TYPE_PUBLIC = 0,
    BLE_ADDR_TYPE_RANDOM = 1,
    BLE_ADDR_TYPE_RPA_PUBLIC = 2,
    BLE_ADDR_TYPE_RPA_RANDOM = 3,
};
pub const esp_ble_wl_addr_type_t = enum(c_uint) {
    BLE_WL_ADDR_TYPE_PUBLIC = 0,
    BLE_WL_ADDR_TYPE_RANDOM = 1,
};
pub const esp_ble_key_mask_t = u8;
pub const esp_bt_dev_coex_op_t = u8;
pub const esp_bt_dev_coex_type_t = enum(c_uint) {
    ESP_BT_DEV_COEX_TYPE_BLE = 1,
    ESP_BT_DEV_COEX_TYPE_BT = 2,
};
pub const esp_bt_dev_cb_event_t = enum(c_uint) {
    ESP_BT_DEV_NAME_RES_EVT = 0,
    ESP_BT_DEV_EVT_MAX = 1,
};
pub const name_res_param_18 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    name: [*c]u8 = std.mem.zeroes([*c]u8),
};
pub const esp_bt_dev_cb_param_t = extern union {
    name_res: name_res_param_18,
};
pub const esp_bt_dev_cb_t = ?*const fn (esp_bt_dev_cb_event_t, [*c]esp_bt_dev_cb_param_t) callconv(.C) void;
pub extern fn esp_bt_dev_register_callback(callback: esp_bt_dev_cb_t) esp_err_t;
pub extern fn esp_bt_dev_get_address() [*:0]const u8;
pub extern fn esp_bt_dev_set_device_name(name: [*:0]const u8) esp_err_t;
pub extern fn esp_bt_dev_get_device_name() esp_err_t;
pub extern fn esp_bt_dev_coex_status_config(@"type": esp_bt_dev_coex_type_t, op: esp_bt_dev_coex_op_t, status: u8) esp_err_t;
pub extern fn esp_bt_config_file_path_update(file_path: [*:0]const u8) esp_err_t;
pub const wifi_mode_t = enum(c_uint) {
    WIFI_MODE_NULL = 0,
    WIFI_MODE_STA = 1,
    WIFI_MODE_AP = 2,
    WIFI_MODE_APSTA = 3,
    WIFI_MODE_NAN = 4,
    WIFI_MODE_MAX = 5,
};
pub const wifi_interface_t = enum(c_uint) {
    WIFI_IF_STA = 0,
    WIFI_IF_AP = 1,
    WIFI_IF_NAN = 2,
    WIFI_IF_MAX = 3,
};
pub const wifi_country_policy_t = enum(c_uint) {
    WIFI_COUNTRY_POLICY_AUTO = 0,
    WIFI_COUNTRY_POLICY_MANUAL = 1,
};
pub const wifi_country_t = extern struct {
    cc: [3]u8 = std.mem.zeroes([3]u8),
    schan: u8 = std.mem.zeroes(u8),
    nchan: u8 = std.mem.zeroes(u8),
    max_tx_power: i8 = std.mem.zeroes(i8),
    policy: wifi_country_policy_t = std.mem.zeroes(wifi_country_policy_t),
};
pub const wifi_auth_mode_t = enum(c_uint) {
    WIFI_AUTH_OPEN = 0,
    WIFI_AUTH_WEP = 1,
    WIFI_AUTH_WPA_PSK = 2,
    WIFI_AUTH_WPA2_PSK = 3,
    WIFI_AUTH_WPA_WPA2_PSK = 4,
    WIFI_AUTH_ENTERPRISE = 5,
    WIFI_AUTH_WPA2_ENTERPRISE = 5,
    WIFI_AUTH_WPA3_PSK = 6,
    WIFI_AUTH_WPA2_WPA3_PSK = 7,
    WIFI_AUTH_WAPI_PSK = 8,
    WIFI_AUTH_OWE = 9,
    WIFI_AUTH_WPA3_ENT_192 = 10,
    WIFI_AUTH_WPA3_EXT_PSK = 11,
    WIFI_AUTH_WPA3_EXT_PSK_MIXED_MODE = 12,
    WIFI_AUTH_MAX = 13,
};
pub const wifi_err_reason_t = enum(c_uint) {
    WIFI_REASON_UNSPECIFIED = 1,
    WIFI_REASON_AUTH_EXPIRE = 2,
    WIFI_REASON_AUTH_LEAVE = 3,
    WIFI_REASON_ASSOC_EXPIRE = 4,
    WIFI_REASON_ASSOC_TOOMANY = 5,
    WIFI_REASON_NOT_AUTHED = 6,
    WIFI_REASON_NOT_ASSOCED = 7,
    WIFI_REASON_ASSOC_LEAVE = 8,
    WIFI_REASON_ASSOC_NOT_AUTHED = 9,
    WIFI_REASON_DISASSOC_PWRCAP_BAD = 10,
    WIFI_REASON_DISASSOC_SUPCHAN_BAD = 11,
    WIFI_REASON_BSS_TRANSITION_DISASSOC = 12,
    WIFI_REASON_IE_INVALID = 13,
    WIFI_REASON_MIC_FAILURE = 14,
    WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT = 15,
    WIFI_REASON_GROUP_KEY_UPDATE_TIMEOUT = 16,
    WIFI_REASON_IE_IN_4WAY_DIFFERS = 17,
    WIFI_REASON_GROUP_CIPHER_INVALID = 18,
    WIFI_REASON_PAIRWISE_CIPHER_INVALID = 19,
    WIFI_REASON_AKMP_INVALID = 20,
    WIFI_REASON_UNSUPP_RSN_IE_VERSION = 21,
    WIFI_REASON_INVALID_RSN_IE_CAP = 22,
    WIFI_REASON_802_1X_AUTH_FAILED = 23,
    WIFI_REASON_CIPHER_SUITE_REJECTED = 24,
    WIFI_REASON_TDLS_PEER_UNREACHABLE = 25,
    WIFI_REASON_TDLS_UNSPECIFIED = 26,
    WIFI_REASON_SSP_REQUESTED_DISASSOC = 27,
    WIFI_REASON_NO_SSP_ROAMING_AGREEMENT = 28,
    WIFI_REASON_BAD_CIPHER_OR_AKM = 29,
    WIFI_REASON_NOT_AUTHORIZED_THIS_LOCATION = 30,
    WIFI_REASON_SERVICE_CHANGE_PERCLUDES_TS = 31,
    WIFI_REASON_UNSPECIFIED_QOS = 32,
    WIFI_REASON_NOT_ENOUGH_BANDWIDTH = 33,
    WIFI_REASON_MISSING_ACKS = 34,
    WIFI_REASON_EXCEEDED_TXOP = 35,
    WIFI_REASON_STA_LEAVING = 36,
    WIFI_REASON_END_BA = 37,
    WIFI_REASON_UNKNOWN_BA = 38,
    WIFI_REASON_TIMEOUT = 39,
    WIFI_REASON_PEER_INITIATED = 46,
    WIFI_REASON_AP_INITIATED = 47,
    WIFI_REASON_INVALID_FT_ACTION_FRAME_COUNT = 48,
    WIFI_REASON_INVALID_PMKID = 49,
    WIFI_REASON_INVALID_MDE = 50,
    WIFI_REASON_INVALID_FTE = 51,
    WIFI_REASON_TRANSMISSION_LINK_ESTABLISH_FAILED = 67,
    WIFI_REASON_ALTERATIVE_CHANNEL_OCCUPIED = 68,
    WIFI_REASON_BEACON_TIMEOUT = 200,
    WIFI_REASON_NO_AP_FOUND = 201,
    WIFI_REASON_AUTH_FAIL = 202,
    WIFI_REASON_ASSOC_FAIL = 203,
    WIFI_REASON_HANDSHAKE_TIMEOUT = 204,
    WIFI_REASON_CONNECTION_FAIL = 205,
    WIFI_REASON_AP_TSF_RESET = 206,
    WIFI_REASON_ROAMING = 207,
    WIFI_REASON_ASSOC_COMEBACK_TIME_TOO_LONG = 208,
    WIFI_REASON_SA_QUERY_TIMEOUT = 209,
    WIFI_REASON_NO_AP_FOUND_W_COMPATIBLE_SECURITY = 210,
    WIFI_REASON_NO_AP_FOUND_IN_AUTHMODE_THRESHOLD = 211,
    WIFI_REASON_NO_AP_FOUND_IN_RSSI_THRESHOLD = 212,
};
pub const wifi_second_chan_t = enum(c_uint) {
    WIFI_SECOND_CHAN_NONE = 0,
    WIFI_SECOND_CHAN_ABOVE = 1,
    WIFI_SECOND_CHAN_BELOW = 2,
};
pub const wifi_scan_type_t = enum(c_uint) {
    WIFI_SCAN_TYPE_ACTIVE = 0,
    WIFI_SCAN_TYPE_PASSIVE = 1,
};
pub const wifi_active_scan_time_t = extern struct {
    min: u32 = std.mem.zeroes(u32),
    max: u32 = std.mem.zeroes(u32),
};
pub const wifi_scan_time_t = extern struct {
    active: wifi_active_scan_time_t = std.mem.zeroes(wifi_active_scan_time_t),
    passive: u32 = std.mem.zeroes(u32),
};
pub const wifi_scan_config_t = extern struct {
    ssid: [*c]u8 = std.mem.zeroes([*c]u8),
    bssid: [*c]u8 = std.mem.zeroes([*c]u8),
    channel: u8 = std.mem.zeroes(u8),
    show_hidden: bool = std.mem.zeroes(bool),
    scan_type: wifi_scan_type_t = std.mem.zeroes(wifi_scan_type_t),
    scan_time: wifi_scan_time_t = std.mem.zeroes(wifi_scan_time_t),
    home_chan_dwell_time: u8 = std.mem.zeroes(u8),
};
pub const wifi_cipher_type_t = enum(c_uint) {
    WIFI_CIPHER_TYPE_NONE = 0,
    WIFI_CIPHER_TYPE_WEP40 = 1,
    WIFI_CIPHER_TYPE_WEP104 = 2,
    WIFI_CIPHER_TYPE_TKIP = 3,
    WIFI_CIPHER_TYPE_CCMP = 4,
    WIFI_CIPHER_TYPE_TKIP_CCMP = 5,
    WIFI_CIPHER_TYPE_AES_CMAC128 = 6,
    WIFI_CIPHER_TYPE_SMS4 = 7,
    WIFI_CIPHER_TYPE_GCMP = 8,
    WIFI_CIPHER_TYPE_GCMP256 = 9,
    WIFI_CIPHER_TYPE_AES_GMAC128 = 10,
    WIFI_CIPHER_TYPE_AES_GMAC256 = 11,
    WIFI_CIPHER_TYPE_UNKNOWN = 12,
};
pub const wifi_ant_t = enum(c_uint) {
    WIFI_ANT_ANT0 = 0,
    WIFI_ANT_ANT1 = 1,
    WIFI_ANT_MAX = 2,
};
// esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:207:13: warning: struct demoted to opaque type - has bitfield
pub const wifi_he_ap_info_t = opaque {};
// esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:224:14: warning: struct demoted to opaque type - has bitfield
pub const wifi_ap_record_t = opaque {};
pub const wifi_scan_method_t = enum(c_uint) {
    WIFI_FAST_SCAN = 0,
    WIFI_ALL_CHANNEL_SCAN = 1,
};
pub const wifi_sort_method_t = enum(c_uint) {
    WIFI_CONNECT_AP_BY_SIGNAL = 0,
    WIFI_CONNECT_AP_BY_SECURITY = 1,
};
pub const wifi_scan_threshold_t = extern struct {
    rssi: i8 = std.mem.zeroes(i8),
    authmode: wifi_auth_mode_t = std.mem.zeroes(wifi_auth_mode_t),
};

pub const wifi_ps_type_t = enum(c_uint) {
    WIFI_PS_NONE = 0,
    WIFI_PS_MIN_MODEM = 1,
    WIFI_PS_MAX_MODEM = 2,
};
pub const wifi_bandwidth_t = enum(c_uint) {
    WIFI_BW_HT20 = 1,
    WIFI_BW_HT40 = 2,
};
pub const wifi_pmf_config_t = extern struct {
    capable: bool = std.mem.zeroes(bool),
    required: bool = std.mem.zeroes(bool),
};
pub const wifi_sae_pwe_method_t = enum(c_uint) {
    WPA3_SAE_PWE_UNSPECIFIED = 0,
    WPA3_SAE_PWE_HUNT_AND_PECK = 1,
    WPA3_SAE_PWE_HASH_TO_ELEMENT = 2,
    WPA3_SAE_PWE_BOTH = 3,
};
pub const wifi_sae_pk_mode_t = enum(c_uint) {
    WPA3_SAE_PK_MODE_AUTOMATIC = 0,
    WPA3_SAE_PK_MODE_ONLY = 1,
    WPA3_SAE_PK_MODE_DISABLED = 2,
};
pub const wifi_ap_config_t = extern struct {
    ssid: [32]u8 = std.mem.zeroes([32]u8),
    password: [64]u8 = std.mem.zeroes([64]u8),
    ssid_len: u8 = std.mem.zeroes(u8),
    channel: u8 = std.mem.zeroes(u8),
    authmode: wifi_auth_mode_t = std.mem.zeroes(wifi_auth_mode_t),
    ssid_hidden: u8 = std.mem.zeroes(u8),
    max_connection: u8 = std.mem.zeroes(u8),
    beacon_interval: u16 = std.mem.zeroes(u16),
    pairwise_cipher: wifi_cipher_type_t = std.mem.zeroes(wifi_cipher_type_t),
    ftm_responder: bool = std.mem.zeroes(bool),
    pmf_cfg: wifi_pmf_config_t = std.mem.zeroes(wifi_pmf_config_t),
    sae_pwe_h2e: wifi_sae_pwe_method_t = std.mem.zeroes(wifi_sae_pwe_method_t),
}; // esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:321:14: warning: struct demoted to opaque type - has bitfield
pub const wifi_sta_config_t = opaque {};
pub const wifi_nan_config_t = extern struct {
    op_channel: u8 = std.mem.zeroes(u8),
    master_pref: u8 = std.mem.zeroes(u8),
    scan_time: u8 = std.mem.zeroes(u8),
    warm_up_sec: u16 = std.mem.zeroes(u16),
};
pub const wifi_config_t = extern union {
    ap: wifi_ap_config_t,
    sta: wifi_sta_config_t,
    nan: wifi_nan_config_t,
}; // esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:371:14: warning: struct demoted to opaque type - has bitfield
pub const wifi_sta_info_t = opaque {};
pub const wifi_storage_t = enum(c_uint) {
    WIFI_STORAGE_FLASH = 0,
    WIFI_STORAGE_RAM = 1,
};
pub const wifi_vendor_ie_type_t = enum(c_uint) {
    WIFI_VND_IE_TYPE_BEACON = 0,
    WIFI_VND_IE_TYPE_PROBE_REQ = 1,
    WIFI_VND_IE_TYPE_PROBE_RESP = 2,
    WIFI_VND_IE_TYPE_ASSOC_REQ = 3,
    WIFI_VND_IE_TYPE_ASSOC_RESP = 4,
};
pub const wifi_vendor_ie_id_t = enum(c_uint) {
    WIFI_VND_IE_ID_0 = 0,
    WIFI_VND_IE_ID_1 = 1,
};
pub const wifi_phy_mode_t = enum(c_uint) {
    WIFI_PHY_MODE_LR = 0,
    WIFI_PHY_MODE_11B = 1,
    WIFI_PHY_MODE_11G = 2,
    WIFI_PHY_MODE_HT20 = 3,
    WIFI_PHY_MODE_HT40 = 4,
    WIFI_PHY_MODE_HE20 = 5,
};
pub const vendor_ie_data_t = extern struct {
    element_id: u8 align(1) = std.mem.zeroes(u8),
    length: u8 = std.mem.zeroes(u8),
    vendor_oui: [3]u8 = std.mem.zeroes([3]u8),
    vendor_oui_type: u8 = std.mem.zeroes(u8),
    pub fn payload(self: anytype) std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 6)));
    }
};
pub const wifi_promiscuous_pkt_type_t = enum(c_uint) {
    WIFI_PKT_MGMT = 0,
    WIFI_PKT_CTRL = 1,
    WIFI_PKT_DATA = 2,
    WIFI_PKT_MISC = 3,
};
pub const wifi_promiscuous_filter_t = extern struct {
    filter_mask: u32 = std.mem.zeroes(u32),
};
pub const wifi_csi_info_t = extern struct {
    rx_ctrl: wifi_pkt_rx_ctrl_t = std.mem.zeroes(wifi_pkt_rx_ctrl_t),
    mac: [6]u8 = std.mem.zeroes([6]u8),
    dmac: [6]u8 = std.mem.zeroes([6]u8),
    first_word_invalid: bool = std.mem.zeroes(bool),
    buf: [*c]i8 = std.mem.zeroes([*c]i8),
    len: u16 = std.mem.zeroes(u16),
    hdr: [*c]u8 = std.mem.zeroes([*c]u8),
    payload: [*c]u8 = std.mem.zeroes([*c]u8),
    payload_len: u16 = std.mem.zeroes(u16),
};
// esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:490:13: warning: struct demoted to opaque type - has bitfield
pub const wifi_ant_gpio_t = opaque {};
pub const wifi_ant_gpio_config_t = extern struct {
    gpio_cfg: [4]wifi_ant_gpio_t = std.mem.zeroes([4]wifi_ant_gpio_t),
};
pub const wifi_ant_mode_t = enum(c_uint) {
    WIFI_ANT_MODE_ANT0 = 0,
    WIFI_ANT_MODE_ANT1 = 1,
    WIFI_ANT_MODE_AUTO = 2,
    WIFI_ANT_MODE_MAX = 3,
};
// esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:521:21: warning: struct demoted to opaque type - has bitfield
pub const wifi_ant_config_t = opaque {};
pub const wifi_action_rx_cb_t = ?*const fn ([*c]u8, [*c]u8, usize, u8) callconv(.C) c_int;
pub const wifi_action_tx_req_t = extern struct {
    ifx: wifi_interface_t align(4) = std.mem.zeroes(wifi_interface_t),
    dest_mac: [6]u8 = std.mem.zeroes([6]u8),
    no_ack: bool = std.mem.zeroes(bool),
    rx_cb: wifi_action_rx_cb_t = std.mem.zeroes(wifi_action_rx_cb_t),
    data_len: u32 = std.mem.zeroes(u32),
    pub fn data(self: anytype) std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 20)));
    }
};
pub const wifi_ftm_initiator_cfg_t = extern struct {
    resp_mac: [6]u8 = std.mem.zeroes([6]u8),
    channel: u8 = std.mem.zeroes(u8),
    frm_count: u8 = std.mem.zeroes(u8),
    burst_period: u16 = std.mem.zeroes(u16),
};

pub const wifi_nan_service_type_t = enum(c_uint) {
    NAN_PUBLISH_SOLICITED = 0,
    NAN_PUBLISH_UNSOLICITED = 1,
    NAN_SUBSCRIBE_ACTIVE = 2,
    NAN_SUBSCRIBE_PASSIVE = 3,
};
// esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:591:13: warning: struct demoted to opaque type - has bitfield
pub const wifi_nan_publish_cfg_t = opaque {};
// esp-idf/components/esp_wifi/include/esp_wifi_types_generic.h:605:13: warning: struct demoted to opaque type - has bitfield
pub const wifi_nan_subscribe_cfg_t = opaque {};
pub const wifi_nan_followup_params_t = extern struct {
    inst_id: u8 = std.mem.zeroes(u8),
    peer_inst_id: u8 = std.mem.zeroes(u8),
    peer_mac: [6]u8 = std.mem.zeroes([6]u8),
    svc_info: [64]u8 = std.mem.zeroes([64]u8),
};
pub const wifi_nan_datapath_req_t = extern struct {
    pub_id: u8 = std.mem.zeroes(u8),
    peer_mac: [6]u8 = std.mem.zeroes([6]u8),
    confirm_required: bool = std.mem.zeroes(bool),
};
pub const wifi_nan_datapath_resp_t = extern struct {
    accept: bool = std.mem.zeroes(bool),
    ndp_id: u8 = std.mem.zeroes(u8),
    peer_mac: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_nan_datapath_end_req_t = extern struct {
    ndp_id: u8 = std.mem.zeroes(u8),
    peer_mac: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_phy_rate_t = enum(c_uint) {
    WIFI_PHY_RATE_1M_L = 0,
    WIFI_PHY_RATE_2M_L = 1,
    WIFI_PHY_RATE_5M_L = 2,
    WIFI_PHY_RATE_11M_L = 3,
    WIFI_PHY_RATE_2M_S = 5,
    WIFI_PHY_RATE_5M_S = 6,
    WIFI_PHY_RATE_11M_S = 7,
    WIFI_PHY_RATE_48M = 8,
    WIFI_PHY_RATE_24M = 9,
    WIFI_PHY_RATE_12M = 10,
    WIFI_PHY_RATE_6M = 11,
    WIFI_PHY_RATE_54M = 12,
    WIFI_PHY_RATE_36M = 13,
    WIFI_PHY_RATE_18M = 14,
    WIFI_PHY_RATE_9M = 15,
    WIFI_PHY_RATE_MCS0_LGI = 16,
    WIFI_PHY_RATE_MCS1_LGI = 17,
    WIFI_PHY_RATE_MCS2_LGI = 18,
    WIFI_PHY_RATE_MCS3_LGI = 19,
    WIFI_PHY_RATE_MCS4_LGI = 20,
    WIFI_PHY_RATE_MCS5_LGI = 21,
    WIFI_PHY_RATE_MCS6_LGI = 22,
    WIFI_PHY_RATE_MCS7_LGI = 23,
    WIFI_PHY_RATE_MCS8_LGI = 24,
    WIFI_PHY_RATE_MCS9_LGI = 25,
    WIFI_PHY_RATE_MCS0_SGI = 26,
    WIFI_PHY_RATE_MCS1_SGI = 27,
    WIFI_PHY_RATE_MCS2_SGI = 28,
    WIFI_PHY_RATE_MCS3_SGI = 29,
    WIFI_PHY_RATE_MCS4_SGI = 30,
    WIFI_PHY_RATE_MCS5_SGI = 31,
    WIFI_PHY_RATE_MCS6_SGI = 32,
    WIFI_PHY_RATE_MCS7_SGI = 33,
    WIFI_PHY_RATE_MCS8_SGI = 34,
    WIFI_PHY_RATE_MCS9_SGI = 35,
    WIFI_PHY_RATE_LORA_250K = 41,
    WIFI_PHY_RATE_LORA_500K = 42,
    WIFI_PHY_RATE_MAX = 43,
};
pub const wifi_event_t = enum(c_uint) {
    WIFI_EVENT_WIFI_READY = 0,
    WIFI_EVENT_SCAN_DONE = 1,
    WIFI_EVENT_STA_START = 2,
    WIFI_EVENT_STA_STOP = 3,
    WIFI_EVENT_STA_CONNECTED = 4,
    WIFI_EVENT_STA_DISCONNECTED = 5,
    WIFI_EVENT_STA_AUTHMODE_CHANGE = 6,
    WIFI_EVENT_STA_WPS_ER_SUCCESS = 7,
    WIFI_EVENT_STA_WPS_ER_FAILED = 8,
    WIFI_EVENT_STA_WPS_ER_TIMEOUT = 9,
    WIFI_EVENT_STA_WPS_ER_PIN = 10,
    WIFI_EVENT_STA_WPS_ER_PBC_OVERLAP = 11,
    WIFI_EVENT_AP_START = 12,
    WIFI_EVENT_AP_STOP = 13,
    WIFI_EVENT_AP_STACONNECTED = 14,
    WIFI_EVENT_AP_STADISCONNECTED = 15,
    WIFI_EVENT_AP_PROBEREQRECVED = 16,
    WIFI_EVENT_FTM_REPORT = 17,
    WIFI_EVENT_STA_BSS_RSSI_LOW = 18,
    WIFI_EVENT_ACTION_TX_STATUS = 19,
    WIFI_EVENT_ROC_DONE = 20,
    WIFI_EVENT_STA_BEACON_TIMEOUT = 21,
    WIFI_EVENT_CONNECTIONLESS_MODULE_WAKE_INTERVAL_START = 22,
    WIFI_EVENT_AP_WPS_RG_SUCCESS = 23,
    WIFI_EVENT_AP_WPS_RG_FAILED = 24,
    WIFI_EVENT_AP_WPS_RG_TIMEOUT = 25,
    WIFI_EVENT_AP_WPS_RG_PIN = 26,
    WIFI_EVENT_AP_WPS_RG_PBC_OVERLAP = 27,
    WIFI_EVENT_ITWT_SETUP = 28,
    WIFI_EVENT_ITWT_TEARDOWN = 29,
    WIFI_EVENT_ITWT_PROBE = 30,
    WIFI_EVENT_ITWT_SUSPEND = 31,
    WIFI_EVENT_NAN_STARTED = 32,
    WIFI_EVENT_NAN_STOPPED = 33,
    WIFI_EVENT_NAN_SVC_MATCH = 34,
    WIFI_EVENT_NAN_REPLIED = 35,
    WIFI_EVENT_NAN_RECEIVE = 36,
    WIFI_EVENT_NDP_INDICATION = 37,
    WIFI_EVENT_NDP_CONFIRM = 38,
    WIFI_EVENT_NDP_TERMINATED = 39,
    WIFI_EVENT_HOME_CHANNEL_CHANGE = 40,
    WIFI_EVENT_MAX = 41,
};
pub extern const WIFI_EVENT: esp_event_base_t;
pub const wifi_event_sta_scan_done_t = extern struct {
    status: u32 = std.mem.zeroes(u32),
    number: u8 = std.mem.zeroes(u8),
    scan_id: u8 = std.mem.zeroes(u8),
};
pub const wifi_event_sta_connected_t = extern struct {
    ssid: [32]u8 = std.mem.zeroes([32]u8),
    ssid_len: u8 = std.mem.zeroes(u8),
    bssid: [6]u8 = std.mem.zeroes([6]u8),
    channel: u8 = std.mem.zeroes(u8),
    authmode: wifi_auth_mode_t = std.mem.zeroes(wifi_auth_mode_t),
    aid: u16 = std.mem.zeroes(u16),
};
pub const wifi_event_sta_disconnected_t = extern struct {
    ssid: [32]u8 = std.mem.zeroes([32]u8),
    ssid_len: u8 = std.mem.zeroes(u8),
    bssid: [6]u8 = std.mem.zeroes([6]u8),
    reason: u8 = std.mem.zeroes(u8),
    rssi: i8 = std.mem.zeroes(i8),
};
pub const wifi_event_sta_authmode_change_t = extern struct {
    old_mode: wifi_auth_mode_t = std.mem.zeroes(wifi_auth_mode_t),
    new_mode: wifi_auth_mode_t = std.mem.zeroes(wifi_auth_mode_t),
};
pub const wifi_event_sta_wps_er_pin_t = extern struct {
    pin_code: [8]u8 = std.mem.zeroes([8]u8),
};
pub const wifi_event_sta_wps_fail_reason_t = enum(c_uint) {
    WPS_FAIL_REASON_NORMAL = 0,
    WPS_FAIL_REASON_RECV_M2D = 1,
    WPS_FAIL_REASON_MAX = 2,
};
const unnamed_19 = extern struct {
    ssid: [32]u8 = std.mem.zeroes([32]u8),
    passphrase: [64]u8 = std.mem.zeroes([64]u8),
};
pub const wifi_event_sta_wps_er_success_t = extern struct {
    ap_cred_cnt: u8 = std.mem.zeroes(u8),
    ap_cred: [3]unnamed_19 = std.mem.zeroes([3]unnamed_19),
};
pub const wifi_event_ap_staconnected_t = extern struct {
    mac: [6]u8 = std.mem.zeroes([6]u8),
    aid: u8 = std.mem.zeroes(u8),
    is_mesh_child: bool = std.mem.zeroes(bool),
};
pub const wifi_event_ap_stadisconnected_t = extern struct {
    mac: [6]u8 = std.mem.zeroes([6]u8),
    aid: u8 = std.mem.zeroes(u8),
    is_mesh_child: bool = std.mem.zeroes(bool),
    reason: u8 = std.mem.zeroes(u8),
};
pub const wifi_event_ap_probe_req_rx_t = extern struct {
    rssi: c_int = std.mem.zeroes(c_int),
    mac: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_event_bss_rssi_low_t = extern struct {
    rssi: i32 = std.mem.zeroes(i32),
};
pub const wifi_event_home_channel_change_t = extern struct {
    old_chan: u8 = std.mem.zeroes(u8),
    old_snd: wifi_second_chan_t = std.mem.zeroes(wifi_second_chan_t),
    new_chan: u8 = std.mem.zeroes(u8),
    new_snd: wifi_second_chan_t = std.mem.zeroes(wifi_second_chan_t),
};
pub const wifi_ftm_status_t = enum(c_uint) {
    FTM_STATUS_SUCCESS = 0,
    FTM_STATUS_UNSUPPORTED = 1,
    FTM_STATUS_CONF_REJECTED = 2,
    FTM_STATUS_NO_RESPONSE = 3,
    FTM_STATUS_FAIL = 4,
};
pub const wifi_ftm_report_entry_t = extern struct {
    dlog_token: u8 = std.mem.zeroes(u8),
    rssi: i8 = std.mem.zeroes(i8),
    rtt: u32 = std.mem.zeroes(u32),
    t1: u64 = std.mem.zeroes(u64),
    t2: u64 = std.mem.zeroes(u64),
    t3: u64 = std.mem.zeroes(u64),
    t4: u64 = std.mem.zeroes(u64),
};
pub const wifi_event_ftm_report_t = extern struct {
    peer_mac: [6]u8 = std.mem.zeroes([6]u8),
    status: wifi_ftm_status_t = std.mem.zeroes(wifi_ftm_status_t),
    rtt_raw: u32 = std.mem.zeroes(u32),
    rtt_est: u32 = std.mem.zeroes(u32),
    dist_est: u32 = std.mem.zeroes(u32),
    ftm_report_data: [*c]wifi_ftm_report_entry_t = std.mem.zeroes([*c]wifi_ftm_report_entry_t),
    ftm_report_num_entries: u8 = std.mem.zeroes(u8),
};
pub const wifi_event_action_tx_status_t = extern struct {
    ifx: wifi_interface_t = std.mem.zeroes(wifi_interface_t),
    context: u32 = std.mem.zeroes(u32),
    da: [6]u8 = std.mem.zeroes([6]u8),
    status: u8 = std.mem.zeroes(u8),
};
pub const wifi_event_roc_done_t = extern struct {
    context: u32 = std.mem.zeroes(u32),
};
pub const wifi_event_ap_wps_rg_pin_t = extern struct {
    pin_code: [8]u8 = std.mem.zeroes([8]u8),
};
pub const wps_fail_reason_t = enum(c_uint) {
    WPS_AP_FAIL_REASON_NORMAL = 0,
    WPS_AP_FAIL_REASON_CONFIG = 1,
    WPS_AP_FAIL_REASON_AUTH = 2,
    WPS_AP_FAIL_REASON_MAX = 3,
};
pub const wifi_event_ap_wps_rg_fail_reason_t = extern struct {
    reason: wps_fail_reason_t = std.mem.zeroes(wps_fail_reason_t),
    peer_macaddr: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_event_ap_wps_rg_success_t = extern struct {
    peer_macaddr: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_event_nan_svc_match_t = extern struct {
    subscribe_id: u8 = std.mem.zeroes(u8),
    publish_id: u8 = std.mem.zeroes(u8),
    pub_if_mac: [6]u8 = std.mem.zeroes([6]u8),
    update_pub_id: bool = std.mem.zeroes(bool),
};
pub const wifi_event_nan_replied_t = extern struct {
    publish_id: u8 = std.mem.zeroes(u8),
    subscribe_id: u8 = std.mem.zeroes(u8),
    sub_if_mac: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_event_nan_receive_t = extern struct {
    inst_id: u8 = std.mem.zeroes(u8),
    peer_inst_id: u8 = std.mem.zeroes(u8),
    peer_if_mac: [6]u8 = std.mem.zeroes([6]u8),
    peer_svc_info: [64]u8 = std.mem.zeroes([64]u8),
};
pub const wifi_event_ndp_indication_t = extern struct {
    publish_id: u8 = std.mem.zeroes(u8),
    ndp_id: u8 = std.mem.zeroes(u8),
    peer_nmi: [6]u8 = std.mem.zeroes([6]u8),
    peer_ndi: [6]u8 = std.mem.zeroes([6]u8),
    svc_info: [64]u8 = std.mem.zeroes([64]u8),
};
pub const wifi_event_ndp_confirm_t = extern struct {
    status: u8 = std.mem.zeroes(u8),
    ndp_id: u8 = std.mem.zeroes(u8),
    peer_nmi: [6]u8 = std.mem.zeroes([6]u8),
    peer_ndi: [6]u8 = std.mem.zeroes([6]u8),
    own_ndi: [6]u8 = std.mem.zeroes([6]u8),
    svc_info: [64]u8 = std.mem.zeroes([64]u8),
};
pub const wifi_event_ndp_terminated_t = extern struct {
    reason: u8 = std.mem.zeroes(u8),
    ndp_id: u8 = std.mem.zeroes(u8),
    init_ndi: [6]u8 = std.mem.zeroes([6]u8),
};
pub const wifi_sta_list_t = extern struct {
    sta: [10]wifi_sta_info_t = std.mem.zeroes([10]wifi_sta_info_t),
    num: c_int = std.mem.zeroes(c_int),
};
// esp-idf/components/esp_wifi/include/local/esp_wifi_types_native.h:38:12: warning: struct demoted to opaque type - has bitfield
pub const wifi_pkt_rx_ctrl_t = opaque {};
pub const wifi_csi_config_t = extern struct {
    lltf_en: bool = std.mem.zeroes(bool),
    htltf_en: bool = std.mem.zeroes(bool),
    stbc_htltf2_en: bool = std.mem.zeroes(bool),
    ltf_merge_en: bool = std.mem.zeroes(bool),
    channel_filter_en: bool = std.mem.zeroes(bool),
    manu_scale: bool = std.mem.zeroes(bool),
    shift: u8 = std.mem.zeroes(u8),
    dump_ack_en: bool = std.mem.zeroes(bool),
};
pub const wifi_promiscuous_pkt_t = extern struct {
    rx_ctrl: wifi_pkt_rx_ctrl_t align(4) = std.mem.zeroes(wifi_pkt_rx_ctrl_t),
    pub fn payload(self: anytype) std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8) {
        const Intermediate = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 48)));
    }
};
pub const esp_blufi_cb_event_t = enum(c_uint) {
    ESP_BLUFI_EVENT_INIT_FINISH = 0,
    ESP_BLUFI_EVENT_DEINIT_FINISH = 1,
    ESP_BLUFI_EVENT_SET_WIFI_OPMODE = 2,
    ESP_BLUFI_EVENT_BLE_CONNECT = 3,
    ESP_BLUFI_EVENT_BLE_DISCONNECT = 4,
    ESP_BLUFI_EVENT_REQ_CONNECT_TO_AP = 5,
    ESP_BLUFI_EVENT_REQ_DISCONNECT_FROM_AP = 6,
    ESP_BLUFI_EVENT_GET_WIFI_STATUS = 7,
    ESP_BLUFI_EVENT_DEAUTHENTICATE_STA = 8,
    ESP_BLUFI_EVENT_RECV_STA_BSSID = 9,
    ESP_BLUFI_EVENT_RECV_STA_SSID = 10,
    ESP_BLUFI_EVENT_RECV_STA_PASSWD = 11,
    ESP_BLUFI_EVENT_RECV_SOFTAP_SSID = 12,
    ESP_BLUFI_EVENT_RECV_SOFTAP_PASSWD = 13,
    ESP_BLUFI_EVENT_RECV_SOFTAP_MAX_CONN_NUM = 14,
    ESP_BLUFI_EVENT_RECV_SOFTAP_AUTH_MODE = 15,
    ESP_BLUFI_EVENT_RECV_SOFTAP_CHANNEL = 16,
    ESP_BLUFI_EVENT_RECV_USERNAME = 17,
    ESP_BLUFI_EVENT_RECV_CA_CERT = 18,
    ESP_BLUFI_EVENT_RECV_CLIENT_CERT = 19,
    ESP_BLUFI_EVENT_RECV_SERVER_CERT = 20,
    ESP_BLUFI_EVENT_RECV_CLIENT_PRIV_KEY = 21,
    ESP_BLUFI_EVENT_RECV_SERVER_PRIV_KEY = 22,
    ESP_BLUFI_EVENT_RECV_SLAVE_DISCONNECT_BLE = 23,
    ESP_BLUFI_EVENT_GET_WIFI_LIST = 24,
    ESP_BLUFI_EVENT_REPORT_ERROR = 25,
    ESP_BLUFI_EVENT_RECV_CUSTOM_DATA = 26,
};
pub const esp_blufi_sta_conn_state_t = enum(c_uint) {
    ESP_BLUFI_STA_CONN_SUCCESS = 0,
    ESP_BLUFI_STA_CONN_FAIL = 1,
    ESP_BLUFI_STA_CONNECTING = 2,
    ESP_BLUFI_STA_NO_IP = 3,
};
pub const esp_blufi_init_state_t = enum(c_uint) {
    ESP_BLUFI_INIT_OK = 0,
    ESP_BLUFI_INIT_FAILED = 1,
};
pub const esp_blufi_deinit_state_t = enum(c_uint) {
    ESP_BLUFI_DEINIT_OK = 0,
    ESP_BLUFI_DEINIT_FAILED = 1,
};
pub const esp_blufi_error_state_t = enum(c_uint) {
    ESP_BLUFI_SEQUENCE_ERROR = 0,
    ESP_BLUFI_CHECKSUM_ERROR = 1,
    ESP_BLUFI_DECRYPT_ERROR = 2,
    ESP_BLUFI_ENCRYPT_ERROR = 3,
    ESP_BLUFI_INIT_SECURITY_ERROR = 4,
    ESP_BLUFI_DH_MALLOC_ERROR = 5,
    ESP_BLUFI_DH_PARAM_ERROR = 6,
    ESP_BLUFI_READ_PARAM_ERROR = 7,
    ESP_BLUFI_MAKE_PUBLIC_ERROR = 8,
    ESP_BLUFI_DATA_FORMAT_ERROR = 9,
    ESP_BLUFI_CALC_MD5_ERROR = 10,
    ESP_BLUFI_WIFI_SCAN_FAIL = 11,
    ESP_BLUFI_MSG_STATE_ERROR = 12,
};
pub const esp_blufi_extra_info_t = extern struct {
    sta_bssid: [6]u8 = std.mem.zeroes([6]u8),
    sta_bssid_set: bool = std.mem.zeroes(bool),
    sta_ssid: [*c]u8 = std.mem.zeroes([*c]u8),
    sta_ssid_len: c_int = std.mem.zeroes(c_int),
    sta_passwd: [*c]u8 = std.mem.zeroes([*c]u8),
    sta_passwd_len: c_int = std.mem.zeroes(c_int),
    softap_ssid: [*c]u8 = std.mem.zeroes([*c]u8),
    softap_ssid_len: c_int = std.mem.zeroes(c_int),
    softap_passwd: [*c]u8 = std.mem.zeroes([*c]u8),
    softap_passwd_len: c_int = std.mem.zeroes(c_int),
    softap_authmode: u8 = std.mem.zeroes(u8),
    softap_authmode_set: bool = std.mem.zeroes(bool),
    softap_max_conn_num: u8 = std.mem.zeroes(u8),
    softap_max_conn_num_set: bool = std.mem.zeroes(bool),
    softap_channel: u8 = std.mem.zeroes(u8),
    softap_channel_set: bool = std.mem.zeroes(bool),
    sta_max_conn_retry: u8 = std.mem.zeroes(u8),
    sta_max_conn_retry_set: bool = std.mem.zeroes(bool),
    sta_conn_end_reason: u8 = std.mem.zeroes(u8),
    sta_conn_end_reason_set: bool = std.mem.zeroes(bool),
    sta_conn_rssi: i8 = std.mem.zeroes(i8),
    sta_conn_rssi_set: bool = std.mem.zeroes(bool),
};
pub const esp_blufi_ap_record_t = extern struct {
    ssid: [33]u8 = std.mem.zeroes([33]u8),
    rssi: i8 = std.mem.zeroes(i8),
};
pub const esp_blufi_bd_addr_t = [6]u8;
pub const blufi_init_finish_evt_param_20 = extern struct {
    state: esp_blufi_init_state_t = std.mem.zeroes(esp_blufi_init_state_t),
};
pub const blufi_deinit_finish_evt_param_21 = extern struct {
    state: esp_blufi_deinit_state_t = std.mem.zeroes(esp_blufi_deinit_state_t),
};
pub const blufi_set_wifi_mode_evt_param_22 = extern struct {
    op_mode: wifi_mode_t = std.mem.zeroes(wifi_mode_t),
};
pub const blufi_connect_evt_param_23 = extern struct {
    remote_bda: esp_blufi_bd_addr_t = std.mem.zeroes(esp_blufi_bd_addr_t),
    server_if: u8 = std.mem.zeroes(u8),
    conn_id: u16 = std.mem.zeroes(u16),
};
pub const blufi_disconnect_evt_param_24 = extern struct {
    remote_bda: esp_blufi_bd_addr_t = std.mem.zeroes(esp_blufi_bd_addr_t),
};
pub const blufi_recv_sta_bssid_evt_param_25 = extern struct {
    bssid: [6]u8 = std.mem.zeroes([6]u8),
};
pub const blufi_recv_sta_ssid_evt_param_26 = extern struct {
    ssid: [*c]u8 = std.mem.zeroes([*c]u8),
    ssid_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_sta_passwd_evt_param_27 = extern struct {
    passwd: [*c]u8 = std.mem.zeroes([*c]u8),
    passwd_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_softap_ssid_evt_param_28 = extern struct {
    ssid: [*c]u8 = std.mem.zeroes([*c]u8),
    ssid_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_softap_passwd_evt_param_29 = extern struct {
    passwd: [*c]u8 = std.mem.zeroes([*c]u8),
    passwd_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_softap_max_conn_num_evt_param_30 = extern struct {
    max_conn_num: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_softap_auth_mode_evt_param_31 = extern struct {
    auth_mode: wifi_auth_mode_t = std.mem.zeroes(wifi_auth_mode_t),
};
pub const blufi_recv_softap_channel_evt_param_32 = extern struct {
    channel: u8 = std.mem.zeroes(u8),
};
pub const blufi_recv_username_evt_param_33 = extern struct {
    name: [*c]u8 = std.mem.zeroes([*c]u8),
    name_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_ca_evt_param_34 = extern struct {
    cert: [*c]u8 = std.mem.zeroes([*c]u8),
    cert_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_client_cert_evt_param_35 = extern struct {
    cert: [*c]u8 = std.mem.zeroes([*c]u8),
    cert_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_server_cert_evt_param_36 = extern struct {
    cert: [*c]u8 = std.mem.zeroes([*c]u8),
    cert_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_client_pkey_evt_param_37 = extern struct {
    pkey: [*c]u8 = std.mem.zeroes([*c]u8),
    pkey_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_recv_server_pkey_evt_param_38 = extern struct {
    pkey: [*c]u8 = std.mem.zeroes([*c]u8),
    pkey_len: c_int = std.mem.zeroes(c_int),
};
pub const blufi_get_error_evt_param_39 = extern struct {
    state: esp_blufi_error_state_t = std.mem.zeroes(esp_blufi_error_state_t),
};
pub const blufi_recv_custom_data_evt_param_40 = extern struct {
    data: [*c]u8 = std.mem.zeroes([*c]u8),
    data_len: u32 = std.mem.zeroes(u32),
};
pub const esp_blufi_cb_param_t = extern union {
    init_finish: blufi_init_finish_evt_param_20,
    deinit_finish: blufi_deinit_finish_evt_param_21,
    wifi_mode: blufi_set_wifi_mode_evt_param_22,
    connect: blufi_connect_evt_param_23,
    disconnect: blufi_disconnect_evt_param_24,
    sta_bssid: blufi_recv_sta_bssid_evt_param_25,
    sta_ssid: blufi_recv_sta_ssid_evt_param_26,
    sta_passwd: blufi_recv_sta_passwd_evt_param_27,
    softap_ssid: blufi_recv_softap_ssid_evt_param_28,
    softap_passwd: blufi_recv_softap_passwd_evt_param_29,
    softap_max_conn_num: blufi_recv_softap_max_conn_num_evt_param_30,
    softap_auth_mode: blufi_recv_softap_auth_mode_evt_param_31,
    softap_channel: blufi_recv_softap_channel_evt_param_32,
    username: blufi_recv_username_evt_param_33,
    ca: blufi_recv_ca_evt_param_34,
    client_cert: blufi_recv_client_cert_evt_param_35,
    server_cert: blufi_recv_server_cert_evt_param_36,
    client_pkey: blufi_recv_client_pkey_evt_param_37,
    server_pkey: blufi_recv_server_pkey_evt_param_38,
    report_error: blufi_get_error_evt_param_39,
    custom_data: blufi_recv_custom_data_evt_param_40,
};
pub const esp_blufi_event_cb_t = ?*const fn (esp_blufi_cb_event_t, [*c]esp_blufi_cb_param_t) callconv(.C) void;
pub const esp_blufi_negotiate_data_handler_t = ?*const fn ([*c]u8, c_int, [*c][*c]u8, [*c]c_int, [*c]bool) callconv(.C) void;
pub const esp_blufi_encrypt_func_t = ?*const fn (u8, [*c]u8, c_int) callconv(.C) c_int;
pub const esp_blufi_decrypt_func_t = ?*const fn (u8, [*c]u8, c_int) callconv(.C) c_int;
pub const esp_blufi_checksum_func_t = ?*const fn (u8, [*c]u8, c_int) callconv(.C) u16;
pub const esp_blufi_callbacks_t = extern struct {
    event_cb: esp_blufi_event_cb_t = std.mem.zeroes(esp_blufi_event_cb_t),
    negotiate_data_handler: esp_blufi_negotiate_data_handler_t = std.mem.zeroes(esp_blufi_negotiate_data_handler_t),
    encrypt_func: esp_blufi_encrypt_func_t = std.mem.zeroes(esp_blufi_encrypt_func_t),
    decrypt_func: esp_blufi_decrypt_func_t = std.mem.zeroes(esp_blufi_decrypt_func_t),
    checksum_func: esp_blufi_checksum_func_t = std.mem.zeroes(esp_blufi_checksum_func_t),
};
pub extern fn esp_blufi_register_callbacks(callbacks: [*c]esp_blufi_callbacks_t) esp_err_t;
pub extern fn esp_blufi_profile_init() esp_err_t;
pub extern fn esp_blufi_profile_deinit() esp_err_t;
pub extern fn esp_blufi_send_wifi_conn_report(opmode: wifi_mode_t, sta_conn_state: esp_blufi_sta_conn_state_t, softap_conn_num: u8, extra_info: [*c]esp_blufi_extra_info_t) esp_err_t;
pub extern fn esp_blufi_send_wifi_list(apCount: u16, list: [*c]esp_blufi_ap_record_t) esp_err_t;
pub extern fn esp_blufi_get_version() u16;
pub extern fn esp_blufi_send_error_info(state: esp_blufi_error_state_t) esp_err_t;
pub extern fn esp_blufi_send_custom_data(data: [*c]u8, data_len: u32) esp_err_t;
pub const esp_ble_key_type_t = u8;
pub const esp_ble_auth_req_t = u8;
pub const esp_ble_io_cap_t = u8;
pub const esp_ble_dtm_pkt_payload_t = u8;
pub const esp_gap_ble_cb_event_t = enum(c_uint) {
    ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT = 0,
    ESP_GAP_BLE_SCAN_RSP_DATA_SET_COMPLETE_EVT = 1,
    ESP_GAP_BLE_SCAN_PARAM_SET_COMPLETE_EVT = 2,
    ESP_GAP_BLE_SCAN_RESULT_EVT = 3,
    ESP_GAP_BLE_ADV_DATA_RAW_SET_COMPLETE_EVT = 4,
    ESP_GAP_BLE_SCAN_RSP_DATA_RAW_SET_COMPLETE_EVT = 5,
    ESP_GAP_BLE_ADV_START_COMPLETE_EVT = 6,
    ESP_GAP_BLE_SCAN_START_COMPLETE_EVT = 7,
    ESP_GAP_BLE_AUTH_CMPL_EVT = 8,
    ESP_GAP_BLE_KEY_EVT = 9,
    ESP_GAP_BLE_SEC_REQ_EVT = 10,
    ESP_GAP_BLE_PASSKEY_NOTIF_EVT = 11,
    ESP_GAP_BLE_PASSKEY_REQ_EVT = 12,
    ESP_GAP_BLE_OOB_REQ_EVT = 13,
    ESP_GAP_BLE_LOCAL_IR_EVT = 14,
    ESP_GAP_BLE_LOCAL_ER_EVT = 15,
    ESP_GAP_BLE_NC_REQ_EVT = 16,
    ESP_GAP_BLE_ADV_STOP_COMPLETE_EVT = 17,
    ESP_GAP_BLE_SCAN_STOP_COMPLETE_EVT = 18,
    ESP_GAP_BLE_SET_STATIC_RAND_ADDR_EVT = 19,
    ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT = 20,
    ESP_GAP_BLE_SET_PKT_LENGTH_COMPLETE_EVT = 21,
    ESP_GAP_BLE_SET_LOCAL_PRIVACY_COMPLETE_EVT = 22,
    ESP_GAP_BLE_REMOVE_BOND_DEV_COMPLETE_EVT = 23,
    ESP_GAP_BLE_CLEAR_BOND_DEV_COMPLETE_EVT = 24,
    ESP_GAP_BLE_GET_BOND_DEV_COMPLETE_EVT = 25,
    ESP_GAP_BLE_READ_RSSI_COMPLETE_EVT = 26,
    ESP_GAP_BLE_UPDATE_WHITELIST_COMPLETE_EVT = 27,
    ESP_GAP_BLE_UPDATE_DUPLICATE_EXCEPTIONAL_LIST_COMPLETE_EVT = 28,
    ESP_GAP_BLE_SET_CHANNELS_EVT = 29,
    ESP_GAP_BLE_READ_PHY_COMPLETE_EVT = 30,
    ESP_GAP_BLE_SET_PREFERRED_DEFAULT_PHY_COMPLETE_EVT = 31,
    ESP_GAP_BLE_SET_PREFERRED_PHY_COMPLETE_EVT = 32,
    ESP_GAP_BLE_EXT_ADV_SET_RAND_ADDR_COMPLETE_EVT = 33,
    ESP_GAP_BLE_EXT_ADV_SET_PARAMS_COMPLETE_EVT = 34,
    ESP_GAP_BLE_EXT_ADV_DATA_SET_COMPLETE_EVT = 35,
    ESP_GAP_BLE_EXT_SCAN_RSP_DATA_SET_COMPLETE_EVT = 36,
    ESP_GAP_BLE_EXT_ADV_START_COMPLETE_EVT = 37,
    ESP_GAP_BLE_EXT_ADV_STOP_COMPLETE_EVT = 38,
    ESP_GAP_BLE_EXT_ADV_SET_REMOVE_COMPLETE_EVT = 39,
    ESP_GAP_BLE_EXT_ADV_SET_CLEAR_COMPLETE_EVT = 40,
    ESP_GAP_BLE_PERIODIC_ADV_SET_PARAMS_COMPLETE_EVT = 41,
    ESP_GAP_BLE_PERIODIC_ADV_DATA_SET_COMPLETE_EVT = 42,
    ESP_GAP_BLE_PERIODIC_ADV_START_COMPLETE_EVT = 43,
    ESP_GAP_BLE_PERIODIC_ADV_STOP_COMPLETE_EVT = 44,
    ESP_GAP_BLE_PERIODIC_ADV_CREATE_SYNC_COMPLETE_EVT = 45,
    ESP_GAP_BLE_PERIODIC_ADV_SYNC_CANCEL_COMPLETE_EVT = 46,
    ESP_GAP_BLE_PERIODIC_ADV_SYNC_TERMINATE_COMPLETE_EVT = 47,
    ESP_GAP_BLE_PERIODIC_ADV_ADD_DEV_COMPLETE_EVT = 48,
    ESP_GAP_BLE_PERIODIC_ADV_REMOVE_DEV_COMPLETE_EVT = 49,
    ESP_GAP_BLE_PERIODIC_ADV_CLEAR_DEV_COMPLETE_EVT = 50,
    ESP_GAP_BLE_SET_EXT_SCAN_PARAMS_COMPLETE_EVT = 51,
    ESP_GAP_BLE_EXT_SCAN_START_COMPLETE_EVT = 52,
    ESP_GAP_BLE_EXT_SCAN_STOP_COMPLETE_EVT = 53,
    ESP_GAP_BLE_PREFER_EXT_CONN_PARAMS_SET_COMPLETE_EVT = 54,
    ESP_GAP_BLE_PHY_UPDATE_COMPLETE_EVT = 55,
    ESP_GAP_BLE_EXT_ADV_REPORT_EVT = 56,
    ESP_GAP_BLE_SCAN_TIMEOUT_EVT = 57,
    ESP_GAP_BLE_ADV_TERMINATED_EVT = 58,
    ESP_GAP_BLE_SCAN_REQ_RECEIVED_EVT = 59,
    ESP_GAP_BLE_CHANNEL_SELECT_ALGORITHM_EVT = 60,
    ESP_GAP_BLE_PERIODIC_ADV_REPORT_EVT = 61,
    ESP_GAP_BLE_PERIODIC_ADV_SYNC_LOST_EVT = 62,
    ESP_GAP_BLE_PERIODIC_ADV_SYNC_ESTAB_EVT = 63,
    ESP_GAP_BLE_SC_OOB_REQ_EVT = 64,
    ESP_GAP_BLE_SC_CR_LOC_OOB_EVT = 65,
    ESP_GAP_BLE_GET_DEV_NAME_COMPLETE_EVT = 66,
    ESP_GAP_BLE_PERIODIC_ADV_RECV_ENABLE_COMPLETE_EVT = 67,
    ESP_GAP_BLE_PERIODIC_ADV_SYNC_TRANS_COMPLETE_EVT = 68,
    ESP_GAP_BLE_PERIODIC_ADV_SET_INFO_TRANS_COMPLETE_EVT = 69,
    ESP_GAP_BLE_SET_PAST_PARAMS_COMPLETE_EVT = 70,
    ESP_GAP_BLE_PERIODIC_ADV_SYNC_TRANS_RECV_EVT = 71,
    ESP_GAP_BLE_DTM_TEST_UPDATE_EVT = 72,
    ESP_GAP_BLE_ADV_CLEAR_COMPLETE_EVT = 73,
    ESP_GAP_BLE_EVT_MAX = 74,
};
pub const esp_gap_ble_channels = [5]u8;
pub const esp_ble_adv_data_type = enum(c_uint) {
    ESP_BLE_AD_TYPE_FLAG = 1,
    ESP_BLE_AD_TYPE_16SRV_PART = 2,
    ESP_BLE_AD_TYPE_16SRV_CMPL = 3,
    ESP_BLE_AD_TYPE_32SRV_PART = 4,
    ESP_BLE_AD_TYPE_32SRV_CMPL = 5,
    ESP_BLE_AD_TYPE_128SRV_PART = 6,
    ESP_BLE_AD_TYPE_128SRV_CMPL = 7,
    ESP_BLE_AD_TYPE_NAME_SHORT = 8,
    ESP_BLE_AD_TYPE_NAME_CMPL = 9,
    ESP_BLE_AD_TYPE_TX_PWR = 10,
    ESP_BLE_AD_TYPE_DEV_CLASS = 13,
    ESP_BLE_AD_TYPE_SM_TK = 16,
    ESP_BLE_AD_TYPE_SM_OOB_FLAG = 17,
    ESP_BLE_AD_TYPE_INT_RANGE = 18,
    ESP_BLE_AD_TYPE_SOL_SRV_UUID = 20,
    ESP_BLE_AD_TYPE_128SOL_SRV_UUID = 21,
    ESP_BLE_AD_TYPE_SERVICE_DATA = 22,
    ESP_BLE_AD_TYPE_PUBLIC_TARGET = 23,
    ESP_BLE_AD_TYPE_RANDOM_TARGET = 24,
    ESP_BLE_AD_TYPE_APPEARANCE = 25,
    ESP_BLE_AD_TYPE_ADV_INT = 26,
    ESP_BLE_AD_TYPE_LE_DEV_ADDR = 27,
    ESP_BLE_AD_TYPE_LE_ROLE = 28,
    ESP_BLE_AD_TYPE_SPAIR_C256 = 29,
    ESP_BLE_AD_TYPE_SPAIR_R256 = 30,
    ESP_BLE_AD_TYPE_32SOL_SRV_UUID = 31,
    ESP_BLE_AD_TYPE_32SERVICE_DATA = 32,
    ESP_BLE_AD_TYPE_128SERVICE_DATA = 33,
    ESP_BLE_AD_TYPE_LE_SECURE_CONFIRM = 34,
    ESP_BLE_AD_TYPE_LE_SECURE_RANDOM = 35,
    ESP_BLE_AD_TYPE_URI = 36,
    ESP_BLE_AD_TYPE_INDOOR_POSITION = 37,
    ESP_BLE_AD_TYPE_TRANS_DISC_DATA = 38,
    ESP_BLE_AD_TYPE_LE_SUPPORT_FEATURE = 39,
    ESP_BLE_AD_TYPE_CHAN_MAP_UPDATE = 40,
    ESP_BLE_AD_MANUFACTURER_SPECIFIC_TYPE = 255,
};
pub const esp_ble_adv_type_t = enum(c_uint) {
    ADV_TYPE_IND = 0,
    ADV_TYPE_DIRECT_IND_HIGH = 1,
    ADV_TYPE_SCAN_IND = 2,
    ADV_TYPE_NONCONN_IND = 3,
    ADV_TYPE_DIRECT_IND_LOW = 4,
};
pub const esp_ble_adv_channel_t = enum(c_uint) {
    ADV_CHNL_37 = 1,
    ADV_CHNL_38 = 2,
    ADV_CHNL_39 = 4,
    ADV_CHNL_ALL = 7,
};
pub const esp_ble_adv_filter_t = enum(c_uint) {
    ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY = 0,
    ADV_FILTER_ALLOW_SCAN_WLST_CON_ANY = 1,
    ADV_FILTER_ALLOW_SCAN_ANY_CON_WLST = 2,
    ADV_FILTER_ALLOW_SCAN_WLST_CON_WLST = 3,
};
pub const esp_ble_sec_act_t = enum(c_uint) {
    ESP_BLE_SEC_ENCRYPT = 1,
    ESP_BLE_SEC_ENCRYPT_NO_MITM = 2,
    ESP_BLE_SEC_ENCRYPT_MITM = 3,
};
pub const esp_ble_sm_param_t = enum(c_uint) {
    ESP_BLE_SM_PASSKEY = 0,
    ESP_BLE_SM_AUTHEN_REQ_MODE = 1,
    ESP_BLE_SM_IOCAP_MODE = 2,
    ESP_BLE_SM_SET_INIT_KEY = 3,
    ESP_BLE_SM_SET_RSP_KEY = 4,
    ESP_BLE_SM_MAX_KEY_SIZE = 5,
    ESP_BLE_SM_MIN_KEY_SIZE = 6,
    ESP_BLE_SM_SET_STATIC_PASSKEY = 7,
    ESP_BLE_SM_CLEAR_STATIC_PASSKEY = 8,
    ESP_BLE_SM_ONLY_ACCEPT_SPECIFIED_SEC_AUTH = 9,
    ESP_BLE_SM_OOB_SUPPORT = 10,
    ESP_BLE_APP_ENC_KEY_SIZE = 11,
    ESP_BLE_SM_MAX_PARAM = 12,
};
pub const esp_ble_dtm_update_evt_t = enum(c_uint) {
    DTM_TX_START_EVT = 0,
    DTM_RX_START_EVT = 1,
    DTM_TEST_STOP_EVT = 2,
};
pub const esp_ble_dtm_tx_t = extern struct {
    tx_channel: u8 = std.mem.zeroes(u8),
    len_of_data: u8 = std.mem.zeroes(u8),
    pkt_payload: esp_ble_dtm_pkt_payload_t = std.mem.zeroes(esp_ble_dtm_pkt_payload_t),
};
pub const esp_ble_dtm_rx_t = extern struct {
    rx_channel: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_adv_params_t = extern struct {
    adv_int_min: u16 = std.mem.zeroes(u16),
    adv_int_max: u16 = std.mem.zeroes(u16),
    adv_type: esp_ble_adv_type_t = std.mem.zeroes(esp_ble_adv_type_t),
    own_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    peer_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    peer_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    channel_map: esp_ble_adv_channel_t = std.mem.zeroes(esp_ble_adv_channel_t),
    adv_filter_policy: esp_ble_adv_filter_t = std.mem.zeroes(esp_ble_adv_filter_t),
};
pub const esp_ble_adv_data_t = extern struct {
    set_scan_rsp: bool = std.mem.zeroes(bool),
    include_name: bool = std.mem.zeroes(bool),
    include_txpower: bool = std.mem.zeroes(bool),
    min_interval: c_int = std.mem.zeroes(c_int),
    max_interval: c_int = std.mem.zeroes(c_int),
    appearance: c_int = std.mem.zeroes(c_int),
    manufacturer_len: u16 = std.mem.zeroes(u16),
    p_manufacturer_data: [*c]u8 = std.mem.zeroes([*c]u8),
    service_data_len: u16 = std.mem.zeroes(u16),
    p_service_data: [*c]u8 = std.mem.zeroes([*c]u8),
    service_uuid_len: u16 = std.mem.zeroes(u16),
    p_service_uuid: [*c]u8 = std.mem.zeroes([*c]u8),
    flag: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_scan_type_t = enum(c_uint) {
    BLE_SCAN_TYPE_PASSIVE = 0,
    BLE_SCAN_TYPE_ACTIVE = 1,
};
pub const esp_ble_scan_filter_t = enum(c_uint) {
    BLE_SCAN_FILTER_ALLOW_ALL = 0,
    BLE_SCAN_FILTER_ALLOW_ONLY_WLST = 1,
    BLE_SCAN_FILTER_ALLOW_UND_RPA_DIR = 2,
    BLE_SCAN_FILTER_ALLOW_WLIST_RPA_DIR = 3,
};
pub const esp_ble_scan_duplicate_t = enum(c_uint) {
    BLE_SCAN_DUPLICATE_DISABLE = 0,
    BLE_SCAN_DUPLICATE_ENABLE = 1,
    BLE_SCAN_DUPLICATE_ENABLE_RESET = 2,
    BLE_SCAN_DUPLICATE_MAX = 3,
};
pub const esp_ble_scan_params_t = extern struct {
    scan_type: esp_ble_scan_type_t = std.mem.zeroes(esp_ble_scan_type_t),
    own_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    scan_filter_policy: esp_ble_scan_filter_t = std.mem.zeroes(esp_ble_scan_filter_t),
    scan_interval: u16 = std.mem.zeroes(u16),
    scan_window: u16 = std.mem.zeroes(u16),
    scan_duplicate: esp_ble_scan_duplicate_t = std.mem.zeroes(esp_ble_scan_duplicate_t),
};
pub const esp_gap_conn_params_t = extern struct {
    interval: u16 = std.mem.zeroes(u16),
    latency: u16 = std.mem.zeroes(u16),
    timeout: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_conn_update_params_t = extern struct {
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    min_int: u16 = std.mem.zeroes(u16),
    max_int: u16 = std.mem.zeroes(u16),
    latency: u16 = std.mem.zeroes(u16),
    timeout: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_pkt_data_length_params_t = extern struct {
    rx_len: u16 = std.mem.zeroes(u16),
    tx_len: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_penc_keys_t = extern struct {
    ltk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    rand: esp_bt_octet8_t = std.mem.zeroes(esp_bt_octet8_t),
    ediv: u16 = std.mem.zeroes(u16),
    sec_level: u8 = std.mem.zeroes(u8),
    key_size: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_pcsrk_keys_t = extern struct {
    counter: u32 = std.mem.zeroes(u32),
    csrk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    sec_level: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_pid_keys_t = extern struct {
    irk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    static_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const esp_ble_lenc_keys_t = extern struct {
    ltk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    div: u16 = std.mem.zeroes(u16),
    key_size: u8 = std.mem.zeroes(u8),
    sec_level: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_lcsrk_keys = extern struct {
    counter: u32 = std.mem.zeroes(u32),
    div: u16 = std.mem.zeroes(u16),
    sec_level: u8 = std.mem.zeroes(u8),
    csrk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
};
pub const esp_ble_sec_key_notif_t = extern struct {
    bd_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    passkey: u32 = std.mem.zeroes(u32),
};
pub const esp_ble_sec_req_t = extern struct {
    bd_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const esp_ble_key_value_t = extern union {
    penc_key: esp_ble_penc_keys_t,
    pcsrk_key: esp_ble_pcsrk_keys_t,
    pid_key: esp_ble_pid_keys_t,
    lenc_key: esp_ble_lenc_keys_t,
    lcsrk_key: esp_ble_lcsrk_keys,
};
pub const esp_ble_bond_key_info_t = extern struct {
    key_mask: esp_ble_key_mask_t = std.mem.zeroes(esp_ble_key_mask_t),
    penc_key: esp_ble_penc_keys_t = std.mem.zeroes(esp_ble_penc_keys_t),
    pcsrk_key: esp_ble_pcsrk_keys_t = std.mem.zeroes(esp_ble_pcsrk_keys_t),
    pid_key: esp_ble_pid_keys_t = std.mem.zeroes(esp_ble_pid_keys_t),
};
pub const esp_ble_bond_dev_t = extern struct {
    bd_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    bond_key: esp_ble_bond_key_info_t = std.mem.zeroes(esp_ble_bond_key_info_t),
};
pub const esp_ble_key_t = extern struct {
    bd_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    key_type: esp_ble_key_type_t = std.mem.zeroes(esp_ble_key_type_t),
    p_key_value: esp_ble_key_value_t = std.mem.zeroes(esp_ble_key_value_t),
};
pub const esp_ble_local_id_keys_t = extern struct {
    ir: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    irk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    dhk: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
};
pub const esp_ble_local_oob_data_t = extern struct {
    oob_c: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
    oob_r: esp_bt_octet16_t = std.mem.zeroes(esp_bt_octet16_t),
};
pub const esp_ble_auth_cmpl_t = extern struct {
    bd_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    key_present: bool = std.mem.zeroes(bool),
    key: esp_link_key = std.mem.zeroes(esp_link_key),
    key_type: u8 = std.mem.zeroes(u8),
    success: bool = std.mem.zeroes(bool),
    fail_reason: u8 = std.mem.zeroes(u8),
    addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    dev_type: esp_bt_dev_type_t = std.mem.zeroes(esp_bt_dev_type_t),
    auth_mode: esp_ble_auth_req_t = std.mem.zeroes(esp_ble_auth_req_t),
};
pub const esp_ble_sec_t = extern union {
    key_notif: esp_ble_sec_key_notif_t,
    ble_req: esp_ble_sec_req_t,
    ble_key: esp_ble_key_t,
    ble_id_keys: esp_ble_local_id_keys_t,
    oob_data: esp_ble_local_oob_data_t,
    auth_cmpl: esp_ble_auth_cmpl_t,
};
pub const esp_gap_search_evt_t = enum(c_uint) {
    ESP_GAP_SEARCH_INQ_RES_EVT = 0,
    ESP_GAP_SEARCH_INQ_CMPL_EVT = 1,
    ESP_GAP_SEARCH_DISC_RES_EVT = 2,
    ESP_GAP_SEARCH_DISC_BLE_RES_EVT = 3,
    ESP_GAP_SEARCH_DISC_CMPL_EVT = 4,
    ESP_GAP_SEARCH_DI_DISC_CMPL_EVT = 5,
    ESP_GAP_SEARCH_SEARCH_CANCEL_CMPL_EVT = 6,
    ESP_GAP_SEARCH_INQ_DISCARD_NUM_EVT = 7,
};
pub const esp_ble_evt_type_t = enum(c_uint) {
    ESP_BLE_EVT_CONN_ADV = 0,
    ESP_BLE_EVT_CONN_DIR_ADV = 1,
    ESP_BLE_EVT_DISC_ADV = 2,
    ESP_BLE_EVT_NON_CONN_ADV = 3,
    ESP_BLE_EVT_SCAN_RSP = 4,
};
pub const esp_ble_wl_operation_t = enum(c_uint) {
    ESP_BLE_WHITELIST_REMOVE = 0,
    ESP_BLE_WHITELIST_ADD = 1,
    ESP_BLE_WHITELIST_CLEAR = 2,
};
pub const esp_bt_duplicate_exceptional_subcode_type_t = enum(c_uint) {
    ESP_BLE_DUPLICATE_EXCEPTIONAL_LIST_ADD = 0,
    ESP_BLE_DUPLICATE_EXCEPTIONAL_LIST_REMOVE = 1,
    ESP_BLE_DUPLICATE_EXCEPTIONAL_LIST_CLEAN = 2,
};
pub const esp_ble_duplicate_exceptional_info_type_t = enum(c_uint) {
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_ADV_ADDR = 0,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_MESH_LINK_ID = 1,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_MESH_BEACON_TYPE = 2,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_MESH_PROV_SRV_ADV = 3,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_MESH_PROXY_SRV_ADV = 4,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_MESH_PROXY_SOLIC_ADV = 5,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_INFO_MESH_URI_ADV = 6,
};
pub const esp_duplicate_scan_exceptional_list_type_t = enum(c_uint) {
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_ADDR_LIST = 1,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_MESH_LINK_ID_LIST = 2,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_MESH_BEACON_TYPE_LIST = 4,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_MESH_PROV_SRV_ADV_LIST = 8,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_MESH_PROXY_SRV_ADV_LIST = 16,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_MESH_PROXY_SOLIC_ADV_LIST = 32,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_MESH_URI_ADV_LIST = 64,
    ESP_BLE_DUPLICATE_SCAN_EXCEPTIONAL_ALL_LIST = 65535,
};
pub const esp_duplicate_info_t = [6]u8;
pub const esp_ble_ext_adv_type_mask_t = u16;
pub const esp_ble_gap_phy_t = u8;
pub const esp_ble_gap_all_phys_t = u8;
pub const esp_ble_gap_pri_phy_t = u8;
pub const esp_ble_gap_phy_mask_t = u8;
pub const esp_ble_gap_prefer_phy_options_t = u16;
pub const esp_ble_ext_scan_cfg_mask_t = u8;
pub const esp_ble_gap_ext_adv_data_status_t = u8;
pub const esp_ble_gap_sync_t = u8;
pub const esp_ble_gap_adv_type_t = u8;
pub const esp_ble_gap_ext_adv_params_t = extern struct {
    type: esp_ble_ext_adv_type_mask_t = std.mem.zeroes(esp_ble_ext_adv_type_mask_t),
    interval_min: u32 = std.mem.zeroes(u32),
    interval_max: u32 = std.mem.zeroes(u32),
    channel_map: esp_ble_adv_channel_t = std.mem.zeroes(esp_ble_adv_channel_t),
    own_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    peer_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    peer_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    filter_policy: esp_ble_adv_filter_t = std.mem.zeroes(esp_ble_adv_filter_t),
    tx_power: i8 = std.mem.zeroes(i8),
    primary_phy: esp_ble_gap_pri_phy_t = std.mem.zeroes(esp_ble_gap_pri_phy_t),
    max_skip: u8 = std.mem.zeroes(u8),
    secondary_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    sid: u8 = std.mem.zeroes(u8),
    scan_req_notif: bool = std.mem.zeroes(bool),
};
pub const esp_ble_ext_scan_cfg_t = extern struct {
    scan_type: esp_ble_scan_type_t = std.mem.zeroes(esp_ble_scan_type_t),
    scan_interval: u16 = std.mem.zeroes(u16),
    scan_window: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_ext_scan_params_t = extern struct {
    own_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    filter_policy: esp_ble_scan_filter_t = std.mem.zeroes(esp_ble_scan_filter_t),
    scan_duplicate: esp_ble_scan_duplicate_t = std.mem.zeroes(esp_ble_scan_duplicate_t),
    cfg_mask: esp_ble_ext_scan_cfg_mask_t = std.mem.zeroes(esp_ble_ext_scan_cfg_mask_t),
    uncoded_cfg: esp_ble_ext_scan_cfg_t = std.mem.zeroes(esp_ble_ext_scan_cfg_t),
    coded_cfg: esp_ble_ext_scan_cfg_t = std.mem.zeroes(esp_ble_ext_scan_cfg_t),
};
pub const esp_ble_gap_conn_params_t = extern struct {
    scan_interval: u16 = std.mem.zeroes(u16),
    scan_window: u16 = std.mem.zeroes(u16),
    interval_min: u16 = std.mem.zeroes(u16),
    interval_max: u16 = std.mem.zeroes(u16),
    latency: u16 = std.mem.zeroes(u16),
    supervision_timeout: u16 = std.mem.zeroes(u16),
    min_ce_len: u16 = std.mem.zeroes(u16),
    max_ce_len: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_gap_ext_adv_t = extern struct {
    instance: u8 = std.mem.zeroes(u8),
    duration: c_int = std.mem.zeroes(c_int),
    max_events: c_int = std.mem.zeroes(c_int),
};
pub const esp_ble_gap_periodic_adv_params_t = extern struct {
    interval_min: u16 = std.mem.zeroes(u16),
    interval_max: u16 = std.mem.zeroes(u16),
    properties: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_gap_periodic_adv_sync_params_t = extern struct {
    filter_policy: esp_ble_gap_sync_t = std.mem.zeroes(esp_ble_gap_sync_t),
    sid: u8 = std.mem.zeroes(u8),
    addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    skip: u16 = std.mem.zeroes(u16),
    sync_timeout: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_gap_ext_adv_reprot_t = extern struct {
    event_type: esp_ble_gap_adv_type_t = std.mem.zeroes(esp_ble_gap_adv_type_t),
    addr_type: u8 = std.mem.zeroes(u8),
    addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    primary_phy: esp_ble_gap_pri_phy_t = std.mem.zeroes(esp_ble_gap_pri_phy_t),
    secondly_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    sid: u8 = std.mem.zeroes(u8),
    tx_power: u8 = std.mem.zeroes(u8),
    rssi: i8 = std.mem.zeroes(i8),
    per_adv_interval: u16 = std.mem.zeroes(u16),
    dir_addr_type: u8 = std.mem.zeroes(u8),
    dir_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    data_status: esp_ble_gap_ext_adv_data_status_t = std.mem.zeroes(esp_ble_gap_ext_adv_data_status_t),
    adv_data_len: u8 = std.mem.zeroes(u8),
    adv_data: [251]u8 = std.mem.zeroes([251]u8),
};
pub const esp_ble_gap_periodic_adv_report_t = extern struct {
    sync_handle: u16 = std.mem.zeroes(u16),
    tx_power: u8 = std.mem.zeroes(u8),
    rssi: i8 = std.mem.zeroes(i8),
    data_status: esp_ble_gap_ext_adv_data_status_t = std.mem.zeroes(esp_ble_gap_ext_adv_data_status_t),
    data_length: u8 = std.mem.zeroes(u8),
    data: [251]u8 = std.mem.zeroes([251]u8),
};
pub const esp_ble_gap_periodic_adv_sync_estab_t = extern struct {
    status: u8 = std.mem.zeroes(u8),
    sync_handle: u16 = std.mem.zeroes(u16),
    sid: u8 = std.mem.zeroes(u8),
    addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    adv_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    adv_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    period_adv_interval: u16 = std.mem.zeroes(u16),
    adv_clk_accuracy: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_dtm_enh_tx_t = extern struct {
    tx_channel: u8 = std.mem.zeroes(u8),
    len_of_data: u8 = std.mem.zeroes(u8),
    pkt_payload: esp_ble_dtm_pkt_payload_t = std.mem.zeroes(esp_ble_dtm_pkt_payload_t),
    phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
};
pub const esp_ble_dtm_enh_rx_t = extern struct {
    rx_channel: u8 = std.mem.zeroes(u8),
    phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    modulation_idx: u8 = std.mem.zeroes(u8),
};
pub const esp_ble_gap_past_mode_t = u8;
pub const esp_ble_gap_past_params_t = extern struct {
    mode: esp_ble_gap_past_mode_t = std.mem.zeroes(esp_ble_gap_past_mode_t),
    skip: u16 = std.mem.zeroes(u16),
    sync_timeout: u16 = std.mem.zeroes(u16),
    cte_type: u8 = std.mem.zeroes(u8),
};
pub const ble_get_dev_name_cmpl_evt_param_41 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    name: [*c]u8 = std.mem.zeroes([*c]u8),
};
pub const ble_adv_data_cmpl_evt_param_42 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_scan_rsp_data_cmpl_evt_param_43 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_scan_param_cmpl_evt_param_44 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_scan_result_evt_param_45 = extern struct {
    search_evt: esp_gap_search_evt_t = std.mem.zeroes(esp_gap_search_evt_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    dev_type: esp_bt_dev_type_t = std.mem.zeroes(esp_bt_dev_type_t),
    ble_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    ble_evt_type: esp_ble_evt_type_t = std.mem.zeroes(esp_ble_evt_type_t),
    rssi: c_int = std.mem.zeroes(c_int),
    ble_adv: [62]u8 = std.mem.zeroes([62]u8),
    flag: c_int = std.mem.zeroes(c_int),
    num_resps: c_int = std.mem.zeroes(c_int),
    adv_data_len: u8 = std.mem.zeroes(u8),
    scan_rsp_len: u8 = std.mem.zeroes(u8),
    num_dis: u32 = std.mem.zeroes(u32),
};
pub const ble_adv_data_raw_cmpl_evt_param_46 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_scan_rsp_data_raw_cmpl_evt_param_47 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_adv_start_cmpl_evt_param_48 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_scan_start_cmpl_evt_param_49 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_scan_stop_cmpl_evt_param_50 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_adv_stop_cmpl_evt_param_51 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_adv_clear_cmpl_evt_param_52 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_set_rand_cmpl_evt_param_53 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_update_conn_params_evt_param_54 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    min_int: u16 = std.mem.zeroes(u16),
    max_int: u16 = std.mem.zeroes(u16),
    latency: u16 = std.mem.zeroes(u16),
    conn_int: u16 = std.mem.zeroes(u16),
    timeout: u16 = std.mem.zeroes(u16),
};
pub const ble_pkt_data_length_cmpl_evt_param_55 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    params: esp_ble_pkt_data_length_params_t = std.mem.zeroes(esp_ble_pkt_data_length_params_t),
};
pub const ble_local_privacy_cmpl_evt_param_56 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_remove_bond_dev_cmpl_evt_param_57 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bd_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const ble_clear_bond_dev_cmpl_evt_param_58 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_get_bond_dev_cmpl_evt_param_59 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    dev_num: u8 = std.mem.zeroes(u8),
    bond_dev: [*c]esp_ble_bond_dev_t = std.mem.zeroes([*c]esp_ble_bond_dev_t),
};
pub const ble_read_rssi_cmpl_evt_param_60 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    rssi: i8 = std.mem.zeroes(i8),
    remote_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const ble_update_whitelist_cmpl_evt_param_61 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    wl_operation: esp_ble_wl_operation_t = std.mem.zeroes(esp_ble_wl_operation_t),
};
pub const ble_update_duplicate_exceptional_list_cmpl_evt_param_62 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    subcode: u8 = std.mem.zeroes(u8),
    length: u16 = std.mem.zeroes(u16),
    device_info: esp_duplicate_info_t = std.mem.zeroes(esp_duplicate_info_t),
};
pub const ble_set_channels_evt_param_63 = extern struct {
    stat: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_read_phy_cmpl_evt_param_64 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    tx_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    rx_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
};
pub const ble_set_perf_def_phy_cmpl_evt_param_65 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_set_perf_phy_cmpl_evt_param_66 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_set_rand_addr_cmpl_evt_param_67 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_set_params_cmpl_evt_param_68 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_data_set_cmpl_evt_param_69 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_scan_rsp_set_cmpl_evt_param_70 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_start_cmpl_evt_param_71 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_stop_cmpl_evt_param_72 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_set_remove_cmpl_evt_param_73 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_adv_set_clear_cmpl_evt_param_74 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_periodic_adv_set_params_cmpl_param_75 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_periodic_adv_data_set_cmpl_param_76 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_periodic_adv_start_cmpl_param_77 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_periodic_adv_stop_cmpl_param_78 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_period_adv_create_sync_cmpl_param_79 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_period_adv_sync_cancel_cmpl_param_80 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_period_adv_sync_terminate_cmpl_param_81 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_period_adv_add_dev_cmpl_param_82 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_period_adv_remove_dev_cmpl_param_83 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_period_adv_clear_dev_cmpl_param_84 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_set_ext_scan_params_cmpl_param_85 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_scan_start_cmpl_param_86 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_scan_stop_cmpl_param_87 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_ext_conn_params_set_cmpl_param_88 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_adv_terminate_param_89 = extern struct {
    status: u8 = std.mem.zeroes(u8),
    adv_instance: u8 = std.mem.zeroes(u8),
    conn_idx: u16 = std.mem.zeroes(u16),
    completed_event: u8 = std.mem.zeroes(u8),
};
pub const ble_scan_req_received_param_90 = extern struct {
    adv_instance: u8 = std.mem.zeroes(u8),
    scan_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    scan_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const ble_channel_sel_alg_param_91 = extern struct {
    conn_handle: u16 = std.mem.zeroes(u16),
    channel_sel_alg: u8 = std.mem.zeroes(u8),
};
pub const ble_periodic_adv_sync_lost_param_92 = extern struct {
    sync_handle: u16 = std.mem.zeroes(u16),
};
pub const ble_periodic_adv_sync_estab_param_93 = extern struct {
    status: u8 = std.mem.zeroes(u8),
    sync_handle: u16 = std.mem.zeroes(u16),
    sid: u8 = std.mem.zeroes(u8),
    adv_addr_type: esp_ble_addr_type_t = std.mem.zeroes(esp_ble_addr_type_t),
    adv_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    adv_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    period_adv_interval: u16 = std.mem.zeroes(u16),
    adv_clk_accuracy: u8 = std.mem.zeroes(u8),
};
pub const ble_phy_update_cmpl_param_94 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    tx_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    rx_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
};
pub const ble_ext_adv_report_param_95 = extern struct {
    params: esp_ble_gap_ext_adv_reprot_t = std.mem.zeroes(esp_ble_gap_ext_adv_reprot_t),
};
pub const ble_periodic_adv_report_param_96 = extern struct {
    params: esp_ble_gap_periodic_adv_report_t = std.mem.zeroes(esp_ble_gap_periodic_adv_report_t),
};
pub const ble_periodic_adv_recv_enable_cmpl_param_97 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
};
pub const ble_periodic_adv_sync_trans_cmpl_param_98 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const ble_periodic_adv_set_info_trans_cmpl_param_99 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const ble_set_past_params_cmpl_param_100 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
};
pub const ble_periodic_adv_sync_trans_recv_param_101 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    bda: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    service_data: u16 = std.mem.zeroes(u16),
    sync_handle: u16 = std.mem.zeroes(u16),
    adv_sid: u8 = std.mem.zeroes(u8),
    adv_addr_type: u8 = std.mem.zeroes(u8),
    adv_addr: esp_bd_addr_t = std.mem.zeroes(esp_bd_addr_t),
    adv_phy: esp_ble_gap_phy_t = std.mem.zeroes(esp_ble_gap_phy_t),
    adv_interval: u16 = std.mem.zeroes(u16),
    adv_clk_accuracy: u8 = std.mem.zeroes(u8),
};
pub const ble_dtm_state_update_evt_param_102 = extern struct {
    status: esp_bt_status_t = std.mem.zeroes(esp_bt_status_t),
    update_evt: esp_ble_dtm_update_evt_t = std.mem.zeroes(esp_ble_dtm_update_evt_t),
    num_of_pkt: u16 = std.mem.zeroes(u16),
};
pub const esp_ble_gap_cb_param_t = extern union {
    get_dev_name_cmpl: ble_get_dev_name_cmpl_evt_param_41,
    adv_data_cmpl: ble_adv_data_cmpl_evt_param_42,
    scan_rsp_data_cmpl: ble_scan_rsp_data_cmpl_evt_param_43,
    scan_param_cmpl: ble_scan_param_cmpl_evt_param_44,
    scan_rst: ble_scan_result_evt_param_45,
    adv_data_raw_cmpl: ble_adv_data_raw_cmpl_evt_param_46,
    scan_rsp_data_raw_cmpl: ble_scan_rsp_data_raw_cmpl_evt_param_47,
    adv_start_cmpl: ble_adv_start_cmpl_evt_param_48,
    scan_start_cmpl: ble_scan_start_cmpl_evt_param_49,
    ble_security: esp_ble_sec_t,
    scan_stop_cmpl: ble_scan_stop_cmpl_evt_param_50,
    adv_stop_cmpl: ble_adv_stop_cmpl_evt_param_51,
    adv_clear_cmpl: ble_adv_clear_cmpl_evt_param_52,
    set_rand_addr_cmpl: ble_set_rand_cmpl_evt_param_53,
    update_conn_params: ble_update_conn_params_evt_param_54,
    pkt_data_length_cmpl: ble_pkt_data_length_cmpl_evt_param_55,
    local_privacy_cmpl: ble_local_privacy_cmpl_evt_param_56,
    remove_bond_dev_cmpl: ble_remove_bond_dev_cmpl_evt_param_57,
    clear_bond_dev_cmpl: ble_clear_bond_dev_cmpl_evt_param_58,
    get_bond_dev_cmpl: ble_get_bond_dev_cmpl_evt_param_59,
    read_rssi_cmpl: ble_read_rssi_cmpl_evt_param_60,
    update_whitelist_cmpl: ble_update_whitelist_cmpl_evt_param_61,
    update_duplicate_exceptional_list_cmpl: ble_update_duplicate_exceptional_list_cmpl_evt_param_62,
    ble_set_channels: ble_set_channels_evt_param_63,
    read_phy: ble_read_phy_cmpl_evt_param_64,
    set_perf_def_phy: ble_set_perf_def_phy_cmpl_evt_param_65,
    set_perf_phy: ble_set_perf_phy_cmpl_evt_param_66,
    ext_adv_set_rand_addr: ble_ext_adv_set_rand_addr_cmpl_evt_param_67,
    ext_adv_set_params: ble_ext_adv_set_params_cmpl_evt_param_68,
    ext_adv_data_set: ble_ext_adv_data_set_cmpl_evt_param_69,
    scan_rsp_set: ble_ext_adv_scan_rsp_set_cmpl_evt_param_70,
    ext_adv_start: ble_ext_adv_start_cmpl_evt_param_71,
    ext_adv_stop: ble_ext_adv_stop_cmpl_evt_param_72,
    ext_adv_remove: ble_ext_adv_set_remove_cmpl_evt_param_73,
    ext_adv_clear: ble_ext_adv_set_clear_cmpl_evt_param_74,
    peroid_adv_set_params: ble_periodic_adv_set_params_cmpl_param_75,
    period_adv_data_set: ble_periodic_adv_data_set_cmpl_param_76,
    period_adv_start: ble_periodic_adv_start_cmpl_param_77,
    period_adv_stop: ble_periodic_adv_stop_cmpl_param_78,
    period_adv_create_sync: ble_period_adv_create_sync_cmpl_param_79,
    period_adv_sync_cancel: ble_period_adv_sync_cancel_cmpl_param_80,
    period_adv_sync_term: ble_period_adv_sync_terminate_cmpl_param_81,
    period_adv_add_dev: ble_period_adv_add_dev_cmpl_param_82,
    period_adv_remove_dev: ble_period_adv_remove_dev_cmpl_param_83,
    period_adv_clear_dev: ble_period_adv_clear_dev_cmpl_param_84,
    set_ext_scan_params: ble_set_ext_scan_params_cmpl_param_85,
    ext_scan_start: ble_ext_scan_start_cmpl_param_86,
    ext_scan_stop: ble_ext_scan_stop_cmpl_param_87,
    ext_conn_params_set: ble_ext_conn_params_set_cmpl_param_88,
    adv_terminate: ble_adv_terminate_param_89,
    scan_req_received: ble_scan_req_received_param_90,
    channel_sel_alg: ble_channel_sel_alg_param_91,
    periodic_adv_sync_lost: ble_periodic_adv_sync_lost_param_92,
    periodic_adv_sync_estab: ble_periodic_adv_sync_estab_param_93,
    phy_update: ble_phy_update_cmpl_param_94,
    ext_adv_report: ble_ext_adv_report_param_95,
    period_adv_report: ble_periodic_adv_report_param_96,
    period_adv_recv_enable: ble_periodic_adv_recv_enable_cmpl_param_97,
    period_adv_sync_trans: ble_periodic_adv_sync_trans_cmpl_param_98,
    period_adv_set_info_trans: ble_periodic_adv_set_info_trans_cmpl_param_99,
    set_past_params: ble_set_past_params_cmpl_param_100,
    past_received: ble_periodic_adv_sync_trans_recv_param_101,
    dtm_state_update: ble_dtm_state_update_evt_param_102,
};
pub const esp_gap_ble_cb_t = ?*const fn (esp_gap_ble_cb_event_t, [*c]esp_ble_gap_cb_param_t) callconv(.C) void;
pub extern fn esp_ble_gap_register_callback(callback: esp_gap_ble_cb_t) esp_err_t;
pub extern fn esp_ble_gap_get_callback() esp_gap_ble_cb_t;
pub extern fn esp_ble_gap_config_adv_data(adv_data: [*c]esp_ble_adv_data_t) esp_err_t;
pub extern fn esp_ble_gap_set_scan_params(scan_params: [*c]esp_ble_scan_params_t) esp_err_t;
pub extern fn esp_ble_gap_start_scanning(duration: u32) esp_err_t;
pub extern fn esp_ble_gap_stop_scanning() esp_err_t;
pub extern fn esp_ble_gap_start_advertising(adv_params: [*c]esp_ble_adv_params_t) esp_err_t;
pub extern fn esp_ble_gap_stop_advertising() esp_err_t;
pub extern fn esp_ble_gap_update_conn_params(params: [*c]esp_ble_conn_update_params_t) esp_err_t;
pub extern fn esp_ble_gap_set_pkt_data_len(remote_device: [*c]u8, tx_data_length: u16) esp_err_t;
pub extern fn esp_ble_gap_set_rand_addr(rand_addr: [*c]u8) esp_err_t;
pub extern fn esp_ble_gap_clear_rand_addr() esp_err_t;
pub extern fn esp_ble_gap_config_local_privacy(privacy_enable: bool) esp_err_t;
pub extern fn esp_ble_gap_config_local_icon(icon: u16) esp_err_t;
pub extern fn esp_ble_gap_update_whitelist(add_remove: bool, remote_bda: [*c]u8, wl_addr_type: esp_ble_wl_addr_type_t) esp_err_t;
pub extern fn esp_ble_gap_clear_whitelist() esp_err_t;
pub extern fn esp_ble_gap_get_whitelist_size(length: [*c]u16) esp_err_t;
pub extern fn esp_ble_gap_set_prefer_conn_params(bd_addr: [*c]u8, min_conn_int: u16, max_conn_int: u16, slave_latency: u16, supervision_tout: u16) esp_err_t;
pub extern fn esp_ble_gap_set_device_name(name: [*:0]const u8) esp_err_t;
pub extern fn esp_ble_gap_get_device_name() esp_err_t;
pub extern fn esp_ble_gap_get_local_used_addr(local_used_addr: [*c]u8, addr_type: [*c]u8) esp_err_t;
pub extern fn esp_ble_resolve_adv_data(adv_data: [*c]u8, @"type": u8, length: [*c]u8) [*c]u8;
pub extern fn esp_ble_gap_config_adv_data_raw(raw_data: [*c]u8, raw_data_len: u32) esp_err_t;
pub extern fn esp_ble_gap_config_scan_rsp_data_raw(raw_data: [*c]u8, raw_data_len: u32) esp_err_t;
pub extern fn esp_ble_gap_read_rssi(remote_addr: [*c]u8) esp_err_t;
pub extern fn esp_ble_gap_add_duplicate_scan_exceptional_device(@"type": esp_ble_duplicate_exceptional_info_type_t, device_info: [*c]u8) esp_err_t;
pub extern fn esp_ble_gap_remove_duplicate_scan_exceptional_device(@"type": esp_ble_duplicate_exceptional_info_type_t, device_info: [*c]u8) esp_err_t;
pub extern fn esp_ble_gap_clean_duplicate_scan_exceptional_list(list_type: esp_duplicate_scan_exceptional_list_type_t) esp_err_t;
pub extern fn esp_ble_gap_set_security_param(param_type: esp_ble_sm_param_t, value: ?*anyopaque, len: u8) esp_err_t;
pub extern fn esp_ble_gap_security_rsp(bd_addr: [*c]u8, accept: bool) esp_err_t;
pub extern fn esp_ble_set_encryption(bd_addr: [*c]u8, sec_act: esp_ble_sec_act_t) esp_err_t;
pub extern fn esp_ble_passkey_reply(bd_addr: [*c]u8, accept: bool, passkey: u32) esp_err_t;
pub extern fn esp_ble_confirm_reply(bd_addr: [*c]u8, accept: bool) esp_err_t;
pub extern fn esp_ble_remove_bond_device(bd_addr: [*c]u8) esp_err_t;
pub extern fn esp_ble_get_bond_device_num() c_int;
pub extern fn esp_ble_get_bond_device_list(dev_num: [*c]c_int, dev_list: [*c]esp_ble_bond_dev_t) esp_err_t;
pub extern fn esp_ble_oob_req_reply(bd_addr: [*c]u8, TK: [*c]u8, len: u8) esp_err_t;
pub extern fn esp_ble_sc_oob_req_reply(bd_addr: [*c]u8, p_c: [*c]u8, p_r: [*c]u8) esp_err_t;
pub extern fn esp_ble_create_sc_oob_data() esp_err_t;
pub extern fn esp_ble_gap_disconnect(remote_device: [*c]u8) esp_err_t;
pub extern fn esp_ble_get_current_conn_params(bd_addr: [*c]u8, conn_params: [*c]esp_gap_conn_params_t) esp_err_t;
pub extern fn esp_gap_ble_set_channels(channels: [*c]u8) esp_err_t;
pub extern fn esp_gap_ble_set_authorization(bd_addr: [*c]u8, authorize: bool) esp_err_t;
pub extern fn esp_ble_gap_read_phy(bd_addr: [*c]u8) esp_err_t;
pub extern fn esp_ble_gap_set_preferred_default_phy(tx_phy_mask: esp_ble_gap_phy_mask_t, rx_phy_mask: esp_ble_gap_phy_mask_t) esp_err_t;
pub extern fn esp_ble_gap_set_preferred_phy(bd_addr: [*c]u8, all_phys_mask: esp_ble_gap_all_phys_t, tx_phy_mask: esp_ble_gap_phy_mask_t, rx_phy_mask: esp_ble_gap_phy_mask_t, phy_options: esp_ble_gap_prefer_phy_options_t) esp_err_t;
pub extern fn esp_ble_gap_ext_adv_set_rand_addr(instance: u8, rand_addr: [*c]u8) esp_err_t;
pub extern fn esp_ble_gap_ext_adv_set_params(instance: u8, params: [*c]const esp_ble_gap_ext_adv_params_t) esp_err_t;
pub extern fn esp_ble_gap_config_ext_adv_data_raw(instance: u8, length: u16, data: [*:0]const u8) esp_err_t;
pub extern fn esp_ble_gap_config_ext_scan_rsp_data_raw(instance: u8, length: u16, scan_rsp_data: [*:0]const u8) esp_err_t;
pub extern fn esp_ble_gap_ext_adv_start(num_adv: u8, ext_adv: [*c]const esp_ble_gap_ext_adv_t) esp_err_t;
pub extern fn esp_ble_gap_ext_adv_stop(num_adv: u8, ext_adv_inst: [*:0]const u8) esp_err_t;
pub extern fn esp_ble_gap_ext_adv_set_remove(instance: u8) esp_err_t;
pub extern fn esp_ble_gap_ext_adv_set_clear() esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_set_params(instance: u8, params: [*c]const esp_ble_gap_periodic_adv_params_t) esp_err_t;
pub extern fn esp_ble_gap_config_periodic_adv_data_raw(instance: u8, length: u16, data: [*:0]const u8) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_start(instance: u8) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_stop(instance: u8) esp_err_t;
pub extern fn esp_ble_gap_set_ext_scan_params(params: [*c]const esp_ble_ext_scan_params_t) esp_err_t;
pub extern fn esp_ble_gap_start_ext_scan(duration: u32, period: u16) esp_err_t;
pub extern fn esp_ble_gap_stop_ext_scan() esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_create_sync(params: [*c]const esp_ble_gap_periodic_adv_sync_params_t) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_sync_cancel() esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_sync_terminate(sync_handle: u16) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_add_dev_to_list(addr_type: esp_ble_addr_type_t, addr: [*c]u8, sid: u8) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_remove_dev_from_list(addr_type: esp_ble_addr_type_t, addr: [*c]u8, sid: u8) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_clear_dev() esp_err_t;
pub extern fn esp_ble_gap_prefer_ext_connect_params_set(addr: [*c]u8, phy_mask: esp_ble_gap_phy_mask_t, phy_1m_conn_params: [*c]const esp_ble_gap_conn_params_t, phy_2m_conn_params: [*c]const esp_ble_gap_conn_params_t, phy_coded_conn_params: [*c]const esp_ble_gap_conn_params_t) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_recv_enable(sync_handle: u16, enable: u8) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_sync_trans(addr: [*c]u8, service_data: u16, sync_handle: u16) esp_err_t;
pub extern fn esp_ble_gap_periodic_adv_set_info_trans(addr: [*c]u8, service_data: u16, adv_handle: u8) esp_err_t;
pub extern fn esp_ble_gap_set_periodic_adv_sync_trans_params(addr: [*c]u8, params: [*c]const esp_ble_gap_past_params_t) esp_err_t;
pub extern fn esp_ble_dtm_tx_start(tx_params: [*c]const esp_ble_dtm_tx_t) esp_err_t;
pub extern fn esp_ble_dtm_rx_start(rx_params: [*c]const esp_ble_dtm_rx_t) esp_err_t;
pub extern fn esp_ble_dtm_enh_tx_start(tx_params: [*c]const esp_ble_dtm_enh_tx_t) esp_err_t;
pub extern fn esp_ble_dtm_enh_rx_start(rx_params: [*c]const esp_ble_dtm_enh_rx_t) esp_err_t;
pub extern fn esp_ble_dtm_stop() esp_err_t;
pub extern fn esp_ble_gap_clear_advertising() esp_err_t;
pub extern fn esp_blufi_close(gatts_if: u8, conn_id: u16) esp_err_t;
pub extern fn esp_blufi_gap_event_handler(event: esp_gap_ble_cb_event_t, param: [*c]esp_ble_gap_cb_param_t) void;
pub extern fn esp_blufi_init() u8;
pub extern fn bleprph_advertise() void;
pub extern fn esp_blufi_send_notify(arg: ?*anyopaque) void;
pub extern fn esp_blufi_deinit() void;
pub extern fn esp_blufi_disconnect() void;
pub extern fn esp_blufi_adv_stop() void;
pub extern fn esp_blufi_adv_start() void;
pub extern fn esp_blufi_send_encap(arg: ?*anyopaque) void;
pub extern fn esp_random() u32;
pub extern fn esp_fill_random(buf: ?*anyopaque, len: usize) void;

pub const heap_trace_mode_t = enum(c_uint) {
    HEAP_TRACE_ALL = 0,
    HEAP_TRACE_LEAKS = 1,
};
pub const heap_trace_record_t = extern struct {
    ccount: u32 align(4) = std.mem.zeroes(u32),
    address: ?*anyopaque = null,
    size: usize = std.mem.zeroes(usize),
    alloced_by: [0]?*anyopaque = std.mem.zeroes([0]?*anyopaque),
    pub fn freed_by(self: anytype) std.zig.c_translation.FlexibleArrayType(@TypeOf(self), ?*anyopaque) {
        const Intermediate = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        const ReturnType = std.zig.c_translation.FlexibleArrayType(@TypeOf(self), ?*anyopaque);
        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 12)));
    }
};
pub const heap_trace_summary_t = extern struct {
    mode: heap_trace_mode_t = std.mem.zeroes(heap_trace_mode_t),
    total_allocations: usize = std.mem.zeroes(usize),
    total_frees: usize = std.mem.zeroes(usize),
    count: usize = std.mem.zeroes(usize),
    capacity: usize = std.mem.zeroes(usize),
    high_water_mark: usize = std.mem.zeroes(usize),
    has_overflowed: usize = std.mem.zeroes(usize),
};
pub extern fn heap_trace_init_standalone(record_buffer: [*c]heap_trace_record_t, num_records: usize) esp_err_t;
pub extern fn heap_trace_init_tohost() esp_err_t;
pub extern fn heap_trace_start(mode: heap_trace_mode_t) esp_err_t;
pub extern fn heap_trace_stop() esp_err_t;
pub extern fn heap_trace_resume() esp_err_t;
pub extern fn heap_trace_get_count() usize;
pub extern fn heap_trace_get(index: usize, record: [*c]heap_trace_record_t) esp_err_t;
pub extern fn heap_trace_dump() void;
pub extern fn heap_trace_dump_caps(caps: u32) void;
pub extern fn heap_trace_summary(summary: [*c]heap_trace_summary_t) esp_err_t;
pub const SEGGER_RTT_BUFFER_UP = extern struct {
    sName: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    pBuffer: [*c]u8 = std.mem.zeroes([*c]u8),
    SizeOfBuffer: c_uint = std.mem.zeroes(c_uint),
    WrOff: c_uint = std.mem.zeroes(c_uint),
    RdOff: c_uint = std.mem.zeroes(c_uint),
    Flags: c_uint = std.mem.zeroes(c_uint),
};
pub const SEGGER_RTT_BUFFER_DOWN = extern struct {
    sName: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    pBuffer: [*c]u8 = std.mem.zeroes([*c]u8),
    SizeOfBuffer: c_uint = std.mem.zeroes(c_uint),
    WrOff: c_uint = std.mem.zeroes(c_uint),
    RdOff: c_uint = std.mem.zeroes(c_uint),
    Flags: c_uint = std.mem.zeroes(c_uint),
};
pub const SEGGER_RTT_CB = extern struct {
    acID: [16]u8 = std.mem.zeroes([16]u8),
    MaxNumUpBuffers: c_int = std.mem.zeroes(c_int),
    MaxNumDownBuffers: c_int = std.mem.zeroes(c_int),
    aUp: [3]SEGGER_RTT_BUFFER_UP = std.mem.zeroes([3]SEGGER_RTT_BUFFER_UP),
    aDown: [3]SEGGER_RTT_BUFFER_DOWN = std.mem.zeroes([3]SEGGER_RTT_BUFFER_DOWN),
};
pub extern var _SEGGER_RTT: SEGGER_RTT_CB;
pub extern fn SEGGER_RTT_AllocDownBuffer(sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int;
pub extern fn SEGGER_RTT_AllocUpBuffer(sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int;
pub extern fn SEGGER_RTT_ConfigUpBuffer(BufferIndex: c_uint, sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int;
pub extern fn SEGGER_RTT_ConfigDownBuffer(BufferIndex: c_uint, sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int;
pub extern fn SEGGER_RTT_GetKey() c_int;
pub extern fn SEGGER_RTT_HasData(BufferIndex: c_uint) c_uint;
pub extern fn SEGGER_RTT_HasKey() c_int;
pub extern fn SEGGER_RTT_HasDataUp(BufferIndex: c_uint) c_uint;
pub extern fn SEGGER_RTT_Init() void;
pub extern fn SEGGER_RTT_Read(BufferIndex: c_uint, pBuffer: ?*anyopaque, BufferSize: c_uint) c_uint;
pub extern fn SEGGER_RTT_ReadNoLock(BufferIndex: c_uint, pData: ?*anyopaque, BufferSize: c_uint) c_uint;
pub extern fn SEGGER_RTT_SetNameDownBuffer(BufferIndex: c_uint, sName: [*:0]const u8) c_int;
pub extern fn SEGGER_RTT_SetNameUpBuffer(BufferIndex: c_uint, sName: [*:0]const u8) c_int;
pub extern fn SEGGER_RTT_SetFlagsDownBuffer(BufferIndex: c_uint, Flags: c_uint) c_int;
pub extern fn SEGGER_RTT_SetFlagsUpBuffer(BufferIndex: c_uint, Flags: c_uint) c_int;
pub extern fn SEGGER_RTT_WaitKey() c_int;
pub extern fn SEGGER_RTT_Write(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
pub extern fn SEGGER_RTT_WriteNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
pub extern fn SEGGER_RTT_WriteSkipNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
pub extern fn SEGGER_RTT_ASM_WriteSkipNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
pub extern fn SEGGER_RTT_WriteString(BufferIndex: c_uint, s: [*:0]const u8) c_uint;
pub extern fn SEGGER_RTT_WriteWithOverwriteNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) void;
pub extern fn SEGGER_RTT_PutChar(BufferIndex: c_uint, c: u8) c_uint;
pub extern fn SEGGER_RTT_PutCharSkip(BufferIndex: c_uint, c: u8) c_uint;
pub extern fn SEGGER_RTT_PutCharSkipNoLock(BufferIndex: c_uint, c: u8) c_uint;
pub extern fn SEGGER_RTT_GetAvailWriteSpace(BufferIndex: c_uint) c_uint;
pub extern fn SEGGER_RTT_GetBytesInBuffer(BufferIndex: c_uint) c_uint;
pub extern fn SEGGER_RTT_ESP_FlushNoLock(min_sz: c_ulong, tmo: c_ulong) void;
pub extern fn SEGGER_RTT_ESP_Flush(min_sz: c_ulong, tmo: c_ulong) void;
pub extern fn SEGGER_RTT_ReadUpBuffer(BufferIndex: c_uint, pBuffer: ?*anyopaque, BufferSize: c_uint) c_uint;
pub extern fn SEGGER_RTT_ReadUpBufferNoLock(BufferIndex: c_uint, pData: ?*anyopaque, BufferSize: c_uint) c_uint;
pub extern fn SEGGER_RTT_WriteDownBuffer(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
pub extern fn SEGGER_RTT_WriteDownBufferNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
pub extern fn SEGGER_RTT_SetTerminal(TerminalId: u8) c_int;
pub extern fn SEGGER_RTT_TerminalOut(TerminalId: u8, s: [*:0]const u8) c_int;
pub extern fn SEGGER_RTT_printf(BufferIndex: c_uint, sFormat: [*:0]const u8, ...) c_int;
pub extern fn SEGGER_RTT_vprintf(BufferIndex: c_uint, sFormat: [*:0]const u8, pParamList: [*c]va_list) c_int;
pub const enum_intr_type = enum(c_uint) {
    INTR_TYPE_LEVEL = 0,
    INTR_TYPE_EDGE = 1,
};
pub const esp_timer = opaque {};
pub const esp_timer_handle_t = ?*esp_timer;
pub const esp_timer_cb_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub const esp_timer_dispatch_t = enum(c_uint) {
    ESP_TIMER_TASK = 0,
    ESP_TIMER_MAX = 1,
};
pub const esp_timer_create_args_t = extern struct {
    callback: esp_timer_cb_t = std.mem.zeroes(esp_timer_cb_t),
    arg: ?*anyopaque = null,
    dispatch_method: esp_timer_dispatch_t = std.mem.zeroes(esp_timer_dispatch_t),
    name: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    skip_unhandled_events: bool = std.mem.zeroes(bool),
};
pub extern fn esp_timer_early_init() esp_err_t;
pub extern fn esp_timer_init() esp_err_t;
pub extern fn esp_timer_deinit() esp_err_t;
pub extern fn esp_timer_create(create_args: [*c]const esp_timer_create_args_t, out_handle: [*c]esp_timer_handle_t) esp_err_t;
pub extern fn esp_timer_start_once(timer: esp_timer_handle_t, timeout_us: u64) esp_err_t;
pub extern fn esp_timer_start_periodic(timer: esp_timer_handle_t, period: u64) esp_err_t;
pub extern fn esp_timer_restart(timer: esp_timer_handle_t, timeout_us: u64) esp_err_t;
pub extern fn esp_timer_stop(timer: esp_timer_handle_t) esp_err_t;
pub extern fn esp_timer_delete(timer: esp_timer_handle_t) esp_err_t;
pub extern fn esp_timer_get_time() i64;
pub extern fn esp_timer_get_next_alarm() i64;
pub extern fn esp_timer_get_next_alarm_for_wake_up() i64;
pub extern fn esp_timer_get_period(timer: esp_timer_handle_t, period: [*c]u64) esp_err_t;
pub extern fn esp_timer_get_expiry_time(timer: esp_timer_handle_t, expiry: [*c]u64) esp_err_t;
pub extern fn esp_timer_dump(stream: std.c.FILE) esp_err_t;
pub extern fn esp_timer_is_active(timer: esp_timer_handle_t) bool;
pub const esp_apptrace_tmo_t = extern struct {
    start: i64 = std.mem.zeroes(i64),
    tmo: i64 = std.mem.zeroes(i64),
    elapsed: i64 = std.mem.zeroes(i64),
};
pub fn esp_apptrace_tmo_init(arg_tmo: [*c]esp_apptrace_tmo_t, arg_user_tmo: u32) callconv(.C) void {
    var tmo = arg_tmo;
    _ = &tmo;
    var user_tmo = arg_user_tmo;
    _ = &user_tmo;
    tmo.*.start = esp_timer_get_time();
    tmo.*.tmo = if (user_tmo == @as(u32, @bitCast(-@as(c_int, 1)))) @as(i64, @bitCast(@as(c_longlong, -@as(c_int, 1)))) else @as(i64, @bitCast(@as(c_ulonglong, user_tmo)));
    tmo.*.elapsed = 0;
}
pub extern fn esp_apptrace_tmo_check(tmo: [*c]esp_apptrace_tmo_t) esp_err_t;
pub fn esp_apptrace_tmo_remaining_us(arg_tmo: [*c]esp_apptrace_tmo_t) callconv(.C) u32 {
    var tmo = arg_tmo;
    _ = &tmo;
    return @as(u32, @bitCast(@as(c_int, @truncate(if (tmo.*.tmo != @as(i64, @bitCast(@as(c_longlong, -@as(c_int, 1))))) tmo.*.elapsed - tmo.*.tmo else @as(i64, @bitCast(@as(c_ulonglong, @as(u32, @bitCast(-@as(c_int, 1))))))))));
}
pub const esp_apptrace_lock_t = extern struct {
    mux: spinlock_t = std.mem.zeroes(spinlock_t),
    int_state: c_uint = std.mem.zeroes(c_uint),
};
pub fn esp_apptrace_lock_init(arg_lock: [*c]esp_apptrace_lock_t) callconv(.C) void {
    var lock = arg_lock;
    _ = &lock;
    spinlock_initialize(&lock.*.mux);
    lock.*.int_state = 0;
}
pub extern fn esp_apptrace_lock_take(lock: [*c]esp_apptrace_lock_t, tmo: [*c]esp_apptrace_tmo_t) esp_err_t;
pub extern fn esp_apptrace_lock_give(lock: [*c]esp_apptrace_lock_t) esp_err_t;
pub const esp_apptrace_rb_t = extern struct {
    data: [*c]u8 = std.mem.zeroes([*c]u8),
    size: u32 = std.mem.zeroes(u32),
    cur_size: u32 = std.mem.zeroes(u32),
    rd: u32 = std.mem.zeroes(u32),
    wr: u32 = std.mem.zeroes(u32),
};
pub fn esp_apptrace_rb_init(arg_rb: [*c]esp_apptrace_rb_t, arg_data: [*c]u8, arg_size: u32) callconv(.C) void {
    var rb = arg_rb;
    _ = &rb;
    var data = arg_data;
    _ = &data;
    var size = arg_size;
    _ = &size;
    rb.*.data = data;
    rb.*.size = blk: {
        const tmp = size;
        rb.*.cur_size = tmp;
        break :blk tmp;
    };
    rb.*.rd = 0;
    rb.*.wr = 0;
}
pub extern fn esp_apptrace_rb_produce(rb: [*c]esp_apptrace_rb_t, size: u32) [*c]u8;
pub extern fn esp_apptrace_rb_consume(rb: [*c]esp_apptrace_rb_t, size: u32) [*c]u8;
pub extern fn esp_apptrace_rb_read_size_get(rb: [*c]esp_apptrace_rb_t) u32;
pub extern fn esp_apptrace_rb_write_size_get(rb: [*c]esp_apptrace_rb_t) u32;
pub extern fn esp_apptrace_log_lock() c_int;
pub extern fn esp_apptrace_log_unlock() void;
pub fn esp_sysview_flush(tmo: u32) callconv(.C) esp_err_t {
    SEGGER_RTT_ESP_Flush(@as(c_ulong, @bitCast(@as(c_long, @as(c_int, 0)))), @as(c_ulong, @bitCast(@as(c_ulong, tmo))));
    return 0;
}
pub extern fn esp_sysview_vprintf(format: [*:0]const u8, args: va_list) c_int;
pub extern fn esp_sysview_heap_trace_start(tmo: u32) esp_err_t;
pub extern fn esp_sysview_heap_trace_stop() esp_err_t;
pub extern fn esp_sysview_heap_trace_alloc(addr: ?*anyopaque, size: u32, callers: ?*const anyopaque) void;
pub extern fn esp_sysview_heap_trace_free(addr: ?*anyopaque, callers: ?*const anyopaque) void;

pub const esp_crypto_hash_alg_t = enum(c_uint) {
    ESP_CRYPTO_HASH_ALG_MD5 = 0,
    ESP_CRYPTO_HASH_ALG_SHA1 = 1,
    ESP_CRYPTO_HASH_ALG_HMAC_MD5 = 2,
    ESP_CRYPTO_HASH_ALG_HMAC_SHA1 = 3,
    ESP_CRYPTO_HASH_ALG_SHA256 = 4,
    ESP_CRYPTO_HASH_ALG_HMAC_SHA256 = 5,
};
pub const esp_crypto_cipher_alg_t = enum(c_uint) {
    ESP_CRYPTO_CIPHER_NULL = 0,
    ESP_CRYPTO_CIPHER_ALG_AES = 1,
    ESP_CRYPTO_CIPHER_ALG_3DES = 2,
    ESP_CRYPTO_CIPHER_ALG_DES = 3,
    ESP_CRYPTO_CIPHER_ALG_RC2 = 4,
    ESP_CRYPTO_CIPHER_ALG_RC4 = 5,
};
pub const crypto_hash = opaque {};
pub const esp_crypto_hash_t = crypto_hash;
pub const crypto_cipher = opaque {};
pub const esp_crypto_cipher_t = crypto_cipher;
pub const esp_aes_128_encrypt_t = ?*const fn ([*:0]const u8, [*:0]const u8, [*c]u8, c_int) callconv(.C) c_int;
pub const esp_aes_128_decrypt_t = ?*const fn ([*:0]const u8, [*:0]const u8, [*c]u8, c_int) callconv(.C) c_int;
pub const esp_aes_wrap_t = ?*const fn ([*:0]const u8, c_int, [*:0]const u8, [*c]u8) callconv(.C) c_int;
pub const esp_aes_unwrap_t = ?*const fn ([*:0]const u8, c_int, [*:0]const u8, [*c]u8) callconv(.C) c_int;
pub const esp_hmac_sha256_vector_t = ?*const fn ([*:0]const u8, c_int, c_int, [*c][*c]const u8, [*c]const c_int, [*c]u8) callconv(.C) c_int;
pub const esp_sha256_prf_t = ?*const fn ([*:0]const u8, c_int, [*:0]const u8, [*:0]const u8, c_int, [*c]u8, c_int) callconv(.C) c_int;
pub const esp_hmac_md5_t = ?*const fn ([*:0]const u8, c_uint, [*:0]const u8, c_uint, [*c]u8) callconv(.C) c_int;
pub const esp_hmac_md5_vector_t = ?*const fn ([*:0]const u8, c_uint, c_uint, [*c][*c]const u8, [*c]const c_uint, [*c]u8) callconv(.C) c_int;
pub const esp_hmac_sha1_t = ?*const fn ([*:0]const u8, c_uint, [*:0]const u8, c_uint, [*c]u8) callconv(.C) c_int;
pub const esp_hmac_sha1_vector_t = ?*const fn ([*:0]const u8, c_uint, c_uint, [*c][*c]const u8, [*c]const c_uint, [*c]u8) callconv(.C) c_int;
pub const esp_sha1_prf_t = ?*const fn ([*:0]const u8, c_uint, [*:0]const u8, [*:0]const u8, c_uint, [*c]u8, c_uint) callconv(.C) c_int;
pub const esp_sha1_vector_t = ?*const fn (c_uint, [*c][*c]const u8, [*c]const c_uint, [*c]u8) callconv(.C) c_int;
pub const esp_pbkdf2_sha1_t = ?*const fn ([*:0]const u8, [*:0]const u8, c_uint, c_int, [*c]u8, c_uint) callconv(.C) c_int;
pub const esp_rc4_skip_t = ?*const fn ([*:0]const u8, c_uint, c_uint, [*c]u8, c_uint) callconv(.C) c_int;
pub const esp_md5_vector_t = ?*const fn (c_uint, [*c][*c]const u8, [*c]const c_uint, [*c]u8) callconv(.C) c_int;
pub const esp_aes_encrypt_t = ?*const fn (?*anyopaque, [*:0]const u8, [*c]u8) callconv(.C) void;
pub const esp_aes_encrypt_init_t = ?*const fn ([*:0]const u8, c_uint) callconv(.C) ?*anyopaque;
pub const esp_aes_encrypt_deinit_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub const esp_aes_decrypt_t = ?*const fn (?*anyopaque, [*:0]const u8, [*c]u8) callconv(.C) void;
pub const esp_aes_decrypt_init_t = ?*const fn ([*:0]const u8, c_uint) callconv(.C) ?*anyopaque;
pub const esp_aes_decrypt_deinit_t = ?*const fn (?*anyopaque) callconv(.C) void;
pub const esp_omac1_aes_128_t = ?*const fn ([*:0]const u8, [*:0]const u8, usize, [*c]u8) callconv(.C) c_int;
pub const esp_ccmp_decrypt_t = ?*const fn ([*:0]const u8, [*:0]const u8, [*:0]const u8, usize, [*c]usize, bool) callconv(.C) [*c]u8;
pub const esp_ccmp_encrypt_t = ?*const fn ([*:0]const u8, [*c]u8, usize, usize, [*c]u8, c_int, [*c]usize) callconv(.C) [*c]u8;
pub const esp_aes_gmac_t = ?*const fn ([*:0]const u8, usize, [*:0]const u8, usize, [*:0]const u8, usize, [*c]u8) callconv(.C) c_int;
pub const esp_sha256_vector_t = ?*const fn (usize, [*c][*c]const u8, [*c]const usize, [*c]u8) callconv(.C) c_int;
pub const esp_crc32_le_t = ?*const fn (u32, [*:0]const u8, u32) callconv(.C) u32;
pub const wpa_crypto_funcs_t = extern struct {
    size: u32 = std.mem.zeroes(u32),
    version: u32 = std.mem.zeroes(u32),
    aes_wrap: esp_aes_wrap_t = std.mem.zeroes(esp_aes_wrap_t),
    aes_unwrap: esp_aes_unwrap_t = std.mem.zeroes(esp_aes_unwrap_t),
    hmac_sha256_vector: esp_hmac_sha256_vector_t = std.mem.zeroes(esp_hmac_sha256_vector_t),
    sha256_prf: esp_sha256_prf_t = std.mem.zeroes(esp_sha256_prf_t),
    hmac_md5: esp_hmac_md5_t = std.mem.zeroes(esp_hmac_md5_t),
    hamc_md5_vector: esp_hmac_md5_vector_t = std.mem.zeroes(esp_hmac_md5_vector_t),
    hmac_sha1: esp_hmac_sha1_t = std.mem.zeroes(esp_hmac_sha1_t),
    hmac_sha1_vector: esp_hmac_sha1_vector_t = std.mem.zeroes(esp_hmac_sha1_vector_t),
    sha1_prf: esp_sha1_prf_t = std.mem.zeroes(esp_sha1_prf_t),
    sha1_vector: esp_sha1_vector_t = std.mem.zeroes(esp_sha1_vector_t),
    pbkdf2_sha1: esp_pbkdf2_sha1_t = std.mem.zeroes(esp_pbkdf2_sha1_t),
    rc4_skip: esp_rc4_skip_t = std.mem.zeroes(esp_rc4_skip_t),
    md5_vector: esp_md5_vector_t = std.mem.zeroes(esp_md5_vector_t),
    aes_encrypt: esp_aes_encrypt_t = std.mem.zeroes(esp_aes_encrypt_t),
    aes_encrypt_init: esp_aes_encrypt_init_t = std.mem.zeroes(esp_aes_encrypt_init_t),
    aes_encrypt_deinit: esp_aes_encrypt_deinit_t = std.mem.zeroes(esp_aes_encrypt_deinit_t),
    aes_decrypt: esp_aes_decrypt_t = std.mem.zeroes(esp_aes_decrypt_t),
    aes_decrypt_init: esp_aes_decrypt_init_t = std.mem.zeroes(esp_aes_decrypt_init_t),
    aes_decrypt_deinit: esp_aes_decrypt_deinit_t = std.mem.zeroes(esp_aes_decrypt_deinit_t),
    aes_128_encrypt: esp_aes_128_encrypt_t = std.mem.zeroes(esp_aes_128_encrypt_t),
    aes_128_decrypt: esp_aes_128_decrypt_t = std.mem.zeroes(esp_aes_128_decrypt_t),
    omac1_aes_128: esp_omac1_aes_128_t = std.mem.zeroes(esp_omac1_aes_128_t),
    ccmp_decrypt: esp_ccmp_decrypt_t = std.mem.zeroes(esp_ccmp_decrypt_t),
    ccmp_encrypt: esp_ccmp_encrypt_t = std.mem.zeroes(esp_ccmp_encrypt_t),
    aes_gmac: esp_aes_gmac_t = std.mem.zeroes(esp_aes_gmac_t),
    sha256_vector: esp_sha256_vector_t = std.mem.zeroes(esp_sha256_vector_t),
    crc32: esp_crc32_le_t = std.mem.zeroes(esp_crc32_le_t),
};
pub const mesh_crypto_funcs_t = extern struct {
    aes_128_encrypt: esp_aes_128_encrypt_t = std.mem.zeroes(esp_aes_128_encrypt_t),
    aes_128_decrypt: esp_aes_128_decrypt_t = std.mem.zeroes(esp_aes_128_decrypt_t),
};
pub const esp_ip6_addr = extern struct {
    addr: [4]u32 = std.mem.zeroes([4]u32),
    zone: u8 = std.mem.zeroes(u8),
};
pub const esp_ip4_addr = extern struct {
    addr: u32 = std.mem.zeroes(u32),
};
pub const esp_ip4_addr_t = esp_ip4_addr;
pub const esp_ip6_addr_t = esp_ip6_addr;
const union_unnamed_5 = extern union {
    ip6: esp_ip6_addr_t,
    ip4: esp_ip4_addr_t,
};
pub const _ip_addr = extern struct {
    u_addr: union_unnamed_5 = std.mem.zeroes(union_unnamed_5),
    type: u8 = std.mem.zeroes(u8),
};
pub const esp_ip_addr_t = _ip_addr;
pub const esp_ip6_addr_type_t = enum(c_uint) {
    ESP_IP6_ADDR_IS_UNKNOWN = 0,
    ESP_IP6_ADDR_IS_GLOBAL = 1,
    ESP_IP6_ADDR_IS_LINK_LOCAL = 2,
    ESP_IP6_ADDR_IS_SITE_LOCAL = 3,
    ESP_IP6_ADDR_IS_UNIQUE_LOCAL = 4,
    ESP_IP6_ADDR_IS_IPV4_MAPPED_IPV6 = 5,
};
pub extern fn esp_netif_ip6_get_addr_type(ip6_addr: [*c]esp_ip6_addr_t) esp_ip6_addr_type_t;
pub fn esp_netif_ip_addr_copy(arg_dest: [*c]esp_ip_addr_t, arg_src: [*c]const esp_ip_addr_t) callconv(.C) void {
    var dest = arg_dest;
    _ = &dest;
    var src = arg_src;
    _ = &src;
    dest.*.type = src.*.type;
    if (@as(c_uint, @bitCast(@as(c_uint, src.*.type))) == @as(c_uint, 6)) {
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 0)))] = src.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 0)))];
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 1)))] = src.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 1)))];
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 2)))] = src.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 2)))];
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 3)))] = src.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 3)))];
        dest.*.u_addr.ip6.zone = src.*.u_addr.ip6.zone;
    } else {
        dest.*.u_addr.ip4.addr = src.*.u_addr.ip4.addr;
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 1)))] = 0;
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 2)))] = 0;
        dest.*.u_addr.ip6.addr[@as(c_uint, @intCast(@as(c_int, 3)))] = 0;
        dest.*.u_addr.ip6.zone = 0;
    }
}
pub const esp_netif_obj = opaque {};
pub const esp_netif_t = esp_netif_obj;
pub const esp_netif_dns_type_t = enum(c_uint) {
    ESP_NETIF_DNS_MAIN = 0,
    ESP_NETIF_DNS_BACKUP = 1,
    ESP_NETIF_DNS_FALLBACK = 2,
    ESP_NETIF_DNS_MAX = 3,
};
pub const esp_netif_dns_info_t = extern struct {
    ip: esp_ip_addr_t = std.mem.zeroes(esp_ip_addr_t),
};
pub const esp_netif_dhcp_status_t = enum(c_uint) {
    ESP_NETIF_DHCP_INIT = 0,
    ESP_NETIF_DHCP_STARTED = 1,
    ESP_NETIF_DHCP_STOPPED = 2,
    ESP_NETIF_DHCP_STATUS_MAX = 3,
};
pub const esp_netif_dhcp_option_mode_t = enum(c_uint) {
    ESP_NETIF_OP_START = 0,
    ESP_NETIF_OP_SET = 1,
    ESP_NETIF_OP_GET = 2,
    ESP_NETIF_OP_MAX = 3,
};
pub const esp_netif_dhcp_option_id_t = enum(c_uint) {
    ESP_NETIF_SUBNET_MASK = 1,
    ESP_NETIF_DOMAIN_NAME_SERVER = 6,
    ESP_NETIF_ROUTER_SOLICITATION_ADDRESS = 32,
    ESP_NETIF_REQUESTED_IP_ADDRESS = 50,
    ESP_NETIF_IP_ADDRESS_LEASE_TIME = 51,
    ESP_NETIF_IP_REQUEST_RETRY_TIME = 52,
    ESP_NETIF_VENDOR_CLASS_IDENTIFIER = 60,
    ESP_NETIF_VENDOR_SPECIFIC_INFO = 43,
};
pub const ip_event_t = enum(c_uint) {
    IP_EVENT_STA_GOT_IP = 0,
    IP_EVENT_STA_LOST_IP = 1,
    IP_EVENT_AP_STAIPASSIGNED = 2,
    IP_EVENT_GOT_IP6 = 3,
    IP_EVENT_ETH_GOT_IP = 4,
    IP_EVENT_ETH_LOST_IP = 5,
    IP_EVENT_PPP_GOT_IP = 6,
    IP_EVENT_PPP_LOST_IP = 7,
};
pub extern const IP_EVENT: esp_event_base_t;
pub const esp_netif_ip_info_t = extern struct {
    ip: esp_ip4_addr_t = std.mem.zeroes(esp_ip4_addr_t),
    netmask: esp_ip4_addr_t = std.mem.zeroes(esp_ip4_addr_t),
    gw: esp_ip4_addr_t = std.mem.zeroes(esp_ip4_addr_t),
};
pub const esp_netif_ip6_info_t = extern struct {
    ip: esp_ip6_addr_t = std.mem.zeroes(esp_ip6_addr_t),
};
pub const ip_event_got_ip_t = extern struct {
    esp_netif: ?*esp_netif_t = std.mem.zeroes(?*esp_netif_t),
    ip_info: esp_netif_ip_info_t = std.mem.zeroes(esp_netif_ip_info_t),
    ip_changed: bool = std.mem.zeroes(bool),
};
pub const ip_event_got_ip6_t = extern struct {
    esp_netif: ?*esp_netif_t = std.mem.zeroes(?*esp_netif_t),
    ip6_info: esp_netif_ip6_info_t = std.mem.zeroes(esp_netif_ip6_info_t),
    ip_index: c_int = std.mem.zeroes(c_int),
};
pub const ip_event_add_ip6_t = extern struct {
    addr: esp_ip6_addr_t = std.mem.zeroes(esp_ip6_addr_t),
    preferred: bool = std.mem.zeroes(bool),
};
pub const ip_event_ap_staipassigned_t = extern struct {
    esp_netif: ?*esp_netif_t = std.mem.zeroes(?*esp_netif_t),
    ip: esp_ip4_addr_t = std.mem.zeroes(esp_ip4_addr_t),
    mac: [6]u8 = std.mem.zeroes([6]u8),
};
pub const enum_esp_netif_flags = enum(c_uint) {
    ESP_NETIF_DHCP_CLIENT = 1,
    ESP_NETIF_DHCP_SERVER = 2,
    ESP_NETIF_FLAG_AUTOUP = 4,
    ESP_NETIF_FLAG_GARP = 8,
    ESP_NETIF_FLAG_EVENT_IP_MODIFIED = 16,
    ESP_NETIF_FLAG_IS_PPP = 32,
    ESP_NETIF_FLAG_IS_BRIDGE = 64,
    ESP_NETIF_FLAG_MLDV6_REPORT = 128,
};
pub const esp_netif_flags_t = enum_esp_netif_flags;
pub const enum_esp_netif_ip_event_type = enum(c_uint) {
    ESP_NETIF_IP_EVENT_GOT_IP = 1,
    ESP_NETIF_IP_EVENT_LOST_IP = 2,
};
pub const esp_netif_ip_event_type_t = enum_esp_netif_ip_event_type;
pub const bridgeif_config = extern struct {
    max_fdb_dyn_entries: u16 = std.mem.zeroes(u16),
    max_fdb_sta_entries: u16 = std.mem.zeroes(u16),
    max_ports: u8 = std.mem.zeroes(u8),
};
pub const bridgeif_config_t = bridgeif_config;
pub const esp_netif_inherent_config = extern struct {
    flags: esp_netif_flags_t = std.mem.zeroes(esp_netif_flags_t),
    mac: [6]u8 = std.mem.zeroes([6]u8),
    ip_info: [*c]const esp_netif_ip_info_t = std.mem.zeroes([*c]const esp_netif_ip_info_t),
    get_ip_event: u32 = std.mem.zeroes(u32),
    lost_ip_event: u32 = std.mem.zeroes(u32),
    if_key: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    if_desc: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    route_prio: c_int = std.mem.zeroes(c_int),
    bridge_info: [*c]bridgeif_config_t = std.mem.zeroes([*c]bridgeif_config_t),
};
pub const esp_netif_inherent_config_t = esp_netif_inherent_config;
pub const esp_netif_iodriver_handle = ?*anyopaque;
pub const esp_netif_driver_ifconfig = extern struct {
    handle: esp_netif_iodriver_handle = std.mem.zeroes(esp_netif_iodriver_handle),
    transmit: ?*const fn (?*anyopaque, ?*anyopaque, usize) callconv(.C) esp_err_t = std.mem.zeroes(?*const fn (?*anyopaque, ?*anyopaque, usize) callconv(.C) esp_err_t),
    transmit_wrap: ?*const fn (?*anyopaque, ?*anyopaque, usize, ?*anyopaque) callconv(.C) esp_err_t = std.mem.zeroes(?*const fn (?*anyopaque, ?*anyopaque, usize, ?*anyopaque) callconv(.C) esp_err_t),
    driver_free_rx_buffer: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void = std.mem.zeroes(?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void),
};
pub const esp_netif_driver_ifconfig_t = esp_netif_driver_ifconfig;
pub const esp_netif_netstack_config = opaque {};
pub const esp_netif_netstack_config_t = esp_netif_netstack_config;
pub const esp_netif_config = extern struct {
    base: [*c]const esp_netif_inherent_config_t = std.mem.zeroes([*c]const esp_netif_inherent_config_t),
    driver: [*c]const esp_netif_driver_ifconfig_t = std.mem.zeroes([*c]const esp_netif_driver_ifconfig_t),
    stack: ?*const esp_netif_netstack_config_t = std.mem.zeroes(?*const esp_netif_netstack_config_t),
};
pub const esp_netif_config_t = esp_netif_config;
pub const esp_netif_driver_base_s = extern struct {
    post_attach: ?*const fn (?*esp_netif_t, esp_netif_iodriver_handle) callconv(.C) esp_err_t = std.mem.zeroes(?*const fn (?*esp_netif_t, esp_netif_iodriver_handle) callconv(.C) esp_err_t),
    netif: ?*esp_netif_t = std.mem.zeroes(?*esp_netif_t),
};
pub const esp_netif_driver_base_t = esp_netif_driver_base_s;
pub const esp_netif_pair_mac_ip_t = extern struct {
    mac: [6]u8 = std.mem.zeroes([6]u8),
    ip: esp_ip4_addr_t = std.mem.zeroes(esp_ip4_addr_t),
};
pub const esp_netif_receive_t = ?*const fn (?*esp_netif_t, ?*anyopaque, usize, ?*anyopaque) callconv(.C) esp_err_t;
pub extern var _g_esp_netif_netstack_default_eth: ?*const esp_netif_netstack_config_t;
pub extern var _g_esp_netif_netstack_default_br: ?*const esp_netif_netstack_config_t;
pub extern var _g_esp_netif_netstack_default_wifi_sta: ?*const esp_netif_netstack_config_t;
pub extern var _g_esp_netif_netstack_default_wifi_ap: ?*const esp_netif_netstack_config_t;
pub extern const _g_esp_netif_inherent_sta_config: esp_netif_inherent_config_t;
pub extern const _g_esp_netif_inherent_ap_config: esp_netif_inherent_config_t;
pub extern const _g_esp_netif_inherent_eth_config: esp_netif_inherent_config_t;
pub extern const _g_esp_netif_soft_ap_ip: esp_netif_ip_info_t;
pub extern fn esp_netif_init() esp_err_t;
pub extern fn esp_netif_deinit() esp_err_t;
pub extern fn esp_netif_new(esp_netif_config: [*c]const esp_netif_config_t) ?*esp_netif_t;
pub extern fn esp_netif_destroy(esp_netif: ?*esp_netif_t) void;
pub extern fn esp_netif_set_driver_config(esp_netif: ?*esp_netif_t, driver_config: [*c]const esp_netif_driver_ifconfig_t) esp_err_t;
pub extern fn esp_netif_attach(esp_netif: ?*esp_netif_t, driver_handle: esp_netif_iodriver_handle) esp_err_t;
pub extern fn esp_netif_receive(esp_netif: ?*esp_netif_t, buffer: ?*anyopaque, len: usize, eb: ?*anyopaque) esp_err_t;
pub extern fn esp_netif_action_start(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_stop(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_connected(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_disconnected(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_got_ip(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_join_ip6_multicast_group(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_leave_ip6_multicast_group(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_add_ip6_address(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_action_remove_ip6_address(esp_netif: ?*anyopaque, base: esp_event_base_t, event_id: i32, data: ?*anyopaque) void;
pub extern fn esp_netif_set_default_netif(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_get_default_netif() ?*esp_netif_t;
pub extern fn esp_netif_join_ip6_multicast_group(esp_netif: ?*esp_netif_t, addr: [*c]const esp_ip6_addr_t) esp_err_t;
pub extern fn esp_netif_leave_ip6_multicast_group(esp_netif: ?*esp_netif_t, addr: [*c]const esp_ip6_addr_t) esp_err_t;
pub extern fn esp_netif_set_mac(esp_netif: ?*esp_netif_t, mac: [*c]u8) esp_err_t;
pub extern fn esp_netif_get_mac(esp_netif: ?*esp_netif_t, mac: [*c]u8) esp_err_t;
pub extern fn esp_netif_set_hostname(esp_netif: ?*esp_netif_t, hostname: [*:0]const u8) esp_err_t;
pub extern fn esp_netif_get_hostname(esp_netif: ?*esp_netif_t, hostname: [*c][*c]const u8) esp_err_t;
pub extern fn esp_netif_is_netif_up(esp_netif: ?*esp_netif_t) bool;
pub extern fn esp_netif_get_ip_info(esp_netif: ?*esp_netif_t, ip_info: [*c]esp_netif_ip_info_t) esp_err_t;
pub extern fn esp_netif_get_old_ip_info(esp_netif: ?*esp_netif_t, ip_info: [*c]esp_netif_ip_info_t) esp_err_t;
pub extern fn esp_netif_set_ip_info(esp_netif: ?*esp_netif_t, ip_info: [*c]const esp_netif_ip_info_t) esp_err_t;
pub extern fn esp_netif_set_old_ip_info(esp_netif: ?*esp_netif_t, ip_info: [*c]const esp_netif_ip_info_t) esp_err_t;
pub extern fn esp_netif_get_netif_impl_index(esp_netif: ?*esp_netif_t) c_int;
pub extern fn esp_netif_get_netif_impl_name(esp_netif: ?*esp_netif_t, name: [*c]u8) esp_err_t;
pub extern fn esp_netif_napt_enable(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_napt_disable(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_dhcps_option(esp_netif: ?*esp_netif_t, opt_op: esp_netif_dhcp_option_mode_t, opt_id: esp_netif_dhcp_option_id_t, opt_val: ?*anyopaque, opt_len: u32) esp_err_t;
pub extern fn esp_netif_dhcpc_option(esp_netif: ?*esp_netif_t, opt_op: esp_netif_dhcp_option_mode_t, opt_id: esp_netif_dhcp_option_id_t, opt_val: ?*anyopaque, opt_len: u32) esp_err_t;
pub extern fn esp_netif_dhcpc_start(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_dhcpc_stop(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_dhcpc_get_status(esp_netif: ?*esp_netif_t, status: [*c]esp_netif_dhcp_status_t) esp_err_t;
pub extern fn esp_netif_dhcps_get_status(esp_netif: ?*esp_netif_t, status: [*c]esp_netif_dhcp_status_t) esp_err_t;
pub extern fn esp_netif_dhcps_start(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_dhcps_stop(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_dhcps_get_clients_by_mac(esp_netif: ?*esp_netif_t, num: c_int, mac_ip_pair: [*c]esp_netif_pair_mac_ip_t) esp_err_t;
pub extern fn esp_netif_set_dns_info(esp_netif: ?*esp_netif_t, @"type": esp_netif_dns_type_t, dns: [*c]esp_netif_dns_info_t) esp_err_t;
pub extern fn esp_netif_get_dns_info(esp_netif: ?*esp_netif_t, @"type": esp_netif_dns_type_t, dns: [*c]esp_netif_dns_info_t) esp_err_t;
pub extern fn esp_netif_create_ip6_linklocal(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_get_ip6_linklocal(esp_netif: ?*esp_netif_t, if_ip6: [*c]esp_ip6_addr_t) esp_err_t;
pub extern fn esp_netif_get_ip6_global(esp_netif: ?*esp_netif_t, if_ip6: [*c]esp_ip6_addr_t) esp_err_t;
pub extern fn esp_netif_get_all_ip6(esp_netif: ?*esp_netif_t, if_ip6: [*c]esp_ip6_addr_t) c_int;
pub extern fn esp_netif_add_ip6_address(esp_netif: ?*esp_netif_t, addr: esp_ip6_addr_t, preferred: bool) esp_err_t;
pub extern fn esp_netif_remove_ip6_address(esp_netif: ?*esp_netif_t, addr: [*c]const esp_ip6_addr_t) esp_err_t;
pub extern fn esp_netif_set_ip4_addr(addr: [*c]esp_ip4_addr_t, a: u8, b: u8, c: u8, d: u8) void;
pub extern fn esp_ip4addr_ntoa(addr: [*c]const esp_ip4_addr_t, buf: [*c]u8, buflen: c_int) [*c]u8;
pub extern fn esp_ip4addr_aton(addr: [*:0]const u8) u32;
pub extern fn esp_netif_str_to_ip4(src: [*:0]const u8, dst: [*c]esp_ip4_addr_t) esp_err_t;
pub extern fn esp_netif_str_to_ip6(src: [*:0]const u8, dst: [*c]esp_ip6_addr_t) esp_err_t;
pub extern fn esp_netif_get_io_driver(esp_netif: ?*esp_netif_t) esp_netif_iodriver_handle;
pub extern fn esp_netif_get_handle_from_ifkey(if_key: [*:0]const u8) ?*esp_netif_t;
pub extern fn esp_netif_get_flags(esp_netif: ?*esp_netif_t) esp_netif_flags_t;
pub extern fn esp_netif_get_ifkey(esp_netif: ?*esp_netif_t) [*:0]const u8;
pub extern fn esp_netif_get_desc(esp_netif: ?*esp_netif_t) [*:0]const u8;
pub extern fn esp_netif_get_route_prio(esp_netif: ?*esp_netif_t) c_int;
pub extern fn esp_netif_get_event_id(esp_netif: ?*esp_netif_t, event_type: esp_netif_ip_event_type_t) i32;
pub extern fn esp_netif_next(esp_netif: ?*esp_netif_t) ?*esp_netif_t;
pub extern fn esp_netif_next_unsafe(esp_netif: ?*esp_netif_t) ?*esp_netif_t;
pub const esp_netif_find_predicate_t = ?*const fn (?*esp_netif_t, ?*anyopaque) callconv(.C) bool;
pub extern fn esp_netif_find_if(@"fn": esp_netif_find_predicate_t, ctx: ?*anyopaque) ?*esp_netif_t;
pub extern fn esp_netif_get_nr_of_ifs() usize;
pub extern fn esp_netif_netstack_buf_ref(netstack_buf: ?*anyopaque) void;
pub extern fn esp_netif_netstack_buf_free(netstack_buf: ?*anyopaque) void;
pub const esp_netif_callback_fn = ?*const fn (?*anyopaque) callconv(.C) esp_err_t;
pub extern fn esp_netif_tcpip_exec(@"fn": esp_netif_callback_fn, ctx: ?*anyopaque) esp_err_t;
pub extern fn esp_netif_attach_wifi_station(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_netif_attach_wifi_ap(esp_netif: ?*esp_netif_t) esp_err_t;
pub extern fn esp_wifi_set_default_wifi_sta_handlers() esp_err_t;
pub extern fn esp_wifi_set_default_wifi_ap_handlers() esp_err_t;
pub extern fn esp_wifi_set_default_wifi_nan_handlers() esp_err_t;
pub extern fn esp_wifi_clear_default_wifi_driver_and_handlers(esp_netif: ?*anyopaque) esp_err_t;
pub extern fn esp_netif_create_default_wifi_ap() ?*esp_netif_t;
pub extern fn esp_netif_create_default_wifi_sta() ?*esp_netif_t;
pub extern fn esp_netif_create_default_wifi_nan() ?*esp_netif_t;
pub extern fn esp_netif_destroy_default_wifi(esp_netif: ?*anyopaque) void;
pub extern fn esp_netif_create_wifi(wifi_if: wifi_interface_t, esp_netif_config: [*c]const esp_netif_inherent_config_t) ?*esp_netif_t;
pub extern fn esp_netif_create_default_wifi_mesh_netifs(p_netif_sta: [*c]?*esp_netif_t, p_netif_ap: [*c]?*esp_netif_t) esp_err_t;
pub const wifi_osi_funcs_t = opaque {};
pub const wifi_init_config_t = extern struct {
    osi_funcs: ?*wifi_osi_funcs_t = std.mem.zeroes(?*wifi_osi_funcs_t),
    wpa_crypto_funcs: wpa_crypto_funcs_t = std.mem.zeroes(wpa_crypto_funcs_t),
    static_rx_buf_num: c_int = std.mem.zeroes(c_int),
    dynamic_rx_buf_num: c_int = std.mem.zeroes(c_int),
    tx_buf_type: c_int = std.mem.zeroes(c_int),
    static_tx_buf_num: c_int = std.mem.zeroes(c_int),
    dynamic_tx_buf_num: c_int = std.mem.zeroes(c_int),
    rx_mgmt_buf_type: c_int = std.mem.zeroes(c_int),
    rx_mgmt_buf_num: c_int = std.mem.zeroes(c_int),
    cache_tx_buf_num: c_int = std.mem.zeroes(c_int),
    csi_enable: c_int = std.mem.zeroes(c_int),
    ampdu_rx_enable: c_int = std.mem.zeroes(c_int),
    ampdu_tx_enable: c_int = std.mem.zeroes(c_int),
    amsdu_tx_enable: c_int = std.mem.zeroes(c_int),
    nvs_enable: c_int = std.mem.zeroes(c_int),
    nano_enable: c_int = std.mem.zeroes(c_int),
    rx_ba_win: c_int = std.mem.zeroes(c_int),
    wifi_task_core_id: c_int = std.mem.zeroes(c_int),
    beacon_max_len: c_int = std.mem.zeroes(c_int),
    mgmt_sbuf_num: c_int = std.mem.zeroes(c_int),
    feature_caps: u64 = std.mem.zeroes(u64),
    sta_disconnected_pm: bool = std.mem.zeroes(bool),
    espnow_max_encrypt_num: c_int = std.mem.zeroes(c_int),
    magic: c_int = std.mem.zeroes(c_int),
};
pub extern const g_wifi_default_wpa_crypto_funcs: wpa_crypto_funcs_t;
pub extern var g_wifi_osi_funcs: wifi_osi_funcs_t;
pub extern fn esp_wifi_init(config: [*c]const wifi_init_config_t) esp_err_t;
pub extern fn esp_wifi_deinit() esp_err_t;
pub extern fn esp_wifi_set_mode(mode: wifi_mode_t) esp_err_t;
pub extern fn esp_wifi_get_mode(mode: [*c]wifi_mode_t) esp_err_t;
pub extern fn esp_wifi_start() esp_err_t;
pub extern fn esp_wifi_stop() esp_err_t;
pub extern fn esp_wifi_restore() esp_err_t;
pub extern fn esp_wifi_connect() esp_err_t;
pub extern fn esp_wifi_disconnect() esp_err_t;
pub extern fn esp_wifi_clear_fast_connect() esp_err_t;
pub extern fn esp_wifi_deauth_sta(aid: u16) esp_err_t;
pub extern fn esp_wifi_scan_start(config: [*c]const wifi_scan_config_t, block: bool) esp_err_t;
pub extern fn esp_wifi_scan_stop() esp_err_t;
pub extern fn esp_wifi_scan_get_ap_num(number: [*c]u16) esp_err_t;
pub extern fn esp_wifi_scan_get_ap_records(number: [*c]u16, ap_records: ?*wifi_ap_record_t) esp_err_t;
pub extern fn esp_wifi_scan_get_ap_record(ap_record: ?*wifi_ap_record_t) esp_err_t;
pub extern fn esp_wifi_clear_ap_list() esp_err_t;
pub extern fn esp_wifi_sta_get_ap_info(ap_info: ?*wifi_ap_record_t) esp_err_t;
pub extern fn esp_wifi_set_ps(@"type": wifi_ps_type_t) esp_err_t;
pub extern fn esp_wifi_get_ps(@"type": [*c]wifi_ps_type_t) esp_err_t;
pub extern fn esp_wifi_set_protocol(ifx: wifi_interface_t, protocol_bitmap: u8) esp_err_t;
pub extern fn esp_wifi_get_protocol(ifx: wifi_interface_t, protocol_bitmap: [*c]u8) esp_err_t;
pub extern fn esp_wifi_set_bandwidth(ifx: wifi_interface_t, bw: wifi_bandwidth_t) esp_err_t;
pub extern fn esp_wifi_get_bandwidth(ifx: wifi_interface_t, bw: [*c]wifi_bandwidth_t) esp_err_t;
pub extern fn esp_wifi_set_channel(primary: u8, second: wifi_second_chan_t) esp_err_t;
pub extern fn esp_wifi_get_channel(primary: [*c]u8, second: [*c]wifi_second_chan_t) esp_err_t;
pub extern fn esp_wifi_set_country(country: [*c]const wifi_country_t) esp_err_t;
pub extern fn esp_wifi_get_country(country: [*c]wifi_country_t) esp_err_t;
pub extern fn esp_wifi_set_mac(ifx: wifi_interface_t, mac: [*:0]const u8) esp_err_t;
pub extern fn esp_wifi_get_mac(ifx: wifi_interface_t, mac: [*c]u8) esp_err_t;
pub const wifi_promiscuous_cb_t = ?*const fn (?*anyopaque, wifi_promiscuous_pkt_type_t) callconv(.C) void;
pub extern fn esp_wifi_set_promiscuous_rx_cb(cb: wifi_promiscuous_cb_t) esp_err_t;
pub extern fn esp_wifi_set_promiscuous(en: bool) esp_err_t;
pub extern fn esp_wifi_get_promiscuous(en: [*c]bool) esp_err_t;
pub extern fn esp_wifi_set_promiscuous_filter(filter: [*c]const wifi_promiscuous_filter_t) esp_err_t;
pub extern fn esp_wifi_get_promiscuous_filter(filter: [*c]wifi_promiscuous_filter_t) esp_err_t;
pub extern fn esp_wifi_set_promiscuous_ctrl_filter(filter: [*c]const wifi_promiscuous_filter_t) esp_err_t;
pub extern fn esp_wifi_get_promiscuous_ctrl_filter(filter: [*c]wifi_promiscuous_filter_t) esp_err_t;
pub extern fn esp_wifi_set_config(interface: wifi_interface_t, conf: ?*wifi_config_t) esp_err_t;
pub extern fn esp_wifi_get_config(interface: wifi_interface_t, conf: ?*wifi_config_t) esp_err_t;
pub extern fn esp_wifi_ap_get_sta_list(sta: ?*wifi_sta_list_t) esp_err_t;
pub extern fn esp_wifi_ap_get_sta_aid(mac: [*:0]const u8, aid: [*c]u16) esp_err_t;
pub extern fn esp_wifi_set_storage(storage: wifi_storage_t) esp_err_t;
pub const esp_vendor_ie_cb_t = ?*const fn (?*anyopaque, wifi_vendor_ie_type_t, [*:0]const u8, [*c]const vendor_ie_data_t, c_int) callconv(.C) void;
pub extern fn esp_wifi_set_vendor_ie(enable: bool, @"type": wifi_vendor_ie_type_t, idx: wifi_vendor_ie_id_t, vnd_ie: ?*const anyopaque) esp_err_t;
pub extern fn esp_wifi_set_vendor_ie_cb(cb: esp_vendor_ie_cb_t, ctx: ?*anyopaque) esp_err_t;
pub extern fn esp_wifi_set_max_tx_power(power: i8) esp_err_t;
pub extern fn esp_wifi_get_max_tx_power(power: [*c]i8) esp_err_t;
pub extern fn esp_wifi_set_event_mask(mask: u32) esp_err_t;
pub extern fn esp_wifi_get_event_mask(mask: [*c]u32) esp_err_t;
pub extern fn esp_wifi_80211_tx(ifx: wifi_interface_t, buffer: ?*const anyopaque, len: c_int, en_sys_seq: bool) esp_err_t;
pub const wifi_csi_cb_t = ?*const fn (?*anyopaque, ?*wifi_csi_info_t) callconv(.C) void;
pub extern fn esp_wifi_set_csi_rx_cb(cb: wifi_csi_cb_t, ctx: ?*anyopaque) esp_err_t;
pub extern fn esp_wifi_set_csi_config(config: ?*const wifi_csi_config_t) esp_err_t;
pub extern fn esp_wifi_set_csi(en: bool) esp_err_t;
pub extern fn esp_wifi_set_ant_gpio(config: [*c]const wifi_ant_gpio_config_t) esp_err_t;
pub extern fn esp_wifi_get_ant_gpio(config: [*c]wifi_ant_gpio_config_t) esp_err_t;
pub extern fn esp_wifi_set_ant(config: ?*const wifi_ant_config_t) esp_err_t;
pub extern fn esp_wifi_get_ant(config: ?*wifi_ant_config_t) esp_err_t;
pub extern fn esp_wifi_get_tsf_time(interface: wifi_interface_t) i64;
pub extern fn esp_wifi_set_inactive_time(ifx: wifi_interface_t, sec: u16) esp_err_t;
pub extern fn esp_wifi_get_inactive_time(ifx: wifi_interface_t, sec: [*c]u16) esp_err_t;
pub extern fn esp_wifi_statis_dump(modules: u32) esp_err_t;
pub extern fn esp_wifi_set_rssi_threshold(rssi: i32) esp_err_t;
pub extern fn esp_wifi_ftm_initiate_session(cfg: [*c]wifi_ftm_initiator_cfg_t) esp_err_t;
pub extern fn esp_wifi_ftm_end_session() esp_err_t;
pub extern fn esp_wifi_ftm_resp_set_offset(offset_cm: i16) esp_err_t;
pub extern fn esp_wifi_config_11b_rate(ifx: wifi_interface_t, disable: bool) esp_err_t;
pub extern fn esp_wifi_connectionless_module_set_wake_interval(wake_interval: u16) esp_err_t;
pub extern fn esp_wifi_force_wakeup_acquire() esp_err_t;
pub extern fn esp_wifi_force_wakeup_release() esp_err_t;
pub extern fn esp_wifi_set_country_code(country: [*:0]const u8, ieee80211d_enabled: bool) esp_err_t;
pub extern fn esp_wifi_get_country_code(country: [*c]u8) esp_err_t;
pub extern fn esp_wifi_config_80211_tx_rate(ifx: wifi_interface_t, rate: wifi_phy_rate_t) esp_err_t;
pub extern fn esp_wifi_disable_pmf_config(ifx: wifi_interface_t) esp_err_t;
pub extern fn esp_wifi_sta_get_aid(aid: [*c]u16) esp_err_t;
pub extern fn esp_wifi_sta_get_negotiated_phymode(phymode: [*c]wifi_phy_mode_t) esp_err_t;
pub extern fn esp_wifi_set_dynamic_cs(enabled: bool) esp_err_t;
pub extern fn esp_wifi_sta_get_rssi(rssi: [*c]c_int) esp_err_t;

pub const va_list = extern struct {
    __va_stk: [*c]c_int = std.mem.zeroes([*c]c_int),
    __va_reg: [*c]c_int = std.mem.zeroes([*c]c_int),
    __va_ndx: c_int = std.mem.zeroes(c_int),
};
pub const sched_param = extern struct {
    sched_priority: c_int = std.mem.zeroes(c_int),
};
pub extern fn sched_yield() c_int;
pub const pthread_t = c_uint;
pub const pthread_attr_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    stackaddr: ?*anyopaque = null,
    stacksize: c_int = std.mem.zeroes(c_int),
    contentionscope: c_int = std.mem.zeroes(c_int),
    inheritsched: c_int = std.mem.zeroes(c_int),
    schedpolicy: c_int = std.mem.zeroes(c_int),
    schedparam: sched_param = std.mem.zeroes(sched_param),
    detachstate: c_int = std.mem.zeroes(c_int),
};
pub const pthread_mutex_t = c_uint;
pub const pthread_mutexattr_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    type: c_int = std.mem.zeroes(c_int),
    recursive: c_int = std.mem.zeroes(c_int),
};
pub const pthread_cond_t = c_uint;
pub const pthread_condattr_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    clock: c_ulong = std.mem.zeroes(c_ulong),
};
pub const pthread_key_t = c_uint;
pub const pthread_once_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    init_executed: c_int = std.mem.zeroes(c_int),
};
pub const bintime = extern struct {
    sec: i64 = std.mem.zeroes(i64),
    frac: u64 = std.mem.zeroes(u64),
};
pub const pthread_cleanup_context = extern struct {
    _routine: ?*const fn (?*anyopaque) callconv(.C) void = std.mem.zeroes(?*const fn (?*anyopaque) callconv(.C) void),
    _arg: ?*anyopaque = null,
    _canceltype: c_int = std.mem.zeroes(c_int),
    _previous: [*c]pthread_cleanup_context = std.mem.zeroes([*c]pthread_cleanup_context),
};
pub extern fn pthread_mutexattr_init(__attr: [*c]pthread_mutexattr_t) c_int;
pub extern fn pthread_mutexattr_destroy(__attr: [*c]pthread_mutexattr_t) c_int;
pub extern fn pthread_mutexattr_getpshared(__attr: [*c]const pthread_mutexattr_t, __pshared: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_setpshared(__attr: [*c]pthread_mutexattr_t, __pshared: c_int) c_int;
pub extern fn pthread_mutexattr_gettype(__attr: [*c]const pthread_mutexattr_t, __kind: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_settype(__attr: [*c]pthread_mutexattr_t, __kind: c_int) c_int;
pub extern fn pthread_mutex_init(__mutex: [*c]pthread_mutex_t, __attr: [*c]const pthread_mutexattr_t) c_int;
pub extern fn pthread_mutex_destroy(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_lock(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_trylock(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_unlock(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_timedlock(__mutex: [*c]pthread_mutex_t, __timeout: [*c]const timespec) c_int;
pub extern fn pthread_condattr_init(__attr: [*c]pthread_condattr_t) c_int;
pub extern fn pthread_condattr_destroy(__attr: [*c]pthread_condattr_t) c_int;
pub extern fn pthread_condattr_getclock(noalias __attr: [*c]const pthread_condattr_t, noalias __clock_id: [*c]c_ulong) c_int;
pub extern fn pthread_condattr_setclock(__attr: [*c]pthread_condattr_t, __clock_id: c_ulong) c_int;
pub extern fn pthread_condattr_getpshared(__attr: [*c]const pthread_condattr_t, __pshared: [*c]c_int) c_int;
pub extern fn pthread_condattr_setpshared(__attr: [*c]pthread_condattr_t, __pshared: c_int) c_int;
pub extern fn pthread_cond_init(__cond: [*c]pthread_cond_t, __attr: [*c]const pthread_condattr_t) c_int;
pub extern fn pthread_cond_destroy(__mutex: [*c]pthread_cond_t) c_int;
pub extern fn pthread_cond_signal(__cond: [*c]pthread_cond_t) c_int;
pub extern fn pthread_cond_broadcast(__cond: [*c]pthread_cond_t) c_int;
pub extern fn pthread_cond_wait(__cond: [*c]pthread_cond_t, __mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_cond_timedwait(__cond: [*c]pthread_cond_t, __mutex: [*c]pthread_mutex_t, __abstime: [*c]const timespec) c_int;
pub extern fn pthread_attr_setschedparam(__attr: [*c]pthread_attr_t, __param: [*c]const sched_param) c_int;
pub extern fn pthread_attr_getschedparam(__attr: [*c]const pthread_attr_t, __param: [*c]sched_param) c_int;
pub extern fn pthread_attr_init(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_destroy(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_setstack(attr: [*c]pthread_attr_t, __stackaddr: ?*anyopaque, __stacksize: usize) c_int;
pub extern fn pthread_attr_getstack(attr: [*c]const pthread_attr_t, __stackaddr: [*c]?*anyopaque, __stacksize: [*c]usize) c_int;
pub extern fn pthread_attr_getstacksize(__attr: [*c]const pthread_attr_t, __stacksize: [*c]usize) c_int;
pub extern fn pthread_attr_setstacksize(__attr: [*c]pthread_attr_t, __stacksize: usize) c_int;
pub extern fn pthread_attr_getstackaddr(__attr: [*c]const pthread_attr_t, __stackaddr: [*c]?*anyopaque) c_int;
pub extern fn pthread_attr_setstackaddr(__attr: [*c]pthread_attr_t, __stackaddr: ?*anyopaque) c_int;
pub extern fn pthread_attr_getdetachstate(__attr: [*c]const pthread_attr_t, __detachstate: [*c]c_int) c_int;
pub extern fn pthread_attr_setdetachstate(__attr: [*c]pthread_attr_t, __detachstate: c_int) c_int;
pub extern fn pthread_attr_getguardsize(__attr: [*c]const pthread_attr_t, __guardsize: [*c]usize) c_int;
pub extern fn pthread_attr_setguardsize(__attr: [*c]pthread_attr_t, __guardsize: usize) c_int;
pub extern fn pthread_create(__pthread: [*c]pthread_t, __attr: [*c]const pthread_attr_t, __start_routine: ?*const fn (?*anyopaque) callconv(.C) ?*anyopaque, __arg: ?*anyopaque) c_int;
pub extern fn pthread_join(__pthread: pthread_t, __value_ptr: [*c]?*anyopaque) c_int;
pub extern fn pthread_detach(__pthread: pthread_t) c_int;
pub extern fn pthread_exit(__value_ptr: ?*anyopaque) noreturn;
pub extern fn pthread_self() pthread_t;
pub extern fn pthread_equal(__t1: pthread_t, __t2: pthread_t) c_int;
pub extern fn pthread_getcpuclockid(thread: pthread_t, clock_id: [*c]c_ulong) c_int;
pub extern fn pthread_setconcurrency(new_level: c_int) c_int;
pub extern fn pthread_getconcurrency() c_int;
pub extern fn pthread_yield() void;
pub extern fn pthread_once(__once_control: [*c]pthread_once_t, __init_routine: ?*const fn () callconv(.C) void) c_int;
pub extern fn pthread_key_create(__key: [*c]pthread_key_t, __destructor: ?*const fn (?*anyopaque) callconv(.C) void) c_int;
pub extern fn pthread_setspecific(__key: pthread_key_t, __value: ?*const anyopaque) c_int;
pub extern fn pthread_getspecific(__key: pthread_key_t) ?*anyopaque;
pub extern fn pthread_key_delete(__key: pthread_key_t) c_int;
pub extern fn pthread_cancel(__pthread: pthread_t) c_int;
pub extern fn pthread_setcancelstate(__state: c_int, __oldstate: [*c]c_int) c_int;
pub extern fn pthread_setcanceltype(__type: c_int, __oldtype: [*c]c_int) c_int;
pub extern fn pthread_testcancel() void;
pub extern fn _pthread_cleanup_push(_context: [*c]pthread_cleanup_context, _routine: ?*const fn (?*anyopaque) callconv(.C) void, _arg: ?*anyopaque) void;
pub extern fn _pthread_cleanup_pop(_context: [*c]pthread_cleanup_context, _execute: c_int) void;
pub const timespec = extern struct {
    tv_sec: i64 = std.mem.zeroes(i64),
    tv_nsec: c_long = std.mem.zeroes(c_long),
};
pub const itimerspec = extern struct {
    it_interval: timespec = std.mem.zeroes(timespec),
    it_value: timespec = std.mem.zeroes(timespec),
};
// TODO: port zig (std.Thread) to FreeRTOS

// panic handler for esp-idf
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    esp_log_write(default_level, "panic_handler", "PANIC: caused by %s\n", msg.ptr, esp_log_timestamp());
    if (error_return_trace) |trace| {
        for (trace.instruction_addresses) |address| {
            esp_log_write(default_level, "panic_handler", "Addr: %d\n", address, esp_log_timestamp());
        }
    }
    esp_system_abort("aborting...");
}

pub fn espLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    var heap = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    defer heap.deinit();
    const allocator = heap.allocator();

    // Ignore all non-error logging from sources other than
    // .my_project, .nice_library and the default
    const scope_prefix = "(" ++ switch (scope) {
        .my_project, .nice_library, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            @tagName(scope),
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;
    ESP_LOGI(allocator, "logging", prefix ++ format ++ "\n", args);
}
