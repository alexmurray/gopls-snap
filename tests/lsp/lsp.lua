-- Drive gopls with Neovim's built-in LSP client, as an editor would: open a
-- clean and a broken file from the workspace given as the first argument,
-- then check hover and diagnostics. gopls is spawned over stdio, unless a
-- second argument gives the unix socket of an already running gopls daemon
-- to connect to instead.
-- nvim is a classic snap, so runs under a complain-mode AppArmor profile,
-- and snap-confine's profile denies inheriting file descriptors created
-- under that label - so `snap run gopls` silently exits 2 when given the
-- unix socketpair nvim creates for its stdio (LP: #1849753, seen on 20.04).
-- Like the opencode snap's CLI wrapper, arm an AppArmor onexec transition
-- and re-run this script in a fresh nvim, which then runs (and creates
-- gopls' socketpair) unconfined - nvim has no exec(), so the original
-- process just relays the child's output and exit code.
local attr_dir = vim.uv.fs_stat('/proc/thread-self/attr/apparmor/current')
  and '/proc/thread-self/attr/apparmor/' or '/proc/thread-self/attr/'
local f = io.open(attr_dir .. 'current')
local label = f and f:read('*a') or ''
if f then f:close() end
if label:match('^snap%.nvim%.') and label:match('%(complain%)%s*$') then
  f = assert(io.open(attr_dir .. 'exec', 'w'))
  assert(f:write('exec unconfined'))
  assert(f:close())
  local relay = function(out)
    return function(_, data)
      if data then out:write(data) end
    end
  end
  local res = vim.system({ vim.v.progpath, '--clean', '-l', arg[0], unpack(arg) }, {
    stdout = relay(io.stdout),
    stderr = relay(io.stderr),
  }):wait()
  os.exit(res.code)
end

local root = vim.fn.fnamemodify(arg[1], ':p'):gsub('/$', '')
local cmd = { 'gopls', 'serve' }
if arg[2] then
  cmd = vim.lsp.rpc.connect(arg[2])
end
local timeout = 120000

local function fail(msg)
  -- the server's stderr ends up in the LSP log
  local log = io.open(vim.lsp.log.get_filename())
  if log then
    io.stderr:write(log:read('*a'))
    log:close()
  end
  io.stderr:write(msg .. '\n')
  os.exit(1)
end

local function open(name)
  vim.cmd.edit(root .. '/' .. name)
  local buf = vim.api.nvim_get_current_buf()
  local id = vim.lsp.start({ name = 'gopls', cmd = cmd, root_dir = root })
  return buf, vim.lsp.get_client_by_id(id)
end

local main, client = open('main.go')
if not vim.wait(timeout, function() return client.initialized end) then
  fail('timed out waiting for gopls to initialize')
end
print('server: ' .. client.server_info.name)

-- LSP positions are 0-based: line 9 col 13 is greet in `fmt.Println(greet(...))`
local res, err = client:request_sync('textDocument/hover', {
  textDocument = { uri = vim.uri_from_bufnr(main) },
  position = { line = 9, character = 13 },
}, timeout, main)
if not res or res.err then
  fail('hover failed: ' .. vim.inspect(err or res))
end
local hover = res.result.contents.value
print('hover: ' .. hover)
if not hover:find('func greet(name string) string', 1, true) then
  fail('unexpected hover result')
end

local broken = open('broken.go')
local found = vim.wait(timeout, function()
  for _, d in ipairs(vim.diagnostic.get(broken)) do
    if d.message:find('undefined: undefinedThing', 1, true) then
      print('diagnostic: ' .. d.lnum + 1 .. ':' .. d.col + 1 .. ': ' .. d.message)
      return true
    end
  end
  return false
end)
if not found then
  fail('timed out waiting for diagnostics for broken.go: ' .. vim.inspect(vim.diagnostic.get(broken)))
end

client:stop()
if not vim.wait(timeout, function() return client:is_stopped() end) then
  fail('gopls did not shut down')
end
os.exit(0)
