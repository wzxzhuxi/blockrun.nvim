-- blockrun/init.lua — 插件入口：setup、代码提取、<Plug> 映射、命令注册

local M = {}

local langs = require("blockrun.langs")
local runner = require("blockrun.runner")
local output = require("blockrun.output")

---@type table
local config = {
  timeout = 10, -- 超时秒数
  langs = {},   -- 用户覆盖: { python = { cmd = "python" } }
}

--- 获取 visual 模式选中的文本（Neovim 0.11+）
---@return string
local function get_visual_selection()
  local region = vim.fn.getregion(
    vim.fn.getpos("'<"),
    vim.fn.getpos("'>"),
    { type = vim.fn.visualmode() }
  )
  return table.concat(region, "\n")
end

--- 从 treesitter 节点范围提取文本，处理根节点 ec=0 的情况
---@param sr integer 起始行（0 起）
---@param sc integer 起始列（0 起，字节）
---@param er integer 结束行（0 起，不含）
---@param ec integer 结束列（0 起，字节）
---@return string?
local function get_node_text(sr, sc, er, ec)
  local lines
  if ec == 0 and er > sr then
    -- 根节点：范围止于 (下一行, 0)，实际内容到上一行末尾
    lines = vim.api.nvim_buf_get_lines(0, sr, er, false)
  else
    lines = vim.api.nvim_buf_get_lines(0, sr, er + 1, false)
    if #lines > 0 then
      lines[#lines] = lines[#lines]:sub(1, ec)
    end
  end
  if #lines == 0 then
    return nil
  end
  lines[1] = lines[1]:sub(sc + 1)
  return table.concat(lines, "\n")
end

--- 尝试用 treesitter 获取光标所在的代码块
---@return string?
local function get_ts_block()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return nil
  end

  -- 可识别的代码块节点类型
  local block_types = {
    function_definition = true,
    function_declaration = true,
    function_item = true,       -- rust
    method_definition = true,
    method_declaration = true,
    class_definition = true,
    class_declaration = true,
    if_statement = true,
    for_statement = true,
    while_statement = true,
    do_statement = true,
    match_expression = true,    -- rust
    block = true,
    chunk = true,               -- lua 顶层
    program = true,             -- js/py 顶层
    translation_unit = true,    -- c/cpp 顶层
    source_file = true,         -- rust/go/zig 顶层
  }

  -- 从光标节点向上查找最近的代码块
  while node do
    if block_types[node:type()] then
      local sr, sc, er, ec = node:range()
      local text = get_node_text(sr, sc, er, ec)
      if text and text ~= "" then
        return text
      end
    end
    node = node:parent()
  end

  return nil
end

--- 围栏语言别名 -> filetype 映射
local fence_to_ft = {
  py = "python", python3 = "python",
  js = "javascript", jsx = "javascript",
  ts = "typescript", tsx = "typescript",
  ["c++"] = "cpp", cc = "cpp", cxx = "cpp",
  shell = "sh",
}

--- 查找光标所在的 markdown 围栏代码块
--- 扫描原始行文本，正确处理嵌套围栏（如 README 中的 ````markdown 包裹）
---@return string? code, string? ft
local function get_markdown_block()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1] -- 1 起
  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- 查找包含光标的最内层 3 反引号围栏
  -- 4+ 反引号的围栏（````markdown）会被跳过
  local best_code, best_ft

  local fence_start, fence_lang
  for i, line in ipairs(buf_lines) do
    -- 开启围栏：恰好 ``` 后跟语言名
    local lang = line:match("^```(%a[%w_-]*)%s*$")
    if lang then
      fence_start = i
      fence_lang = lang
    elseif line:match("^```%s*$") and fence_start then
      -- 关闭围栏：恰好 ```
      if cursor_row > fence_start and cursor_row < i then
        local code_lines = {}
        for j = fence_start + 1, i - 1 do
          code_lines[#code_lines + 1] = buf_lines[j]
        end
        local ft = fence_to_ft[fence_lang] or fence_lang
        best_code = table.concat(code_lines, "\n")
        best_ft = ft
        -- 不中断：继续扫描以找到更内层的匹配
      end
      fence_start = nil
    end
  end

  return best_code, best_ft
end

--- 根据模式提取代码
---@param mode? string "v" 为 visual 模式，nil 为 normal 模式
---@return string?
local function extract_code(mode)
  if mode == "v" then
    return get_visual_selection()
  end

  -- Normal 模式：先尝试 treesitter 代码块，失败则取当前行
  local block = get_ts_block()
  if block and block ~= "" then
    return block
  end

  return vim.api.nvim_get_current_line()
end

--- 主运行函数
---@param mode? string "v" 为 visual 模式
function M.run(mode)
  local ft = vim.bo.filetype
  local code, spec

  if ft == "markdown" or ft == "markdown.mdx" then
    -- Markdown：提取围栏代码块及其语言
    local md_code, md_ft = get_markdown_block()
    if not md_code or not md_ft then
      vim.notify("[blockrun] 光标不在围栏代码块内", vim.log.levels.WARN)
      return
    end
    spec = langs.get(md_ft)
    if not spec then
      vim.notify(string.format("[blockrun] 不支持的语言: %s", md_ft), vim.log.levels.WARN)
      return
    end
    -- Markdown 中 visual 模式：用选区内容，但语言从围栏检测
    if mode == "v" then
      code = get_visual_selection()
    else
      code = md_code
    end
  else
    spec = langs.get(ft)
    if not spec then
      vim.notify(string.format("[blockrun] 不支持的文件类型: %s", ft), vim.log.levels.WARN)
      return
    end
    code = extract_code(mode)
  end

  if not code or code == "" then
    vim.notify("[blockrun] 没有可运行的代码", vim.log.levels.WARN)
    return
  end

  runner.execute(code, spec, config, function(result)
    output.show(result, config)
  end)
end

--- 关闭输出窗口
function M.close()
  output.close()
end

--- 终止进程 + 关闭窗口，完全重置
function M.reset()
  runner.kill()
  output.close()
end

--- setup 入口，由 lazy.nvim 调用
---@param opts? table
function M.setup(opts)
  opts = opts or {}

  if opts.timeout then
    config.timeout = opts.timeout
  end

  -- 注册用户自定义语言
  if opts.langs then
    for ft, spec in pairs(opts.langs) do
      langs.register(ft, spec)
    end
  end

  -- <Plug> 映射（兼容 sniprun 命名）
  vim.keymap.set("n", "<Plug>SnipRun", function() M.run() end, { desc = "运行代码块/当前行" })
  vim.keymap.set("v", "<Plug>SnipRun", function() M.run("v") end, { desc = "运行选中代码" })
  vim.keymap.set("n", "<Plug>SnipClose", function() M.close() end, { desc = "关闭输出" })
  vim.keymap.set("n", "<Plug>SnipReset", function() M.reset() end, { desc = "终止并关闭" })

  -- 用户命令
  vim.api.nvim_create_user_command("SnipRun", function(cmd_opts)
    if cmd_opts.range > 0 then
      M.run("v")
    else
      M.run()
    end
  end, { range = true, desc = "运行代码片段" })

  vim.api.nvim_create_user_command("SnipClose", function() M.close() end, { desc = "关闭输出窗口" })
  vim.api.nvim_create_user_command("SnipReset", function() M.reset() end, { desc = "终止进程并关闭" })
  vim.api.nvim_create_user_command("SnipInfo", function()
    vim.notify(
      string.format("[blockrun] 支持的语言: %s", table.concat(langs.supported(), ", ")),
      vim.log.levels.INFO
    )
  end, { desc = "显示支持的语言" })
end

return M
