# Description:
#   A quick integration with our local index API - TIMDEX
#
# Dependencies:
#   None
#
# Configuration:
#   TIMDEX_BASIC_TOKEN - find this at https://mitlibraries-timdex.docs.stoplight.io/authenticate/authenticate
#
# Commands:
#   timbot auth - Generate the Bearer token, from your Basic token, for use in all other steps.
#   timbot search <phrase> - Conduct a search against TIMEDEX using <phrase>. Displays the first five results and summary information.
#   timbot debug <phrase> - Conduct the same type of search as above, but displays the raw returned JSON for further development.
#
# Author:
#   matt-bernhardt

module.exports = (robot) ->

  # Tokens
  robot.brain.data.basic_token = "process.env.TIMDEX_BASIC_TOKEN"
  robot.brain.data.bearer_token = ""

  authorize = (res) ->
    res.send "Authorizing with API..."
    robot.http("https://timdex.mit.edu/api/v1/auth")
      .header("authorization", "Basic #{robot.brain.data.basic_token}")
      .get() (err, httpRes, body) ->
        # Error handling
        if err
          res.send "Authorization error: #{err}"
          return
        if httpRes.statusCode is 401
          # 401 status codes indicate authentication problems.
          res.send "Authorization denied (401 error when requesting new token)"
          return
        else if httpRes.statusCode isnt 200
          # Other non-200 status codes are best passed to the user for diagnosis.
          res.send "Unexpected authorization status code: #{httpRes.statusCode}"
          return
        # Deal with return data
        try
          robot.brain.data.bearer_token = JSON.parse(body)
          res.send "Authorization successful!"
        catch error
          res.send "Authorization parsing error: #{error}"


  # Manually-invoked authorization
  robot.respond /auth/i, (res) ->
    authorize(res)


  # Conduct a search against the TIMDEX api
  robot.respond /search (.*)/i, (res) ->
    query = res.match[1]
    res.send "Searching TIMDEX for \"#{query}\""

    if "" == robot.brain.data.bearer_token
      res.send "Search will fail, authorization token not present. Please run `timbot auth` to request one."
      return

    robot.http("https://timdex.mit.edu/api/v1/search?q=#{query}")
      .header("authorization", "Bearer #{robot.brain.data.bearer_token}")
      .get() (err, httpRes, body) ->
        # Error handling
        if err
          res.send "Search error: #{err}"
          return
        if httpRes.statusCode is 401
          # 401 status codes indicate authentication problems.
          res.send "Search denied"
          return
        else if httpRes.statusCode isnt 200
          # Other non-200 status codes are best passed to the user for diagnosis.
          res.send "Unexpected search status code: #{httpRes.statusCode}"
          return
        # Deal with return data
        try
          data = JSON.parse(body)
          res.send "#{data.hits} response(s) indicated:"
          res.send "#{data.results.length} returned. The first five are:"
          for item, idx in data.results
            if idx >= 5
              return
            res.send "#{item.title}"
            res.send "  #{item.id}"
            res.send "  #{item.source_link}"
            res.send ""
        catch error
          res.send "Search parsing error: #{error}"


  # Used for debugging
  robot.respond /debug (.*)/i, (res) ->
    query = res.match[1]
    res.reply "Retrieving JSON for \"#{query}\""

    robot.http("https://timdex.mit.edu/api/v1/search?q=#{query}")
      .header("authorization", "Bearer #{robot.brain.data.bearer_token}")
      .get() (err, httpRes, body) ->
        # Error handling
        if err
          res.send "Debug search error: #{err}"
          return
        if httpRes.statusCode is 401
          # 401 status codes indicate authentication problems.
          res.send "Debug search denied"
          return
        else if httpRes.statusCode isnt 200
          # Non-200 status code (usually some non-error problem)
          res.send "Unexpected debug status code: #{httpRes.statusCode}"
          return
        try
          data = JSON.parse(body)
          res.send "#{body}"
        catch error
          res.send "Debug parsing error: #{error}"
