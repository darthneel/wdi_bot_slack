# Description:
#   Allows Students to queue for help and for Instructors to pull students from the queue 
#
# Commands:
#   hubot queue me for <what they need help for> - Queues student
#   hubot student queue - Gives you the current queue
#   hubot pop student -  Removes student from queue and assigns to Instructor who popped them.


util   = require 'util'
_      = require 'underscore'
moment = require 'moment'
tfmt   = (time) -> moment(time).format 'MMM Do, h:mm:ss a'

module.exports = (robot) ->
  robot.brain.data.instructorQueue ?= []
  robot.brain.data.instructorQueuePops ?= []

  queueStudent = (name, reason) ->
    robot.brain.data.instructorQueue.push
      name: name
      queuedAt: new Date()
      reason: reason

  stringifyQueue = ->
    _.reduce robot.brain.data.instructorQueue, (reply, student) ->
      reply += "\n"
      reply += "#{student.name} at #{tfmt student.queuedAt} for #{student.reason}"
      reply
    , ""

  popStudent = ->
    robot.brain.data.instructorQueue.shift()

  robot.respond /q(ueue)? me$/i, (msg) ->
    msg.reply "usage: bot queue me for [reason]"

  robot.respond /q(ueue)? me(.+)/i, (msg) ->
    unless msg.match[2].match /^[ ]*for/i
      msg.reply "usage: bot queue me for [reason]"

  robot.respond /q(ueue)? me for (.+)/i, (msg) ->
    name = msg.envelope.user.real_name
    reason = msg.match[2]
    if _.any(robot.brain.data.instructorQueue, (student) -> student.name == name)
      msg.send "#{name} is already queued"
    else
      queueStudent name, reason
      msg.send "Current queue is: #{stringifyQueue()}"

  robot.respond /unq(ueue)? me/i, (msg) ->
    name = msg.envelope.user.real_name
    if _.any(robot.brain.data.instructorQueue, (student) -> student.name == name)
      robot.brain.data.instructorQueue = _.filter robot.brain.data.instructorQueue, (student) ->
        student.name != name
      msg.reply "ok, you're removed from the queue."
    else
      msg.reply "you weren't in the queue."

  robot.respond /(pop )?student( pop)?/i, (msg) ->
    return unless msg.match[1]? || msg.match[2]?
    instructors = ["Jeff Konowitch", "Neel Patel", "Andrew Fritz", "Sean Jackson"]
    if  msg.envelope.user.real_name in instructors
      if _.isEmpty robot.brain.data.instructorQueue
        msg.send "Student queue is empty"
      else
        student = popStudent()
        student.poppedAt = new Date()
        student.poppedBy = msg.envelope.user.real_name
        robot.brain.data.instructorQueuePops.push student
        msg.reply "Go help #{student.name} with #{student.reason}, queued at #{tfmt student.queuedAt}"
    else 
      msg.reply "Sorry, you do not have permission to do that!"

  robot.respond /student q(ueue)?/i, (msg) ->
    if _.isEmpty robot.brain.data.instructorQueue
      msg.send "Student queue is empty"
    else
      msg.send stringifyQueue()

  robot.respond /empty q(ueue)?/i, (msg) ->
    instructors = ["Jeff Konowitch", "Neel Patel", "Andrew Fritz", "Sean Jackson"]
    if instructors.indexOf(msg.envelope.user.real_name) != -1
      robot.brain.data.instructorQueue = []
      msg.reply "cleared the queue"
    else
      msg.reply "Sorry, you aren't allowed to do that"

  robot.respond /q(ueue)?[ .]length/i, (msg) ->
    _.tap robot.brain.data.instructorQueue.length, (length) ->
      msg.send "Current queue length is #{length} students."

  robot.router.get "/queue/pops", (req, res) ->
    res.setHeader 'Content-Type', 'text/html'
    _.each robot.brain.data.instructorQueuePops, (student) ->
      res.write "#{student.name} queued for #{student.reason} at #{tfmt student.queuedAt} popped at #{tfmt student.poppedAt} by #{student.poppedBy || 'nobody'}<br/>"
    res.end()
