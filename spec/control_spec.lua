local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('control', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    function r.run(query)
      return query.run(query.r.c, function(err, cur)
        return cur, err
      end)
    end

    r.reql_db = r.reql.db'control'
    r.reql_table = r.reql.table'func'

    local err

    r.c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.run(r.reql.db_create'control')
    r.c.use'control'
    r.run(r.reql.table_create'func')
  end)

  teardown(function()
    r.run(r.reql_table.delete())
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('branch db', function()
    local cur, _err = r.run(r.reql_db.branch(1, 2))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('branch error', function()
    local cur, _err = r.run(r.reql.branch(r.reql.error_'a', 1, 2))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('branch false', function()
    local cur, _err = r.run(r.reql.branch(false, 1, 2))
    assert.is_nil(_err)
    assert.same({2}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('branch nil', function()
    local cur, _err = r.run(r.reql().branch(1, 2))
    assert.is_nil(_err)
    assert.same({2}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('branch num', function()
    local cur, _err = r.run(r.reql.branch(1, 'c', false))
    assert.is_nil(_err)
    assert.same({'c'}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('branch table', function()
    local cur, _err = r.run(r.reql_table.branch(1, 2))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('branch true', function()
    local cur, _err = r.run(r.reql.branch(true, 1, 2))
    assert.is_nil(_err)
    assert.same({1}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do', function()
    local cur, _err = r.run(r.reql.do_(function() return 1 end))
    assert.is_nil(_err)
    assert.same({1}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do add', function()
    local cur, _err = r.run(r.reql.do_(1, 2, function(x, y) return x.add(y) end))
    assert.is_nil(_err)
    assert.same({3}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do append', function()
    local cur, _err = r.run(r.reql{0, 1, 2}.do_(function(v) return v.append(3) end))
    assert.is_nil(_err)
    assert.same({{0, 1, 2, 3}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  if string.match(_VERSION, '5.[23]') then
    it('do extra arg', function()
      local cur, _err = r.run(r.reql.do_(1, function(x, y) return x + y end))
      assert.is_nil(_err)
      cur.to_array(function(err, arr)
        assert.is_nil(arr)
        assert.is_not_nil(err)
      end)
    end)

    it('do missing arg', function()
      local cur, _err = r.run(r.reql.do_(1, 2, function(x) return x end))
      assert.is_nil(_err)
      cur.to_array(function(err, arr)
        assert.is_nil(arr)
        assert.is_not_nil(err)
      end)
    end)
  end

  it('do mul', function()
    local cur, _err = r.run(r.reql(1).do_(function(v) return v.mul(2) end))
    assert.is_nil(_err)
    assert.same({2}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do no args', function()
    local cur, _err = r.run(r.reql.do_())
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('do no func', function()
    local cur, _err = r.run(r.reql.do_(1))
    assert.is_nil(_err)
    assert.same({1}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do no return', function()
    local cur, _err = r.run(r.reql.do_(1, function() end))
    assert.is_nil(_err)
    assert.is_not_nil(cur)
  end)

  it('do return nil', function()
    local cur, _err = r.run(r.reql.do_(1, function() return nil end))
    assert.is_nil(_err)
    assert.is_not_nil(cur)
  end)

  it('do str add num', function()
    local cur, _err = r.run(r.reql'abc'.do_(function(v) return v.add(3) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('do str add str add num', function()
    local cur, _err = r.run(r.reql'abc'.do_(function(v) return v.add'def' end).add(3))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('do str append', function()
    local cur, _err = r.run(r.reql'abc'.do_(function(v) return v.append(3) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('error', function()
    local cur, _err = r.run(r.reql.error_'Hello World')
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('js', function()
    local cur, _err = r.run(r.reql.js'1 + 1')
    assert.is_nil(_err)
    assert.same({2}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('js add add', function()
    local cur, _err = r.run(r.reql.js'1 + 1; 2 + 2')
    assert.is_nil(_err)
    assert.same({4}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do js function add', function()
    local cur, _err = r.run(r.reql.do_(1, 2, r.reql.js'(function(a, b) { return a + b; })'))
    assert.is_nil(_err)
    assert.same({3}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do js function', function()
    local cur, _err = r.run(r.reql.do_(1, r.reql.js'(function(x) { return x + 1; })'))
    assert.is_nil(_err)
    assert.same({2}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)
  it('do js function add str', function()
    local cur, _err = r.run(r.reql.do_('foo', r.reql.js'(function(x) { return x + "bar"; })'))
    assert.is_nil(_err)
    assert.same({'foobar'}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do js no timeout', function()
    local cur, _err = r.run(r.reql.js('1 + 2', {timeout = 1.2}))
    assert.is_nil(_err)
    assert.same({3}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('js function result', function()
    local cur, _err = r.run(r.reql.js'(function() { return 1; })')
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('js function no wrap', function()
    local cur, _err = r.run(r.reql.js'function() { return 1; }')
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('do js function missing arg', function()
    local cur, _err = r.run(r.reql.do_(1, 2, r.reql.js'(function(a) { return a; })'))
    assert.is_nil(_err)
    assert.same({1}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do js function extra arg', function()
    local cur, _err = r.run(r.reql.do_(1, 2, r.reql.js'(function(a, b, c) { return a; })'))
    assert.is_nil(_err)
    assert.same({1}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('do js function return undefined', function()
    local cur, _err = r.run(r.reql.do_(1, 2, r.reql.js'(function(a, b, c) { return c; })'))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('filter js', function()
    local cur, _err = r.run(r.reql.filter({1, 2, 3}, r.reql.js'(function(a) { return a >= 2; })'))
    assert.is_nil(_err)
    assert.same({{2, 3}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('map js', function()
    local cur, _err = r.run(r.reql.map({1, 2, 3}, r.reql.js'(function(a) { return a + 1; })'))
    assert.is_nil(_err)
    assert.same({{2, 3, 4}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('map js constant', function()
    local cur, _err = r.run(r.reql.map({1, 2, 3}, r.reql.js'1'))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('filter js undefined', function()
    local cur, _err = r.run(r.reql.filter({1, 2, 3}, r.reql.js'(function(a) {})'))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('map constant', function()
    local cur, _err = r.run(r.reql.map({1, 2, 3}, 1))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(arr)
      assert.is_not_nil(err)
    end)
  end)

  it('filter constant str', function()
    local cur, _err = r.run(r.reql.filter({1, 2, 3}, 'foo'))
    assert.is_nil(_err)
    assert.same({{1, 2, 3}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('filter constant obj', function()
    local cur, _err = r.run(r.reql.filter({1, 2, 3}, {}))
    assert.is_nil(_err)
    assert.same({{1, 2, 3}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('filter nil', function()
    local cur, _err = r.run(r.reql.filter({1, 2, 3}, r.reql()))
    assert.is_nil(_err)
    assert.same({{}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('filter false', function()
    local cur, _err = r.run(r.reql.filter({1, 2, 3}, false))
    assert.is_nil(_err)
    assert.same({{}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('for each insert', function()
    local cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.insert({id = row}) end))
    assert.is_nil(_err)
    assert.same({{deleted = 0, replaced = 0, unchanged = 0, errors = 0, skipped = 0, inserted = 3}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('count for each insert', function()
    local cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.insert({id = row}) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql_table.count())
    assert.is_nil(_err)
    assert.same({3}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('for each update', function()
    local cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.insert({id = row}) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.update({foo = row}) end))
    assert.is_nil(_err)
    assert.same({{deleted = 0, replaced = 9, unchanged = 0, errors = 0, skipped = 0, inserted = 0}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('for each insert with duplicates', function()
    local cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.insert({id = row}) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.update({foo = row}) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return {r.reql_table.insert({id = row}), r.reql_table.insert({id = row * 10})} end))
    assert.is_nil(_err)
    assert.same({{first_error = 'Duplicate primary key `id`.\n{\n\t"foo".\t3,\n\t"id".\t1\n}\n{\n\t"id".\t1\n}', deleted = 0, replaced = 0, unchanged = 0, errors = 3, skipped = 0, inserted = 3}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)

  it('for each update many', function()
    local cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.insert({id = row}) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.update({foo = row}) end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return {r.reql_table.insert({id = row}), r.reql_table.insert({id = row * 10})} end))
    assert.is_nil(_err)
    cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end)
    cur, _err = r.run(r.reql.for_each({1, 2, 3}, function(row) return r.reql_table.update({foo = row}) end))
    assert.is_nil(_err)
    assert.same({{deleted = 0, replaced = 36, unchanged = 0, errors = 0, skipped = 0, inserted = 0}}, cur.to_array(function(err, arr)
      assert.is_nil(err)
      return arr
    end))
  end)
end)
