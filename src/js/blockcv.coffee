BLOCK_SIZE_MIN = 10
BLOCK_SIZE_MAX = 30
NUM_BLOCKS = 40

BALL_SIZE = 15
BALL_MASS = 1
BALL_INITIAL_SPEED = 20000

PADDLE_WIDTH = 200

SPHERE_RESOLUTION = 10

Array::remove = (obj) ->
  @filter (el) -> el isnt obj


PARTICLE_COLOURS = [
  0xDC0048,
  0xF14646,
  0x4AE6A9,
  0x7CFF3F,
  0x4EC9D9,
  0xE4272E
]

PARTICLE_MATERIALS = (new THREE.MeshPhongMaterial({color: c}) for c in PARTICLE_COLOURS)

class Block extends Particle
  constructor: () ->

    radius = BLOCK_SIZE_MIN + Math.random() * (BLOCK_SIZE_MAX - BLOCK_SIZE_MIN)
    mass = Math.sqrt (radius / 8)
    @fragility = 1 # + Math.floor ( Math.random() * 5 )

    # ThreeJS stuff
    material = Random.item PARTICLE_MATERIALS

    super mass

    @setRadius radius
    geometry = new THREE.SphereGeometry(@radius, SPHERE_RESOLUTION, SPHERE_RESOLUTION)
    @mesh = new THREE.Mesh(geometry, material)
    position = new Vector(random(app.game.width), random(app.game.height / 3))
    @moveTo position

class Paddle extends Particle

  constructor: ->
    height = 20

    super 10
    @setRadius PADDLE_WIDTH / 2

    geometry = new THREE.BoxGeometry(PADDLE_WIDTH, height, 1)
    material = new THREE.MeshPhongMaterial({color: 0x000000})
    @mesh = new THREE.Mesh(geometry, material)

    bottomcentre = new Vector(app.game.width / 2, app.game.height - 30)
    @moveTo bottomcentre


class Ball extends Particle
  constructor: () ->
    radius = BALL_SIZE
    super BALL_MASS

    # black ball
    material = new THREE.MeshPhongMaterial({color: 0x000000})
    geometry = new THREE.SphereGeometry(radius, SPHERE_RESOLUTION, SPHERE_RESOLUTION)
    @mesh = new THREE.Mesh(geometry, material)

    @setRadius radius
    centre = new Vector(app.game.width/2, app.game.height/2)
    @moveTo centre

class AttractionPowerup extends Attraction
  constructor: ->
    @enabled = false
    @enabled_time = 0
    super

  apply: ->
    if Date.now() - @enabled_time > 10000
      @enabled = false

    if @enabled then super else undefined

  setEnabled: ->
    @enabled = true
    @enabled_time = Date.now()

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


# class EaselStage
#   constructor: (game)->
#     @game = game
#     @stage = new createjs.Stage 'fragment_canvas'

#     @scoreCounter = new createjs.Text "", "36px Arial", "black"
#     @scoreCounter.x = @scoreCounter.y = 10
#     @stage.addChild @scoreCounter

#     @canvas = $('#fragment_canvas')
#     createjs.Ticker.addEventListener 'tick', @handleTick

#   updateScoreCounter: =>
#     @scoreCounter.text = "#{@game.score} points"

#   handleTick: =>
#     @updateScoreCounter()
#     setTimeout =>
#       i = 0
#       while i < @stage.getNumChildren()
#         frag = @stage.getChildAt i
#         if frag.text?
#           i += 1
#           continue

#         frag.x += frag.vel.x
#         frag.y += frag.vel.y
#         frag.alpha -= 0.1

#         if frag.x > @canvas.width() or frag.x < 0
#           frag.vel.x = -frag.vel.x

#         if frag.y > @canvas.height() or frag.y < 0
#           frag.vel.y = -frag.vel.y

#         if frag.alpha <= 0
#           @stage.removeChildAt i

#         @stage.update()
#         i += 1
#     , 0

#   makeExplosion: (pos) =>
#     setTimeout =>
#       for i in [1..30]
#         if @stage.getNumChildren() > 50
#           return
#         circle = new createjs.Shape()
#         col = -> Math.round(Math.random() * 255)
#         circle.graphics.beginFill("rgb(#{col()},#{col()},#{col()})").drawCircle 0, 0, 5
#         circle.x = pos.x
#         circle.y = pos.y

#         # now to set the random velocity
#         angle = Math.random() * 360 * (Math.PI / 180)
#         mag = Math.random() * 15
#         circle.vel =
#           x: Math.cos(angle) * mag
#           y: Math.sin(angle) * mag

#         @stage.addChild circle
#     , 0

