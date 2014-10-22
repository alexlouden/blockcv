BALL_SIZE_MIN = .8
BALL_SIZE_VARIANCE = 1.5
NUM_BALLS = 40

WORKER = null

Array::remove = (obj) ->
  @filter (el) -> el isnt obj

class Block extends Particle

class Paddle extends Particle

class Ball extends Particle

class PaddleBehaviour extends Behaviour

  constructor: (@desired_x = 200, @set_y = 200) ->
    @f = 0.9
    super

  apply: (p, dt, index) ->

    # Move paddle along x
    p.pos.x = p.pos.x * @f + @desired_x * (1 - @f)
    p.old.pos.x = p.pos.x

    # Fix Y
    p.pos.y = @set_y
    p.vel.y = 0
    p.acc.y = 0

class BallSpeed extends Behaviour

class CustomCollision extends Collision

  constructor: (@useMass = yes, @callback = null, @ball = null, @paddle = null) ->

    # Pool of collidable particles.
    @pool = []

    # Delta between particle positions.
    @_delta = new Vector()

    super

  apply: (p, dt, index) ->

    # Check pool for collisions.
    for o in @pool[index..] when o isnt p

      # Delta between particles positions
      (@_delta.copy o.pos).sub p.pos

      # Squared distance between particles
      distSq = @_delta.magSq()

      if o is @paddle
        # Left < ball < right
        if o.pos.x - o.radius < p.pos.x < o.pos.x + o.radius
          # above paddle
          if o.pos.y - 10 < p.pos.y
            # bounce only if ball is travelling downward.
            if p.vel.y > 0
              p.old.pos.y = p.pos.y + p.vel.y

              paddleX = p.pos.x - o.pos.x
              if (paddleX < 0 and p.vel.x > 0) or (paddleX > 0 and p.vel.x < 0)
                p.old.pos.x = p.pos.x + p.vel.x

              p.acc.x = (paddleX / 50) * 5000

        continue

      # Sum of both radii
      radii = p.radius + o.radius

      # Check if particles collide
      if distSq <= radii * radii

        if o is @ball

          # Ball <--> particle
          # bounce
          o.old.pos.y = o.pos.y + o.vel.y

          # Fire callback if defined.
          @callback?(p, o, overlap)

        else
          # Particle <--> particle

          # Compute real distance.
          dist = Math.sqrt distSq

          # Determine overlap.
          overlap = radii - dist
          overlap += 0.5

          # Total mass.
          mt = p.mass + o.mass

          # Distribute collision responses.
          r1 = if @useMass then o.mass / mt else 0.5
          r2 = if @useMass then p.mass / mt else 0.5

          # Move particles so they no longer overlap.
          p.pos.add (@_delta.clone().norm().scale overlap * -r1)
          o.pos.add (@_delta.norm().scale overlap * r2)

class EdgeBouncy extends EdgeBounce

  apply: (p, dt, index) ->

    if p.pos.x - p.radius < @min.x
      # Left
      p.pos.x = @min.x + p.radius
      p.old.pos.x = p.pos.x + p.vel.x

    else if p.pos.x + p.radius > @max.x
      # Right
      p.pos.x = @max.x - p.radius
      p.old.pos.x = p.pos.x + p.vel.x

    if p.pos.y - p.radius < @min.y
      # Top
      p.pos.y = @min.y + p.radius
      p.old.pos.y = p.pos.y + p.vel.y

    else if p.pos.y + p.radius > @max.y
      if p is @ball
        # Bottom
        console.log 'out'
        @missed()


class FragmentEffects
  constructor: ->
    @stage = new createjs.Stage 'fragment_canvas'
    @canvas = $('#fragment_canvas')
    createjs.Ticker.addEventListener 'tick', @handleTick

  handleTick: =>
    i = 0
    while i < @stage.getNumChildren()
      frag = @stage.getChildAt i

      frag.x += frag.vel.x
      frag.y += frag.vel.y
      frag.alpha -= 0.1

      if frag.x > @canvas.width() or frag.x < 0
        frag.vel.x = -frag.vel.x

      if frag.y > @canvas.height() or frag.y < 0
        frag.vel.y = -frag.vel.y

      if frag.alpha <= 0
        @stage.removeChildAt i

      @stage.update()
      i += 1

  makeExplosion: (pos) =>
    console.log 'explsotion!'
    for i in [1..30]
      circle = new createjs.Shape()
      col = -> Math.round(Math.random() * 255)
      circle.graphics.beginFill("rgb(#{col()},#{col()},#{col()})").drawCircle 0, 0, 5
      circle.x = pos.x
      circle.y = pos.y

      # now to set the random velocity
      angle = Math.random() * 360 * (Math.PI / 180)
      mag = Math.random() * 15
      circle.vel =
        x: Math.cos(angle) * mag
        y: Math.sin(angle) * mag

      @stage.addChild circle

