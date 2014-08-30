err = require('./errors')
util = require('./util')

protoResponseType = require('./proto-def').ResponseType
EventEmitter = require('events').EventEmitter

-- Import some names to this namespace for convenience
ar = util.ar
varar = util.varar
aropt = util.aropt
mkErr = util.mkErr

-- setImmediate is not defined in some browsers (including Chrome)
if not setImmediate
    setImmediate = (cb) ->
        setTimeout cb, 0

class IterableResult
    stackSize: 100

    new: (conn, token, opts, root) ->
        @_conn = conn
        @_token = token
        @_opts = opts
        @_root = root -- current query

        @_responses = {}
        @_responseIndex = 0
        @_outstandingRequests = 1 -- Because we haven't add the response yet
        @_iterations = 0
        @_endFlag = false
        @_contFlag = false
        @_closeAsap = false
        @_cont = nil
        @_cbQueue = {}

        @next = @_next
        @each = @_each

    _addResponse: (response) ->
        if response.t == @_type or response.t == protoResponseType.SUCCESS_SEQUENCE
            -- We push a "ok" response only if it's not empty
            if response.r.length > 0
                @_responses.push response
        else
            @_responses.push response


        @_outstandingRequests -= 1
        if response.t != @_type
            -- We got an error or a SUCCESS_SEQUENCE
            @_endFlag = true

            if @_closeCb
                switch response.t
                    when protoResponseType.COMPILE_ERROR
                        @_closeCb mkErr(err.RqlRuntimeError, response, @_root)
                    when protoResponseType.CLIENT_ERROR
                        @_closeCb mkErr(err.RqlRuntimeError, response, @_root)
                    when protoResponseType.RUNTIME_ERROR
                        @_closeCb mkErr(err.RqlRuntimeError, response, @_root)
                    else
                        @_closeCb()

        @_contFlag = false
        if @_closeAsap == false
            @_promptNext()
        else
            @close @_closeCb
        @

    _getCallback: ->
        @_iterations += 1
        cb = @_cbQueue.shift()

        if @_iterations % @stackSize == @stackSize - 1
            immediateCb = ((err, row) -> setImmediate -> cb(err, row))
            return immediateCb
        else
            return cb

    _handleRow: ->
        response = @_responses[0]
        row = util.recursivelyConvertPseudotype(response.r[@_responseIndex], @_opts)
        cb = @_getCallback()

        @_responseIndex += 1

        -- If we're done with this response, discard it
        if @_responseIndex == response.r.length
            @_responses.shift()
            @_responseIndex = 0

        cb nil, row

    bufferEmpty: ->
        @_responses.length == 0 or @_responses[0].r.length <= @_responseIndex

    _promptNext: ->
        -- If there are no more waiting callbacks, just wait until the next event
        while @_cbQueue[0]
            if @bufferEmpty() == true
                -- We prefetch things here, set `is 0` to avoid prefectch
                if @_endFlag == true
                    cb = @_getCallback()
                    cb err.RqlDriverError "No more rows in the cursor."
                else if @_responses.length <= 1
                    @_promptCont()

                return
            else

                -- Try to get a row out of the responses
                response = @_responses[0]

                if @_responses.length == 1
                    -- We're low on data, prebuffer
                    @_promptCont()

                -- Error responses are not discarded, and the error will be sent to all future callbacks
                switch response.t
                    when protoResponseType.SUCCESS_PARTIAL
                        @_handleRow()
                    when protoResponseType.SUCCESS_FEED
                        @_handleRow()
                    when protoResponseType.SUCCESS_SEQUENCE
                        if response.r.length == 0
                            @_responses.shift()
                        else
                            @_handleRow()
                    when protoResponseType.COMPILE_ERROR
                        @_responses.shift()
                        cb = @_getCallback()
                        cb mkErr(err.RqlCompileError, response, @_root)
                    when protoResponseType.CLIENT_ERROR
                        @_responses.shift()
                        cb = @_getCallback()
                        cb mkErr(err.RqlClientError, response, @_root)
                    when protoResponseType.RUNTIME_ERROR
                        @_responses.shift()
                        cb = @_getCallback()
                        cb mkErr(err.RqlRuntimeError, response, @_root)
                    else
                        @_responses.shift()
                        cb = @_getCallback()
                        cb err.RqlDriverError "Unknown response type for cursor"

    _promptCont: ->
        -- Let's ask the server for more data if we haven't already
        unless (@_contFlag or @_endFlag)
            @_contFlag = true
            @_outstandingRequests += 1
            @_conn._continueQuery(@_token)


    -- Implement IterableResult
    hasNext: ->
        error(err.RqlDriverError "The `hasNext` command has been removed since 1.13. Use `next` instead.")

    _next: varar 0, 1, (cb) ->
        fn = (cb) =>
            @_cbQueue.push cb
            @_promptNext()

        fn(cb)


    close: varar 0, 1, (cb) ->
        if @_endFlag == true
            cb()
        else
            @_closeCb = cb

            if @_outstandingRequests > 0
                @_closeAsap = true
            else
                @_outstandingRequests += 1
                @_conn._endQuery(@_token)


    _each: varar 1, 2, (cb, onFinished) ->
        unless type(cb) == 'function'
            error(err.RqlDriverError "First argument to each must be a function.")
        if onFinished and type(onFinished) != 'function'
            error(err.RqlDriverError "Optional second argument to each must be a function.")

        stopFlag = false
        self = @
        nextCb = (err, data) =>
            if stopFlag != true
                if err
                    if err.message == 'No more rows in the cursor.'
                        if onFinished
                            onFinished()
                    else
                        cb(err)
                else
                    stopFlag = cb(nil, data) == false
                    @_next nextCb
            else if onFinished
                onFinished()
        @_next nextCb

    toArray: varar 0, 1, (cb) ->
        fn = (cb) =>
            arr = {}
            eachCb = (err, row) =>
                if err
                    cb err
                else
                    arr.push(row)

            onFinish = (err, ar) =>
                cb nil, arr

            @each eachCb, onFinish

        fn(cb)

    _makeEmitter: ->
        @emitter = EventEmitter
        @each = ->
            error(err.RqlDriverError "You cannot use the cursor interface and the EventEmitter interface at the same time.")
        @next = ->
            error(err.RqlDriverError "You cannot use the cursor interface and the EventEmitter interface at the same time.")


    addListener: (...) ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.addListener(unpack arg)

    on: (...) ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.on(unpack arg)


    once: ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.once()

    removeListener: ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.removeListener()

    removeAllListeners: ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.removeAllListeners()

    setMaxListeners: ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.setMaxListeners()

    listeners: ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.listeners()

    emit: ->
        if not @emitter
            @_makeEmitter()
            setImmediate => @_each @_eachCb
        @emitter.emit()

    _eachCb: (err, data) =>
        if err
            @emitter.emit('error', err)
        else
            @emitter.emit('data', data)



