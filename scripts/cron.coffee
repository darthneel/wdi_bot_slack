# Description:
#   Allows for the creation and maintence of Cron jobs.
#
# Commands:


CronJob = require("cron").CronJob
_       = require 'underscore'
request = require 'request'

JOBS = {}

module.exports = (robot) ->
  robot.brain.data.cronJobs ?= {}

  robot.on "cron created", (cron) ->
    result = _.where(robot.brain.data.cronJobs, {pattern: cron.pattern, url: cron.url, timezone: cron.timezone, description: cron.description})
    # === Ensures job is not already in database
    # console.log result
    unless result[0]?
      job = new Job cron.pattern, cron.url, cron.timezone, cron.description
      job.createCron()
      job.startJob()
      save job
      JOBS[job.id] = job

  robot.brain.on 'loaded', () ->
    _.each robot.brain.data.cronJobs, (job, id) ->

      job = new Job job["pattern"], job["url"], job["timezone"], job["description"], job["running"]
      job.id = id
      job.createCron()
      if job.running is true
        job.startJob()
      JOBS[job.id.toString()] = job

  save = (obj) ->
    robot.brain.data.cronJobs[obj.id] = {pattern: obj.pattern, url: obj.url, timezone: obj.timezone, description: obj.description, running: obj.running}

  #===== Functions being called in robot.respond callbacks ======
  allJobs = ->
    console.log robot.brain.data.cronJobs

  stringifyJobs = ->
    list = robot.brain.data.cronJobs
    _.reduce list, (reply, job, id) ->
      reply += "\n"
      reply += "\n Job Number: #{id} - #{job.description}. Currently Running: #{job.running}"
      reply
    , ""

  # ===== Response patterns =====

  robot.respond /k(ill)? job (\d{7})/i, (msg) ->
    jobNumber =  msg.match[2]
    job = JOBS[jobNumber]
    if job? and job.running is true
      job.stopJob()
      robot.brain.data.cronJobs[jobNumber]["running"] = false
      job.running = false
      msg.send "Job #{job.id} has been stopped"
    else
      msg.send "Error: The job number you entered is either not running or does not exist"
      msg.send "Use the command 'l jobs' to check the job number"

  robot.respond /l(ist)? jobs/i, (msg) ->
    if Object.keys(robot.brain.data.cronJobs).length == 0
      msg.send "There are currently no jobs in my brain"
    else
      msg.send stringifyJobs()

  robot.respond /s(tart)? job (\d{7})/i, (msg) ->
    jobNumber =  msg.match[2]
    job = JOBS[jobNumber]
    if job? and job.running is false
      job.startJob()
      robot.brain.data.cronJobs[jobNumber]["running"] = true
      job.running = true
      msg.send "Job #{job.id} has been started"
    else
      msg.send "Error: The job number you entered is either already running or does not exist"
      msg.send "Use the command 'l jobs' to check the job number"

  robot.respond /clear cron/i, (msg) ->
    robot.brain.data.cronJobs = {}
    msg.send "Brain has been cleared"
    
# ======= Class definitions =======

class Job
  constructor: (@pattern, @url, @timezone, @description, running) ->
    @id = this.generateID()
    @running = running or false

  generateID: () ->
    now = Date.now().toString()
    now.substring(now.length - 7, now.length)

  startJob: () ->
    @cronJob.start()
    @running = true

  stopJob: () ->
    @cronJob.stop()
    @running = false

  createCron: () ->
    # console.log "in create"
    @cronJob = new CronJob @pattern, =>
      request @url, (err, res, body) ->
        console.log res
    , ->
      console.log "job ended"
    , false
    , @timezone
    console.log "finished creating"
