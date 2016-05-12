insulate('safety net', function()
  describe('environment #sanity', function()
    it('is sane', function()
      local socket = require('socket')
      local client = assert(socket.tcp())

      assert(client:connect('localhost', 28015))

      assert(require('rethinkdb'))
    end)
  end)
end)
