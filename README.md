# Lua-ReQL

Rethinkdb driver in Lua
[![Build Status](https://travis-ci.org/grandquista/Lua-ReQL.svg?branch=master)](https://travis-ci.org/grandquista/Lua-ReQL)
[![Coverage Status](https://coveralls.io/repos/github/grandquista/Lua-ReQL/badge.svg?branch=master)](https://coveralls.io/github/grandquista/Lua-ReQL?branch=master)

## Installing
- _IF USING LUA 5.1_ `luarocks install luabitop`
- `luarocks install lua-reql`

See [Wiki](https://github.com/grandquista/Lua-ReQL/wiki) for documentation.

## Dev Dependencies
- Lua >= 5.1
- Luarocks
  - busted
  - luacheck
  - luacov
  - _IF USING LUA 5.1_ luabitop
- RethinkDB

## Testing
- `luacheck .`
- `busted -c`
- `luacov`

## Installing from source
- `luarocks make`
