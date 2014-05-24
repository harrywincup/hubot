# Description:
#   Manage Server Density alerts
#
# Commands:
#   hubot sd pause alert <alertID>
#   hubot sd resume alert <alertID>
#   hubot sd list alerts [<device/service ID>]
#
# Configuration:
#   HUBOT_SD_API_TOKEN

class SDAlerts
	apiToken: process.env.HUBOT_SD_API_TOKEN
	baseURL: 'https://api.serverdensity.io'

	constructor: (@robot) -> @createCommands()

	createCommands: =>
		@robot.respond /sd (resume|pause) (?:alert)?(?:\s)?([a-z0-9]{24})?/i, @updateState
		@robot.respond /sd open alerts(?:\s?)([a-z0-9]{24})?/i, @listOpen
		@robot.respond /sd paused alerts/i, @listPaused

	listPaused: (msg) =>
		msg.send "Fetching paused alerts..."

		params =
			token: @apiToken
			filter:
				enabled: no

		msg
			.http("#{@baseURL}/alerts/configs/")
			.headers
				'Accept': 'application/json'
				'Content-Type': 'application/json'

			.query(filter)

			.get() (error, response, body) ->
				console.log body

	listOpen: (msg) =>
		subjectID = msg.match[1]

		msg.send "Fetching alerts" + (if subjectID then " for #{subjectID}" else "") + "..."

		filter =
			closed: no

		msg
			.http("#{@baseURL}/alerts/triggered/" + (subjectID or "") + "?token=#{@apiToken}")
			.headers
				'Accept': 'application/json'
				'content-type': 'application/json'

			.query(filter)

			.get() (error, response, body) ->
				if error
					msg.send "HTTP Error: #{error}"

					return

				response = JSON.parse(body)

				if response.errors
					msg.send "API Error: #{response.errors.type}"
				else
					if response.length is 0
						msg.send 'No open alerts. Good. Good.'
					else
						alerts = "\n\n" + response.length + " open alert(s)\n"

						for alert, index in response
							alerts += "\n#{index + 1}) #{alert.config.fullField} #{alert.config.comparison} #{alert.config.value} for #{alert.config.subjectType} (#{alert.config.subjectId}) - [Config: #{alert.config._id}]"

						alerts += "\n\n"

						msg.send alerts

	updateState: (msg) =>
		command  = msg.match[1]
		configID = msg.match[2]

		unless configID
			msg.send "No config ID provided. *panics*"

			return

		msg.send command.charAt(0).toUpperCase() + command[1...command.length - 1] + 'ing alert...'

		data =
			enabled: (command is 'resume')

		msg
			.http("#{@baseURL}/alerts/configs/#{configID}?token=#{@apiToken}")
			.headers
				'Accept': 'application/json'
				'content-type': 'application/json'

			.put(JSON.stringify(data)) (error, response, body) ->
				if error
					msg.send "HTTP Error: #{error}"

					return

				response = JSON.parse(body)
				message  = if response.errors then "Error: #{response.errors.type}" else "#{command}d alert #{configID} (#{response.fullField} #{response.comparison} #{response.value})"

				msg.send message

module.exports = (robot) -> new SDAlerts(robot)
