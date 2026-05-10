local cfg = toml.read([=[title = "demo"
enabled = true
ports = [8000, 8001]

[database]
host = "localhost"
limits = { max = 10, ratio = 0.5 }

[[servers]]
name = "one"
ip = "10.0.0.1"

[[servers]]
name = "two"
ip = "10.0.0.2"
]=])

print(cfg.title, cfg.enabled, cfg.ports[2])
print(cfg.database.host, cfg.database.limits.max, cfg.database.limits.ratio)
print(cfg.servers[1].name, cfg.servers[2].ip)
