describe('datum', function()
  local r, reql_db, reql_table, c

  setup(function()
    r = require('rethinkdb')

    reql_db = 'roundtrip'
    reql_table = 'datum'

    local err

    c, err = r.connect()
    if err then error(err.message()) end

    r.db_create(reql_db).run(c)
    c.use(reql_db)
    r.table_create(reql_table).run(c)
  end)

  after_each(function()
    r.table(reql_table).delete().run(c)
  end)

  teardown(function()
    r = nil
  end)

  it('false', function()
    assert.same({false}, r(false).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('true', function()
    assert.same({true}, r(true).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('nil', function()
    assert.same({nil}, r(nil).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('string', function()
    assert.same({'not yap wa\' Hol'}, r('not yap wa\' Hol').run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('0', function()
    assert.same({0}, r(0).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('1', function()
    assert.same({1}, r(1).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('-1', function()
    assert.same({-1}, r(-1).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('τ', function()
    assert.same({6.28}, r(6.28).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('𝑒', function()
    assert.same({2.2}, r(2.2).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('α', function()
    assert.same({0.00001}, r(0.00001).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('array', function()
    assert.same({{[1] = 1, [2] = 2}}, r({[1] = 1, [2] = 2}).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('table', function()
    assert.same({{first = 1, second = 2}}, r({first = 1, second = 2}).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)
end)
