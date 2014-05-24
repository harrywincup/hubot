# Description:
#   Manage bookings for who can use the staging server
#
# Dependencies:
#   "moment": "2.6.x"
#   "underscore": "1.6.x"
#
# Configuration:
#   None
#
# Commands:
#   stagehand [env] free? - Check all or individual environment availability
#   stagehand book [env] [minutes] - Book the environment and optionally specify usage time.
#   stagehand cancel [env] - Cancel your requests for the environment
#   stagehand done [env] - Tell stagehand you're finished
#
# Author:
#   harrywincup (inspired by tinifni)

_ 	 = require('underscore')
moment = require('moment')

class StageHand
	environments: ['staging', 'production']
	defaultEnvironment: 'staging'
	defaultDuration: 30 #minutes

	constructor: (@robot) ->
		@robot.brain.data.stagehand =
			bookings: {}
			queues: {}

		@robot.brain.data.stagehand.queues[environment] = [] for environment in @environments

		@listenForCommands()

	listenForCommands: =>
		@robot.respond /stagehand book(\s[a-z]+)?( [0-9]+)?/i, @book
		@robot.respond /stagehand( [a-z]+)? free\?/i, @checkAvailability
		@robot.respond /stagehand done(?:\s)?([a-z]+)?/i, @release
		@robot.respond /stagehand cancel ([a-z]+)/i, @cancelRequest

	addToQueue: (request) => @robot.brain.data.stagehand.queues[request.environment].push(request)

	removeFromQueue: (userID, environment) =>
		queue = @getQueue(environment)

		if queue.length > 0
			for request, index in queue
				if request.user.id is userID then queue.splice(index, 1)

	book: (msg) =>
		environment  = msg.match[1]?.trim() or @defaultEnvironment
		duration 	= msg.match[2]?.trim() or @defaultDuration
		user 		= msg.message.user

		if @environmentExists(environment, msg)
			booking = @getActiveBooking(environment)

			bookingRequest =
				user: user
				duration: duration
				environment: environment

			if booking
				if user.id is booking.user.id
					msg.reply "You're already on #{environment}! Pull yourself together, man."
				else
					msg.reply "#{environment} is in use by #{booking.user.name} ... I'll let you know when it's your turn!"

					@addToQueue(bookingRequest)
			else
				@setActiveBooking(bookingRequest)

	cancelRequest: (msg) =>
		environment = msg.match[1]?.trim()

		if @environmentExists(environment, msg)
			msg.reply "I've cleared your requests for #{environment}"

			@removeFromQueue(msg.message.user.id, environment)

	checkAvailability: (msg) =>
		user 	   = msg.message.user
		environment = msg.match[1]?.trim()

		if environment and @environmentExists(environment, msg)
			booking = @getActiveBooking(environment)

			if booking
				remainingTime = moment.unix(booking.expiresAt).fromNow(yes)

				if user.id is booking.user.id
					msg.reply "You've got it for #{remainingTime}"
				else
					msg.reply "Nope! #{booking.user.name} has #{environment} for #{remainingTime}"
			else
				msg.reply "Sure is! Get involved..."
		else
			output = ""

			for environment in @environments
				booking = @getActiveBooking(environment)

				if booking
					remainingTime = moment.unix(booking.expiresAt).fromNow(yes)

					details = "#{booking.user.name}'s for #{remainingTime}"
				else
					details = "available"

				output += "\n#{environment}: #{details}"

			msg.send output

	clearBooking: (environment) =>
		booking = @robot.brain.data.stagehand.bookings[environment]

		if booking
			clearTimeout(booking.expiryTimerID)

			@robot.brain.data.stagehand.bookings[environment] = null

			@processQueue(environment)

	environmentExists: (environment, msg) =>
		environmentExists  = _(@environments).contains(environment)

		if not environmentExists then msg.reply "#{environment} doesn't exist :("

		return environmentExists

	getQueue: (environment) => return @robot.brain.data.stagehand.queues[environment]

	getAllBookingsForUser: (userID) => return _(@robot.brain.data.stagehand.bookings).filter (booking) -> booking?.user?.id is userID

	getActiveBooking: (environment) => return @robot.brain.data.stagehand.bookings[environment]

	setActiveBooking: (options) =>
		user 		= options.user
		duration 	= options.duration
		environment  = options.environment

		expiresAt = moment().add(Number(duration), 'minutes')

		booking =
			environment: environment
			user: user
			expiresAt: expiresAt.unix()

		expiryTimerID = setTimeout =>
			@clearBooking(environment)
		, expiresAt.diff(moment())

		booking.expiryTimerID = expiryTimerID

		@robot.brain.data.stagehand.bookings[environment] = booking

		@robot.reply booking, "#{environment} is yours for #{duration} minute" + (if parseInt(duration) isnt 1 then 's' else '')

	processQueue: (environment) =>
		queue = @getQueue(environment)

		if queue.length > 0
			@setActiveBooking(queue.shift())

	release: (msg) =>
		user 	   = msg.message.user
		environment = msg.match[1]?.trim()

		if environment
			if @environmentExists(environment, msg)
				booking = @getActiveBooking(environment)

				if booking and booking.user.id is user.id
					msg.reply "Schweet"

					@clearBooking(environment)

					if not @getActiveBooking(environment) then msg.send "#{environment} is now available"
				else
					msg.reply "You're not even using #{environment}. Sort it out."
		else
			bookings = @getAllBookingsForUser(user.id)

			if bookings.length > 0
				msg.reply "Nice!"

				for booking in bookings
					@clearBooking(booking.environment)

					if not @getActiveBooking(booking.environment) then msg.send "#{booking.environment} is now available"
			else
				msg.reply "You're not using anything, silly"

				msg.send output

module.exports = (robot) -> new StageHand(robot)
