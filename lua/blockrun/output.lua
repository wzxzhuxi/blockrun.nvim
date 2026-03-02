-- blockrun/output.lua — 浮动窗口 + virtual text 输出显示

local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  virt_mark_id = nil,
  virt_bufnr = nil,
  virt_timer = nil,
}

local ns = vim.api.nvim_create_namespace("blockrun")

--- 清除 virtual text extmark
function M.clear_virt_text()
  local timer = state.virt_timer
  state.virt_timer = nil
  if timer then
    timer:stop()
    timer:close()
  end

  local mark_id = state.virt_mark_id
  local bufnr = state.virt_bufnr
  state.virt_mark_id = nil
  state.virt_bufnr = nil

  if mark_id and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark_id)
  end
end

--- 关闭输出窗口 + 清除 virtual text（防重入安全）
function M.close()
  M.clear_virt_text()

  local winid = state.winid
  local bufnr = state.bufnr
  state.winid = nil
  state.bufnr = nil

  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  -- bufhidden=wipe 会在窗口关闭时自动删除 buffer，这里兜底处理窗口已消失的情况
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- 将运行结果格式化为显示行和高亮区域
---@param result { stdout: string, stderr: string, code: integer, signal: integer, timed_out?: boolean }
---@return string[] lines, table[] hl_regions
local function format_result(result)
  local lines = {}
  local hls = {}

  local function add(text, hl_group)
    for line in text:gmatch("[^\n]*") do
      lines[#lines + 1] = line
      if hl_group then
        hls[#hls + 1] = { line = #lines - 1, group = hl_group }
      end
    end
  end

  -- 移除尾部空行
  local function trim_trailing(tbl)
    while #tbl > 0 and tbl[#tbl] == "" do
      tbl[#tbl] = nil
    end
  end

  if result.stdout and result.stdout ~= "" then
    add(result.stdout, nil)
  end

  if result.stderr and result.stderr ~= "" then
    if #lines > 0 then
      lines[#lines + 1] = ""
    end
    add(result.stderr, "DiagnosticError")
  end

  trim_trailing(lines)

  -- 非零退出码或超时的状态行
  if result.timed_out then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[timed out]"
    hls[#hls + 1] = { line = #lines - 1, group = "Comment" }
  elseif result.code ~= 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("[exit %d]", result.code)
    hls[#hls + 1] = { line = #lines - 1, group = "Comment" }
  end

  if #lines == 0 then
    lines[#lines + 1] = "(no output)"
    hls[#hls + 1] = { line = 0, group = "Comment" }
  end

  return lines, hls
end

--- 根据内容计算窗口尺寸
---@param lines string[]
---@return integer width, integer height
local function calc_dimensions(lines)
  local max_width = 10
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_width then
      max_width = w
    end
  end
  local width = math.min(max_width + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.6))
  return width, height
end

--- 在浮动窗口中显示运行结果
---@param result { stdout: string, stderr: string, code: integer, signal: integer, timed_out?: boolean }
---@param cfg? table
function M.show(result, cfg)
  -- 只关闭浮动窗口部分，保留 virt_text
  local winid = state.winid
  local bufnr = state.bufnr
  state.winid = nil
  state.bufnr = nil
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  local lines, hls = format_result(result)
  local width, height = calc_dimensions(lines)

  -- 创建临时 buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "blockrun_output"

  -- 通过 extmark 设置高亮
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buf, ns, hl.line, 0, {
      end_row = hl.line,
      end_col = #lines[hl.line + 1],
      hl_group = hl.group,
    })
  end

  -- 浮动窗口配置
  local win_config = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Output ",
    title_pos = "center",
    noautocmd = true,
  }

  local win = vim.api.nvim_open_win(buf, true, win_config)
  vim.wo[win].wrap = true
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"

  state.bufnr = buf
  state.winid = win

  -- 快捷键：q / <Esc> 关闭
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, M.close, { buffer = buf, nowait = true })
  end

  -- 离开窗口自动关闭
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(M.close)
    end,
  })
end

--- 在行尾显示 virtual text
---@param result { stdout: string, stderr: string, code: integer, signal: integer, timed_out?: boolean }
---@param cfg table  全局 config（含 virt_text 子表）
---@param ctx { bufnr: integer, line: integer }  bufnr + 0-indexed 行号
function M.show_virt_text(result, cfg, ctx)
  M.clear_virt_text()

  local vt_cfg = cfg.virt_text or {}
  local prefix = vt_cfg.prefix or "→ "
  local hl = vt_cfg.hl or "Comment"
  local err_hl = vt_cfg.err_hl or "DiagnosticError"
  local clear_after = vt_cfg.clear_after or 5000

  -- 决定显示内容：stderr 优先
  local text, use_hl
  if result.stderr and result.stderr ~= "" then
    text = result.stderr
    use_hl = err_hl
  elseif result.stdout and result.stdout ~= "" then
    text = result.stdout
    use_hl = hl
  elseif result.timed_out then
    text = "[timed out]"
    use_hl = err_hl
  elseif result.code ~= 0 then
    text = string.format("[exit %d]", result.code)
    use_hl = err_hl
  else
    text = "(no output)"
    use_hl = hl
  end

  -- 多行只取第一行
  local first_line = text:match("^([^\n]*)")
  local line_count = select(2, text:gsub("\n", "")) + 1
  if line_count > 1 then
    first_line = first_line .. string.format(" (+%d lines)", line_count - 1)
  end

  local display_text = prefix .. first_line

  -- 确保 buffer 有效且行号在范围内
  if not vim.api.nvim_buf_is_valid(ctx.bufnr) then return end
  local line_count_buf = vim.api.nvim_buf_line_count(ctx.bufnr)
  local line = math.min(ctx.line, line_count_buf - 1)

  local mark_id = vim.api.nvim_buf_set_extmark(ctx.bufnr, ns, line, 0, {
    virt_text = { { display_text, use_hl } },
    virt_text_pos = "eol",
  })

  state.virt_mark_id = mark_id
  state.virt_bufnr = ctx.bufnr

  -- 自动清除定时器
  if clear_after > 0 then
    local timer = vim.uv.new_timer()
    state.virt_timer = timer
    timer:start(clear_after, 0, vim.schedule_wrap(function()
      M.clear_virt_text()
    end))
  end
end

--- 统一显示入口 — 根据 config.display 分发到各后端
---@param result table  运行结果
---@param cfg table     全局 config
---@param ctx { bufnr: integer, line: integer }  源 buffer + 0-indexed 行号
function M.display(result, cfg, ctx)
  local backends = cfg.display or { "float" }
  for _, backend in ipairs(backends) do
    if backend == "float" then
      M.show(result, cfg)
    elseif backend == "virt_text" then
      M.show_virt_text(result, cfg, ctx)
    end
  end
end

--- 输出窗口是否可见
---@return boolean
function M.is_open()
  return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

return M
