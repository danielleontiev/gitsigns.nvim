local fn = vim.fn

local SignsConfig = require('gitsigns.config').Config.SignsConfig
local config = require('gitsigns.config').config

local emptytable = require('gitsigns.util').emptytable

local B = require('gitsigns.signs.base')

local M = {}

-- The internal representation of signs in Neovim is a linked list which is slow
-- to index. To improve efficiency we add an abstraction layer to the signs API
-- which keeps track of which signs have already been placed in the buffer.
--
-- This allows us to:
--    - efficiently query placed signs.
--    - skip adding a sign if it has already been placed.

local function capitalise_word(x)
   return x:sub(1, 1):upper() .. x:sub(2)
end

local sign_define_cache = {}
local sign_name_cache = {}

local function get_sign_name(name, stype)
   local key = name .. stype
   if not sign_name_cache[key] then
      sign_name_cache[key] = string.format(
      '%s%s%s', 'GitSigns', capitalise_word(key), capitalise_word(stype))
   end

   return sign_name_cache[key]
end

local function sign_get(name)
   if not sign_define_cache[name] then
      local s = fn.sign_getdefined(name)
      if not vim.tbl_isempty(s) then
         sign_define_cache[name] = s
      end
   end
   return sign_define_cache[name]
end

local function define_sign(name, opts, redefine)
   if redefine then
      sign_define_cache[name] = nil
      fn.sign_undefine(name)
      fn.sign_define(name, opts)
   elseif not sign_get(name) then
      fn.sign_define(name, opts)
   end
end

local function define_signs(obj, redefine)
   -- Define signs
   for stype, cs in pairs(obj.config) do
      local hls = obj.hls[stype]
      define_sign(get_sign_name(obj.name, stype), {
         texthl = hls.hl,
         text = config.signcolumn and cs.text or nil,
         numhl = config.numhl and hls.numhl or nil,
         linehl = config.linehl and hls.linehl or nil,
      }, redefine)
   end
end

local group_base = 'gitsigns_vimfn_signs_'

function M._new(cfg, hls, name)
   local self = setmetatable({}, { __index = M })
   self.name = name or ''
   self.group = group_base .. (name or '')
   self.config = cfg
   self.hls = hls
   self.placed = emptytable()

   define_signs(self, false)

   return self
end

function M:on_lines(_, _, _, _)
end

function M:remove(bufnr, start_lnum, end_lnum)
   end_lnum = end_lnum or start_lnum

   if start_lnum then
      for lnum = start_lnum, end_lnum do
         self.placed[bufnr][lnum] = nil
         fn.sign_unplace(self.group, { buffer = bufnr, id = lnum })
      end
   else
      self.placed[bufnr] = nil
      fn.sign_unplace(self.group, { buffer = bufnr })
   end
end

function M:add(bufnr, signs)
   if not config.signcolumn and not config.numhl and not config.linehl then
      -- Don't place signs if it won't show anything
      return
   end

   local to_place = {}

   for _, s in ipairs(signs) do
      local sign_name = get_sign_name(self.name, s.type)

      local cs = self.config[s.type]
      if config.signcolumn and cs.show_count and s.count then
         local count = s.count
         local cc = config.count_chars
         local count_suffix = cc[count] and tostring(count) or (cc['+'] and 'Plus') or ''
         local count_char = cc[count] or cc['+'] or ''
         local hls = self.hls[s.type]
         sign_name = sign_name .. count_suffix
         define_sign(sign_name, {
            texthl = hls.hl,
            text = config.signcolumn and cs.text .. count_char or '',
            numhl = config.numhl and hls.numhl or nil,
            linehl = config.linehl and hls.linehl or nil,
         })
      end

      if not self.placed[bufnr][s.lnum] then
         local sign = {
            id = s.lnum,
            group = self.group,
            name = sign_name,
            buffer = bufnr,
            lnum = s.lnum,
            priority = config.sign_priority,
         }
         self.placed[bufnr][s.lnum] = s
         to_place[#to_place + 1] = sign
      end
   end

   if #to_place > 0 then
      fn.sign_placelist(to_place)
   end
end

function M:contains(bufnr, start, last)
   for i = start + 1, last + 1 do
      if self.placed[bufnr][i] then
         return true
      end
   end
   return false
end

function M:reset()
   self.placed = emptytable()
   fn.sign_unplace(self.group)
   define_signs(self, true)
end

return M
