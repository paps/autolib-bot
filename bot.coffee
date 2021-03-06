'use strict'
'phantombuster command: casperjs'
'phantombuster package: 2'

casper = require('casper').create
	#verbose: yes
	colorizerType: 'Dummy'
	pageSettings:
		userAgent: 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:35.0) Gecko/20100101 Firefox/35.0'
	logLevel: 'debug'
	viewportSize:
		width: 1280
		height: 1024
	onResourceRequested: (casper, request, net) ->
		blocked = [
			'maps.google.com'
			'maps.gstatic.com'
			'maps.googleapis.com'
			'fonts.googleapis.com'
		]
		for domain in blocked
			if (request.url.indexOf('https://' + domain) is 0) or (request.url.indexOf('http://' + domain) is 0) or (request.url.indexOf(domain) is 0)
				console.log "> Blocked: #{request.url}"
				return net.abort()

buster = require('phantombuster').create casper

if (typeof(buster.argument.autolibLogin) isnt 'string') or
(typeof(buster.argument.autolibPassword) isnt 'string') or
(typeof(buster.argument.autolibId) isnt 'string') or
(typeof(buster.argument.pushoverAppToken) isnt 'string') or
(typeof(buster.argument.pushoverUserKey) isnt 'string') or
(typeof(buster.argument.type) isnt 'string') or
(typeof(buster.argument.mode) isnt 'string') or
(typeof(buster.argument.stationName) isnt 'string') or
(typeof(buster.argument.stationPostalCode) isnt 'number') or
(typeof(buster.argument.stationLat) isnt 'number') or
(typeof(buster.argument.stationLong) isnt 'number') or
(typeof(buster.argument.maxExecutionTime) isnt 'number') or
(typeof(buster.argument.refreshRate) isnt 'number')
	console.log '''Invalid argument
		{
			"autolibLogin": "",
			"autolibPassword": "",
			"autolibId": "123456",
			"pushoverAppToken": "",
			"pushoverUserKey": "",
			"type": "parking/vehicle",
			"mode": "check/reserve",
			"stationName": "Paris/Dalayrac/19",
			"stationPostalCode": 75002,
			"stationLat": 48.868181,
			"stationLong": 2.335097,
			"maxExecutionTime": 3600,
			"refreshRate": 10
		}'''
	casper.exit 1
if not (buster.argument.type in ['vehicle', 'parking'])
	console.log 'Argument "type" must be "vehicle" or "parking"'
	casper.exit 1
if not (buster.argument.mode in ['check', 'reserve'])
	console.log 'Argument "mode" must be "check" or "reserve"'
	casper.exit 1

startTime = Date.now()
nbRefresh = 0
notifTitle = "#{if buster.argument.mode is 'check' then 'Checking for' else 'Reserving'} a #{buster.argument.type} in #{buster.argument.stationName}"

