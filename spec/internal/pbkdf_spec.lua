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
    assert.are_same(
      '\12\96\200\15\150\31\14\113\243\169\181\36\175\96\18\6\47\224\55\166',
      pbkdf('sha1', password, salt, iteration, dkLen)
    )
  end)

  it('test 2', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 2
    local dkLen = 20
    assert.are_same(
      '\234\108\1\77\199\45\111\140\205\30\217\42\206\29\65\240\216\222\137\87',
      pbkdf('sha1', password, salt, iteration, dkLen)
    )
  end)

  it('test 3', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 4096
    local dkLen = 20
    assert.are_same(
      '\75\0\121\1\183\101\72\154\190\173\73\217\38\247\33\208\101\164\41\193',
      pbkdf('sha1', password, salt, iteration, dkLen)
    )
  end)

  it('test 4 #expensive', function()
    local password = 'password'
    local salt = 'salt'
    local iteration = 16777216
    local dkLen = 20
    assert.are_same(
      '\238\254\61\97\205\77\164\228\233\148\91\61\107\162\21\140\38\52\233\132',
      pbkdf('sha1', password, salt, iteration, dkLen)
    )
  end)

  it('test 5', function()
    local password = 'passwordPASSWORDpassword'
    local salt = 'saltSALTsaltSALTsaltSALTsaltSALTsalt'
    local iteration = 4096
    local dkLen = 25
    assert.are_same(
      '\61\46\236\79\228\28\132\155\128\200\216\54\98\192\228\74\139\41\26\150\76\242\240\112\56',
      pbkdf('sha1', password, salt, iteration, dkLen)
    )
  end)

  it('test 6', function()
    local password = 'pass\0word'
    local salt = 'sa\0lt'
    local iteration = 4096
    local dkLen = 16
    assert.are_same(
      '\86\250\106\167\85\72\9\157\204\55\215\240\52\37\224\195',
      pbkdf('sha1', password, salt, iteration, dkLen)
    )
  end)
end)
