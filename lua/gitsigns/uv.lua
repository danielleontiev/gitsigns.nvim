local uv = vim.loop

local M = {}








local handles = {}

M.handles = handles

function M.print_handles()
   local none = true
   for _, e in pairs(handles) do
      local handle, longlived, tr = unpack(e)
      if handle and not longlived and not handle:is_closing() then
         print('')
         print(tr)
         none = false
      end
   end
   if none then
      print('No active handles')
   end
end

vim.api.nvim_create_autocmd('VimLeavePre', {
   callback = function()
      for _, e in pairs(handles) do
         local handle = e[1]
         if handle and not handle:is_closing() then
            handle:close()
         end
      end
   end,
})

local function c(fn)
   return function(longlived)
      local r = fn()
      handles[#handles + 1] = { r, longlived, debug.traceback() }
      return r
   end
end

M.new_timer = c(uv.new_timer)
M.new_fs_poll = c(uv.new_fs_poll)
M.new_fs_event = c(uv.new_fs_event)

function M.new_pipe(ipc)
   local r = uv.new_pipe(ipc)
   handles[#handles + 1] = { r, false, debug.traceback() }
   return r
end

function M.spawn(cmd, opts, on_exit)
   local handle, pid = uv.spawn(cmd, opts, on_exit)
   if handle then
      handles[#handles + 1] = { handle, false, cmd .. ' ' .. vim.inspect(opts) }
   end
   return handle, pid
end

return M
