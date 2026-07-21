-- make_config defaults
local mock_http
local mock_ltn12

local function setup_mock()
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
            -- captured for assertions but also used as orig by wrapper
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
    local enabled = true
    if overrides.enabled ~= nil then
        enabled = overrides.enabled
    end
    return {
        enabled = enabled,
        client_id = overrides.client_id or "<client-id>",
        client_secret = overrides.client_secret or "<client-secret>",
        domains = overrides.domains or {},
        custom_headers = overrides.custom_headers or {},
    }
end

describe("log throttle", function()
    local hooks
    local log

    before_each(function()
        setup_mock()
        package.loaded["hooks"] = nil
        hooks = require("hooks")
        hooks._reset_for_test()
        log = require("lib.log")
        log.setLevel("dbg")
        log.clear()
    end)

    after_each(function()
        teardown_mock()
    end)

    it("suppresses repeated skip-host lines for the same host", function()
        hooks.install(function()
            return make_config({ enabled = false, domains = {} })
        end)

        -- 100 requests to same host, all skipped
        for _ = 1, 100 do
            mock_http.request("https://github.com/api")
        end

        -- switch host to flush the suppressed count
        mock_http.request("https://calibre.example.com/data")

        local entries = log.getEntries()
        print("DEBUG total entries: " .. #entries)
        for _, e in ipairs(entries) do
            print("DEBUG entry: " .. e.message)
        end
        local skip_entries = {}
        for _, e in ipairs(entries) do
            if e.message:match("^skip host=") then
                table.insert(skip_entries, e.message)
            end
        end

        -- 3 skip lines: first github, suppressed 99, new host calibre
        assert.equals(3, #skip_entries)
        assert.equals("skip host=github.com (not in allowlist)", skip_entries[1])
        assert.equals("skip host=github.com (suppressed 99 times)", skip_entries[2])
        assert.equals("skip host=calibre.example.com (not in allowlist)", skip_entries[3])
    end)

    it("resets skip counter when injection fires mid-stream", function()
        hooks.install(function()
            return make_config({ enabled = true, domains = { "github.com" } })
        end)

        -- 10 skips to a host that won't match
        for _ = 1, 10 do
            mock_http.request("https://gitlab.com/api")
        end

        -- 1 request that triggers injection (allowed host)
        mock_http.request("https://github.com/api")

        -- 10 more skips to the same host, then flush with a different host
        for _ = 1, 10 do
            mock_http.request("https://gitlab.com/api")
        end
        mock_http.request("https://bitbucket.org/repo")

        local entries = log.getEntries()
        local skip_entries = {}
        for _, e in ipairs(entries) do
            if e.message:match("^skip host=gitlab%.com %(not in allowlist%)") then
                table.insert(skip_entries, e.message)
            end
        end

        -- Two "skip host=gitlab.com (not in allowlist)" lines exist:
        -- one before injection, one after (cache was reset by injection)
        assert.equals(2, #skip_entries)
        assert.equals("skip host=gitlab.com (not in allowlist)", skip_entries[1])
        assert.equals("skip host=gitlab.com (not in allowlist)", skip_entries[2])
    end)
end)
