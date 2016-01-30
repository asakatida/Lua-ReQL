local errors = require'rethinkdb.errors'

function convert_pseudotype(obj, opts)
  if type(obj) == 'table' then
    for key, value in pairs(obj) do
      obj[key] = convert_pseudotype(value, opts)
    end
    -- An R_OBJECT may be a regular table or a 'pseudo-type' so we need a
    -- second layer of type switching here on the obfuscated field '$reql_type$'
    local reql_type = obj['$reql_type$']
    if 'TIME' == reql_type then
      local time_format = opts.time_format
      if 'native' == time_format or not time_format then
        if not (obj['epoch_time']) then
          return error(errors.ReQLDriverError('pseudo-type TIME ' .. obj .. ' table missing expected field `epoch_time`.'))
        end

        -- We ignore the timezone field of the pseudo-type TIME table. JS dates do not support timezones.
        -- By converting to a native date table we are intentionally throwing out timezone information.

        -- field 'epoch_time' is in seconds but the Date constructor expects milliseconds
        return obj['epoch_time']
      elseif 'raw' == time_format then
        return obj
      else
        return error(errors.ReQLDriverError('Unknown time_format run option ' .. opts.time_format .. '.'))
      end
    elseif 'GROUPED_DATA' == reql_type then
      local group_format = opts.group_format
      if 'native' == group_format or not group_format then
        -- Don't convert the data into a map, because the keys could be tables which doesn't work in JS
        -- Instead, we have the following format:
        -- [ { 'group': <group>, 'reduction': <value(s)> } }, ... ]
        res = {}
        for i, v in ipairs(obj['data']) do
          res[i] = {
            group = i,
            reduction = v
          }
        end
        obj = res
      elseif 'raw' == group_format then
        return obj
      else
        return error(errors.ReQLDriverError('Unknown group_format run option ' .. opts.group_format .. '.'))
      end
    elseif 'BINARY' == reql_type then
      local binary_format = opts.binary_format
      if 'native' == binary_format or not binary_format then
        if not obj.data then
          return error(errors.ReQLDriverError('pseudo-type BINARY table missing expected field `data`.'))
        end
        return r._unb64(obj.data)
      elseif 'raw' == binary_format then
        return obj
      else
        return error(errors.ReQLDriverError('Unknown binary_format run option ' .. opts.binary_format .. '.'))
      end
    else
      -- Regular table or unknown pseudo type
      return obj
    end
  end
  return obj
end

return convert_pseudotype
