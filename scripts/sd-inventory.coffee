# Description:
#   Server Density Inventory
#
# Commands:
#   hubot sd list services
#   hubot sd list devices
#
# Configuration:
#   HUBOT_SD_API_TOKEN

apiToken = process.env.HUBOT_SD_API_TOKEN
baseURL  = 'https://api.serverdensity.io'

template = (item, type) =>
	switch type
		when 'services'
			return "\n#{item.name} | #{item.checkMethod} #{item.checkUrl} | [ID: #{item._id}]"

		when 'devices'
			return "\n#{item.name} | #{item.hostname} | [ID: #{item._id}]"

module.exports = (robot) ->
	robot.respond /SD list (devices|services)/i, (msg) ->
		type = msg.match[1]

		msg.send "Fetching #{type}..."

		msg
			.http("#{baseURL}/inventory/#{type}?token=#{apiToken}")
			.headers
				"Accept": 'application/json'
				"content-type": 'application/json'

			.query
				deleted: no

			.get() (error, response, body) ->
				if error
					msg.send "HTTP Error: #{error}"

					return

				response = JSON.parse(body)

				if response.errors
					msg.send "API Error: #{response.errors.type}"

					return

				output = "\n\n" + response.length + " " + type[0...type.length - 1] + "(s)\n"

				for item in response
					output += template(item, type)

				output += "\n\n"

				msg.send output
