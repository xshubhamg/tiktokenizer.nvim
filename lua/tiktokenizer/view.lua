-- Build virt_text lines for the volt "tokens" section.
local highlights = require("tiktokenizer.highlights")
local state = require("tiktokenizer.state")
local config = require("tiktokenizer.config")

local M = {}

local function visualize(text)
  if not config.options.show_whitespace then
    return text
  end
  text = text:gsub(" ", "·")
  text = text:gsub("\t", "→")
  return text
end

--- Split segments into wrapped volt lines.
--- Each volt line: { {text, hl}, ... }
---@param width number usable width
---@return table lines
function M.build_lines(width)
  local segments = state.tokens.segments or {}
  if #segments == 0 then
    return { { { "Type on the left …", "TiktokDim" } }, { { "" } } }
  end

  local lines = {}
  local cur = {}
  local cur_w = 0

  local function flush()
    if #cur > 0 then
      table.insert(lines, cur)
      cur = {}
      cur_w = 0
    end
  end

  for i, seg in ipairs(segments) do
    local raw = seg.text or ""
    -- keep newlines as line breaks (tiktoken segments may contain them)
    local parts = vim.split(raw, "\n", { plain = true })
    for pi, part in ipairs(parts) do
      if part ~= "" then
        local txt = visualize(part)
        local w = vim.fn.strwidth(txt)
        if cur_w + w > width and cur_w > 0 then
          flush()
        end
        -- hard-split a single very long token
        while vim.fn.strwidth(txt) > width do
          local cut = 0
          local acc = 0
          for c in txt:gmatch(".") do
            local cw = vim.fn.strwidth(c)
            if acc + cw > width then
              break
            end
            acc = acc + cw
            cut = cut + #c
          end
          if cut == 0 then
            break
          end
          table.insert(cur, { txt:sub(1, cut), highlights.for_index(i - 1) })
          table.insert(lines, cur)
          cur = {}
          cur_w = 0
          txt = txt:sub(cut + 1)
        end
        if txt ~= "" then
          table.insert(cur, { txt, highlights.for_index(i - 1) })
          cur_w = cur_w + vim.fn.strwidth(txt)
        end
      end
      if pi < #parts then
        flush() -- explicit newline
      end
    end
  end
  flush()
  return lines
end

return M
