insulate('safety net', function()
  describe('environment #sanity', function()
    it('is sane', function()
      local socket = require('socket')
      local client = assert.is_not_nil(socket.tcp())

      finally(function() client:close() end)

      assert.is_not_nil(client:connect('localhost', 28015))

      local idx = assert.is_not_nil(client:send'\0\0\0\0\0\0\0\0\0\0\0\0')

      assert.are_equal(idx, 12)

      local message = assert.is_not_nil(client:receive('*a'))

      assert.are_equal(
        message,
        'ERROR: Received an unsupported protocol version. This port is for ' ..
        'RethinkDB queries. Does your client driver version not match the ' ..
        'server?\n\0')

      assert.is_not_nil(require('rethinkdb'))
    end)
  end)
end)
