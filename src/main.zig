const json = @import("json.zig");
pub fn main() !void {
    const pyfile = "logger.py";
    const root_id = "SKIC05008E004";
    const output_path = "logger_output.json";
    const is_lambda = false;
    json.tojson(pyfile.ptr, pyfile.len, root_id.ptr, root_id.len, output_path.ptr, output_path.len, is_lambda);
}
