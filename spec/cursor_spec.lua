local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('cursor', function()
  local r, reql_db, reql_table, c, num_rows

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    reql_db = 'cursor'
    reql_table = 'tests'

    local err

    c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.reql.db_create(reql_db).run(c)
    c.use(reql_db)
    r.reql.table_create(reql_table).run(c)
  end)

  before_each(function()
    num_rows = math.random(1111, 2222)

    local doc = {}
    for i=0, 500, 1 do
      table.insert(doc, i)
    end
    local document = {}
    for _=0, num_rows, 1 do
      table.insert(document, doc)
    end

    r.reql.table(reql_table).insert(document).run(c)
  end)

  teardown(function()
    r.reql.table(reql_table).delete().run(c)
    c.close()
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('type', function()
    assert.are.equal(
      'cursor',
      r.reql.table(reql_table).run(
        c, function(err, cur)
          assert.is_nil(err)
          return r.type(cur)
        end
      )
    )
  end)

  it('count', function()
    assert.are.equal(
      num_rows,
      r.reql.table(reql_table).run(
        c, function(_err, cur)
          assert.is_nil(_err)
          return cur.to_array(function(err, arr)
            assert.is_nil(err)
            return #arr
          end)
        end
      )
    )
  end)

  it('close', function()
    assert.has_no.errors(function()
      r.reql.table(reql_table).run(
        c, function(_err, cur)
          assert.is_nil(_err)
          cur.close(function(err) assert.is_nil(err) end)
        end
      )
    end)
  end)
end)
