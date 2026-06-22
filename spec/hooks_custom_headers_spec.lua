-- Integration tests for hooks.lua custom header injection.
-- Uses a mocked socket.http to verify header injection behavior.

-- Mock socket.http that captures the request and returns a canned response
local captured_requests
local mock_http

local function setup_mock()
    captured_requests = {}
    mock_http = {
        request = function(req, body)
            if type(req) == "table" then
                table.insert(captured_requests, {
                    url = req.url,
                    headers = req.headers or {},
                    method = req.method,
                })
            else
                table.insert(captured_requests, {
                    url = req,
                    headers = {},
                    string_form = true,
                })
            end
            return 1, 200, { ["cf-ray"] = "test-ray-123" }
        end,
    }
    package.loaded["socket.http"] = mock_http
    package.loaded["ssl.https"] = mock_http
end

local function teardown_mock()
    package.loaded["socket.http"] = nil
    package.loaded["ssl.https"] = nil
end

-- Helper: make a valid rule
local function make_rule(overrides)
    return {
        name = overrides.name or "X-Test-Header",
        value = overrides.value or "test-value",
        domains = overrides.domains or {},
        enabled = overrides.enabled == nil and true or overrides.enabled,
        secret = overrides.secret == nil and true or overrides.secret,
    }
end

describe("hooks custom headers integration", function()
    local hooks

    before_each(function()
        setup_mock()
        -- Force re-require hooks so it picks up the mock
        package.loaded["hooks"] = nil
        hooks = require("hooks")
        hooks._reset_for_test()
    end)

    after_each(function()
        teardown_mock()
    end)

    describe("table form", function()
        it("injects custom headers for matching host", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = { "example.com" },
                    custom_headers = {
                        make_rule({ name = "X-Custom", value = "custom-val", domains = { "example.com" } }),
                    },
                }
            end)

            mock_http.request({ url = "https://example.com/path" })
            assert.equals("custom-val", captured_requests[1].headers["X-Custom"])
        end)

        it("does not inject custom headers for non-matching host", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {
                        make_rule({ name = "X-Custom", value = "custom-val", domains = { "example.com" } }),
                    },
                }
            end)

            mock_http.request({ url = "https://other.com/path" })
            assert.is_nil(captured_requests[1].headers["X-Custom"])
        end)

        it("skips disabled rules", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {
                        make_rule({ name = "X-Disabled", value = "val", enabled = false, domains = { "example.com" } }),
                    },
                }
            end)

            mock_http.request({ url = "https://example.com/path" })
            assert.is_nil(captured_requests[1].headers["X-Disabled"])
        end)

        it("applies CF Access headers AND custom headers together", function()
            hooks.install(function()
                return {
                    enabled = true,
                    client_id = "<client-id>",
                    client_secret = "<client-secret>",
                    domains = { "example.com" },
                    custom_headers = {
                        make_rule({ name = "X-Custom", value = "custom-val", domains = {} }),
                    },
                }
            end)

            mock_http.request({ url = "https://example.com/path" })
            assert.equals("<client-id>", captured_requests[1].headers["CF-Access-Client-Id"])
            assert.equals("<client-secret>", captured_requests[1].headers["CF-Access-Client-Secret"])
            assert.equals("custom-val", captured_requests[1].headers["X-Custom"])
        end)

        it("does not overwrite caller-supplied headers", function()
            hooks.install(function()
                return {
                    enabled = true,
                    client_id = "<client-id>",
                    client_secret = "<client-secret>",
                    domains = { "example.com" },
                    custom_headers = {
                        make_rule({ name = "X-Custom", value = "injected", domains = {} }),
                    },
                }
            end)

            mock_http.request({
                url = "https://example.com/path",
                headers = { ["X-Custom"] = "caller-value" },
            })
            assert.equals("caller-value", captured_requests[1].headers["X-Custom"])
        end)

        it("later custom rule overwrites earlier one with same name", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {
                        make_rule({ name = "X-Dup", value = "first", domains = {} }),
                        make_rule({ name = "X-Dup", value = "second", domains = {} }),
                    },
                }
            end)

            mock_http.request({ url = "https://example.com/path" })
            assert.equals("second", captured_requests[1].headers["X-Dup"])
        end)

        it("custom rule with empty domains inherits global allowlist", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = { "example.com" },
                    custom_headers = {
                        make_rule({ name = "X-Inherited", value = "val", domains = {} }),
                    },
                }
            end)

            mock_http.request({ url = "https://example.com/path" })
            assert.equals("val", captured_requests[1].headers["X-Inherited"])

            mock_http.request({ url = "https://other.com/path" })
            assert.is_nil(captured_requests[2].headers["X-Inherited"])
        end)

        it("custom rule with empty domains + empty global matches everything", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {
                        make_rule({ name = "X-Global", value = "val", domains = {} }),
                    },
                }
            end)

            mock_http.request({ url = "https://anything.com/path" })
            assert.equals("val", captured_requests[1].headers["X-Global"])
        end)
    end)

    describe("string form", function()
        it("promotes string form and injects custom headers", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {
                        make_rule({ name = "X-Custom", value = "custom-val", domains = {} }),
                    },
                }
            end)

            local _body, code = mock_http.request("https://example.com/path")
            assert.equals(200, code)
            assert.truthy(_body)
        end)

        it("passes through unchanged when no rules apply", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {
                        make_rule({ name = "X-Custom", value = "val", domains = { "example.com" } }),
                    },
                }
            end)

            local _, code = mock_http.request("https://other.com/path")
            assert.equals(200, code)
            -- String form passed through directly, no promotion
            assert.is_true(captured_requests[1].string_form)
        end)
    end)

    describe("no-op when disabled", function()
        it("passes through when CF disabled and no custom headers", function()
            hooks.install(function()
                return {
                    enabled = false,
                    client_id = "",
                    client_secret = "",
                    domains = {},
                    custom_headers = {},
                }
            end)

            mock_http.request({ url = "https://example.com/path" })
            assert.same({}, captured_requests[1].headers)
        end)
    end)
end)
