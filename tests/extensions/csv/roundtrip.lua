local input = {
    {name = "Ada", meta = {city = "London", zip = 123}, quote = "hi, \"Ada\""},
    {name = "Bob", meta = {city = "Paris"}, quote = "line\nbreak"},
}

local text = csv.write(input, {record_terminator = "lf"})
local rows = csv.read(text)

print(rows[1].name, rows[1]["meta.city"], rows[1]["meta.zip"])
print(rows[1].quote)
print(rows[2].name, rows[2]["meta.city"], rows[2]["meta.zip"] == csv.null)
print(rows[2].quote)
