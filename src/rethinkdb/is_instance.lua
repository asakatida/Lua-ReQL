local function is_instance(obj, cls, ...)
  if cls == nil then return false end

  if type(cls) == 'string' then
    if type(obj) == cls then
      return true
    end
  elseif type(cls) == 'table' then
    cls = cls.__name
  else
    return false
  end

  if type(obj) == 'table' then
    local obj_cls = obj
    while obj_cls do
      if obj_cls.__name == cls then
        return true
      end
      obj_cls = obj_cls.__parent
    end
  end

  return is_instance(obj, ...)
end

return is_instance
