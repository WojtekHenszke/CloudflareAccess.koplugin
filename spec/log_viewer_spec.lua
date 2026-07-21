local log = require("lib.log")

local function reset_device()
    for k in pairs(_G._test_device_stub) do
        _G._test_device_stub[k] = nil
    end
end

local function button_texts(buttons)
    local texts = {}
    for _, row in ipairs(buttons) do
        for _, btn in ipairs(row) do
            texts[#texts + 1] = btn.text
        end
    end
    return texts
end

local function has_button(texts, label)
    for _, t in ipairs(texts) do
        if t == label then return true end
    end
    return false
end

describe("log_viewer clipboard detection", function()
    before_each(function()
        reset_device()
        _G._test_textviewer_stub.last_opts = nil
        log.setLevel("dbg")
        log.clear()
    end)

    after_each(function()
        reset_device()
    end)

    it("includes Copy button when Device.input.setClipboardText is callable", function()
        _G._test_device_stub.input = { setClipboardText = function() end }

        local log_viewer = require("ui.log_viewer")
        log_viewer._show_viewer()
        local opts = _G._test_textviewer_stub.last_opts

        assert.truthy(opts)
        local texts = button_texts(opts.buttons_table)
        assert.truthy(has_button(texts, "Copy"))
    end)

    it("omits Copy button when Device.input.setClipboardText is unavailable", function()
        local log_viewer = require("ui.log_viewer")
        log_viewer._show_viewer()
        local opts = _G._test_textviewer_stub.last_opts

        assert.truthy(opts)
        local texts = button_texts(opts.buttons_table)
        assert.is_false(has_button(texts, "Copy"))
    end)

    it("omits Copy button when Device has no input table at all", function()
        local log_viewer = require("ui.log_viewer")
        log_viewer._show_viewer()
        local opts = _G._test_textviewer_stub.last_opts

        assert.truthy(opts)
        local texts = button_texts(opts.buttons_table)
        assert.is_false(has_button(texts, "Copy"))
    end)

    it("includes Log file, Refresh, and Clear buttons regardless of clipboard", function()
        _G._test_device_stub.input = { setClipboardText = function() end }

        local log_viewer = require("ui.log_viewer")
        log_viewer._show_viewer()
        local opts = _G._test_textviewer_stub.last_opts
        local texts = button_texts(opts.buttons_table)

        assert.truthy(has_button(texts, "Log file"))
        assert.truthy(has_button(texts, "Refresh"))
        assert.truthy(has_button(texts, "Clear"))

        reset_device()

        log_viewer._show_viewer()
        opts = _G._test_textviewer_stub.last_opts
        texts = button_texts(opts.buttons_table)

        assert.truthy(has_button(texts, "Log file"))
        assert.truthy(has_button(texts, "Refresh"))
        assert.truthy(has_button(texts, "Clear"))
    end)
end)
