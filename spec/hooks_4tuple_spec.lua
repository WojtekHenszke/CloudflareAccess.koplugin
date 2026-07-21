-- Regression test: the wrapper must preserve LuaSocket's 4-tuple return contract
-- (body, code, headers, status_line).

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
                })
            else
                table.insert(captured_requests, {
                    url = req,
                    headers = {},
                    string_form = true,
                })
            end
            -- 4-tuple: body, status_code, headers, status_line
            return "body", 200, { ["cf-ray"] = "test-ray-123" }, "HTTP/1.1 200 OK"
        end,
    }
    package.loaded["socket.http"] = mock_http
    package.loaded["ssl.https"] = mock_http
end

local function teardown_mock()
    package.loaded["socket.http"] = nil
    package.loaded["ssl.https"] = nil
end

local function make_config(overrides)
    overrides = overrides or {}
    return {
        enabled = overrides.enabled ~= nil and overrides.enabled or false,
        client_id = overrides.client_id or "",
        client_secret = overrides.client_secret or "",
        domains = overrides.domains or {},
        custom_headers = overrides.custom_headers or {},
    }
end

describe("hooks 4-tuple return contract", function()
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

    describe("table form", function()
        it("propagates all 4 return values from orig() (no-op path)", function()
            hooks.install(function()
                return make_config()
            end)

            local body, code, headers, status = mock_http.request({ url = "https://example.com/path" })
            assert.equals("body", body)
            assert.equals(200, code)
            assert.equals("test-ray-123", headers["cf-ray"])
            assert.equals("HTTP/1.1 200 OK", status)
        end)

        it("propagates all 4 return values from orig() (injection path)", function()
            hooks.install(function()
                return {
                    enabled = true,
                    client_id = "<client-id>",
                    client_secret = "<client-secret>",
                    domains = {},
                    custom_headers = {},
                }
            end)

            local body, code, headers, status = mock_http.request({ url = "https://example.com/path" })
            assert.equals("body", body)
            assert.equals(200, code)
            assert.equals("test-ray-123", headers["cf-ray"])
            assert.equals("HTTP/1.1 200 OK", status)
        end)
    end)

    describe("string form", function()
        it("propagates all 4 return values when promoted (injection applies)", function()
            hooks.install(function()
                return {
                    enabled = true,
                    client_id = "<client-id>",
                    client_secret = "<client-secret>",
                    domains = {},
                    custom_headers = {},
                }
            end)

            -- string form is promoted to table form internally
            local body, code, headers, status = mock_http.request("https://example.com/path")
            assert.truthy(body)
            assert.equals(200, code)
            assert.equals("test-ray-123", headers["cf-ray"])
            assert.equals("HTTP/1.1 200 OK", status)
        end)

        it("propagates all 4 return values in no-op passthrough (no injection)", function()
            hooks.install(function()
                return make_config()
            end)

            local body, code, headers, status = mock_http.request("https://example.com/path")
            assert.equals("body", body)
            assert.equals(200, code)
            assert.equals("test-ray-123", headers["cf-ray"])
            assert.equals("HTTP/1.1 200 OK", status)
        end)
    end)
end)
