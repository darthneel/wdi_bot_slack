_      = require 'underscore'
fs     = require 'fs'
moment = require 'moment-timezone'

module.exports = (robot) ->
  robot.brain.data.hwData ?= {}

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
    if msg.message.user.name in instructors
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
          robot.messageRoom process.env.HUBOT_INSTRUCTOR_ROOM "Pull request for user #{pullRequest.user.login} has been closed"
        else
          msg.send "Pull request for user #{pullRequest.user.login} has been closed"

  closeAllPullRequests = (msg) ->
    getOpenPulls msg, (allPullRequests) ->
      if allPullRequests.items.length is 0
        if msg? and typeof msg not "string"
          msg.send "No open pull requests at this time"
        else
          robot.messageRoom process.env.HUBOT_INSTRUCTOR_ROOM, "Update: There are no open pull requests at this time"
      else
        _.each allPullRequests.items, (pullRequest) ->
          closePullRequest(msg, pullRequest)

  checkHW = (msg) ->
    date = hwDueDate()
    robot.brain.data.hwData[date] = []
    robot.brain.data.hwReport[date] = {}  

    console.log robot.brain.data.hwData[date]

    students = studentsHash()  

    getOpenPulls msg, (allPullRequests) ->
      _.each students, (student) ->

        payload = {
          student_id: student['id'],
          completed: ""
        }

        studentMatch = _.find(allPullRequests["items"], (pr) ->
          pr["user"]["login"] is student["github"])

        if studentMatch? then payload.completed = true else payload.completed = false

        console.log payload

        robot.brain.data.hwData[date].push payload

  robot.router.get "/hubot/hwdata", (req, res) ->
    data = JSON.stringify robot.brain.data.hwData
    res.end data


#=======================

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

  robot.respond /clear brain/i, (msg) ->
    robot.brain.data.hwData = {}