class ColourTracker
  constructor: (@video, @canvas, @callback, @colourFn) ->
    @count = 0
    @context = @canvas.getContext '2d'

    navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia
    window.URL = window.URL || window.webkitURL
    navigator.getUserMedia {video:true}, (stream) =>
      @video.src = window.URL.createObjectURL stream
    , ->
      console.log 'Camerca fail'

    @video.addEventListener 'play', =>
      @drawToCanvas()
    , false

  drawToCanvas: =>
    @count++
    if @count % 10 == 0
      @count = 0
      return

    @context.drawImage @video, 0, 0
    data = @context.getImageData 0, 0, @canvas.width, @canvas.height

    rSum = 0
    cSum = 0
    points = 0

    for r in [0..data.height-1] by 10
      for c in [0..data.width-1] by 10
        i = r * data.width * 4 + c * 4
        if @colourFn data.data[i], data.data[i+1], data.data[i+2]
          points++
          rSum += r
          cSum += c

    rPerc = (rSum / points) / data.width
    cPerc = (cSum / points) / data.height

    if points > 0
      @callback
        y: rPerc
        x: cPerc
        width: 200
        height: 200
