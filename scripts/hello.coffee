module.exports = (robot) ->

	robot.respond /hello tom/i, (msg) ->
		msg.send "Hello user!"