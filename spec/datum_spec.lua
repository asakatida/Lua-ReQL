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

    function r.run(query)
      return query.run(query.r.c, function(err, cur)
        return cur, err
      end)
    end

    local reql_db = 'roundtrip'
    r.reql_table = r.reql.table'datum'

    local err

    r.c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.run(r.reql.db_create(reql_db))
    r.c.use(reql_db)
    r.run(r.reql.table_create'datum')
  end)

  teardown(function()
    r.run(r.reql_table.delete())
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('false', function()
    local var = false
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('true', function()
    local var = true
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('nil', function()
    local var = nil
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('string', function()
    local var = 'not yap wa\' Hol'
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('0', function()
    local var = 0
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('1', function()
    local var = 1
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('-1', function()
    local var = -1
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('τ', function()
    local var = 6.28
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('𝑒', function()
    local var = 2.2
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('α', function()
    local var = 0.00001
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('array', function()
    local var = {[1] = 1, [2] = 2}
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)

  it('table', function()
    local var = {first = 1, second = 2}
    local cur, _err = r.run(r.reql(var))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      assert.same({var}, arr)
    end)
  end)
end)
