module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		console.log msg.message.name
	
	