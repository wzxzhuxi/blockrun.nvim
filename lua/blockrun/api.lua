-- blockrun/api.lua — 公开 API：供外部脚本/插件调用

local M = {}

local langs = require("blockrun.langs")
local runner = require("blockrun.runner")
local output = require("blockrun.output")

--- 获取全局 config（延迟引用，避免循环 require 时 config 还未初始化）
---@return table
local function get_config()
  return require("blockrun")._config
end

--- 运行任意代码字符串
---@param code string           源代码文本
---@param filetype string       文件类型（如 "python", "lua"）
---@param opts? { timeout?: integer, display?: string[], callback?: fun(result: table), bufnr?: integer, line?: integer }
function M.run_string(code, filetype, opts)
  opts = opts or {}

  local spec = langs.get(filetype)
  if not spec then
    local err = string.format("[blockrun] 不支持的文件类型: %s", filetype)
    if opts.callback then
      opts.callback({ stdout = "", stderr = err, code = 1, signal = 0 })
    else
      vim.notify(err, vim.log.levels.WARN)
    end
    return
  end

  if not code or code == "" then
    local err = "[blockrun] 没有可运行的代码"
    if opts.callback then
      opts.callback({ stdout = "", stderr = err, code = 1, signal = 0 })
    else
      vim.notify(err, vim.log.levels.WARN)
    end
    return
  end

  -- 合并配置：opts 覆盖全局 config
  local cfg = vim.tbl_deep_extend("force", get_config(), {
    timeout = opts.timeout,
    display = opts.display,
  })

  if opts.callback then
    -- 纯 API 模式：只调回调，不显示
    runner.execute(code, spec, cfg, opts.callback)
  else
    -- 显示模式
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local line = opts.line and (opts.line - 1) or (vim.api.nvim_win_get_cursor(0)[1] - 1) -- 转 0-indexed

    runner.execute(code, spec, cfg, function(result)
      output.display(result, cfg, { bufnr = bufnr, line = line })
    end)
  end
end

--- 运行当前 buffer 指定行范围
---@param start_line integer   1-indexed
---@param end_line integer     1-indexed, inclusive
---@param filetype? string     默认用当前 buffer filetype
---@param opts? table          同 run_string opts
function M.run_range(start_line, end_line, filetype, opts)
  opts = opts or {}
  filetype = filetype or vim.bo.filetype

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local code = table.concat(lines, "\n")

  -- 默认 virt_text 定位到范围末行
  if not opts.line then
    opts.line = end_line
  end

  M.run_string(code, filetype, opts)
end

return M
