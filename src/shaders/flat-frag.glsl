#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const int RAY_STEPS = 100;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
const float PI = 3.14159;

// Shapes
// Capped Cylinder
float cappedCylinderSDF(vec3 p, vec2 h)
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

// rotation
vec2 rot(vec2 v, float y){
    return cos(y)*v + sin(y)*vec2(-v.y, v.x);
}

//Substraction 
// d1 - d2
float subOp( float d1, float d2 ){
    return max(-d1,d2);
}

// Min, pick color of closest object
// pick the vector for the closests object so you grab the correct color along with position
vec3 minVec(vec3 a, vec3 b){
    if (a.x < b.x) {
        return a;
    }
    return b;
}

// toolbox function
float sawtoothWave(float x, float freq, float amp){
  return (x * freq - floor(x * freq)) * amp;
}

vec3 sceneSDF(vec3 point){  
  
  float rotateControl = u_Time * 0.2;
  float sawtooth = sawtoothWave(sin(u_Time * 0.04), 2.0, 4.0) ;
  
  // red coin
  vec3 q = point - vec3(0.0, 0.0, 0.0);
  vec3 redCoinOffset = vec3(0.0, 0.0, 0.0);
  q.xy = rot(q.xy, 1.5708);  
  q.yz = rot(q.yz, rotateControl * -0.25);
  float coinRed = cappedCylinderSDF(q - vec3(0.0, 0.4, 0.0) + redCoinOffset, vec2(1.0, 0.4));
  float s1 = cappedCylinderSDF(q + redCoinOffset , vec2(0.5, 0.2));
  float s2 = cappedCylinderSDF(q - vec3(0.0, 0.8, 0.0) + redCoinOffset, vec2(0.5, 0.2));
  coinRed = subOp(s1, coinRed);
  coinRed = subOp(s2, coinRed);

  // drawing and coloring  
  vec3 temp = vec3(coinRed, 9.0, 0.0);
  return temp;
}

// calculate normals
vec3 getNormals(vec3 pos) {
   vec3 eps = vec3(0.0, 0.001, 0.0);
    vec3 normals =  normalize(vec3(
        sceneSDF(vec3(pos + eps.yxz)).x - sceneSDF(vec3(pos - eps.yxz)).x,
        sceneSDF(vec3(pos + eps.xyz)).x - sceneSDF(vec3(pos - eps.xyz)).x,
        sceneSDF(vec3(pos + eps.xzy)).x - sceneSDF(vec3(pos - eps.xzy)).x
    ));
   return normals;
}

vec3 march(vec3 origin, vec3 marchDir, float start, float end){
  float t = 0.001;
  vec3 temp = vec3(0.0);
  float dist = 0.0;
  float colorID = 0.0;
  float depth = start;
      
  for (int i = 0; i < RAY_STEPS; i ++){
    vec3 pos = origin + depth * marchDir;
    //dist = bvhFunc(u_Eye, marchDir, boxes);
    temp = sceneSDF(pos);
    dist = temp.x; // the minimum distance
    colorID = temp.y; // the color ID
    if(dist < EPSILON){
      //return t;
      return vec3(depth, colorID, 0.0);
    }
    depth += dist;
    if(depth >= end){
      return vec3(end, colorID, 0.0);
    }
  } // closes for loop

  return vec3(end, colorID, 0.0);

}

vec3 getColor(float id, float lightMult, float specVal, vec3 point) {
  vec3 coloring = vec3(0.0);
        
    // Chomp - black, no specular
    if (id == 1.0){
        coloring = vec3(0.0431, 0.0549, 0.0) * lightMult;
        return coloring;
    }
    // Specular black
    if (id == 1.5){
        coloring = vec3(0.0431, 0.0549, 0.0) * lightMult + specVal;
        return coloring;
    }    
    // red coin color
    if (id == 9.0){
        coloring = vec3(0.7529, 0.1686, 0.1451) * lightMult + specVal;
        return coloring;
    }
    
    return vec3(id / 10.0);
}

void main() {
  // Casting Rays
  vec3 rightVec = normalize(cross((u_Ref - u_Eye), u_Up));
  float FOV = 45.0; // field of view
  float len = length(u_Ref - u_Eye);
  vec3 V = u_Up * len * tan(FOV/2.0);
  vec3 H = rightVec * len * (u_Dimensions.x / u_Dimensions.y) * tan(FOV/2.0);

  vec3 pixel = u_Ref + (fs_Pos.x*H) + (fs_Pos.y*V);
  vec3 dir = normalize(pixel - u_Eye);
  vec3 color = 0.5 * (dir + vec3(1.0, 1.0, 1.0)); // test rays    
  
  // ray marching
  vec3 marchVals = march(u_Eye, dir, MIN_DIST, MAX_DIST);

  float dist = marchVals.x;
  float colorVal = marchVals.y;
  
  if(dist > 100.0 - EPSILON){
    // not in the shape - color the background     
    vec3 color = 0.5 * (dir + vec3(1.0, 1.0, 1.0)); // for checking correct rays
    out_Col = vec4(color, 1.0);    
    return;
  } 

  // Lighting
  vec3 normals = getNormals(u_Eye + marchVals.x * dir);

  vec3 lightVector = u_Eye; 

  // h is the average of the view and light vectors
  vec3 h = (u_Eye + u_Eye) / 2.0;

  // specular intensity
  float specularInt = max(pow(dot(normalize(h), normalize(normals)), 23.0) , 0.0);  

  vec3 theColor = vec3(1.0, 0.0, 0.0); 
  // dot between normals and light direction
  float diffuseTerm = dot(normalize(normals), normalize(lightVector)); 
  // Avoid negative lighting values 
  diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);
    
  float ambientTerm = 0.2;
  float lightIntensity = diffuseTerm + ambientTerm;

  out_Col = vec4(getColor(colorVal, lightIntensity, specularInt, u_Eye + marchVals.x * dir), 1.0);
  //out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  
}
