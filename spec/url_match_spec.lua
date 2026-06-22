local url_match = require("lib.url_match")
local get_host = url_match.get_host
local is_allowed = url_match.is_allowed

describe("get_host", function()
    it("returns nil for nil input", function()
        assert.is_nil(get_host(nil))
    end)

    it("returns nil for empty string", function()
        assert.is_nil(get_host(""))
    end)

    it("returns nil for garbage input (no scheme/authority)", function()
        assert.is_nil(get_host("not a url at all"))
        -- A bare hostname without a scheme has no authority component,
        -- so socket.url.parse does not populate .host.
        assert.is_nil(get_host("example.com"))
    end)

    it("extracts host from a simple HTTPS URL", function()
        assert.equals("example.com", get_host("https://example.com/path"))
    end)

    it("extracts host without port", function()
        assert.equals("example.com", get_host("https://example.com:8080/path"))
    end)

    it("extracts host without userinfo", function()
        assert.equals("example.com", get_host("https://user:pass@example.com/path"))
    end)

    it("lowercases the host", function()
        assert.equals("example.com", get_host("https://EXAMPLE.COM/Path"))
    end)

    it("extracts IPv4 host", function()
        assert.equals("192.168.1.1", get_host("http://192.168.1.1:8080/path"))
    end)

    it("preserves trailing dot in FQDN form", function()
        -- get_host does not strip the trailing dot; is_allowed normalizes it.
        assert.equals("example.com.", get_host("https://example.com./path"))
    end)
end)

describe("is_allowed", function()
    it("returns true for exact match", function()
        assert.is_true(is_allowed("wojtasord.com", {"wojtasord.com"}))
    end)

    it("returns true for subdomain match", function()
        assert.is_true(is_allowed("sub.wojtasord.com", {"wojtasord.com"}))
        assert.is_true(is_allowed("a.b.c.wojtasord.com", {"wojtasord.com"}))
    end)

    it("returns false for sibling-domain non-match", function()
        -- evilwojtasord.com must NOT match wojtasord.com.
        -- The leading dot in the suffix check prevents this false positive.
        assert.is_false(is_allowed("evilwojtasord.com", {"wojtasord.com"}))
    end)

    it("matches case-insensitively (uppercase host)", function()
        assert.is_true(is_allowed("WOJTASORD.COM", {"wojtasord.com"}))
    end)

    it("matches case-insensitively (uppercase domain entry)", function()
        assert.is_true(is_allowed("wojtasord.com", {"WOJTASORD.COM"}))
    end)

    it("matches when multiple entries are in the list", function()
        assert.is_true(is_allowed("other.com", {"wojtasord.com", "other.com"}))
        assert.is_true(is_allowed("sub.wojtasord.com", {"wojtasord.com", "other.com"}))
        assert.is_false(is_allowed("nope.com", {"wojtasord.com", "other.com"}))
    end)

    it("normalizes trailing-dot host (FQDN form)", function()
        assert.is_true(is_allowed("example.com.", {"example.com"}))
        assert.is_true(is_allowed("sub.example.com.", {"example.com"}))
    end)

    it("normalizes trailing-dot in domain entry", function()
        assert.is_true(is_allowed("example.com", {"example.com."}))
    end)

    it("matches IPv4 host exactly", function()
        assert.is_true(is_allowed("192.168.1.1", {"192.168.1.1"}))
        assert.is_false(is_allowed("192.168.1.1", {"10.0.0.1"}))
    end)

    it("returns false for nil or empty host", function()
        assert.is_false(is_allowed(nil, {"example.com"}))
        assert.is_false(is_allowed("", {"example.com"}))
    end)

    -- Empty allowlist: documented unsafe fallback.
    -- This describe block is intentionally isolated from single-entry
    -- behaviour so no test relies on both at once.
    describe("with empty allowlist", function()
        it("returns true for any host (unsafe fallback)", function()
            -- NOTE: empty allowlist = match every host. This is the documented
            -- unsafe-but-convenient fallback (see SECURITY.md). The plugin warns
            -- the user when this mode is active. Do not combine this expectation
            -- with single-entry behaviour in the same test.
            assert.is_true(is_allowed("anything.example.com", {}))
            assert.is_true(is_allowed("evilwojtasord.com", {}))
            assert.is_true(is_allowed("192.168.1.1", {}))
        end)

        it("returns true even when domains is nil", function()
            assert.is_true(is_allowed("anything.example.com", nil))
        end)
    end)

    -- Single-entry allowlist: tested independently of the empty-list
    -- short-circuit so the two behaviours are mutually exclusive in tests.
    describe("with a single entry", function()
        it("matches only that entry and its subdomains", function()
            assert.is_true(is_allowed("wojtasord.com", {"wojtasord.com"}))
            assert.is_true(is_allowed("a.b.wojtasord.com", {"wojtasord.com"}))
            assert.is_false(is_allowed("other.com", {"wojtasord.com"}))
            assert.is_false(is_allowed("evilwojtasord.com", {"wojtasord.com"}))
        end)
    end)
end)
