-- Async bridge: input text -> uvx + tiktoken -> {count, segments}
local config = require("tiktokenizer.config")
local state = require("tiktokenizer.state")

local M = {}

local function script_path()
  -- lua/tiktokenizer/tokenizer.lua -> <root>/python/tokenize.py
  local src = debug.getinfo(1, "S").source:sub(2)
  local dir = vim.fn.fnamemodify(src, ":h") -- lua/tiktokenizer
  return vim.fn.fnamemodify(dir, ":h:h") .. "/python/tokenize.py"
end

function M.script()
  return script_path()
end

local function set_tokens(tokens)
  state.tokens = tokens
  local ok, volt = pcall(require, "volt")
  if ok and state.open and state.view_buf and vim.api.nvim_buf_is_valid(state.view_buf) then
    pcall(volt.redraw, state.view_buf, { "count", "tokens" })
  end
end

--- Simple no-dependency fallback so the UI still works without uv/tiktoken.
local function fallback_tokenize(text)
  local segments = {}
  -- split keeping whitespace runs, so colors still show something sane
  for chunk in text:gmatch("[^%s]+%s*") do
    if chunk ~= "" then
      table.insert(segments, { text = chunk, id = -1 })
    end
  end
  if #segments == 0 and #text > 0 then
    table.insert(segments, { text = text, id = -1 })
  end
  return { count = #segments, segments = segments, fallback = true }
end

local function run_job(text, encoding, seq)
  local cmd = {}
  for _, v in ipairs(config.options.uv_cmd) do
    table.insert(cmd, v)
  end
  table.insert(cmd, "python")
  table.insert(cmd, script_path())
  table.insert(cmd, "--encoding")
  table.insert(cmd, encoding)

  local stdout = {}
  local stderr = {}
  local uv = vim.uv or vim.loop

  local function on_done(code)
    if seq ~= state.seq then
      return -- stale response
    end
    state.job = nil
    if code ~= 0 then
      local msg = table.concat(stderr, ""):gsub("%s+$", "")
      if msg == "" then
        msg = "tokenizer failed (is `uv` installed?)"
      end
      vim.schedule(function()
        vim.notify("[tiktokenizer] " .. msg .. " — using fallback split", vim.log.levels.WARN)
        set_tokens(fallback_tokenize(text))
      end)
      return
    end
    local ok, decoded = pcall(vim.json.decode, table.concat(stdout, ""))
    if not ok or type(decoded) ~= "table" or decoded.error then
      local msg = (type(decoded) == "table" and decoded.error) or "bad tokenizer output"
      vim.schedule(function()
        vim.notify("[tiktokenizer] " .. msg .. " — using fallback split", vim.log.levels.WARN)
        set_tokens(fallback_tokenize(text))
      end)
      return
    end
    vim.schedule(function()
      if seq == state.seq then
        set_tokens({ count = decoded.count or 0, segments = decoded.segments or {} })
      end
    end)
  end

  if vim.system then
    state.job = vim.system(cmd, { stdin = text, text = true }, function(out)
      if seq ~= state.seq then
        return
      end
      state.job = nil
      if out.code ~= 0 then
        local msg = (out.stderr or ""):gsub("%s+$", "")
        if msg == "" then
          msg = "tokenizer failed (is `uv` installed?)"
        end
        vim.schedule(function()
          vim.notify("[tiktokenizer] " .. msg .. " — using fallback split", vim.log.levels.WARN)
          set_tokens(fallback_tokenize(text))
        end)
        return
      end
      local ok, decoded = pcall(vim.json.decode, out.stdout or "")
      if not ok or type(decoded) ~= "table" or decoded.error then
        local msg = (type(decoded) == "table" and decoded.error) or "bad tokenizer output"
        vim.schedule(function()
          vim.notify("[tiktokenizer] " .. msg .. " — using fallback split", vim.log.levels.WARN)
          set_tokens(fallback_tokenize(text))
        end)
        return
      end
      vim.schedule(function()
        if seq == state.seq then
          set_tokens({ count = decoded.count or 0, segments = decoded.segments or {} })
        end
      end)
    end)
  else
    -- neovim < 0.10 fallback
    local jobid = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        stdout = data or {}
      end,
      on_stderr = function(_, data)
        stderr = data or {}
      end,
      on_exit = function(_, code)
        on_done(code)
      end,
    })
    if jobid <= 0 then
      set_tokens(fallback_tokenize(text))
      return
    end
    state.job = jobid
    vim.fn.chansend(jobid, text)
    vim.fn.chanclose(jobid, "stdin")
  end
  _ = uv
end

--- Debounced entry point. Reads current input buffer text.
function M.request()
  if not state.open or not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
    return
  end
  if state.timer then
    pcall(vim.uv.close, state.timer)
    state.timer = nil
  end
  local ms = config.options.debounce_ms or 150
  local timer = assert(vim.uv.new_timer())
  state.timer = timer
  timer:start(ms, 0, function()
    vim.schedule(function()
      state.timer = nil
      if not state.open then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
      local text = table.concat(lines, "\n")
      state.seq = state.seq + 1
      local seq = state.seq
      if text == "" then
        set_tokens({ count = 0, segments = {} })
        return
      end
      run_job(text, state.encoding, seq)
    end)
  end)
end

--- Immediate (synchronous-looking) tokenize used on open for placeholder text.
function M.request_now()
  if state.timer then
    pcall(vim.uv.close, state.timer)
    state.timer = nil
  end
  if not state.open then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  state.seq = state.seq + 1
  if text == "" then
    set_tokens({ count = 0, segments = {} })
    return
  end
  run_job(text, state.encoding, state.seq)
end

return M
