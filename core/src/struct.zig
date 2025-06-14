pub const LogLevel = enum(u8) {
    Debug = 0,
    Info = 1,
    Warning = 2,
    Error = 3,
    Critical = 4,
};
pub const LogEntry = struct {
    /// The message is the log message.
    /// `logger.debug("debug message")` will be stored as `debug message`.
    /// `logger.info("info message")` will be stored as `info message`.
    /// `logger.warning("warning message")` will be stored as `warning message`.
    /// `logger.error("error message")` will be stored as `error message`.
    /// `logger.critical("critical message")` will be stored as `critical message`.
    message: []const u8,
    /// The level is the log level.
    /// `logger.debug("debug message")` will be stored as `LogLevel.Debug`.
    /// `logger.info("info message")` will be stored as `LogLevel.Info`.
    /// `logger.warning("warning message")` will be stored as `LogLevel.Warning`.
    /// `logger.error("error message")` will be stored as `LogLevel.Error`.
    /// `logger.critical("critical message")` will be stored as `LogLevel.Critical`.
    level: LogLevel,
};

pub const Logger = struct {
    /// Currently, three zeros are added to the end of numbers.
    /// It is necessary to allow users to configure this setting.
    id: [3]u8 = .{ 0, 0, 0 },
    entry: LogEntry,
};
