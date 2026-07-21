--[[-- Pure helpers for the header rules editor.

Extracted so unit tests can verify default-coercion logic without
instantiating UI widgets.
--]]

local M = {}

--- Return a (name, value, domains, enabled, secret) tuple for a rule.
-- When `existing` is nil (new rule), returns safe defaults.
-- When `existing` is a rule table, returns its fields as-is (preserving false).
-- @tparam[opt] table existing rule table, or nil for a new rule
-- @treturn string name
-- @treturn string value
-- @treturn table domains
-- @treturn boolean enabled
-- @treturn boolean secret
function M.coerce_defaults(existing)
    if existing then
        return existing.name, existing.value, existing.domains, existing.enabled, existing.secret
    end
    return "", "", {}, true, true
end

return M
