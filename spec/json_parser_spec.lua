local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('control dkjson', function()
  local r, reql_table, c, dkjson

  setup(function()
    assert:add_formatter(reql_error_formatter)
    dkjson = require('dkjson')
    r = require('rethinkdb').new{json_parser = dkjson}

    local reql_db = 'dkjson'
    reql_table = 'func'

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
    dkjson = nil
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('branch false', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({2}, r.reql.branch(false, 1, 2).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('branch num', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({'c'}, r.reql.branch(1, 'c', false).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('branch true', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({1}, r.reql.branch(true, 1, 2).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({1}, r.reql.do_(function() return 1 end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do add', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({3}, r.reql.do_(1, 2, function(x, y) return x.add(y) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do append', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{0, 1, 2, 3}}, r{0, 1, 2}.do_(function(v) return v.append(3) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do mul', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({2}, r.reql(1).do_(function(v) return v.mul(2) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do no func', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({1}, r.reql.do_(1).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('js', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({2}, r.reql.js'1 + 1'.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('js add add', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({4}, r.reql.js'1 + 1; 2 + 2'.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do js function add', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({3}, r.reql.do_(1, 2, r.reql.js'(function(a, b) { return a + b; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do js function', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({2}, r.reql.do_(1, r.reql.js'(function(x) { return x + 1; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do js function add str', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({'foobar'}, r.reql.do_('foo', r.reql.js'(function(x) { return x + "bar"; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do js no timeout', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({3}, r.reql.js('1 + 2', {timeout = 1.2}).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do js function missing arg', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({1}, r.reql.do_(1, 2, r.reql.js'(function(a) { return a; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('do js function extra arg', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({1}, r.reql.do_(1, 2, r.reql.js'(function(a, b, c) { return a; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('filter js', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{2, 3}}, r.reql.filter({1, 2, 3}, r.reql.js'(function(a) { return a >= 2; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('map js', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{2, 3, 4}}, r.reql.map({1, 2, 3}, r.reql.js'(function(a) { return a + 1; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('filter constant str', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{1, 2, 3}}, r.reql.filter({1, 2, 3}, 'foo').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('filter constant obj', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{1, 2, 3}}, r.reql.filter({1, 2, 3}, {}).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('filter false', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{}}, r.reql.filter({1, 2, 3}, false).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  it('for each insert', function()
    assert.equal(r.decode, dkjson.decode)
    assert.equal(r.encode, dkjson.encode)
    assert.same({{deleted = 0, replaced = 0, unchanged = 0, errors = 0, skipped = 0, inserted = 3}}, r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)
end)
