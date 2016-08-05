--- Copyright (c) 2016 IETF Trust and the persons identified as authors of the
-- code. All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, is permitted pursuant to, and subject to the license terms
-- contained in, the Simplified BSD License set forth in Section 4.c of the IETF
-- Trust’s Legal Provisions Relating to IETF Documents
-- (http://trustee.ietf.org/license-info).


local binstring = require('luassert.formatters.binarystring')

describe('pbkdf', function()
  local pbkdf

  setup(function()
    assert:add_formatter(binstring)
    pbkdf = require('rethinkdb.internal.pbkdf')
  end)

  teardown(function()
    pbkdf = nil
    assert:remove_formatter(binstring)
  end)

  it('test 1', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 1
    local dkLen = 20
    local DK = pbkdf('sha1', password, salt, iteration, dkLen)
    assert.are_same(dkLen, string.len(DK))
    assert.are_same('\x0c\x60\xc8\x0f\x96\x1f\x0e\x71\xf3\xa9\xb5\x24\xaf\x60\x12\x06\x2f\xe0\x37\xa6', DK)
  end)

  it('test 2', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 2
    local dkLen = 20
    local DK = pbkdf('sha1', password, salt, iteration, dkLen)
    assert.are_same(dkLen, string.len(DK))
    assert.are_same('\xea\x6c\x01\x4d\xc7\x2d\x6f\x8c\xcd\x1e\xd9\x2a\xce\x1d\x41\xf0\xd8\xde\x89\x57', DK)
  end)

  it('test 3', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 4096
    local dkLen = 20
    local DK = pbkdf('sha1', password, salt, iteration, dkLen)
    assert.are_same(dkLen, string.len(DK))
    assert.are_same('\x4b\x00\x79\x01\xb7\x65\x48\x9a\xbe\xad\x49\xd9\x26\xf7\x21\xd0\x65\xa4\x29\xc1', DK)
  end)

  it('test 4 #expensive', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 16777216
    local dkLen = 20
    local DK = pbkdf('sha1', password, salt, iteration, dkLen)
    assert.are_same(dkLen, string.len(DK))
    assert.are_same('\xee\xfe\x3d\x61\xcd\x4d\xa4\xe4\xe9\x94\x5b\x3d\x6b\xa2\x15\x8c\x26\x34\xe9\x84', DK)
  end)

  it('test 5', function()
    local password = 'passwordPASSWORDpassword'
    local salt = 'saltSALTsaltSALTsaltSALTsaltSALTsalt'
    local iteration = 4096
    local dkLen = 25
    local DK = pbkdf('sha1', password, salt, iteration, dkLen)
    assert.are_same(dkLen, string.len(DK))
    assert.are_same('\x3d\x2e\xec\x4f\xe4\x1c\x84\x9b\x80\xc8\xd8\x36\x62\xc0\xe4\x4a\x8b\x29\x1a\x96\x4c\xf2\xf0\x70\x38', DK)
  end)

  it('test 6', function()
    local password = 'pass\0word'
    local salt = 'sa\0lt'
    local iteration = 4096
    local dkLen = 16
    local DK = pbkdf('sha1', password, salt, iteration, dkLen)
    assert.are_same(dkLen, string.len(DK))
    assert.are_same('\x56\xfa\x6a\xa7\x55\x48\x09\x9d\xcc\x37\xd7\xf0\x34\x25\xe0\xc3', DK)
  end)
end)
