module.exports = (robot) ->

	robot.respond /name/i, (msg) ->
		console.log msg
		# slack user info
		console.log Object.keys msg.envelope.user
		# native hubot user info
		console.log msg.envelope.user.name
		
		name = msg.envelope.user.real_name
		msg.send name
	
# 	2015-03-07T17:54:19.662756+00:00 app[web.1]:   envelope: 
# 2015-03-07T17:54:19.662757+00:00 app[web.1]:    { room: 'darthneel',
# 2015-03-07T17:54:19.662759+00:00 app[web.1]:      user: 
# 2015-03-07T17:54:19.662760+00:00 app[web.1]:       { id: 'U03SQDJAB',
# 2015-03-07T17:54:19.662761+00:00 app[web.1]:         name: 'darthneel',
# 2015-03-07T17:54:19.662763+00:00 app[web.1]:         real_name: 'Neel Patel',
# 2015-03-07T17:54:19.662764+00:00 app[web.1]:         email_address: 'neel.patel@generalassemb.ly',
# 2015-03-07T17:54:19.662766+00:00 app[web.1]:         room: 'darthneel' },