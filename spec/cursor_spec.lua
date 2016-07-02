local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('cursor', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    function r.run(query)
      return query.run(query.r.c, function(err, cur)
        return cur, err
      end)
    end

    local reql_db = 'cursor'
    r.reql_table = r.reql.table'tests'

    local err

    r.c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.run(r.reql.db_create(reql_db))
    r.c.use(reql_db)
    r.run(r.reql.table_create'tests')

    r.num_rows = math.random(1111, 2222)

    local doc = {}
    for i=0, 500, 1 do
      table.insert(doc, i)
    end
    local document = {}
    for _=0, r.num_rows, 1 do
      table.insert(document, doc)
    end

    r.run(r.reql_table.insert(document))
  end)

  teardown(function()
    r.run(r.reql_table.delete())
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('type', function()
    local cur, err = r.run(r.reql_table)
    assert.is_nil(err)
    assert.are.equal('cursor', r.type(cur))
  end)

  it('count', function()
    local cur, _err = r.run(r.reql_table)
    assert.is_nil(_err)
    assert.are.equal(
      r.num_rows,
      cur.to_array(function(err, arr)
        assert.is_nil(err)
        return #arr
      end)
    )
  end)

  it('close', function()
    local cur, _err = r.run(r.reql_table)
    assert.is_nil(_err)
    assert.is_nil(_err)
    cur.close(function(err) assert.is_nil(err) end)
  end)
end)
