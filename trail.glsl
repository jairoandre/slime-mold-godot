#[compute]
#version 450

layout(local_size_x=1024,local_size_y=1,local_size_z=1)in;

layout(set=0,binding=0,std430)restrict buffer Params{
  float delta;
  float diffuseRate;
  float decayRate;
}params;

layout(rgba32f,binding=1)uniform image2D trail_map;
layout(rgba32f,binding=2)uniform image2D trail_map_result;

ivec2 to_coord(int index,int size_x){
  int x=index%size_x;
  int y=index/size_x;
  return ivec2(x,y);
}

void main(){
  ivec2 size=imageSize(trail_map);
  int total_pixels=size.x*size.y;
  int index=int(gl_GlobalInvocationID.x);
  if(index>=total_pixels){
    return;
  }
  ivec2 coord=to_coord(index,size.x);
  vec3 sum_col=vec3(0.);
  for(int i=-1;i<=1;i++){
    for(int j=-1;j<=1;j++){
      sum_col+=imageLoad(trail_map,coord+ivec2(i,j)).rgb;
    }
  }
  sum_col/=9.;
  vec3 col=imageLoad(trail_map,coord).rgb;
  // diffuse
  col=mix(col,sum_col,params.diffuseRate);
  // decay
  col=max(vec3(0.),col-params.decayRate);
  imageStore(trail_map_result,coord,vec4(col,1.));
}

