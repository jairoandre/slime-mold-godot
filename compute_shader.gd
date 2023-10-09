# Component that is responsible for all the compute shader management.
# You need to create a .glsl file inside the project folder with an external
# text editor.
# To use this component, look the example of a compute shader above:
#
##[compute]
##version 450
#// The local_size_x number defines the number of localized "threads"
#// that will be running in parallalel per workgroup at the GPU. The workgroup
#// should be set to attend your computational needs.
#layout(local_size_x=1024,local_size_y=1,local_size_z=1)in;
#
#// Here you seet "general" parameters for the computation.
#// The binding defines the order of uniforms that will be passed by the
#// caller.
#layout(set=0,binding=0,std430)restrict buffer Params{
#  float delta;
#}params;
#
#// In this example, we are reading the input as a texture image and store
#// the results as an image as well.
#layout(rgba32f,binding=1)uniform image2D data_input;
#layout(rgba32f,binding=2)uniform image2D data_output;
#
#// This function is to determine the coords (x,y) of the texture input.
#ivec2 to_coord(int index,int size_x){
#  int x=index%size_x;
#  int y=index/size_x;
#  return ivec2(x,y);
#}
#
#// The output coords.
#ivec2 to_out_coord(vec2 pos,ivec2 size){
#  return ivec2(int(pos.x*float(size.x)),int(pos.y*float(size.y)));
#}
#
#float wrap_pos(float v){
#  return v>1?0:v<0?1:v;
#}
#
#void main(){
#  ivec2 size=imageSize(data_input);
#  int total_particles=size.x*size.y;
#  int index=int(gl_GlobalInvocationID.x);
#  if(index>=total_particles){
#    return;
#  }
#  ivec2 coord=to_coord(index,size.x);
#  vec4 agent=imageLoad(data_input,coord);
#  vec2 pos=agent.rg; // the position of the agent is stored on the RG component
#  float a=agent.b; // The face angle of the agent is stored on the B component
#  pos+=vec2(.1*cos(a),.1*sin(a))*params.delta;
#  pos.x=wrap_pos(pos.x);
#  pos.y=wrap_pos(pos.y);
#  ivec2 out_coord=to_out_coord(pos,imageSize(data_ouput));
#  agent.rg=pos;
#  agent.b=a;
#  vec3 col=vec3(1.);
#  imageStore(data_input,coord,agent); // Update the input for the next interation
#  imageStore(data_output,out_coord,vec4(col,agent.a)); // Store the result on the output
#}
class_name ComputeShader
extends Node2D

var filename: String
var bindings: Array[RDUniform]
var buffers: Array[RID]
var shader : RID
var rd : RenderingDevice

# Called when the node enters the scene tree for the first time.
func _ready():
    rd = RenderingServer.create_local_rendering_device()
    bindings = []
    buffers = []

func _create_params_buffer(arr: Array[float]):
    var params_bytes : PackedByteArray = PackedFloat32Array(arr).to_byte_array()
    return rd.storage_buffer_create(params_bytes.size(), params_bytes)
    
func _add_params(arr: Array[float], binding: int):
    var params_uniform = RDUniform.new()
    params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    params_uniform.binding = binding
    var params_buffer = _create_params_buffer(arr)
    params_uniform.add_id(params_buffer)
    bindings.append(params_uniform)
    buffers.append(params_buffer)

func _update_params(arr: Array[float], seq: int):
    var params_bytes : PackedByteArray = PackedFloat32Array(arr).to_byte_array()
    var params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
    bindings[seq].clear_ids()
    bindings[seq].add_id(params_buffer)
    var old_buffer = buffers[seq]
    rd.free_rid(old_buffer)
    buffers[seq] = params_buffer

func _create_fmt(size):
    var fmt = RDTextureFormat.new()
    fmt.width = size.x
    fmt.height = size.y
    fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
    fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    return fmt

func _create_image_buffer(image):
    return rd.texture_create(_create_fmt(image.get_size()), RDTextureView.new(), [image.get_data()])
        
func _add_image(image: Image, binding: int):
    var buffer = _create_image_buffer(image)
    var uniform = RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    uniform.binding = binding
    uniform.add_id(buffer)
    bindings.append(uniform)
    buffers.append(buffer)
    
func _update_image(image: Image, seq: int):
    var buffer = _create_image_buffer(image)
    bindings[seq].clear_ids()
    bindings[seq].add_id(buffer)
    var old_buffer = buffers[seq]
    rd.free_rid(old_buffer)
    buffers[seq] = buffer

func _read_image_buffer(seq: int, size: Vector2i):
    var image_data = rd.texture_get_data(buffers[seq], 0)
    return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAF, image_data)

func _load_shader():
    var shader_file = load(filename) 
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
    shader = rd.shader_create_from_spirv(shader_spirv)
    
func _run(count_number):
    var uniform_set = rd.uniform_set_create(bindings, shader, 0)
    var pipeline = rd.compute_pipeline_create(shader)
    var compute_list = rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    var x_groups = count_number / 1024
    if count_number % 1024 > 0:
        x_groups += 1
    rd.compute_list_dispatch(compute_list, x_groups, 1, 1)
    rd.compute_list_end()
    rd.submit()

func _await():
    rd.sync()
