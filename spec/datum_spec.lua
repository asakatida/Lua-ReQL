local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('datum', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    function r.run(query, ...)
      assert.is_table(query, ...)
      return assert.is_table(query.run(query.r.c))
    end

    local reql_db = 'roundtrip'
    r.reql_table = r.reql.table'datum'

    r.c = assert.is_table(r.connect())

    r.run(r.reql.db_create(reql_db))
    r.c.use(reql_db)
    r.run(r.reql.table_create'datum')
  end)

  teardown(function()
    if r.c then
      r.run(r.reql_table.delete()).to_array()
    end
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('false', function()
    local var = false
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('true', function()
    local var = true
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('nil', function()
    local var = nil
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('string', function()
    local var = 'not yap wa\' Hol'
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('0', function()
    local var = 0
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('1', function()
    local var = 1
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('-1', function()
    local var = -1
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('τ', function()
    local var = 6.28
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('𝑒', function()
    local var = 2.2
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('α', function()
    local var = 0.00001
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('array', function()
    local var = {[1] = 1, [2] = 2}
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)

  it('table', function()
    local var = {first = 1, second = 2}
    local cur = assert.is_table(r.run(r.reql(var)))
    assert.same({var}, cur.to_array())
  end)
end)
