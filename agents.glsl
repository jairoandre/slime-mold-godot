#[compute]
#version 450

layout(local_size_x=1024,local_size_y=1,local_size_z=1)in;

layout(set=0,binding=0,std430)restrict buffer Params{
  float delta;
  float agent_vel;
  float turn;
  float random_seed;
}params;

layout(rgba32f,binding=1)uniform image2D agents_data;
layout(rgba32f,binding=2)uniform image2D trail_output;
layout(rgba32f,binding=3)uniform image2D trail_state;

ivec2 to_coord(int index,int size_x){
  int x=index%size_x;
  int y=index/size_x;
  return ivec2(x,y);
}

ivec2 to_trail_coord(vec2 pos,ivec2 size){
  return ivec2(int(pos.x*float(size.x)),int(pos.y*float(size.y)));
}

float wrap_pos(float v){
  return v>1?0:v<0?1:v;
}

vec3 rgb2hsv(float h)
{
  vec3 c=vec3(h);
  vec4 K=vec4(0.,-1./3.,2./3.,-1.);
  vec4 p=mix(vec4(c.bg,K.wz),vec4(c.gb,K.xy),step(c.b,c.g));
  vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
  
  float d=q.x-min(q.w,q.y);
  float e=1.e-10;
  return vec3(abs(q.z+(q.w-q.y)/(6.*d+e)),d/(q.x+e),q.x);
}

float rand(vec2 co){
  return fract(sin(dot(co,vec2(12.9898,78.233)))*43758.5453);
}

vec3 hsv2rgb(float h)
{
  vec3 c=vec3(min(h,.95));
  vec4 K=vec4(1.,2./3.,1./3.,3.);
  vec3 p=abs(fract(c.xxx+K.xyz)*6.-K.www);
  return c.z*mix(K.xxx,clamp(p-K.xxx,0.,1.),c.y);
}

vec3 get_trail_rgb(vec2 pos,ivec2 size){
  ivec2 ipos=to_trail_coord(pos,size);
  return imageLoad(trail_state,ipos).rgb;
}

vec2 vel_vec(float vel,float angle){
  return vec2(vel*cos(angle),vel*sin(angle));
}

vec4 sensor(ivec2 coord,vec4 agent,vec3 agent_color,ivec2 size){
  float turn=params.turn;
  float vel=params.agent_vel;
  vec2 pos=agent.xy;// current position
  float frontAngle=agent.b;// angle straight
  float leftAngle=frontAngle+turn;
  float rightAngle=frontAngle-turn;
  vec2 front=pos+vel_vec(vel,frontAngle)*params.delta;
  vec2 left=pos+vel_vec(vel,leftAngle)*params.delta;
  vec2 right=pos+vel_vec(vel,rightAngle)*params.delta;
  // take color distance to guide the agent sensor
  float fd=distance(agent_color,get_trail_rgb(front,size));
  float ld=distance(agent_color,get_trail_rgb(left,size));
  float rd=distance(agent_color,get_trail_rgb(right,size));
  if(fd<ld&&fd<rd){
    return vec4(front,frontAngle,agent.a);
  }else if(rd<ld){
    return vec4(right,rightAngle,agent.a);
  }else if(ld<rd){
    return vec4(left,leftAngle,agent.a);
  }else{
    float rnd=rand(pos*params.random_seed);
    if(rnd<.33){
      return vec4(front,frontAngle,agent.a);
    }else if(rnd<.66){
      return vec4(right,rightAngle,agent.a);
    }else{
      return vec4(left,leftAngle,agent.a);
    }
  }
}

void main(){
  ivec2 size=imageSize(agents_data);
  int total_particles=size.x*size.y;
  int index=int(gl_GlobalInvocationID.x);
  if(index>=total_particles){
    return;
  }
  ivec2 coord=to_coord(index,size.x);
  vec4 agent=imageLoad(agents_data,coord);
  vec2 pos=agent.rg;
  float a=agent.b;
  vec3 agent_color=hsv2rgb(agent.a);
  //agent_color=vec3(1.,0.,0.);
  ivec2 trailImageSize=imageSize(trail_state);
  vec4 result=sensor(coord,agent,agent_color,trailImageSize);
  result.x=wrap_pos(result.x);
  result.y=wrap_pos(result.y);
  ivec2 out_coord=to_trail_coord(result.xy,trailImageSize);
  imageStore(agents_data,coord,result);
  imageStore(trail_output,out_coord,vec4(agent_color,1.));
}