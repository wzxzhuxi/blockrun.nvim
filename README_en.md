# blockrun.nvim

[English](README_en.md) | [中文](README.md)

A minimal Neovim code-block runner written in pure Lua. Zero dependencies, zero build steps.

Designed as a drop-in replacement for [sniprun](https://github.com/michaelb/sniprun) -- same `<Plug>` mappings, no Rust toolchain required.

## Features

- **Pure Lua** -- no external binaries, no build steps, no `sh install.sh`
- **Async execution** -- runs code via `vim.system()`, never blocks the editor
- **16 languages** -- interpreted and compiled, plus markdown fenced code blocks
- **Floating window** -- stdout/stderr displayed near cursor, scrollable, auto-close
- **Treesitter-aware** -- in normal mode, detects the surrounding function/class/block
- **Timeout** -- kills runaway processes after 10 seconds (configurable)
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
  },
  opts = {},
}
```

## Configuration

```lua
opts = {
  timeout = 10,  -- seconds, default 10
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
  -> extract code (visual selection / treesitter block / current line)
  -> write to temp file
  -> vim.system() async execute
  -> display result in floating window
```

## License

MIT
