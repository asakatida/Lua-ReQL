insulate('safety net', function()
  describe('environment #sanity', function()
    it('is sane', function()
      local socket = require('socket')
      local client = assert.is_not_nil(socket.tcp())

      finally(function() client:close() end)

      assert.is_not_nil(client:connect('localhost', 28015))

      assert.are_equal(12, client:send'\0\0\0\0\0\0\0\0\0\0\0\0')

      assert.are_equal(
        'ERROR: Received an unsupported protocol version. This port is for ' ..
        'RethinkDB queries. Does your client driver version not match the ' ..
        'server?\n\0',
        client:receive'*a')

      assert.is_not_nil(require('rethinkdb'))
    end)
  end)
end)
