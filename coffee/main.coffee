$ () ->

	cfg = window.autolibBotCfg

	page =
		searchForm: $ '#searchForm'
		searchInput: $ '#searchInput'
		searchResults: $ '#searchResults'
		getStatus: $ '#getStatus'
		abort: $ '#abort'
		statusResult: $ '#statusResult'

	$.ajaxSettings.cache = no
	$.ajaxSettings.timeout = 10000

	startBot = (station, type, mode) ->
		if confirm "Type: #{type.toUpperCase()}, mode: #{mode.toUpperCase()}, station: #{station.fields.nom_de_la_station.toUpperCase()}. Start bot?"
			argument =
				autolibLogin: cfg.autolibLogin
				autolibPassword: cfg.autolibPassword
				autolibId: cfg.autolibId
				pushoverAppToken: cfg.pushoverAppToken
				pushoverUserKey: cfg.pushoverUserKey
				type: type
				mode: mode
				stationName: station.fields.nom_de_la_station
				stationPostalCode: station.fields.code_postal
				stationLat: station.fields.field13[0]
				stationLong: station.fields.field13[1]
			argument = JSON.stringify argument
			$.getJSON "https://phantombuster.com/api/v1/agent/#{cfg.agentId}/launch?key=#{cfg.phantombusterKey}&argument=#{encodeURIComponent argument}&command=casperjs", (data) ->
				page.statusResult.text JSON.stringify data, undefined, 2

	page.searchForm.submit (e) ->
		page.searchResults.text 'Loading results...'
		query = page.searchInput.val()
		$.getJSON "https://data.iledefrance.fr/api/records/1.0/search?dataset=stations_et_espaces_autolib&q=#{encodeURIComponent query}&facet=ville&facet=type_de_station", (data) ->
			if data? and (typeof(data) is 'object')
				if data.nhits > 0
					page.searchResults.empty()
					for station in data.records
						((station) ->
							actionsShown = no
							box = $('<div>').css('border', '1px solid #555').css('padding', '10px').css('margin', '10px')
							clickableBox = $('<div>')
							clickableBox.append $('<div>').css('font-weight', 'bold').text station.fields.nom_de_la_station
							clickableBox.append $('<div>').text "#{station.fields.type_de_station} of #{station.fields.places_autolib} slots (+#{station.fields.places_recharge_tiers})"
							clickableBox.append $('<div>').css('text-align', 'right').append $('<small>').text "#{station.fields.field13[0]}, #{station.fields.field13[1]}, #{station.fields.code_postal}"
							actions = $('<div>').css('text-align', 'center')
							box.append clickableBox
							box.append actions
							page.searchResults.append box
							clickableBox.click () ->
								if actionsShown
									actionsShown = no
									actions.empty()
								else
									actionsShown = yes
									actions.append $('<input>').attr('type', 'button').attr('value', 'Check for vehicle').click () -> startBot station, 'vehicle', 'check'
									actions.append $('<br/>')
									actions.append $('<input>').attr('type', 'button').attr('value', 'Reserve vehicle').click () -> startBot station, 'vehicle', 'reserve'
									actions.append $('<br/>')
									actions.append $('<input>').attr('type', 'button').attr('value', 'Check for parking space').click () -> startBot station, 'parking', 'check'
									actions.append $('<br/>')
									actions.append $('<input>').attr('type', 'button').attr('value', 'Reserve parking space').click () -> startBot station, 'parking', 'reserve'
						)(station)
				else
					page.searchResults.text 'No station found'
			else
				page.searchResults.text 'Search request failed'
		e.preventDefault()

	page.getStatus.click () ->
		page.statusResult.text 'Getting status...'
		$.getJSON "https://phantombuster.com/api/v1/user.json?key=#{cfg.phantombusterKey}", (data) ->
			if data? and (typeof(data) is 'object')
				if (data.status is 'success') and Array.isArray(data.data.agents)
					for agent in data.data.agents
						if agent.id is cfg.agentId
							page.statusResult.text JSON.stringify agent, undefined, 2
							return
					page.statusResult.text "No agent with ID #{cfg.agentId}"
				else
					page.statusResult.text 'Received invalid response'
			else
				page.statusResult.text 'Status request failed'

	page.abort.click () ->
		if confirm "Abort agent #{cfg.agentId}?"
			page.statusResult.text 'Aborting agent...'
			$.getJSON "https://phantombuster.com/api/v1/agent/#{cfg.agentId}/abort.json?key=#{cfg.phantombusterKey}", (data) ->
				page.statusResult.text JSON.stringify data, undefined, 2
