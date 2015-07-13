'use strict'
'phantombuster command: casperjs'
'phantombuster dependencies: lib-Pushover-beta.coffee'

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
		console.log 'request >>>' + JSON.stringify request, undefined, 2
		console.log 'net >>>' + JSON.stringify net, undefined, 2

buster = require('phantombuster').create(casper)
Pushover = require 'lib-Pushover-beta'

if (typeof(buster.argument.autolibLogin) isnt 'string') or
(typeof(buster.argument.autolibPassword) isnt 'string') or
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
			"pushoverAppToken": "",
			"pushoverUserKey": "",
			"type": "parking/vehicle",
			"mode": "check/reserve",
			"stationName": "Paris/Dalayrac/19",
			"stationPostalCode": 10000,
			"stationLat": 0.000001,
			"stationLong": 0.000001
		}'''
	casper.exit 1

pushover = new Pushover buster.argument.pushoverAppToken, buster.argument.pushoverUserKey

casper.start 'http://phantomjs.org/api/webpage/handler/on-resource-requested.html', () ->
	pushover.send 'ceci est un test', (err, res) ->
		console.log "err: #{err}, res: #{res}"

casper.wait 10000

casper.run () ->
	console.log 'All CasperJS steps done.'
	casper.exit()