class App
  constructor: ->
    video = document.getElementById("video")

    tracking.ColorTracker.registerColor 'redish', (r, g, b) ->
      return r > 100 and g < 30 and b < 30

    tracker = new tracking.ColorTracker("redish")
    # can also use custom colours
    # See http://trackingjs.com/api/ColorTracker.js.html#line366

    tracking.track "#video", tracker,
      camera: true

    tracker.on "track", @onTrackEvent

    @fragment_effects = new FragmentEffects()

    # Create a physics instance which uses the Verlet integration method
    @physics = new Physics
    @physics.viscosity = 0

    @physics.integrator = new Verlet()

    # Use Sketch.js to make life much easier
    canvas_scale = 0.5

    @game = Sketch.create
      autopause: false
      fullscreen: false
      width: $('body').width() * canvas_scale
      height: $('body').height() * canvas_scale

    @game.scale = 1 / canvas_scale
    @game.setup = @gameSetup
    @game.draw = @gameDraw

    @state = 'waiting'

  gameSetup: =>

    up = new Vector(0.0, -100.0)
    antiGravity = new ConstantForce(up)
    @ball = new Ball(0.5)

    # powerups
    # ball_attraction = new Attraction @ball.pos, 200, 2000
    # ball_repulsion = new Attraction @ball.pos, 200, -2000
    # top_middle = new Vector(@game.width / 2, -100.0)
    # top_attraction = new Attraction top_middle, 500, 2000

    @collision = new CustomCollision(true, @onCollision)

    # Bounce off edges, with padding
    bound = 10.0
    min = new Vector bound, bound
    max = new Vector @game.width - bound, @game.height - bound
    edge = new EdgeBouncy min, max
    edge.missed = @onMissed
    paddleedges = new EdgeBounce min, max

    # Keep balls in top third
    tophalfmax = new Vector @game.width - bound, @game.height / 3
    tophalf = new EdgeBounce min, tophalfmax

    # Particle colours
    PARTICLE_COLOURS = [
      'DC0048',
      'F14646',
      '4AE6A9',
      '7CFF3F',
      '4EC9D9',
      'E4272E'
    ]

    ################################
    # Set up particles
    for i in [0..NUM_BALLS]

      size = BALL_SIZE_MIN + Math.random() * BALL_SIZE_VARIANCE
      particle = new Block(size)
      position = new Vector(random(@width), random(@height/3))
      particle.setRadius particle.mass * 8
      particle.moveTo position
      particle.colour = Random.item PARTICLE_COLOURS

      # Make it collidable
      @collision.pool.push particle

      # Apply behaviours
      particle.behaviours.push antiGravity, @collision, tophalf

      # Add to the simulation
      @physics.particles.push particle

    ################################
    # Set up ball
    @ball.setRadius @ball.mass * 8
    centre = new Vector(@game.width/2, @game.height/2)
    @ball.moveTo centre
    @ball.colour = '000000'

    # Ball behaviours
    @collision.pool.push @ball
    @ball.behaviours.push edge, @collision
    @physics.particles.push @ball

    ################################
    # Set up paddle
    @paddle = new Paddle(10)
    @paddle.setRadius 50
    bottomcentre = new Vector(@game.width/2, @game.height - 30)
    @paddle.moveTo bottomcentre
    @paddle.colour = '000000'

    # Paddle behaviour
    @collision.pool.push @paddle
    @paddlebehaviour = new PaddleBehaviour(@paddle.pos.x, @paddle.pos.y)
    @paddle.behaviours.push paddleedges, @collision, @paddlebehaviour
    @physics.particles.push @paddle

    @collision.ball = @ball
    @collision.paddle = @paddle
    edge.ball = @ball

  gameDraw: =>

    # Step the simulation
    @physics.step()

    # Draw particles
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

  onCollision: (particle, other) =>
    # ball <--> particle collision?

    @physics.particles = @physics.particles.remove particle
    @collision.pool = @collision.pool.remove particle

    @fragment_effects.makeExplosion
      x: particle.pos.x
      y: particle.pos.y

    # Delete particle
    # remove from pools
    # increment score?


  onTrackEvent: (event) =>

    if event.data.length == 0
      @target_rectangle = false
      return

    # if event.data.length > 1
    #   console.log 'multiple rectangles, choosing first'

    rect = event.data[0]
    rect.height = rect.height * @game.scale
    rect.width = rect.width * @game.scale
    rect.x = @game.width - rect.x * @game.scale - rect.width
    rect.y = rect.y * @game.scale

    @target_rectangle = rect

    if @state == 'waiting'
      @onGameStart()

  onGameStart: =>
    console.log 'Starting game'
    @state = 'playing'

    # TODO randomize initial velocity
    @ball.acc.set 4000, -4000

  onMissed: =>
    console.log 'You missed!'
    centre = new Vector(@game.width/2, @game.height/2)

    @ball.moveTo centre
    @state = 'waiting'
    # ballbehaviour = new BallSpeed()
    # @ball.behaviours.push

$ ->
  window.app = new App()

$(window).unload ->
  window.app.unload()
