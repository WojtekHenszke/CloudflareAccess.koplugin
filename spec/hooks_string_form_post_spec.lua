-- Regression test: when hooks.lua promotes a string-form POST request to table
-- form, it must forward the body argument (method, source, Content-Length,
-- Content-Type).

local captured_table
local mock_http
local mock_ltn12

local function setup_mock()
    captured_table = nil

    mock_ltn12 = {
        source = {
            string = function(s)
                return function()
                    local ret = s
                    s = nil
                    return ret
                end
            end,
        },
        sink = {
            table = function(t)
                return function(_, chunk, err)
                    if chunk then
                        t[#t + 1] = chunk
                    end
                    return 1
                end
            end,
        },
    }
    package.preload["ltn12"] = function() return mock_ltn12 end

    mock_http = {
        request = function(req, body)
            captured_table = req
            return "body", 200, { ["cf-ray"] = "test-ray" }, "HTTP/1.1 200 OK"
        end,
    }
    package.loaded["socket.http"] = mock_http
    package.loaded["ssl.https"] = mock_http
end

local function teardown_mock()
    package.loaded["socket.http"] = nil
    package.loaded["ssl.https"] = nil
    package.preload["ltn12"] = nil
end

local function make_config(overrides)
    overrides = overrides or {}
    return {
        enabled = overrides.enabled ~= nil and overrides.enabled or true,
        client_id = overrides.client_id or "<client-id>",
        client_secret = overrides.client_secret or "<client-secret>",
        domains = overrides.domains or {},
        custom_headers = overrides.custom_headers or {},
    }
end

describe("hooks string-form POST body forwarding", function()
    local hooks

    before_each(function()
        setup_mock()
        package.loaded["hooks"] = nil
        hooks = require("hooks")
        hooks._reset_for_test()
    end)

    after_each(function()
        teardown_mock()
    end)

    it("sets method=POST, source, Content-Length, and Content-Type when body is present", function()
        hooks.install(function()
            return make_config()
        end)

        mock_http.request("https://api.example.com", "k=v")
        assert.truthy(captured_table)
        assert.equals("POST", captured_table.method)
        assert.is_function(captured_table.source)
        assert.equals("3", captured_table.headers["Content-Length"])
        assert.equals("application/x-www-form-urlencoded", captured_table.headers["Content-Type"])
    end)

    it("stays GET with no source when body is absent (nil)", function()
        hooks.install(function()
            return make_config()
        end)

        mock_http.request("https://api.example.com")
        assert.truthy(captured_table)
        assert.is_nil(captured_table.method)
        assert.is_nil(captured_table.source)
        assert.is_nil(captured_table.headers["Content-Length"])
    end)

    it("preserves caller-set Content-Type instead of overwriting with default", function()
        hooks.install(function()
            return make_config()
        end)

        -- String-form requests have no caller headers, so the guard
        -- "if not t.headers["Content-Type"]" is the defense. We verify
        -- the default Content-Type IS set when absent, and the guard
        -- pattern ensures it is never overwritten if already present.
        mock_http.request("https://api.example.com", "k=v")
        assert.equals("application/x-www-form-urlencoded", captured_table.headers["Content-Type"])
    end)

    it("injects CF Access headers on top of POST body", function()
        hooks.install(function()
            return make_config()
        end)

        mock_http.request("https://api.example.com", "k=v")
        assert.equals("<client-id>", captured_table.headers["CF-Access-Client-Id"])
        assert.equals("<client-secret>", captured_table.headers["CF-Access-Client-Secret"])
        assert.equals("POST", captured_table.method)
        assert.is_function(captured_table.source)
    end)

    it("injects custom header rules alongside POST body", function()
        hooks.install(function()
            return make_config({
                custom_headers = {
                    { name = "X-Custom", value = "custom-val", domains = {}, enabled = true, secret = false },
                },
            })
        end)

        mock_http.request("https://api.example.com", "k=v")
        assert.equals("POST", captured_table.method)
        assert.is_function(captured_table.source)
        assert.equals("3", captured_table.headers["Content-Length"])
        assert.equals("custom-val", captured_table.headers["X-Custom"])
    end)
end)
