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

    r.db_create(reql_db).run(c)
    c.use(reql_db)
    r.table_create(reql_table).run(c)
  end)

  teardown(function()
    r.reql.table(reql_table).delete().run(c)
    c.close()
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('branch db', function()
    assert.has_error(
      function()
        r.db(reql_db).branch(1, 2).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type DATUM but found DATABASE.'
    )
  end)

  it('branch error', function()
    assert.has_error(
      function()
        r.branch(r.error_('a'), 1, 2).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'a'
    )
  end)

  it('branch false', function()
    assert.same({2}, r.branch(false, 1, 2).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('branch nil', function()
    assert.same({2}, r().branch(1, 2).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('branch num', function()
    assert.same({'c'}, r.branch(1, 'c', false).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('branch table', function()
    assert.has_error(
      function()
        r.table(reql_table).branch(1, 2).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type DATUM but found TABLE.'
    )
  end)

  it('branch true', function()
    assert.same({1}, r.branch(true, 1, 2).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do', function()
    assert.same({1}, r.do_(function() return 1 end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do add', function()
    assert.same({3}, r.do_(1, 2, function(x, y) return x.add(y) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do append', function()
    assert.same({{0, 1, 2, 3}}, r{0, 1, 2}.do_(function(v) return v.append(3) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  if string.match(_VERSION, '5.[23]') then
    it('do extra arg', function()
      assert.has_error(
        function()
          r.do_(1, function(x, y) return x + y end).run(
            c, function(_err, cur)
              if _err then error(_err.message()) end
              cur.to_array(function(err, arr)
                if err then error(err.msg) end
                error(arr)
              end)
            end
          )
        end, 'Expected function with 1 arguments but found function with 2 argument.'
      )
    end)

    it('do missing arg', function()
      assert.has_error(
        function()
          r.do_(1, 2, function(x) return x end).run(
            c, function(_err, cur)
              if _err then error(_err.message()) end
              cur.to_array(function(err, arr)
                if err then error(err.msg) end
                error(arr)
              end)
            end
          )
        end, 'Expected function with 2 arguments but found function with 1 argument.'
      )
    end)
  end

  it('do mul', function()
    assert.same({2}, r(1).do_(function(v) return v.mul(2) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do no args', function()
    assert.has_error(
      function()
        r.do_().run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected 1 or more arguments but found 0.'
    )
  end)

  it('do no func', function()
    assert.same({1}, r.do_(1).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do no return', function()
    assert.has_error(
      function()
        r.do_(1, function() end)
      end, 'Anonymous function returned `nil`. Did you forget a `return`?'
    )
  end)

  it('do return nil', function()
    assert.has_error(
      function()
        r.do_(1, function() return nil end)
      end, 'Anonymous function returned `nil`. Did you forget a `return`?'
    )
  end)

  it('do str add num', function()
    assert.has_error(
      function()
        r('abc').do_(function(v) return v.add(3) end).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type STRING but found NUMBER.'
    )
  end)

  it('do str add str add num', function()
    assert.has_error(
      function()
        r('abc').do_(function(v) return v.add('def') end).add(3).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type STRING but found NUMBER.'
    )
  end)

  it('do str append', function()
    assert.has_error(
      function()
        r('abc').do_(function(v) return v.append(3) end).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type ARRAY but found STRING.'
    )
  end)

  it('error', function()
    assert.has_error(
      function()
        r.error_('Hello World').run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Hello World'
    )
  end)

  it('js', function()
    assert.same({2}, r.js('1 + 1').run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('js add add', function()
    assert.same({4}, r.js('1 + 1; 2 + 2').run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do js function add', function()
    assert.same({3}, r.do_(1, 2, r.js('(function(a, b) { return a + b; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do js function', function()
    assert.same({2}, r.do_(1, r.js('(function(x) { return x + 1; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)
  it('do js function add str', function()
    assert.same({'foobar'}, r.do_('foo', r.js('(function(x) { return x + "bar"; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do js no timeout', function()
    assert.same({3}, r.js('1 + 2', {timeout = 1.2}).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('js function result', function()
    assert.has_error(
      function()
        r.js('(function() { return 1; })').run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Query result must be of type DATUM, GROUPED_DATA, or STREAM (got FUNCTION).'
    )
  end)

  it('js function no wrap', function()
    assert.has_error(
      function()
        r.js('function() { return 1; }').run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'SyntaxError. Unexpected token ('
    )
  end)

  it('do js function missing arg', function()
    assert.same({1}, r.do_(1, 2, r.js('(function(a) { return a; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do js function extra arg', function()
    assert.same({1}, r.do_(1, 2, r.js('(function(a, b, c) { return a; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('do js function return undefined', function()
    assert.has_error(
      function()
        r.do_(1, 2, r.js('(function(a, b, c) { return c; })')).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Cannot convert javascript `undefined` to ql..datum_t.'
    )
  end)

  it('filter js', function()
    assert.same({{2, 3}}, r.filter({1, 2, 3}, r.js('(function(a) { return a >= 2; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('map js', function()
    assert.same({{2, 3, 4}}, r.map({1, 2, 3}, r.js('(function(a) { return a + 1; })')).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('map js constant', function()
    assert.has_error(
      function()
        r.map({1, 2, 3}, r.js('1')).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type FUNCTION but found DATUM.'
    )
  end)

  it('filter js undefined', function()
    assert.has_error(
      function()
        r.filter({1, 2, 3}, r.js('(function(a) {})')).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Cannot convert javascript `undefined` to ql..datum_t.'
    )
  end)

  it('map constant', function()
    assert.has_error(
      function()
        r.map({1, 2, 3}, 1).run(
          c, function(_err, cur)
            if _err then error(_err.message()) end
            cur.to_array(function(err, arr)
              if err then error(err.msg) end
              error(arr)
            end)
          end
        )
      end, 'Expected type FUNCTION but found DATUM.'
    )
  end)

  it('filter constant str', function()
    assert.same({{1, 2, 3}}, r.filter({1, 2, 3}, 'foo').run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('filter constant obj', function()
    assert.same({{1, 2, 3}}, r.filter({1, 2, 3}, {}).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('filter nil', function()
    assert.same({{}}, r.filter({1, 2, 3}, r()).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('filter false', function()
    assert.same({{}}, r.filter({1, 2, 3}, false).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('for each insert', function()
    assert.same({{deleted = 0, replaced = 0, unchanged = 0, errors = 0, skipped = 0, inserted = 3}}, r.for_each({1, 2, 3}, function(row) return r.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ))
  end)

  it('count for each insert', function()
    r.for_each({1, 2, 3}, function(row) return r.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    assert.same(r.table(reql_table).count().run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ), {3})
  end)

  it('for each update', function()
    r.for_each({1, 2, 3}, function(row) return r.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    assert.same(r.for_each({1, 2, 3}, function(row) return r.table(reql_table).update({foo = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ), {{deleted = 0, replaced = 9, unchanged = 0, errors = 0, skipped = 0, inserted = 0}})
  end)

  it('for each insert with duplicates', function()
    r.for_each({1, 2, 3}, function(row) return r.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    r.for_each({1, 2, 3}, function(row) return r.table(reql_table).update({foo = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    assert.same(r.for_each({1, 2, 3}, function(row) return {r.table(reql_table).insert({id = row}), r.table(reql_table).insert({id = row * 10})} end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ), {{first_error = 'Duplicate primary key `id`.\n{\n\t"foo".\t3,\n\t"id".\t1\n}\n{\n\t"id".\t1\n}', deleted = 0, replaced = 0, unchanged = 0, errors = 3, skipped = 0, inserted = 3}})
  end)

  it('for each update many', function()
    r.for_each({1, 2, 3}, function(row) return r.table(reql_table).insert({id = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    r.for_each({1, 2, 3}, function(row) return r.table(reql_table).update({foo = row}) end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    r.for_each({1, 2, 3}, function(row) return {r.table(reql_table).insert({id = row}), r.table(reql_table).insert({id = row * 10})} end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    )
    assert.same(r.for_each({1, 2, 3}, function(row) return {r.table(reql_table).update({foo = row}), r.table(reql_table).update({bar = row})} end).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        return cur.to_array(function(err, arr)
          if err then error(err.message()) end
          return arr
        end)
      end
    ), {{deleted = 0, replaced = 36, unchanged = 0, errors = 0, skipped = 0, inserted = 0}})
  end)
end)
