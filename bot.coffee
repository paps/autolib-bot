'use strict'
'phantombuster command: casperjs'
#'phantombuster dependencies: lib-Pushover-beta.coffee'

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
		#console.log 'request >>>' + JSON.stringify request, undefined, 2
		#console.log 'net >>>' + JSON.stringify net, undefined, 2

buster = require('phantombuster').create casper
#Pushover = require 'lib-Pushover-beta'

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
(typeof(buster.argument.stationLong) isnt 'number')
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
			"stationLong": 2.335097
		}'''
	casper.exit 1
if not (buster.argument.type in ['vehicle', 'parking'])
	console.log 'Argument "type" must be "vehicle" or "parking"'
	casper.exit 1
if not (buster.argument.mode in ['check', 'reserve'])
	console.log 'Argument "mode" must be "check" or "reserve"'
	casper.exit 1

buster.argument.stationName = "Villejuif/René Thibert/7"

#pushover = new Pushover buster.argument.pushoverAppToken, buster.argument.pushoverUserKey

searchStation = () ->
	if buster.argument.type is 'vehicle'
		searchPageAddress = "https://www.autolib.eu/account/reservations/#{buster.argument.autolibId}/carreservation/?full_address=#{buster.argument.stationLat}%2C#{buster.argument.stationLong}"
	else
		searchPageAddress = "https://www.autolib.eu/account/reservations/#{buster.argument.autolibId}/parkreservation/?full_address=#{buster.argument.stationLat}%2C#{buster.argument.stationLong}"
	casper.thenOpen searchPageAddress, () ->
		console.log "Searching for station #{buster.argument.stationName}"
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
			console.log "Could not find station #{buster.argument.stationName}"
			casper.exit 1
		console.log "Found string \"#{optionString}\""
		matches = optionString.match /^.*\((\d) .*\)$/
		if matches isnt null and matches.length is 2
			available = parseInt matches[1], 10
			if isFinite(available) and (available >= 0) and (available <= 9)
				processStation available
			else
				console.log "Got an invalid number of #{buster.argument.type}s from string \"#{optionString}\""
				casper.exit 1
		else
			console.log "Regular expression failed to find the number of #{buster.argument.type}s from string \"#{optionString}\""
			casper.exit 1

processStation = (available) ->
	if available is 0
		console.log "No #{buster.argument.type} available, retrying"
		casper.wait 10000
		searchStation()
	else
		if buster.argument.mode is 'check'
			console.log "#{available} #{buster.argument.type}#{if available > 1 then 's are' else ' is'} available"
		else
			casper.evaluate () ->
				jQuery('#reserve-form').submit()

casper.start 'https://www.autolib.eu/en/404/', () ->
	console.log 'Logging in'
	casper.fill 'form',
		username: buster.argument.autolibLogin
		password: buster.argument.autolibPassword
		next: '/language/en/',
		yes

#casper.then () ->
#	casper.capture "screen1.jpg"
#	buster.save "screen1.jpg", (err, path) ->
#		console.log "Screenshot - err: #{err}, path: #{path}"

searchStation()

console.log 'Opening login page'
casper.run () ->
	console.log 'All steps were executed'
	casper.exit()
