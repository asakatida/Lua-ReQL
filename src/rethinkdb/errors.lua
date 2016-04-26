local ReQLQueryPrinter = class(
  'ReQLQueryPrinter',
  {
    __init = function(self, term, frames)
      self.term = term
      self.frames = frames
    end,
    print_query = function(self)
      local carrots
      if next(self.frames) then
        carrots = self:compose_carrots(self.term, self.frames)
      else
        carrots = {self:carrotify(self:compose_term(self.term))}
      end
      carrots = self:join_tree(carrots):gsub('[^%^]', '')
      return self:join_tree(self:compose_term(self.term)) .. '\n' .. carrots
    end,
    compose_term = function(self, term)
      if type(term) ~= 'table' then return '' .. term end
      local args = {}
      for i, arg in ipairs(term.args) do
        args[i] = self:compose_term(arg)
      end
      local optargs = {}
      for key, arg in pairs(term.optargs) do
        optargs[key] = self:compose_term(arg)
      end
      return term:compose(args, optargs)
    end,
    compose_carrots = function(self, term, frames)
      local frame = table.remove(frames, 1)
      local args = {}
      for i, arg in ipairs(term.args) do
        if frame == (i - 1) then
          args[i] = self:compose_carrots(arg, frames)
        else
          args[i] = self:compose_term(arg)
        end
      end
      local optargs = {}
      for key, arg in pairs(term.optargs) do
        if frame == key then
          optargs[key] = self:compose_carrots(arg, frames)
        else
          optargs[key] = self:compose_term(arg)
        end
      end
      if frame then
        return term:compose(args, optargs)
      end
      return self:carrotify(term:compose(args, optargs))
    end,
    carrot_marker = {},
    carrotify = function(self, tree)
      return {self.carrot_marker, tree}
    end,
    join_tree = function(self, tree)
      local str = ''
      for _, term in ipairs(tree) do
        if type(term) == 'table' then
          if #term == 2 and term[1] == self.carrot_marker then
            str = str .. self:join_tree(term[2]):gsub('.', '^')
          else
            str = str .. self:join_tree(term)
          end
        else
          str = str .. term
        end
      end
      return str
    end
  }
)

local ReQLError = class(
  'ReQLError',
  function(self, msg, term, frames)
    self.msg = msg
    self.message = function()
      if self._message then return self._message end
      self._message = self.__class.__name .. ' ' .. msg
      if term then
        self._message = self._message .. ' in:\n' .. ReQLQueryPrinter(term, frames):print_query()
      end
      return self._message
    end
  end
)

local ReQLDriverError = class('ReQLDriverError', ReQLError, {})

local ReQLServerError = class('ReQLServerError', ReQLError, {})

local ReQLRuntimeError = class('ReQLRuntimeError', ReQLServerError, {})

local ReQLAvailabilityError = class('ReQLRuntimeError', ReQLRuntimeError, {})
local ReQLQueryLogicError = class('ReQLRuntimeError', ReQLRuntimeError, {})

return {
  ReQLDriverError = ReQLDriverError,

  ReQLRuntimeError = ReQLRuntimeError,
  ReQLCompileError = class('ReQLCompileError', ReQLServerError, {}),

  ReQLAuthError = class('ReQLDriverError', ReQLDriverError, {}),

  ReQLClientError = class('ReQLClientError', ReQLServerError, {}),

  ReQLAvailabilityError = ReQLAvailabilityError,
  ReQLInternalError = class('ReQLRuntimeError', ReQLRuntimeError, {}),
  ReQLQueryLogicError = ReQLQueryLogicError,
  ReQLResourceLimitError = class('ReQLRuntimeError', ReQLRuntimeError, {}),
  ReQLTimeoutError = class('ReQLRuntimeError', ReQLRuntimeError, {}),
  ReQLUserError = class('ReQLRuntimeError', ReQLRuntimeError, {}),

  ReQLOpFailedError = class('ReQLRuntimeError', ReQLAvailabilityError, {}),
  ReQLOpIndeterminateError = class('ReQLRuntimeError', ReQLAvailabilityError, {}),

  ReQLNonExistenceError = class('ReQLRuntimeError', ReQLQueryLogicError, {})
}
