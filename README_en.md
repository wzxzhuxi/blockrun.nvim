# blockrun.nvim

[English](README_en.md) | [中文](README.md)

A minimal Neovim code-block runner written in pure Lua. Zero dependencies, zero build steps.

Designed as a drop-in replacement for [sniprun](https://github.com/michaelb/sniprun) -- same `<Plug>` mappings, no Rust toolchain required.

## Features

- **Pure Lua** -- no external binaries, no build steps, no `sh install.sh`
- **Async execution** -- runs code via `vim.system()`, never blocks the editor
- **16 languages** -- interpreted and compiled, plus markdown fenced code blocks
- **Floating window** -- stdout/stderr displayed near cursor, scrollable, auto-close
- **Virtual text** -- inline results at end of line, auto-clear after timeout
- **Treesitter-aware** -- in normal mode, detects the surrounding function/class/block
- **Operator mode** -- use with vim motions (e.g. `ip`, `3j`, `aw`)
- **Timeout** -- kills runaway processes after 10 seconds (configurable)
- **Public API** -- `run_string()` / `run_range()` for scripting and plugin integration
- **sniprun-compatible** -- `<Plug>SnipRun`, `<Plug>SnipClose`, `<Plug>SnipReset`

## Requirements

- Neovim >= 0.11
- Treesitter parsers (optional, for smart block detection and markdown support)

## Installation

### lazy.nvim (local)

```lua
{
  dir = "path/blockrun.nvim",
  keys = {
    { "<leader>r",  "<Plug>SnipRun",   mode = { "n", "v" }, desc = "Run snippet" },
    { "<leader>rc", "<Plug>SnipClose",  desc = "Close output" },
    { "<leader>rx", "<Plug>SnipReset",  desc = "Kill & close" },
    { "<leader>ro", "<Plug>SnipRunOperator", desc = "Run with motion" },
  },
  opts = {},
}
```

### lazy.nvim (remote)

```lua
{
  "wzxzhuxi/blockrun.nvim",
  keys = {
    { "<leader>r",  "<Plug>SnipRun",   mode = { "n", "v" }, desc = "Run snippet" },
    { "<leader>rc", "<Plug>SnipClose",  desc = "Close output" },
    { "<leader>rx", "<Plug>SnipReset",  desc = "Kill & close" },
    { "<leader>ro", "<Plug>SnipRunOperator", desc = "Run with motion" },
  },
  opts = {},
}
```

## Configuration

```lua
opts = {
  timeout = 10,  -- seconds, default 10
  display = { "float" },  -- "float" | "virt_text" | both
  virt_text = {
    prefix = "→ ",             -- result prefix
    hl = "Comment",            -- stdout highlight group
    err_hl = "DiagnosticError", -- stderr highlight group
    clear_after = 5000,        -- auto-clear delay (ms), 0 = never
  },
  langs = {
    -- override existing or add new languages
    python = { cmd = "python", ext = "py", type = "interpreted" },
    ocaml  = { cmd = "ocaml",  ext = "ml", type = "interpreted" },
  },
}
```

## Supported Languages

| Filetype | Command | Type |
|----------|---------|------|
| c | `gcc` | compiled |
| cpp | `g++` | compiled |
| rust | `rustc` | compiled |
| zig | `zig build-exe` | compiled |
| python | `python3` | interpreted |
| javascript | `node` | interpreted |
| typescript | `npx tsx` | interpreted |
| lua | `lua` | interpreted |
| go | `go run` | interpreted |
| sh | `bash` | interpreted |
| bash | `bash` | interpreted |
| zsh | `zsh` | interpreted |
| haskell | `runghc` | interpreted |
| ruby | `ruby` | interpreted |
| perl | `perl` | interpreted |
| java | `java` | interpreted |
| markdown | (detects fence language) | -- |

## Usage

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>r` | normal | Run treesitter block / current line |
| `<leader>r` | visual | Run selection |
| `<leader>ro` | normal | Operator mode: `<leader>roip` runs paragraph, `<leader>ro3j` runs 3 lines |
| `<leader>rc` | normal | Close output window |
| `<leader>rx` | normal | Kill running process and close |

### Commands

| Command | Description |
|---------|-------------|
| `:SnipRun` | Run code (supports range) |
| `:SnipClose` | Close output window |
| `:SnipReset` | Kill process and close |
| `:SnipInfo` | List supported languages |

### In Markdown

Place cursor inside a fenced code block and press `<leader>r`:

````markdown
```python
print("hello from markdown")
```
````

### Adding a Language

```lua
opts = {
  langs = {
    kotlin = { cmd = "kotlin", ext = "kt", type = "interpreted" },
    swift  = { cmd = "swift",  ext = "swift", type = "interpreted" },
    -- compiled language example
    d = {
      cmd = "dmd",
      ext = "d",
      type = "compiled",
      compile_args = { "-O" },
    },
  },
}
```

### Language Spec Fields

| Field | Type | Description |
|-------|------|-------------|
| `cmd` | `string \| string[]` | Compiler or interpreter command |
| `ext` | `string` | Temp file extension |
| `type` | `"interpreted" \| "compiled"` | Execution mode |
| `args` | `string[]?` | Extra args for interpreter |
| `compile_args` | `string[]?` | Extra args for compiler |
| `compile_fmt` | `"standard" \| "zig"?` | Compile command format |

## How It Works

```
<leader>r
  -> detect filetype / markdown fence language
  -> extract code (visual selection / treesitter block / motion range / current line)
  -> write to temp file
  -> vim.system() async execute
  -> display result in floating window / virtual text
```

## API

Use `require("blockrun").api` from Lua scripts or other plugins:

```lua
local api = require("blockrun").api

-- Run a code string
api.run_string("print(42)", "python")

-- Run with custom display
api.run_string("echo hello", "sh", { display = { "virt_text" } })

-- Callback-only mode (no display, just get the result)
api.run_string("print(42)", "python", {
  callback = function(result)
    print(result.stdout)  --> "42\n"
  end,
})

-- Run lines 5-10 of the current buffer
api.run_range(5, 10)

-- Run a specific range with explicit filetype
api.run_range(1, 20, "python")
```

### `api.run_string(code, filetype, opts?)`

| Parameter | Type | Description |
|-----------|------|-------------|
| `code` | `string` | Source code text |
| `filetype` | `string` | File type |
| `opts.timeout` | `integer?` | Timeout in seconds |
| `opts.display` | `string[]?` | Display backends |
| `opts.callback` | `function?` | Callback; when provided, skips display |
| `opts.bufnr` | `integer?` | Target buffer for virt_text |
| `opts.line` | `integer?` | Target line for virt_text (1-indexed) |

### `api.run_range(start_line, end_line, filetype?, opts?)`

| Parameter | Type | Description |
|-----------|------|-------------|
| `start_line` | `integer` | Start line (1-indexed) |
| `end_line` | `integer` | End line (1-indexed, inclusive) |
| `filetype` | `string?` | File type, defaults to current buffer |
| `opts` | `table?` | Same as `run_string` |

## License

MIT
