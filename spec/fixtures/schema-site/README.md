# schema-site fixture

Valid content under a posts schema (required title, optional numeric
rating). The golden pins the pass path; violation specs copy this
fixture to temp dirs and break files (missing title, bad rating) to
assert all-together build failures.
