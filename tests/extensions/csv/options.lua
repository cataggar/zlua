local rows = csv.read("Ada\t37\nBob\t", {delimiter = "tab", header = false})
print(rows[1]["0"], rows[1]["1"], rows[2]["1"] == csv.null)

local text = csv.write(rows, {
    delimiter = "tab",
    header = false,
    record_terminator = "lf",
    final_record_terminator = true,
})
print(text == "Ada\t37\nBob\t\n")

local ok_options, options_err = pcall(csv.write, {}, "csv")
local ok_delimiter, delimiter_err = pcall(csv.read, "a\n", {delimiter = "pipe"})
local ok_header, header_err = pcall(csv.read, "a\n", {header = "yes"})
local ok_terminator, terminator_err = pcall(csv.write, {}, {record_terminator = "bad"})

print(ok_options, tostring(options_err):find("csv.write") ~= nil)
print(ok_delimiter, tostring(delimiter_err):find("csv.read") ~= nil)
print(ok_header, tostring(header_err):find("csv.read") ~= nil)
print(ok_terminator, tostring(terminator_err):find("csv.write") ~= nil)
