local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('cursor', function()
  local r, reql_db, reql_table, c, num_rows

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    reql_db = 'cursor'
    reql_table = 'tests'

    local err

    c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.reql.db_create(reql_db).run(c)
    c.use(reql_db)
    r.reql.table_create(reql_table).run(c)
  end)

  before_each(function()
    num_rows = math.random(1111, 2222)

    local doc = {}
    for i=0, 500, 1 do
      table.insert(doc, i)
    end
    local document = {}
    for _=0, num_rows, 1 do
      table.insert(document, doc)
    end

    r.reql.table(reql_table).insert(document).run(c)
  end)

  teardown(function()
    r.reql.table(reql_table).delete().run(c)
    c.close()
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('type', function()
    assert.are.equal(
      'cursor',
      r.table(reql_table).run(
        c, function(err, cur)
          if err then error(err.message()) end
          return r.type(cur)
        end
      )
    )
  end)

  it('count', function()
    assert.are.equal(
      num_rows,
      r.table(reql_table).run(
        c, function(_err, cur)
          if _err then error(_err.message()) end
          return cur.to_array(function(err, arr)
            if err then error(err.message()) end
            return #arr
          end)
        end
      )
    )
  end)

  it('close', function()
    assert.has_no.errors(function()
      r.table(reql_table).run(
        c, function(_err, cur)
          if _err then error(_err.message()) end
          cur.close(function(err) if err then error(err.message()) end end)
        end
      )
    end)
  end)
end)
