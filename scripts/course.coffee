# Description:
#   General course functions
#
# Commands:
#   hubot course set students - makes call to WDI app and writes students hash to 'lib/students.json'

fs      = require 'fs'
_       = require 'underscore'
request = require 'request'

module.exports = (robot) ->

  robot.brain.on 'loaded', () ->
    setStudents()
    setInstructors()

  setStudents = (msg) ->
    url = process.env.STUDENT_GIST_URL
    request url, (err, res, body) ->
      fs.writeFile "./lib/students.json", body, (err) ->
        throw err if err
        if msg
          msg.send "Students have been set"
        else
          console.log "Students set upon server restart"

  setInstructors = (msg) ->
    url = process.env.INSTRUCTOR_GIST_URL
    request url, (err, res, body) ->
      fs.writeFile "./lib/instructors.json", body, (err) ->
        throw err if err
        if msg
          msg.send "Instructors have been set"
        else
          console.log "Instructors set upon server restart"

  robot.respond /set students/i, (msg) ->
    setStudents(msg)

  robot.respond /set instructors/i, (msg) ->
    setInstructors(msg)

  robot.respond /get students array/i, (msg) ->
    buffer = fs.readFileSync "./lib/students.json"
    array = buffer.toString()
    msg.send "```" + array + "```"

  robot.respond /get instructors hash/i, (msg) ->
    buffer = fs.readFileSync "./lib/instructors.json"
    hash = buffer.toString()
    msg.send "```" + hash + "```"