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
      return query.run(query.r.c, {array_limit = array_limit}, function(err, cur)
        return cur, err
      end)
    end

    local reql_db = 'array'
    r.reql_table = r.reql.table'limits'

    -- local ten_l = r.reql{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    -- local function ten_f() return ten_l end
    -- huge_l = ten_l.concat_map(ten_f).concat_map(ten_f).concat_map(
    --   ten_f).concat_map(ten_f)
    r.huge_l = r.reql{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}

    local err

    r.c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.reql.db_create(reql_db).run(r.c)
    r.c.use(reql_db)
    r.reql.table_create'limits'.run(r.c)
  end)

  teardown(function()
    r.reql_table.delete().run(r.c)
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('create', function()
    local cur, _err = r.run(r.reql{1, 2, 3, 4, 5, 6, 7, 8}, 4)
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('equal', function()
    local cur, _err = r.run(r.reql{1, 2, 3, 4}.union{5, 6, 7, 8}, 8)
    assert.is_nil(_err)
    assert.same({{1, 2, 3, 4, 5, 6, 7, 8}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('huge', function()
    local cur, _err = r.run(r.huge_l.append(1).count(), 100001)
    assert.is_nil(_err)
    assert.same({100001}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('huge read', function()
    local cur, _err = r.run(r.reql_table.insert{id = 0, array = r.huge_l.append(1)}, 100001)
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql_table.get(0), 100001)
    assert.is_nil(_err)
    assert.same(
      {}, cur.to_array(function(err, arr)
        assert.is_nil(err)
        return arr
      end)
    )
  end)

  it('huge table', function()
    local cur, _err = r.run(r.reql_table.insert{id = 0, array = r.huge_l.append(1)}, 100001)
    assert.is_nil(_err)
    assert.same(
      {{
        deleted = 0, unchanged = 0, replaced = 0, skipped = 0,
        errors = 1, inserted = 0,
        first_error =
        'Array too large for disk writes (limit 100,000 elements).'
      }},
      cur.to_array(function(err, arr)
        assert.is_nil(err)
        return arr
      end)
    )
  end)

  it('less than', function()
    local cur, _err = r.run(r.reql{1, 2, 3, 4}.union{5, 6, 7, 8}, 4)
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('less than read', function()
    local cur, _err = r.run(r.reql_table.insert(
      {id = 1, array = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}}
    ))
    assert.is_nil(_err)
    cur.to_array(function(err)
      assert.is_nil(err)
    end)
    cur, _err = r.run(r.reql_table.get(1), 4)
    assert.is_nil(_err)
    assert.same(
      {{array = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, id = 1}},
      cur.to_array(function(err, arr)
        assert.is_nil(err)
        return arr
      end)
    )
  end)

  it('negative', function()
    local cur, _err = r.run(r.reql{1, 2, 3, 4, 5, 6, 7, 8}, -1)
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('zero', function()
    local cur, _err = r.run(r.reql{1, 2, 3, 4, 5, 6, 7, 8}, 0)
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)
end)
