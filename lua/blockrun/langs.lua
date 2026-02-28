-- blockrun/langs.lua — 语言注册表
-- 纯数据：每个条目定义一种文件类型的运行方式

local M = {}

---@class blockrun.LangSpec
---@field cmd string|string[]       -- 编译器/解释器命令
---@field ext string                -- 临时文件扩展名
---@field type "interpreted"|"compiled" -- 执行模式
---@field args? string[]            -- 解释器额外参数
---@field compile_args? string[]    -- 编译器额外参数
---@field compile_fmt? "standard"|"zig" -- 编译命令格式

---@type table<string, blockrun.LangSpec>
local registry = {
  c = {
    cmd = "gcc",
    ext = "c",
    type = "compiled",
    compile_args = { "-Wall", "-lm" },
  },
  cpp = {
    cmd = "g++",
    ext = "cpp",
    type = "compiled",
    compile_args = { "-Wall", "-std=c++17" },
  },
  python = {
    cmd = "python3",
    ext = "py",
    type = "interpreted",
  },
  javascript = {
    cmd = "node",
    ext = "js",
    type = "interpreted",
  },
  typescript = {
    cmd = { "npx", "tsx" },
    ext = "ts",
    type = "interpreted",
  },
  lua = {
    cmd = "lua",
    ext = "lua",
    type = "interpreted",
  },
  rust = {
    cmd = "rustc",
    ext = "rs",
    type = "compiled",
  },
  go = {
    cmd = { "go", "run" },
    ext = "go",
    type = "interpreted",
  },
  sh = {
    cmd = "bash",
    ext = "sh",
    type = "interpreted",
  },
  bash = {
    cmd = "bash",
    ext = "sh",
    type = "interpreted",
  },
  zsh = {
    cmd = "zsh",
    ext = "zsh",
    type = "interpreted",
  },
  zig = {
    cmd = { "zig", "build-exe" },
    ext = "zig",
    type = "compiled",
    compile_fmt = "zig",
  },
  haskell = {
    cmd = "runghc",
    ext = "hs",
    type = "interpreted",
  },
  ruby = {
    cmd = "ruby",
    ext = "rb",
    type = "interpreted",
  },
  perl = {
    cmd = "perl",
    ext = "pl",
    type = "interpreted",
  },
  java = {
    cmd = "java",
    ext = "java",
    type = "interpreted",
  },
}

--- 根据文件类型获取语言 spec
---@param ft string
---@return blockrun.LangSpec?
function M.get(ft)
  return registry[ft]
end

--- 注册或覆盖语言 spec
---@param ft string
---@param spec blockrun.LangSpec
function M.register(ft, spec)
  registry[ft] = spec
end

--- 列出所有支持的文件类型
---@return string[]
function M.supported()
  local fts = {}
  for ft in pairs(registry) do
    fts[#fts + 1] = ft
  end
  table.sort(fts)
  return fts
end

return M
