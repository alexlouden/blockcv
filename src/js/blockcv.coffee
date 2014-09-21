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
    @physics = new Physics()
    @physics.integrator = new Verlet()

    # Use Sketch.js to make life much easier
    @game = Sketch.create
      fullscreen: false
      width: 400
      height: 400

    @game.setup = @gameSetup
    @game.draw = @gameDraw

  gameSetup: =>

    up = new Vector 0.0, -98.0
    antiGravity = new ConstantForce(up)
    
    collision = new Collision()

    # Bounce off edges, with padding
    bound = 10.0
    min = new Vector bound, bound
    max = new Vector @game.width - bound, @game.height - bound
    edge = new EdgeBounce min, max

    for i in [0..30]
      
      # Create a particle
      size = 1 + Math.random()
      particle = new Particle(size)
      position = new Vector(random(@width), random(@height))
      particle.setRadius particle.mass * 8
      particle.moveTo position
      
      # Make it collidable
      collision.pool.push particle
      
      # Apply behaviours
      particle.behaviours.push antiGravity, collision, edge
      
      # Add to the simulation
      @physics.particles.push particle

    @game.fillStyle = "#ff0000"

  gameDraw: =>
    
    # Step the simulation
    @physics.step()
    
    # Render particles
    for particle in @physics.particles
      
      @game.beginPath()
      @game.arc particle.pos.x, particle.pos.y, particle.radius, 0, Math.PI * 2
      @game.fill()

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
