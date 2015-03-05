fs = require 'fs'

module.exports = (robot) ->

	robot.respond /quote yo self/i, (msg) ->
		buffer = fs.readFileSync "./lib/quotes.json"
		quotesArr = JSON.parse buffer.toString()
		msg.send msg.random quotesArr
