module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		console.log Object.keys msg.envelope.user
		console.log msg.envelope.user.real_name
		# console.log msg.message
		# console.log msg.user
		# console.log msg.message.real_name
		msg.send "hey"
	
	