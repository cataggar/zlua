print(type(csv), type(import), type(package))

local rows = csv.read("name,age,active\r\nAda,37,true\r\nBob,,false")
print(#rows, rows[1].name, rows[1].age, rows[2].age == csv.null)
print(csv.write(rows, {record_terminator = "lf"}))
