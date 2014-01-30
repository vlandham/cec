
root = exports ? this

roundDate = (date, timeInterval) ->
  coeff = 1000 * 60 * timeInterval
  d =  new Date(Math.floor(date.getTime() / coeff) * coeff)
  d

addMinutes = (date, minutes) ->
  new Date(date.getTime() + minutes * 60000)

formatTime = (date) ->
  hours = date.getHours()
  if hours > 12
    hours = hours - 12
  mins = date.getMinutes()
  if mins < 10
    mins = "0#{mins}"
  "#{hours}:#{mins}"

Plot = () ->
  width = 1000
  height = 600
  topHeight = 300
  maxRadius = 25
  maxMapRadius = 80
  data = []
  locs = null
  map = null
  dots = null
  checks = null
  line = null
  margin = {top: 20, right: 20, bottom: 60, left: 150}
  xScale = d3.time.scale().range([0,width])
  yScale = d3.scale.ordinal().rangeRoundBands([0,height], 0.1)
  mapScale = d3.scale.ordinal().rangeRoundBands([0,width], 0.1)
  rScale = d3.scale.sqrt().range([0,maxRadius]).domain([0, 20])
  mapRScale = d3.scale.sqrt().range([0,maxMapRadius]).domain([0,200])
  fontScale = d3.scale.linear().domain([0,200]).range([10,26])

  timeInterval = 5
  curTime = null
  beginTime = null
  endTime = null
  timer = null

  xAxis = d3.svg.axis()
    .scale(xScale)
    .orient("bottom")

  color = d3.scale.category10()

  # parseTime = d3.time.format("%Y-%m-%d").parse
  iso = d3.time.format.utc("%Y-%m-%dT%H:%M:%S.%LZ").parse

  parseData = (raw) ->
    startTimestamp = "2014-01-29T02:02:32.000Z"
    startTime = iso(startTimestamp)
    console.log(startTime)
    raw.forEach (d) ->
      d.time = iso(d.timestamp)
      d.type = if d.rfid_tag_id.slice(0,4) == "ABBA" then "person" else "item"
      d.binTime = roundDate(d.time, timeInterval)
    raw = raw.filter (d) -> d.type == "person" and d.time > startTime
    timeExtent = d3.extent(raw, (d) -> d.binTime)
    curTime = timeExtent[1]
    beginTime = timeExtent[0]
    endTime = timeExtent[1]
    xScale.domain(timeExtent)
    console.log(xScale.domain())
    nest = d3.nest()
      .key((d) -> d.location)
      .key((d) -> d.binTime)
      .rollup (d) ->
        o = {}
        o.location = d[0].location
        o.count = d.length
        o.time = d[0].binTime
        o
      .entries(raw)

    yScale.domain(nest.map((d,i) -> i))
    mapScale.domain(nest.map((d,i) -> i))
    nest

  chart = (selection) ->
    selection.each (rawData) ->

      data = parseData(rawData)
      console.log(data)

      svg = d3.select(this).selectAll("svg").data([data])
      gEnter = svg.enter().append("svg").append("g")
      
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + topHeight + margin.top + margin.bottom )

      g = svg.select("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      xAxisG = g.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + (height + topHeight) + ")")
      xAxisG.call(xAxis)

      locs = g.append("g").attr("id", "vis_points")
        .attr("transform", "translate(0,#{topHeight})")

      lineG = locs.append("g").attr("id", "vis_line")
      map = g.append("g").attr("id", "vis_map")

      line = lineG.append("line")
      addBubbles()
      addMap()
      updateMap(curTime)

  addMap = () ->
    dots = map.selectAll(".dot")
      .data(data)

    dots.enter().append("circle")
      .attr("class", "dot")
      .attr("cx", (d,i) -> mapScale(i))
      .attr("cy", topHeight / 2)
      .attr("fill", (d) -> color(d.key))
      .attr("fill-opacity", 0.6)
      .attr("r", 20)

    map.selectAll(".title").data(data).enter().append("text")
      .attr("class", "title")
      .attr("x", (d,i) -> mapScale(i))
      .attr('y', (d,i) -> if (i % 2) == 0 then 20 else 60)
      .attr('text-anchor', 'middle')
      .attr("fill", (d) -> color(d.key))
      .text((d) -> d.key)

    map.selectAll(".count").data(data).enter().append("text")
      .attr("class", "count")
      .attr("x", (d,i) -> mapScale(i))
      .attr('y', topHeight / 2)
      .attr("dy", 6)
      .attr('text-anchor', 'middle')
      # .attr("fill", (d) -> color(d.key))
      .text((d) -> d.total)

  updateMap = (cur) ->
    data.forEach (d) ->
      transpired = d.values.filter (v) ->
        v.values.time <= cur
      d.total = transpired.map((d) -> d.values.count).reduce(((a,b) -> a + b),0)
    dots.transition()
      .duration(500)
      .attr("r", (d) -> mapRScale(d.total))
    map.selectAll(".count")
      .text((d) -> d.total)
      .transition()
      .duration(500)
      .attr("font-size", (d) -> fontScale(d.total))


  addBubbles = () ->
    locations = locs.selectAll(".location")
      .data(data)

    locations.exit().remove()
    locsE = locations.enter()
      .append("g")
      .attr("transform", (d,i) -> "translate(0,#{yScale(i)})")
    locsE.append("text")
      .attr("text-anchor", "end")
      .attr("dx", -30)
      .attr("dy", 6)
      .attr("y", yScale.rangeBand() / 2)
      .attr("fill", (d) -> color(d.key))
      .text((d) -> d.key)

    checks = locsE.selectAll(".check")
      .data(((d) -> d.values),((d) -> d.key))

    checks.exit().remove()

    checksE = checks.enter()
      .append("g")
      .attr("class", "check")
      .attr("transform", (d) -> "translate(#{xScale(d.values.time)})")
      .append("circle")
      .attr("cy", yScale.rangeBand() / 2 )
      .attr("r", (d) -> rScale(d.values.count))
      .attr("fill", (d) -> color(d.values.location))
      .attr("fill-opacity", 0.6)
      .on("click", (d) -> console.log(d))

    $('svg .check').tipsy({
      gravity:'s'
      html:true
      title: () ->
        d = this.__data__
        "<strong>#{d.values.count}</strong> <br/> #{formatTime(d.values.time)}"
    })
 
  isSelected = (d, cur) ->
    d.values.time == cur

  updateBubbles = (cur) ->
    line.attr("x1", xScale(cur))
      .attr("x2", xScale(cur))
      .attr("y1", 0)
      .attr("y2", height)
      .attr("stroke", "black")
      .attr("stroke-width", 1.5)
      .attr("stroke-opacity", 0.7)
    checks.selectAll("circle")
      .attr("stroke", (d) -> if isSelected(d,cur) then "black" else null)
      .attr("stroke-width", (d) -> if isSelected(d,cur) then 1 else 0)

  play = () ->
    if curTime <= endTime
      updateMap(curTime)
      updateBubbles(curTime)
      curTime = addMinutes(curTime, timeInterval)
      console.log(curTime)
    else
      console.log('stop')
      chart.stop()
    
  chart.start = () ->
    d3.select("#play").attr("disabled", true)
    curTime = beginTime
    play()
    timer = setInterval(play, 600)

  chart.stop = () ->
    line.attr("y1", 0).attr("y2", 0)
    d3.select("#play").attr("disabled", null)
    clearInterval(timer)

  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  chart.margin = (_) ->
    if !arguments.length
      return margin
    margin = _
    chart

  chart.x = (_) ->
    if !arguments.length
      return xValue
    xValue = _
    chart

  chart.y = (_) ->
    if !arguments.length
      return yValue
    yValue = _
    chart

  return chart

root.Plot = Plot

root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)


$ ->

  plot = Plot()
  display = (error, data) ->
    plotData("#vis", data, plot)

  d3.select("#play").on "click", plot.start
  queue()
    .defer(d3.csv, "data/rfid.csv")
    .await(display)

