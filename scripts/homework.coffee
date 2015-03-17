# Description:
#   Commands to work with your students homework and pull requests.
#
# Commands:
#   hubot pr count - Tells you how many pull requests are currently open
#   hubot incompletes - Gives you Github names of all students with no pull requests currently open.
#   hubot close all pr - Closes all open pull requests, but does NOT save the completion data to the bots database. Useful for collecting quizzes and assessments.
#   hubot check hw - Saves completion data to bot's database but does not NOT close pull requests. Use in conjunction with the 'close all pr' count command if pull requests need to be closed.
#   hubot clear stats - Clears all completion stats saved in database. USE CAREFULLY.

_       = require 'underscore'
fs      = require 'fs'
moment  = require 'moment-timezone'
request = require 'request'
cors    = require 'cors'


#===== Cron functions

sendMorningMessage = (robot) ->
  pattern = "00 15 9 * * 1-5"
  url = "#{process.env.HEROKU_URL}/hubot/morningmessage"
  timezone = "America/New_York"
  description = "Messages room at 9:15am to remind students to submit their hw"

  robot.emit "cron created", {
    pattern: pattern,
    url: url,
    timezone: timezone,
    description: description,
    }

hwHandler = (robot) ->
  pattern = "00 30 9 * * 1-5"
  url = "#{process.env.HEROKU_URL}/hubot/handlehw"
  timezone = "America/New_York"
  description = "At 9:30am will close all pull requests and save hw to db"

  robot.emit "cron created", {
    pattern: pattern,
    url: url,
    timezone: timezone,
    description: description,
    }

#=== Starts export function

module.exports = (robot) ->
  robot.brain.data.hwData ?= {}
  robot.brain.data.completionStats ?= {}

#==== Initiate all Cron jobs once database has connected
  robot.brain.on 'loaded', () ->
    console.log "DB HAS LOADED"
    sendMorningMessage(robot)
    hwHandler(robot)
    setUpCompletionStats()

#==== Helper functions

  instructorsHash = ->
    buffer = fs.readFileSync "./lib/instructors.json"
    JSON.parse buffer.toString()

  studentsHash = ->
    buffer = fs.readFileSync "./lib/students.json"
    JSON.parse buffer.toString()

  hwDueDate = () ->
    now = moment()
    if (moment.tz now.format(), "America/New_York").day() isnt 1
      date = (now.subtract 1, 'day').format "YYYY-MM-DD"
    else
      date = (now.subtract 3, 'day').format "YYYY-MM-DD"
    return date

  validate = (msg) ->
    instructors = Object.keys instructorsHash()
    if msg.envelope.user.real_name in instructors
      return true
    else
      return false

  hwDueDate = () ->
    now = moment()
    if (moment.tz now.format(), "America/New_York").day() isnt 1
      date = (now.subtract 1, 'day').format "YYYY-MM-DD"
    else
      date = (now.subtract 3, 'day').format "YYYY-MM-DD"
    return date

  setUpCompletionStats = ->
    students = studentsHash()
    _.each students, (student) ->
      robot.brain.data.completionStats[student.id] ?= {"allHWCodes":[], "completionPercentage": null, "name": "#{student["fname"]} #{student["lname"]}"}

  getOpenPulls = (msg, cb) ->
    robot.http("https://api.github.com/search/issues?access_token=#{process.env.HUBOT_GITHUB_TOKEN}&per_page=100&q=repo:#{process.env.COURSE_REPO}+type:pull+state:open")
      .headers("User-Agent": "#{process.env.GITHUB_USER_NAME}")
      .get() (err, response, body) ->
        parsedBody = JSON.parse body
        cb parsedBody

  checkIncompletes = (msg) ->
    getOpenPulls msg, (allPullRequests) ->
      submittedGithubAccounts = _.pluck (_.pluck allPullRequests.items, 'user'), 'login'

      students = studentsHash()
      githubAccounts = _.pluck students, 'github'

      noPullRequest = _.difference githubAccounts, submittedGithubAccounts

      msg.send "Students with no open pull requests: \n #{noPullRequest.join('\n')}"

  closePullRequest = (msg, pullRequest) ->
    url = pullRequest.pull_request.url
    queryString = JSON.stringify("commit_message": "merged")
    robot.http(url + "/merge?access_token=#{process.env.HUBOT_GITHUB_TOKEN}")
      .headers("User-Agent": "#{process.env.GITHUB_USER_NAME}")
      .put(queryString) (err, response, body) ->
        throw err if err
        if typeof msg is 'string'
          messageRoom process.env.HUBOT_INSTRUCTOR_ROOM, "Pull request for user #{pullRequest.user.login} has been closed"
        else
          msg.send "Pull request for user #{pullRequest.user.login} has been closed"

  closeAllPullRequests = (msg) ->
    getOpenPulls msg, (allPullRequests) ->
      if allPullRequests.items.length is 0
        if msg && typeof msg != "string"
          msg.send "No open pull requests at this time"
        else
          messageRoom process.env.HUBOT_INSTRUCTOR_ROOM, "Update: There are no open pull requests at this time"
      else
        _.each allPullRequests.items, (pullRequest) ->
          closePullRequest(msg, pullRequest)

  checkHW = (msg) ->
    date = hwDueDate()
    robot.brain.data.hwData[date] = []

    students = studentsHash()  

    getOpenPulls msg, (allPullRequests) ->
      _.each students, (student) ->
        console.log student
        payload = {
          student_id: student.id,
          name: "#{student["fname"]} #{student["lname"]}"
          completed: ""
        }

        studentMatch = _.find(allPullRequests["items"], (pr) ->
          pr["user"]["login"] is student["github"])

        if studentMatch? then payload.completed = true else payload.completed = false

        robot.brain.data.hwData[date].push payload
        robot.brain.data.completionStats[student.id]["allHWCodes"].push payload.completed

        completionPercentage = calculateCompletionStat(robot.brain.data.completionStats[student.id])
        robot.brain.data.completionStats[student.id]["completionPercentage"] = completionPercentage

        if msg?
          msg.send "HW updated for #{student["fname"]} #{student["lname"]}"

  calculateCompletionStat = (student) ->
    completions = _.reduce student.allHWCodes, (memo, stat) -> 
      if stat then memo + 1 else memo
    , 0
    completionPercentage = (completions / student.allHWCodes.length) * 100

  messageRoom = (room, message) ->
    token = process.env.HUBOT_SLACK_TOKEN
    text = message.replace(" ", "%20")
    request "https://slack.com/api/chat.postMessage?token=#{token}&channel=#{room}&text=#{text}&as_user=true", (err, res, body) ->
      throw err if err

  #===== HTTP Routes
  
  robot.router.get "/hubot/hwdata", cors(), (req, res) ->
    data = JSON.stringify robot.brain.data.hwData
    res.end data

  robot.router.get "/hubot/morningmessage", (req, res) ->
    studentRoom = process.env.HUBOT_STUDENT_ROOM
    instructorRoom = process.env.HUBOT_INSTRUCTOR_ROOM
    now = moment()
    weekdays = [1..5]
    if (moment.tz now.format(), "America/New_York").day() in weekdays
      messageRoom studentRoom, "Reminder: Please submit yesterday's work before 9:30am"
      messageRoom instructorRoom, "Update: Students have been reminded to submit their homework before 9:30am"
      res.end "Response sent to room"
    else
      res.end "Wrong day!"

  robot.router.get "/hubot/handlehw", (req, res) ->
    studentRoom = process.env.HUBOT_STUDENT_ROOM
    instructorRoom = process.env.HUBOT_INSTRUCTOR_ROOM
    now = moment()
    weekdays = [0..5]
    if (moment.tz now.format(), "America/New_York").day() in weekdays
      checkHW()
      closeAllPullRequests "msg"
      res.end "Response sent to room"
    else
      res.end "Wrong day!"

  # robot.router.get "/hubot/handlehw", (req, res) ->
  #   studentRoom = process.env.HUBOT_STUDENT_ROOM
  #   instructorRoom = process.env.HUBOT_INSTRUCTOR_ROOM
  #   # now = moment()
  #   # weekdays = [0..5]
  #   # if (moment.tz now.format(), "America/New_York").day() in weekdays
  #   checkHW()
  #   closeAllPullRequests "msg"
  #   res.end "Response sent to room"
  #   # else
  #   #   res.end "Wrong day!"



