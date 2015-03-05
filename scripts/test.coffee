module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		console.log Object.keys(msg) 
		# console.log msg.message
		# console.log msg.user
		# console.log msg.message.real_name
		msg.send Object.keys(msg)
	
	