searchTries = 0
maxSearchTries = 3
searchStation = () ->
	++searchTries
	if buster.argument.type is 'vehicle'
		searchPageAddress = "https://moncompte.autolib.eu/account/reservations/#{buster.argument.autolibId}/carreservation/?full_address=#{buster.argument.stationLat}%2C#{buster.argument.stationLong}"
	else
		searchPageAddress = "https://moncompte.autolib.eu/account/reservations/#{buster.argument.autolibId}/parkreservation/?full_address=#{buster.argument.stationLat}%2C#{buster.argument.stationLong}"
	casper.thenOpen searchPageAddress, () ->
		console.log "Searching for station #{buster.argument.stationName} (try #{searchTries}/#{maxSearchTries})"
		words = buster.argument.stationName.split '/'
		if words.length isnt 3
			console.log "Invalid station name (#{words.length} words instead of 3)"
			casper.exit 1
		words[0] = ' ' + words[0].trim() + ' ' # city
		words[1] = ' ' + words[1].trim() # street
		words[2] = words[2].trim() + ' ' # number
		words.push ' ' + buster.argument.stationPostalCode + ' ' # postal code
		getOptionString = (words) ->
			try
				optionStringMatches = []
				lastOptionValue = ''
				jQuery('#id_station > option').each () ->
					optionString = jQuery(@).text()
					wordMatches = 0
					for word in words
						if optionString.indexOf(word) >= 0
							++wordMatches
					if wordMatches is words.length
						optionStringMatches.push optionString
						lastOptionValue = jQuery(@).attr 'value'
				if optionStringMatches.length is 1
					jQuery('#id_station').val lastOptionValue
					return optionStringMatches[0].trim()
				else
					__utils__.echo "#{optionStringMatches.length} stations matched with words [#{words.join ','}]"
			catch e
				__utils__.echo e.toString()
			return 0
		optionString = casper.evaluate getOptionString, words
		if typeof(optionString) isnt 'string'
			if searchTries >= maxSearchTries
				exitWithScreenshot "Could not find station #{buster.argument.stationName}", 'station-no-found'
			else
				searchStation()
		else
			console.log "Found string \"#{optionString}\""
			matches = optionString.match /^.*\((\d) .*\)$/
			if matches isnt null and matches.length is 2
				available = parseInt matches[1], 10
				if isFinite(available) and (available >= 0) and (available <= 9)
					searchTries = 0
					processStation available
				else
					if searchTries >= maxSearchTries
						exitWithScreenshot "Got an invalid number of #{buster.argument.type}s from string \"#{optionString}\"", 'invalid-number'
					else
						searchStation()
			else
				if searchTries >= maxSearchTries
					exitWithScreenshot "Regular expression failed to find the number of #{buster.argument.type}s from string \"#{optionString}\"", 'regex-number-failure'
				else
					searchStation()

processStation = (available) ->
	if available is 0
		console.log "No #{buster.argument.type} available"
		elapsedSeconds = (Date.now() - startTime) / 1000
		if elapsedSeconds > buster.argument.maxExecutionTime
			message = "#{Math.round elapsedSeconds} seconds have elapsed and a #{buster.argument.type} was never available at #{buster.argument.stationName}"
			console.log message
			buster.pushover message, { title: notifTitle }, () -> casper.exit 1
		else
			++nbRefresh
			buster.progressHint (elapsedSeconds / buster.argument.maxExecutionTime), "#{if buster.argument.mode is 'check' then 'Checking for' else 'Reserving'} a #{buster.argument.type}, try #{nbRefresh}"
			casper.wait buster.argument.refreshRate * 1000
			searchStation()
	else
		message = "#{available} #{buster.argument.type}#{if available > 1 then 's are' else ' is'} available"
		console.log message
		if buster.argument.mode is 'check'
			buster.pushover message, { title: notifTitle }
		else
			casper.evaluate () ->
				jQuery('#reserve-form').submit()
			casper.wait 2000
			casper.then () -> confirmReservation()

confirmReservation = () ->
	record = casper.evaluate () -> jQuery('.article > p:nth-child(1)').text().trim()
	expiration = casper.evaluate () -> jQuery('.article > p:nth-child(2)').text().trim()
	if (record.indexOf("Your #{if buster.argument.type is 'vehicle' then 'car' else 'parking'} reservation at station ") is 0) and (expiration.indexOf('Your reservation will expire on ') is 0)
		message = """
			Reservation of #{buster.argument.type} appears successful:
			 -> #{record}
			 -> #{expiration}
			"""
		console.log message
		buster.pushover message, { title: notifTitle }
	else
		exitWithScreenshot "Could not find confirmation messages for this reservation", 'no-confirmation-messages'

exitWithScreenshot = (message, name) ->
	console.log message
	screenshotPath = null
	casper.then () ->
		casper.capture "#{name}.jpg"
		buster.save "#{name}.jpg", (err, path) ->
			console.log "Screenshot - err: #{err}, path: #{path}"
			if (err is null) and path?
				screenshotPath = path
	casper.then () ->
		options =
			title: notifTitle
		if screenshotPath?
			options.url = screenshotPath
			options.url_title = 'Screenshot of error'
		buster.pushover message, options, () -> casper.exit 1

casper.start 'https://www.autolib.eu/en/404/', () ->
	console.log 'Logging in'
	casper.fill 'form',
		username: buster.argument.autolibLogin
		password: buster.argument.autolibPassword
		next: '/language/en/',
		yes

searchStation()

console.log 'Opening login page'
casper.run () ->
	console.log 'All steps were executed'
	casper.exit()
