module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		# slack user info
		console.log Object.keys msg.envelope.user
		# native hubot user info
		console.log msg.envelope.user.name
		
		name = msg.envelope.user.real_name
		msg.send name
	
	