#========== Hubot response patterns

  robot.respond /pr count/i, (msg) ->
    if validate(msg)
      getOpenPulls msg, (allPullRequests) ->
        msg.send "There are currently #{allPullRequests.items.length} open pull requests"
    else
      msg.send "Sorry, you're not allowed to do that"

  robot.respond /incompletes/i, (msg) ->
    if validate(msg)
      checkIncompletes(msg)
    else
      msg.send "Sorry, you're not allowed to do that"

  robot.respond /close all pr/i, (msg) ->
    if validate(msg)
      closeAllPullRequests(msg)
    else
      msg.send "Sorry, you're not allowed to do that"

  robot.respond /check hw/i, (msg) ->
    if validate(msg)
      checkHW(msg)
    else
      msg.send "Sorry, you're not allowed to do that"

  robot.respond /hw stats/i, (msg) ->
    unless msg.envelope.user.name is msg.envelope.room
      msg.send "'hw stats' command only works over private message"
      return
    studentMatch = _.find studentsHash(), (student) ->
      console.log "#{student["fname"]} #{student["lname"]}"
      "#{student["fname"]} #{student["lname"]}" == msg.envelope.user.real_name
    # console.log msg.envelope.user.real_name
    # console.log studentMatch
    completionStat = robot.brain.data.completionStats[studentMatch.id]["completionPercentage"]
    msg.send "You have completed #{completionStat}% of assigned homework."    

  robot.respond /clear brain/i, (msg) ->
    robot.brain.data.hwData = {}  

  robot.respond /clear stats/i, (msg) ->
    robot.brain.data.completionStats = {}

  robot.respond /hwdata/i, (msg) ->
    console.log robot.brain.data.hwData

  robot.respond /comps/i, (msg) ->
    console.log robot.brain.data.completionStats

  robot.respond /setup comps/i,(msg) ->
    setUpCompletionStats()

  robot.respond /insert/i, (msg) ->
    robot.brain.data.completionStats["100"] = {"allHWCodes":[true, true, true, false], "completionPercentage": null}

  robot.respond /comp test/i, (msg) ->
    student = robot.brain.data.completionStats["100"]
    stat = calculateCompletionStat(student)
    console.log stat
