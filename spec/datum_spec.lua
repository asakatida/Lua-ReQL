local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('datum', function()
  local r, reql_table, c

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    local reql_db = 'roundtrip'
    reql_table = 'datum'

    local err

    c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.reql.db_create(reql_db).run(c)
    c.use(reql_db)
    r.reql.table_create(reql_table).run(c)
  end)

  teardown(function()
    r.reql.table(reql_table).delete().run(c)
    c.close()
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('false', function()
    r(false).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({false}, arr)
        end)
      end
    )
  end)

  it('true', function()
    r(true).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({true}, arr)
        end)
      end
    )
  end)

  it('nil', function()
    r(nil).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({nil}, arr)
        end)
      end
    )
  end)

  it('string', function()
    r'not yap wa\' Hol'.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({'not yap wa\' Hol'}, arr)
        end)
      end
    )
  end)

  it('0', function()
    r(0).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({0}, arr)
        end)
      end
    )
  end)

  it('1', function()
    r(1).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({1}, arr)
        end)
      end
    )
  end)

  it('-1', function()
    r(-1).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({-1}, arr)
        end)
      end
    )
  end)

  it('τ', function()
    r(6.28).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({6.28}, arr)
        end)
      end
    )
  end)

  it('𝑒', function()
    r(2.2).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({2.2}, arr)
        end)
      end
    )
  end)

  it('α', function()
    r(0.00001).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({0.00001}, arr)
        end)
      end
    )
  end)

  it('array', function()
    r{[1] = 1, [2] = 2}.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({{[1] = 1, [2] = 2}}, arr)
        end)
      end
    )
  end)

  it('table', function()
    r{first = 1, second = 2}.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(err)
          assert.same({{first = 1, second = 2}}, arr)
        end)
      end
    )
  end)
end)
