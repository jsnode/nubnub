assert = require 'assert'
http   = require 'http'
url    = require 'url'
query  = require 'querystring'
nub    = require '../src'
Crypto = require 'crypto'

port   = 9999
server = http.createServer (req, resp) ->
  body    = ''
  req.on 'data', (chunk) -> body += chunk

  req.on 'end', ->
    req_url = url.parse req.url, true

    switch req_url.query.testing
      when 'json'
        assert.equal "[{\"abc\":1}]", body
        resp.writeHead 200
        resp.end "ok"
      when 'error'
        resp.writeHead 500
        resp.end()
      when 'secret'
        sig = req.headers['x-hub-signature']
        hmac = Crypto.createHmac 'sha1', 'monkey'
        hmac.update body
        st = if sig == hmac.digest('hex') then 200 else 400
        resp.writeHead st
        resp.end()

req = 
  'hub.callback':      'http://localhost:9999?testing=json'
  'hub.mode':          'subscribe'
  'hub.topic':         'http://server.com/foo'
  'hub.verify':        'sync'
  'hub.lease_seconds': '1000'
sub = nub.subscribe(query.stringify(req))

server.listen(port)

calls = 2

# successful publishing
sub.publish [{abc: 1}], {format: 'json'}, (err, resp) ->
  assert.equal null, err
  done()

# errored
sub.callback = sub.callback.replace(/json/, 'error')
sub.publish [{abc: 1}], {format: 'json'}, (err, resp) ->
  assert.equal 'bad status', err.error
  done()

# successful with secret
sub.callback = sub.callback.replace(/error/, 'secret')
sub.secret   = 'monkey'
sub.publish [{abc: 1}], {format: 'json'}, (err, resp) ->
  assert.equal null, err
  done()

# errored with secret
sub.secret   = 'dog'
sub.publish [{abc: 1}], {format: 'json'}, (err, resp) ->
  assert.equal 'bad status', err.error
  done()

done = ->
  calls -= 1
  if calls == 0
    server.close()

process.on 'exit', -> console.log 'done'