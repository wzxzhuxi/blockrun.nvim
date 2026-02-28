-- blockrun/runner.lua — 异步执行引擎，管理临时文件生命周期

local M = {}

local active_job = nil -- 当前运行的进程，用于 kill/reset
local generation = 0   -- 代际计数器，使过期回调失效

--- 生成安全的临时文件路径
---@param ext string
---@return string
local function tmpfile(ext)
  return vim.fn.tempname() .. "." .. ext
end

--- 构建解释型语言的命令
---@param spec blockrun.LangSpec
---@param src_path string
---@return string[]
local function interp_cmd(spec, src_path)
  local cmd = type(spec.cmd) == "table" and vim.deepcopy(spec.cmd) or { spec.cmd }
  if spec.args then
    vim.list_extend(cmd, spec.args)
  end
  cmd[#cmd + 1] = src_path
  return cmd
end

--- 构建编译命令
---@param spec blockrun.LangSpec
---@param src_path string
---@param bin_path string
---@return string[]
local function compile_cmd(spec, src_path, bin_path)
  local cmd = type(spec.cmd) == "table" and vim.deepcopy(spec.cmd) or { spec.cmd }
  if spec.compile_args then
    vim.list_extend(cmd, spec.compile_args)
  end
  if spec.compile_fmt == "zig" then
    -- zig: cmd [args] src -o bin
    cmd[#cmd + 1] = src_path
    cmd[#cmd + 1] = "-o"
    cmd[#cmd + 1] = bin_path
  else
    -- 标准格式: cmd [args] -o bin src
    cmd[#cmd + 1] = "-o"
    cmd[#cmd + 1] = bin_path
    cmd[#cmd + 1] = src_path
  end
  return cmd
end

--- 静默删除文件（可在 luv 回调中安全调用）
---@param paths string[]
local function cleanup(paths)
  for _, p in ipairs(paths) do
    vim.uv.fs_unlink(p)
  end
end

--- 从 vim.system 完成结果构建统一的结果表
---@param comp table
---@return table
local function make_result(comp)
  return {
    stdout = comp.stdout or "",
    stderr = comp.stderr or "",
    code = comp.code,
    signal = comp.signal,
    timed_out = comp.signal == 15 or comp.signal == 9,
  }
end

--- 异步执行代码
---@param code string            源代码文本
---@param spec blockrun.LangSpec  语言 spec
---@param config table           用户配置（timeout 等）
---@param callback fun(result: table)
function M.execute(code, spec, config, callback)
  -- 先终止已有进程
  M.kill()

  generation = generation + 1
  local my_gen = generation

  local src_path = tmpfile(spec.ext)
  local timeout = (config.timeout or 10) * 1000 -- 秒 -> 毫秒

  -- 写源码到临时文件
  local fd, open_err = vim.uv.fs_open(src_path, "w", 438) -- 0o666
  if not fd then
    callback({ stdout = "", stderr = "创建临时文件失败: " .. (open_err or ""), code = 1, signal = 0 })
    return
  end
  local _, write_err = vim.uv.fs_write(fd, code)
  vim.uv.fs_close(fd)
  if write_err then
    callback({ stdout = "", stderr = "写入临时文件失败: " .. write_err, code = 1, signal = 0 })
    cleanup({ src_path })
    return
  end

  local files_to_clean = { src_path }

  if spec.type == "compiled" then
    -- 去掉扩展名作为二进制输出路径
    local bin_path = src_path:gsub("%.[^.]+$", "")
    files_to_clean[#files_to_clean + 1] = bin_path

    local cmd = compile_cmd(spec, src_path, bin_path)
    active_job = vim.system(cmd, { timeout = timeout }, function(comp)
      -- 代际检查：若已被新调用取代则直接清理退出
      if my_gen ~= generation then
        cleanup(files_to_clean)
        return
      end

      if comp.code ~= 0 then
        -- 编译失败
        active_job = nil
        cleanup(files_to_clean)
        vim.schedule(function()
          if my_gen ~= generation then return end
          callback(make_result(comp))
        end)
        return
      end

      -- 编译成功，运行二进制
      active_job = vim.system({ bin_path }, { timeout = timeout }, function(run)
        active_job = nil
        cleanup(files_to_clean)
        vim.schedule(function()
          if my_gen ~= generation then return end
          callback(make_result(run))
        end)
      end)
    end)
  else
    -- 解释型语言
    local cmd = interp_cmd(spec, src_path)
    active_job = vim.system(cmd, { timeout = timeout }, function(comp)
      active_job = nil
      cleanup(files_to_clean)
      vim.schedule(function()
        if my_gen ~= generation then return end
        callback(make_result(comp))
      end)
    end)
  end
end

--- 终止当前运行的进程
function M.kill()
  if active_job then
    active_job:kill(9) -- SIGKILL
    active_job = nil
  end
end

--- 是否有进程在运行
---@return boolean
function M.is_running()
  return active_job ~= nil
end

return M
