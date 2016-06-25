local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('control', function()
  local r, reql_db, reql_table, c

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    reql_db = 'control'
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
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('branch db', function()
    r.reql.db(reql_db).branch(1, 2).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('branch error', function()
    r.reql.branch(r.error_'a', 1, 2).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('branch false', function()
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

  it('branch nil', function()
    assert.same({2}, r.reql().branch(1, 2).run(
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

  it('branch table', function()
    r.reql.table(reql_table).branch(1, 2).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('branch true', function()
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
    assert.same({{0, 1, 2, 3}}, r.reql{0, 1, 2}.do_(function(v) return v.append(3) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ))
  end)

  if string.match(_VERSION, '5.[23]') then
    it('do extra arg', function()
     r.reql.do_(1, function(x, y) return x + y end).run(
        c, function(_err, cur)
          assert.is_nil(_err)
          cur.to_array(function(err, arr)
            assert.is_nil(arr)
            assert.is_not_nil(err)
          end)
        end
      )
    end)

    it('do missing arg', function()
     r.reql.do_(1, 2, function(x) return x end).run(
        c, function(_err, cur)
          assert.is_nil(_err)
          cur.to_array(function(err, arr)
            assert.is_nil(arr)
            assert.is_not_nil(err)
          end)
        end
      )
    end)
  end

  it('do mul', function()
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

  it('do no args', function()
   r.reql.do_().run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('do no func', function()
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

  it('do no return', function()
   r.reql.do_(1, function() end)
  end)

  it('do return nil', function()
   r.reql.do_(1, function() return nil end)
  end)

  it('do str add num', function()
    r.reql'abc'.do_(function(v) return v.add(3) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('do str add str add num', function()
    r.reql'abc'.do_(function(v) return v.add'def' end).add(3).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('do str append', function()
    r.reql'abc'.do_(function(v) return v.append(3) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('error', function()
    r.reql.error_'Hello World'.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('js', function()
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

  it('js function result', function()
   r.reql.js'(function() { return 1; })'.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('js function no wrap', function()
   r.reql.js'function() { return 1; }'.run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('do js function missing arg', function()
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

  it('do js function return undefined', function()
   r.reql.do_(1, 2, r.reql.js'(function(a, b, c) { return c; })').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('filter js', function()
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

  it('map js constant', function()
    r.reql.map({1, 2, 3}, r.reql.js'1').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('filter js undefined', function()
    r.reql.filter({1, 2, 3}, r.reql.js'(function(a) {})').run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('map constant', function()
    r.reql.map({1, 2, 3}, 1).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        cur.to_array(function(err, arr)
          assert.is_nil(arr)
          assert.is_not_nil(err)
        end)
      end
    )
  end)

  it('filter constant str', function()
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

  it('filter nil', function()
    assert.same({{}}, r.reql.filter({1, 2, 3}, r.reql()).run(
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

  it('count for each insert', function()
    r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    assert.same(r.table(reql_table).count().run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ), {3})
  end)

  it('for each update', function()
    r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    assert.same(r.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).update({foo = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ), {{deleted = 0, replaced = 9, unchanged = 0, errors = 0, skipped = 0, inserted = 0}})
  end)

  it('for each insert with duplicates', function()
    r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).update({foo = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    assert.same(r.for_each({1, 2, 3}, function(row) return {r.table(reql_table).insert({id = row}), r.reql.table(reql_table).insert({id = row * 10})} end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ), {{first_error = 'Duplicate primary key `id`.\n{\n\t"foo".\t3,\n\t"id".\t1\n}\n{\n\t"id".\t1\n}', deleted = 0, replaced = 0, unchanged = 0, errors = 3, skipped = 0, inserted = 3}})
  end)

  it('for each update many', function()
    r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    r.reql.for_each({1, 2, 3}, function(row) return r.reql.table(reql_table).update({foo = row}) end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    r.reql.for_each({1, 2, 3}, function(row) return {r.table(reql_table).insert({id = row}), r.reql.table(reql_table).insert({id = row * 10})} end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    )
    assert.same(r.for_each({1, 2, 3}, function(row) return {r.table(reql_table).update({foo = row}), r.reql.table(reql_table).update({bar = row})} end).run(
      c, function(_err, cur)
        assert.is_nil(_err)
        return cur.to_array(function(err, arr)
          assert.is_nil(err)
          return arr
        end)
      end
    ), {{deleted = 0, replaced = 36, unchanged = 0, errors = 0, skipped = 0, inserted = 0}})
  end)
end)
