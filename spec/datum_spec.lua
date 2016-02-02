local r = require('rethinkdb')

describe('datum', function()
  local reql_db, reql_table, c

  reql_table = 'datum'

  setup(function()
    reql_db = 'roundtrip'

    local err

    c, err = r.connect()
    if err then error(err.message) end

    r.db_create(reql_db):run(c)
    c:use(reql_db)
    r.table_create(reql_table):run(c)
  end)

  after_each(function()
    r.table(reql_table):delete():run(c)
  end)

  function test(name, query, res)
    it(name, function()
      assert.same(res, query:run(
        c, function(err, cur)
          if err then error(err.message) end
          return cur:to_array(function(err, arr)
            if err then error(err.message) end
            return arr
          end)
        end
      ))
    end)
  end

  function test_error(name, query, res)
    it(name, function()
      assert.has_error(
        function()
          query:run(
            c, function(err, cur)
              if err then error(err.message) end
              cur:to_array(function(err, arr)
                if err then error(err.msg) end
                error(arr)
              end)
            end
          )
        end, res
      )
    end)
  end

  test('false', r(false), {false})
  test('true', r(true), {true})
  test('nil', r(nil), {nil})
  test('string', r("not yap wa' Hol"), {"not yap wa' Hol"})
  test('0', r(0), {0})
  test('1', r(1), {1})
  test('-1', r(-1), {-1})
  test('τ', r(6.28), {6.28})
  test('𝑒', r(2.2), {2.2})
  test('α', r(0.00001), {0.00001})
  test('array', r({1 = 1, 2 = 2}), {{1 = 1, 2 = 2}})
  test('table', r({first = 1, second = 2}), {{first = 1, second = 2}})
end)
