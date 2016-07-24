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
      return query.run(query.r.c)
    end

    local reql_db = 'cursor'
    r.reql_table = r.reql.table'tests'

    r.c = assert.is_table(r.connect{proto_version = r.proto_V0_4})

    assert.is_table(assert.is_table(r.run(r.reql.db_create(reql_db))).to_array())
    r.c.use(reql_db)
    assert.is_table(assert.is_table(r.run(r.reql.table_create'tests')).to_array())
  end)

  teardown(function()
    assert.is_table(assert.is_table(r.run(r.reql_table.delete())).to_array())
    if r.c then r.c.close() end
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('type', function()
    local cur = assert.is_table(r.run(r.reql_table))
    assert.are.equal('cursor', r.type(cur))
  end)

  it('count', function()
    local num_rows = math.random(1111, 2222)

    local doc = {}
    for i=0, 500, 1 do
      table.insert(doc, i)
    end
    local document = {}
    for _=0, r.num_rows, 1 do
      table.insert(document, doc)
    end

    local insert = assert.is_table(r.run(r.reql_table.insert(document)))
    finally(insert.close)
    assert.is_table(insert.to_array())
    local cur = assert.is_table(r.run(r.reql_table))
    finally(cur.close)
    assert.are.equal(
      num_rows,
      #assert.is_table(cur.to_array())
    )
  end)

  it('close', function()
    local cur = assert.is_table(r.run(r.reql_table))
    cur.close(function(err) assert.is_nil(err) end)
  end)
end)
