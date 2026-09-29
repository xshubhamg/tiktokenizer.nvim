-- Volt layout sections for the right (preview) pane.
-- Volt decides all styling here via virt_text lines.
local state = require("tiktokenizer.state")
local config = require("tiktokenizer.config")
local view = require("tiktokenizer.view")

local M = {}

local function switch_to(enc)
  return function()
    if state.encoding ~= enc then
      state.encoding = enc
      local ok, volt = pcall(require, "volt")
      if ok then
        pcall(volt.redraw, state.view_buf, { "header", "count" })
      end
      require("tiktokenizer.tokenizer").request_now()
    end
  end
end

function M.layout()
  return {
    {
      name = "header",
      lines = function()
        local encs = config.options.encodings
        local row = { { "Tiktokenizer", "TiktokTitle" }, { "  " } }
        for i, enc in ipairs(encs) do
          local active = state.encoding == enc
          local label = (active and "[ " or "  ") .. enc .. (active and " ]" or "  ")
          table.insert(row, { label, active and "TiktokActive" or "TiktokDim", { click = switch_to(enc) } })
          if i < #encs then
            table.insert(row, { " " })
          end
        end
        local hint = { { "" } }
        local hint2 = { { "e: switch encoding   q: close", "TiktokDim" } }
        return { row, hint2, hint }
      end,
    },
    {
      name = "count",
      lines = function()
        local n = state.tokens.count or 0
        local extra = state.tokens.fallback and "  (fallback split)" or ""
        return {
          { { "Token count", "TiktokDim" } },
          { { tostring(n), "TiktokTitle" }, { extra, "TiktokDim" } },
          { { string.rep("─", math.max(10, state.view_w - 2)), "TiktokDim" } },
        }
      end,
    },
    {
      name = "tokens",
      lines = function()
        return view.build_lines(math.max(10, state.view_w - 2))
      end,
    },
  }
end

return M