class App
  constructor: ->
    video = document.getElementById("video")


    tracking.ColorTracker.registerColor 'redish', (r, g, b) ->
      return r > 80 and g < 50 and b < 50

    tracker = new tracking.ColorTracker("redish")
    # can also use custom colours
    # See http://trackingjs.com/api/ColorTracker.js.html#line366

    tracking.track "#video", tracker,
      camera: true

    tracker.on "track", @onTrackEvent

    @score = 0

    # Create a physics instance which uses the Verlet integration method
    @physics = new Physics
    @physics.viscosity = 0
    @physics.integrator = new Verlet

    canvas_scale = 1

    # Use Sketch.js to make life much easier
    @game = Sketch.create
      autopause: false
      fullscreen: false
      width: $('body').width() / canvas_scale
      height: $('body').height() / canvas_scale

    $('#fragment_canvas').attr('height', @game.height)
    $('#fragment_canvas').attr('width', @game.width)

    # Three.JS scene
    aspect = @game.width / @game.height
    @camera = new THREE.OrthographicCamera(0, @game.width, 0, @game.height, 1, 10000)
    # @camera = new THREE.PerspectiveCamera(60, aspect, 1, 10000)
    @camera.position.z = 1000

    @scene = new THREE.Scene()
    @camera.lookAt @scene.position
    @scene.add @camera

    # Lighting
    ambientlight = new THREE.AmbientLight(0x000044)
    @scene.add ambientlight
    @pointlight = new THREE.PointLight(0xffffff)
    @pointlight.position.set(@game.width / 2, -500, -500)
    @scene.add @pointlight

    @renderer = new THREE.WebGLRenderer(alpha: true)
    @renderer.setSize @game.width, @game.height
    @renderer.sortObjects = false
    container = document.getElementById "threejs"
    container.appendChild @renderer.domElement

    @game.scale = 5 / canvas_scale
    @game.setup = @gameSetup
    @game.draw = @gameDraw


    @state = 'waiting'

  gameSetup: =>

    up = new Vector(0.0, -100.0)
    antiGravity = new ConstantForce(up)
    @ball = new Ball()

    # powerups
    @ball_attraction = new AttractionPowerup @ball.pos, 200, 2000
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


    ################################
    # Set up particles
    for i in [0..NUM_BLOCKS]

      particle = new Block()
      @scene.add particle.mesh

      # Make it collidable
      @collision.pool.push particle

      # Apply behaviours
      particle.behaviours.push antiGravity, @collision, tophalf, @ball_attraction

      # Add to the simulation
      @physics.particles.push particle

    ################################

    # Ball behaviours
    @scene.add @ball.mesh
    @collision.pool.push @ball
    @ball.behaviours.push edge, @collision
    @physics.particles.push @ball

    ################################
    # Set up paddle
    @paddle = new Paddle()
    @scene.add @paddle.mesh

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

    # Update particle positions
    for p in @physics.particles

      p.mesh.position.x = p.pos.x
      p.mesh.position.y = p.pos.y
      p.mesh.position.z = 0
      p.mesh.matrixAutoUpdate = false
      p.mesh.updateMatrix()

    # Render blocks in 3d
    @renderer.render @scene, @camera

    # Draw paddle
    # p = @paddle
    # @game.strokeStyle = 'rgba(0,0,0,1)'
    # @game.lineWidth = 10
    # @game.moveTo(p.pos.x - p.radius, p.pos.y)
    # @game.lineTo(p.pos.x + p.radius, p.pos.y)
    # @game.stroke()

    # rectangle position
    if @target_rectangle
      @game.strokeStyle = 'magenta'
      @game.lineWidth = 1
      rect = @target_rectangle
      @game.strokeRect rect.x, rect.y, rect.width, rect.height
      @paddlebehaviour.desired_x = rect.x + rect.width / 2

  onCollision: (particle, other) =>
    # ball <--> particle collision

    # particle.fragility -= 1 # Ball loses health!
    # particle.mesh.scale.x = 0.5  # -= 1 / particle.fragility?
    # if particle.fragility > 0
      # return

    @physics.particles = @physics.particles.remove particle
    @scene.remove particle.mesh
    @collision.pool = @collision.pool.remove particle

    @score += 1

    # @easel_stage.makeExplosion
    #   x: particle.pos.x
    #   y: particle.pos.y

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

    # TODO randomize initial direction
    @ball.acc.set BALL_INITIAL_SPEED, -BALL_INITIAL_SPEED

  onMissed: =>
    console.log 'You missed!'
    centre = new Vector(@game.width/2, @game.height/2)

    @ball.moveTo centre
    @state = 'waiting'
    # ballbehaviour = new BallSpeed()
    # @ball.behaviours.push
    #
  onResize: =>
    console.log 'Resize!'
    view = document.getElementById 'game_viewer'
    view.webkitRequestFullscreen()

$ ->
  window.app = new App()
  document.addEventListener 'resize', app.onResize
  document.addEventListener 'click', app.onResize

$(window).unload ->
  window.app.unload()
