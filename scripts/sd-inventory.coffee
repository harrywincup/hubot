# Description:
#   Server Density Inventory
#
# Commands:
#   hubot sd list <type>
#
# Configuration:
#   HUBOT_SD_API_TOKEN

class SDInventory

	apiToken: process.env.HUBOT_SD_API_TOKEN
	baseURL: 'https://api.serverdensity.io'

	constructor: (@robot) ->
		robot.respond /SD list ([a-z]+)/i, @list

	list: (msg) =>
		itemType = msg.match[1].trim()

		msg.send "Fetching #{itemType}..."

		filter =
			deleted: no
			type: itemType[0...itemType.length - 1]

		params =
			token: @apiToken
			filter: JSON.stringify(filter)

		msg.http("#{@baseURL}/inventory/resources")
		msg.headers
			"Accept": 'application/json'
			"content-type": 'application/json'

		msg.query(params)

		msg.get() (error, response, body) ->
			console.log error
			if error
				msg.send "HTTP Error: #{error}"

				return

			response = JSON.parse(body)

			if response.errors
				msg.send "API Error: #{response.errors.type}"

				return

			output = "\n\n" + response.length + " " + itemType[0...itemType.length - 1] + "(s)\n"

			for item in response
				output += @template(item)

			output += "\n\n"

			msg.send output

	template: (item) =>
		switch item.type
			when 'service'
				return "\n#{item.name} | #{item.checkMethod} #{item.checkUrl} | [ID: #{item._id}]"

			when 'device'
				return "\n#{item.name} | #{item.hostname} | [ID: #{item._id}]"

			else
				return "\n#{item.name} | [ID: #{item._id}]"

module.exports = (robot) -> new SDInventory(robot)
