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

    function r.run(query, ...)
      assert.is_table(query, ...)
      return assert.is_table(query.run(query.r.c))
    end

    local reql_db = 'cursor'
    r.reql_table = r.reql.table'tests'

    r.c = assert.is_table(r.connect())

    r.run(r.reql.db_create(reql_db)).to_array()
    r.c.use(reql_db)
    r.run(r.reql.table_create'tests').to_array()

    assert.is_true(r.c.is_open())
  end)

  teardown(function()
    if r.c then
      r.run(r.reql_table.delete()).to_array()
    end
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('type', function()
    local cur = r.run(r.reql_table)
    assert.are.equal('cursor', r.type(cur))
    assert.is_true(cur.close())
  end)

  it('count', function()
    local num_rows = math.random(10, 11)

    local doc = {a = 1, b = 2, c = 3}
    local document = {}
    for _=1, num_rows, 1 do
      table.insert(document, doc)
    end

    local insert = r.run(r.reql_table.insert(document))
    finally(insert.close)
    assert.are.equal(
      num_rows,
      assert.is_table(insert.to_array())[1].inserted
    )
    local cur = r.run(r.reql_table)
    finally(cur.close)
    assert.are.equal(
      num_rows,
      #assert.is_table(cur.to_array())
    )
  end)

  it('close', function()
    local cur = r.run(r.reql_table)
    assert.is_true(cur.close())
  end)
end)
