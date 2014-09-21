class Paddle extends Particle

class PaddleBehaviour extends Behaviour

  constructor: (@desired_x = 200, @set_y = 200) ->
    @speed = 20
    super

  apply: (p, dt, index) ->

    # Move paddle along x
    dx = p.pos.x - @desired_x

    if dx == 0
      p.vel.x = 0
      p.acc.x = 0
    else
      p.acc.x = -@speed * dx

    # Fix Y
    p.pos.y = @set_y
    p.vel.y = 0
    p.acc.y = 0

class App
  constructor: ->
    video = document.getElementById("video")

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
      autopause: false
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
    tophalfmax = new Vector @game.width - bound, @game.height / 3
    tophalf = new EdgeBounce min, tophalfmax

    # Particle colours
    PARTICLE_COLOURS = ['DC0048', 'F14646', '4AE6A9', '7CFF3F', '4EC9D9', 'E4272E']

    ################################
    # Set up particles
    for i in [0..30]
      
      size = 1 + Math.random()
      particle = new Particle(size)
      position = new Vector(random(@width), random(@height/3))
      particle.setRadius particle.mass * 8
      particle.moveTo position
      particle.colour = Random.item PARTICLE_COLOURS
      
      # Make it collidable
      collision.pool.push particle
      
      # Apply behaviours
      particle.behaviours.push antiGravity, collision, tophalf
      
      # Add to the simulation
      @physics.particles.push particle

    ################################
    # Set up ball
    @ball = new Particle(0.5)
    @ball.setRadius @ball.mass * 8
    centre = new Vector(@game.width/2, @game.height/2)
    @ball.moveTo centre
    @ball.colour = '000000'

    # Ball behaviours
    collision.pool.push @ball
    @ball.behaviours.push collision, edge
    @physics.particles.push @ball

    ################################
    # Set up paddle
    @paddle = new Paddle(10)
    @paddle.setRadius 50
    bottomcentre = new Vector(@game.width/2, @game.height - 30)
    @paddle.moveTo bottomcentre
    @paddle.colour = '000000'

    # Paddle behaviour
    @paddlebehaviour = new PaddleBehaviour(@game.width / 2, @game.height - 30)
    @paddle.behaviours.push edge, @paddlebehaviour
    collision.pool.push @paddle
    @physics.particles.push @paddle

  gameDraw: =>
    
    # Step the simulation
    @physics.step()
    
    # Render particles
    for particle in @physics.particles

      # Skip drawing paddle
      if particle is @paddle
        continue

      @game.beginPath()
      @game.arc particle.pos.x, particle.pos.y, particle.radius, 0, Math.PI * 2
      @game.fillStyle = '#' + (particle.colour or 'FFFFFF')
      @game.fill()

    # Draw paddle
    p = @paddle
    @game.strokeStyle = 'rgba(0,0,0,1)'
    @game.lineWidth = 10
    @game.moveTo(p.pos.x - p.radius, p.pos.y)
    @game.lineTo(p.pos.x + p.radius, p.pos.y)
    @game.stroke()

    # rectangle position
    if @target_rectangle
      @game.strokeStyle = 'magenta'
      @game.lineWidth = 1
      rect = @target_rectangle
      @game.strokeRect rect.x, rect.y, rect.width, rect.height
      @paddlebehaviour.desired_x = rect.x + rect.width / 2


  onTrackEvent: (event) =>

    if event.data.length == 0
      @target_rectangle = false
      return

    console.log event.data

    if event.data.length > 1
      console.log 'more than one rect'

    rect = event.data[0]
    @target_rectangle = rect


$ ->
  window.app = new App()

$(window).unload ->
  window.app.unload()
