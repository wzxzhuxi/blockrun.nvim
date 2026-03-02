# blockrun.nvim

[English](README_en.md) | [中文](README.md)

纯 Lua 编写的 Neovim 代码块/片段运行器。零依赖，零构建步骤。

设计为 [sniprun](https://github.com/michaelb/sniprun) 的替代品 -- 相同的 `<Plug>` 映射，不需要 Rust 工具链。

## 特性

- **纯 Lua** -- 没有外部二进制，没有构建步骤，没有 `sh install.sh`
- **异步执行** -- 通过 `vim.system()` 运行代码，不阻塞编辑器
- **16 种语言** -- 解释型和编译型均支持，另支持 Markdown 围栏代码块
- **浮动窗口** -- stdout/stderr 在光标附近显示，可滚动，自动关闭
- **Treesitter 感知** -- 在 normal 模式下自动检测光标所在的函数/类/代码块
- **超时保护** -- 10 秒后自动终止失控进程（可配置）
- **兼容 sniprun** -- `<Plug>SnipRun`、`<Plug>SnipClose`、`<Plug>SnipReset`

## 环境要求

- Neovim >= 0.11
- Treesitter 解析器（可选，用于智能代码块检测和 Markdown 支持）

## 安装

### lazy.nvim（本地）

```lua
{
  dir = "path/blockrun.nvim",
  keys = {
    { "<leader>r",  "<Plug>SnipRun",   mode = { "n", "v" }, desc = "运行代码" },
    { "<leader>rc", "<Plug>SnipClose",  desc = "关闭输出" },
    { "<leader>rx", "<Plug>SnipReset",  desc = "终止并关闭" },
  },
  opts = {},
}
```

### lazy.nvim（远程）

```lua
{
  "wzxzhuxi/blockrun.nvim",
  keys = {
    { "<leader>r",  "<Plug>SnipRun",   mode = { "n", "v" }, desc = "运行代码" },
    { "<leader>rc", "<Plug>SnipClose",  desc = "关闭输出" },
    { "<leader>rx", "<Plug>SnipReset",  desc = "终止并关闭" },
  },
  opts = {},
}
```

## 配置

```lua
opts = {
  timeout = 10,  -- 秒，默认 10
  langs = {
    -- 覆盖已有语言或添加新语言
    python = { cmd = "python", ext = "py", type = "interpreted" },
    ocaml  = { cmd = "ocaml",  ext = "ml", type = "interpreted" },
  },
}
```

## 支持的语言

| 文件类型 | 命令 | 类型 |
|----------|------|------|
| c | `gcc` | 编译型 |
| cpp | `g++` | 编译型 |
| rust | `rustc` | 编译型 |
| zig | `zig build-exe` | 编译型 |
| python | `python3` | 解释型 |
| javascript | `node` | 解释型 |
| typescript | `npx tsx` | 解释型 |
| lua | `lua` | 解释型 |
| go | `go run` | 解释型 |
| sh | `bash` | 解释型 |
| bash | `bash` | 解释型 |
| zsh | `zsh` | 解释型 |
| haskell | `runghc` | 解释型 |
| ruby | `ruby` | 解释型 |
| perl | `perl` | 解释型 |
| java | `java` | 解释型 |
| markdown | （自动检测围栏语言） | -- |

## 使用方法

| 快捷键 | 模式 | 功能 |
|--------|------|------|
| `<leader>r` | normal | 运行 treesitter 代码块 / 当前行 |
| `<leader>r` | visual | 运行选中内容 |
| `<leader>rc` | normal | 关闭输出窗口 |
| `<leader>rx` | normal | 终止运行中的进程并关闭 |

### 命令

| 命令 | 说明 |
|------|------|
| `:SnipRun` | 运行代码（支持范围选择） |
| `:SnipClose` | 关闭输出窗口 |
| `:SnipReset` | 终止进程并关闭 |
| `:SnipInfo` | 列出支持的语言 |

### 在 Markdown 中使用

将光标放在围栏代码块内，按 `<leader>r`：

```python
print("hello from markdown")
```

### 添加自定义语言

```lua
opts = {
  langs = {
    kotlin = { cmd = "kotlin", ext = "kt", type = "interpreted" },
    swift  = { cmd = "swift",  ext = "swift", type = "interpreted" },
    -- 编译型语言示例
    d = {
      cmd = "dmd",
      ext = "d",
      type = "compiled",
      compile_args = { "-O" },
    },
  },
}
```

### 语言 Spec 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `cmd` | `string \| string[]` | 编译器或解释器命令 |
| `ext` | `string` | 临时文件扩展名 |
| `type` | `"interpreted" \| "compiled"` | 执行模式 |
| `args` | `string[]?` | 解释器额外参数 |
| `compile_args` | `string[]?` | 编译器额外参数 |
| `compile_fmt` | `"standard" \| "zig"?` | 编译命令格式 |

## 工作原理

```
<leader>r
  -> 检测文件类型 / Markdown 围栏语言
  -> 提取代码（选区 / treesitter 代码块 / 当前行）
  -> 写入临时文件
  -> vim.system() 异步执行
  -> 浮动窗口显示结果
```

## 许可证

MIT
