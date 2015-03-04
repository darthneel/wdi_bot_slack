fs    = require 'fs'

module.exports = (robot) ->

	randomFromArray = (arr) ->
		el = arr[Math.floor(Math.random()*arr.length)]
		return el

	robot.respond /quote yourself/i, (msg) ->
		buffer = fs.readFileSync "./lib/quotes.json"
		arr = JSON.parse buffer.toString()
		quote = randomFromArray arr
		msg.send quote
