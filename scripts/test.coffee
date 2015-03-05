module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		console.log msg.envelope.message.real_name
		# console.log msg.message
		# console.log msg.user
		# console.log msg.message.real_name
		msg.send "hey"
	
	