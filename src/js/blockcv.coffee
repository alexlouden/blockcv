class App
  constructor: ->
    video = document.getElementById("video")
    @canvas = document.getElementById("canvas")
    @context = @canvas.getContext("2d")

    tracker = new tracking.ColorTracker("magenta")
    # can also use custom colours
    # See http://trackingjs.com/api/ColorTracker.js.html#line366

    tracking.track "#video", tracker,
      camera: true

    tracker.on "track", @onTrackEvent

    # Create a physics instance which uses the Verlet integration method
    physics = new Physics()
    physics.integrator = new Verlet()

  onTrackEvent: (event) =>
    @context.clearRect 0, 0, @canvas.width, @canvas.height
    
    event.data.forEach (rect) =>
      rect.color = tracker.customColor  if rect.color is "custom"
      @context.strokeStyle = rect.color
      @context.strokeRect rect.x, rect.y, rect.width, rect.height
      @context.font = "11px Helvetica"
      @context.fillStyle = "#fff"
      @context.fillText "x: " + rect.x + "px", rect.x + rect.width + 5, rect.y + 11
      @context.fillText "y: " + rect.y + "px", rect.x + rect.width + 5, rect.y + 22
      return

$ ->
  window.app = new App()

$(window).unload ->
  window.app.unload()
