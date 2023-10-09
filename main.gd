extends Node2D

@onready var display = $CanvasLayer/TextureRect
@onready var agent_shader : ComputeShader = $AgentShader
@onready var trail_shader : ComputeShader = $TrailShader

var size = 128
var n_agents = size * size
var agent_vel = 0.05;
var turn = PI/6.0
var trail_size = 1028
var n_trail_pixels = trail_size * trail_size
var agents : Image
var trail : Image
var trail_tmp : Image
var display_texture : ImageTexture
var diffuseRate = 0.1
var decayRate = 0.001
var trail_params : Array[float] = [0, diffuseRate, decayRate]
#var rd = RenderingServer.create_local_rendering_device()

# Called when the node enters the scene tree for the first time.
func _ready():
    agents = Image.create(size,size,false,Image.FORMAT_RGBAF)
    trail = Image.create(trail_size, trail_size, false, Image.FORMAT_RGBAF)
    trail_tmp = Image.create(trail_size, trail_size, false, Image.FORMAT_RGBAF)
    for i in size:
        for j in size:
            var r = randf_range(0.0, 0.15)
            var a = randf() * 2 * PI
            agents.set_pixel(i, j, Color(r * cos(a) + 0.5, r * sin(a) + 0.5, a, float(randi_range(0,5))/5.0))
    display_texture = ImageTexture.create_from_image(trail)
    display.texture = display_texture
    # Agent Shader Config
    #agent_shader.rd = rd
    agent_shader.filename = "res://agents.glsl"
    agent_shader._load_shader()
    agent_shader._add_params([0, agent_vel, turn, randf()], 0)
    agent_shader._add_image(agents, 1)
    agent_shader._add_image(trail, 2)
    agent_shader._add_image(trail_tmp,3)
    # Trail Map Shader Config
    #trail_shader.rd = rd
    trail_shader.filename = "res://trail.glsl"
    trail_shader._load_shader()
    trail_shader._add_params(trail_params, 0)
    trail_shader._add_image(trail, 1)
    trail_shader._add_image(trail_tmp, 2)
    
    # Run the agent simulation
    agent_shader._run(n_agents)
    
    
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    agent_shader._await()
    $CanvasLayer/Label.text = "FPS: %d, Count: %d, Delta: %f" % [Engine.get_frames_per_second(), n_agents, delta]
    trail = agent_shader._read_image_buffer(2, trail.get_size())
    trail_params[0] = delta
    trail_shader._update_params(trail_params, 0)
    trail_shader._update_image(trail, 1)
    trail_shader._run(n_trail_pixels)
    trail_shader._await()
    trail = trail_shader._read_image_buffer(2, trail.get_size())
    display_texture.update(trail)
    agent_shader._update_params([delta, agent_vel, turn, randf()], 0)
    agent_shader._update_image(trail, 2)
    agent_shader._update_image(trail, 3)
    agent_shader._run(n_agents)