class Cursor extends IterableResult
    new: ->
        @_type = protoResponseType.SUCCESS_PARTIAL
        super

    toString: ar () -> "[object Cursor]"

class Feed extends IterableResult
    new: ->
        @_type = protoResponseType.SUCCESS_FEED
        super

    hasNext: ->
        error(err.RqlDriverError "`hasNext` is not available for feeds.")
    toArray: ->
        error(err.RqlDriverError "`toArray` is not available for feeds.")

    toString: ar () -> "[object Feed]"


-- Used to wrap array results so they support the same iterable result
-- API as cursors.

class ArrayResult extends IterableResult
    -- We store @__index as soon as the user starts using the cursor interface
    _hasNext: ar () ->
        if not @__index
            @__index = 0
        @__index < @length

    _next: varar 0, 1, (cb) ->
        fn = (cb) =>
            if @_hasNext() == true
                self = @
                if self.__index%@stackSize == @stackSize-1
                    -- Reset the stack
                    setImmediate ->
                        cb(nil, self[self.__index])
                        self.__index += 1
                else
                    cb(nil, self[self.__index])
                    self.__index += 1
            else
                cb err.RqlDriverError "No more rows in the cursor."

        fn(cb)


    toArray: varar 0, 1, (cb) ->
        fn = (cb) =>
            -- IterableResult.toArray would create a copy
            if @__index
                cb(nil, @.slice(@__index, @.length))
            else
                cb(nil, @)

        fn(cb)


    close: ->
        return @

    makeIterable: (response) ->
        response.__proto__ = {}
        for name, method of ArrayResult.prototype
            if name != 'constructor'
                if name == '_each'
                    response.__proto__['each'] = method
                    response.__proto__['_each'] = method
                else if name == '_next'
                    response.__proto__['next'] = method
                    response.__proto__['_next'] = method
                else
                    response.__proto__[name] = method

        response.__proto__.__proto__ = [].__proto__
        response

{Cursor: Cursor,
Feed: Feed,
makeIterable: ArrayResult.makeIterable}
