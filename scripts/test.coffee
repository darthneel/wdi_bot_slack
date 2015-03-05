module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		console.log msg.message.real_name
		msg.send msg.message.real_name
	
	