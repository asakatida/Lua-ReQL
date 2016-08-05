local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('array limits', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    function r.run(query, array_limit)
      return query.run(query.r.c, {array_limit = array_limit})
    end

    local reql_db = 'array'
    r.reql_table = r.reql.table'limits'

    local ten_l = assert.is_table(r.reql{1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
    local function ten_f()
      return ten_l
    end
    r.huge_l = ten_l.concat_map(ten_f).concat_map(ten_f).concat_map(ten_f).concat_map(ten_f)

    r.c = assert.is_table(r.connect())

    r.run(r.reql.db_create(reql_db)).to_array()
    r.c.use(reql_db)
    r.run(r.reql.table_create'limits').to_array()
  end)

  teardown(function()
    if r.c then
      r.run(r.reql_table.delete()).to_array()
    end
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('create', function()
    local cur = r.run(r.reql{1, 2, 3, 4, 5, 6, 7, 8}, 4)
    assert.is_nil(cur.to_array())
  end)

  it('equal', function()
    local cur = r.run(r.reql{1, 2, 3, 4}.union{5, 6, 7, 8}, 8)
    assert.same({{1, 2, 3, 4, 5, 6, 7, 8}}, assert.is_table(cur.to_array()))
  end)

  it('huge', function()
    local cur = r.run(r.huge_l.append(1).count(), 100001)
    assert.same({100001}, assert.is_table(cur.to_array()))
  end)

  it('huge read', function()
    local cur = r.run(r.reql_table.insert{id = 0, array = r.huge_l.append(1)}, 100001)
    assert.is_table(cur.to_array())
    cur = r.run(r.reql_table.get(0), 100001)
    assert.same({r.decode'null'}, assert.is_table(cur.to_array()))
  end)

  it('huge table', function()
    local cur = r.run(r.reql_table.insert{id = 0, array = r.huge_l.append(1)}, 100001)
    assert.same(
      {{
        deleted = 0, unchanged = 0, replaced = 0, skipped = 0,
        errors = 1, inserted = 0,
        first_error =
        'Array too large for disk writes (limit 100,000 elements).'
      }},
      assert.is_table(cur.to_array())
    )
  end)

  it('less than', function()
    local cur = r.run(r.reql{1, 2, 3, 4}.union{5, 6, 7, 8}, 4)
    assert.is_nil(cur.to_array())
  end)

  it('less than read', function()
    local cur = r.run(r.reql_table.insert{
      id = 1, array = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    })
    assert.is_table(cur.to_array())
    cur = r.run(r.reql_table.get(1), 4)
    assert.same(
      {{array = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, id = 1}},
      assert.is_table(cur.to_array())
    )
  end)

  it('negative', function()
    local cur = r.run(r.reql{1, 2, 3, 4, 5, 6, 7, 8}, -1)
    assert.is_nil(cur.to_array())
  end)

  it('zero', function()
    local cur = r.run(r.reql{1, 2, 3, 4, 5, 6, 7, 8}, 0)
    assert.is_nil(cur.to_array())
  end)
end)
