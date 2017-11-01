-- render this to a fullscreen plane
-- example:
-- local magic = lovr.graphics.newTexture(1, 1)
-- magic:renderTo(function() lovr.graphics.clear() end)
-- function lovr.draw()
-- 	lovr.graphics.setShader(require "sky")
-- 	lovr.graphics.plane(magic)
-- 	lovr.graphics.setShader()
-- end
return function()
  return lovr.graphics.newShader([[
  out vec3 v_position;

  uniform mat4 u_inv_view_proj;

  vec4 position(mat4 proj, mat4 transform, vec4 vertex) {
  	v_position = (inverse(proj * transform) * vec4(vertex.x, vertex.y, 1.0, 1.0)).xyz;
  	return vertex;
  }
  ]], [[
  in vec3 v_position;

  // make this a uniform in your own thing
  vec3 u_light_direction = vec3(-1.0, 1.0, 0.0);

  const vec3 luma = vec3(0.299, 0.587, 0.114);
  const vec3 cameraPos = vec3(0.0, 0.0, 0.0);
  const float luminance = 1.05;
  const float turbidity = 8.0;
  const float reileigh = 2.0;
  const float mieCoefficient = 0.005;
  const float mieDirectionalG = 0.8;
  const float e = 2.71828182845904523536028747135266249775724709369995957;
  const float pi = 3.141592653589793238462643383279502884197169;
  const float n = 1.0003;
  const float N = 2.545E25;
  const float pn = 0.035;
  const vec3 lambda = vec3(680E-9, 550E-9, 450E-9);
  const vec3 K = vec3(0.686, 0.678, 0.666);
  const float v = 4.0;
  const float rayleighZenithLength = 8.4E3;
  const float mieZenithLength = 1.25E3;
  const vec3 up = vec3(0.0, 1.0, 0.0);
  const float EE = 1000.0;
  const float sunAngularDiameterCos = 0.99996192306417; // probably correct size
  const float steepness = 1.5;
  vec3 Tonemap_ACES(vec3 x) {
  	float a = 2.51;
  	float b = 0.03;
  	float c = 2.43;
  	float d = 0.59;
  	float e = 0.14;
  	return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
  }
  vec3 totalRayleigh(vec3 lambda) {
  	return (8.0 * pow(pi, 3.0) * pow(pow(n, 2.0) - 1.0, 2.0) * (6.0 + 3.0 * pn)) / (3.0 * N * pow(lambda, vec3(4.0)) * (6.0 - 7.0 * pn));
  }
  vec3 simplifiedRayleigh() {
  	return 0.0005 / vec3(94.0, 40.0, 18.0);
  }
  float rayleighPhase(float cosTheta) {
  	return (3.0 / (16.0*pi)) * (1.0 + pow(cosTheta, 2.0));
  }
  vec3 totalMie(vec3 lambda, vec3 K, float T) {
  	float c = (0.2 * T ) * 10E-18;
  	return 0.434 * c * pi * pow((2.0 * pi) / lambda, vec3(v - 2.0)) * K;
  }
  float hgPhase(float cosTheta, float g) {
  	return (1.0 / (4.0*pi)) * ((1.0 - pow(g, 2.0)) / pow(1.0 - 2.0*g*cosTheta + pow(g, 2.0), 1.5));
  }
  float sunIntensity(float zenithAngleCos) {
  	float cutoffAngle = pi/1.95;
  	return EE * max(0.0, 1.0 - pow(e, -((cutoffAngle - acos(zenithAngleCos))/steepness)));
  }
  vec4 color(vec4 _c, sampler2D _i, vec2 _u) {
  	float sunfade = 1.0-clamp(1.0-exp((u_light_direction.y/450000.0)),0.0,1.0);
  	float reileighCoefficient = reileigh - (1.0* (1.0-sunfade));
  	vec3 sunDirection = normalize(u_light_direction);
  	float sunE = sunIntensity(dot(sunDirection, up));
  	vec3 betaR = simplifiedRayleigh() * reileighCoefficient;
  	vec3 betaM = totalMie(lambda, K, turbidity) * mieCoefficient;
  	float zenithAngle = acos(max(0.0, dot(up, normalize(v_position.xyz - cameraPos))));
  	float sR = rayleighZenithLength / (cos(zenithAngle) + 0.15 * pow(93.885 - ((zenithAngle * 180.0) / pi), -1.253));
  	float sM = mieZenithLength / (cos(zenithAngle) + 0.15 * pow(93.885 - ((zenithAngle * 180.0) / pi), -1.253));
  	vec3 Fex = exp(-(betaR * sR + betaM * sM));
  	float cosTheta = dot(normalize(v_position.xyz - cameraPos), sunDirection);
  	float rPhase = rayleighPhase(cosTheta*0.5+0.5);
  	vec3 betaRTheta = betaR * rPhase;
  	float mPhase = hgPhase(cosTheta, mieDirectionalG);
  	vec3 betaMTheta = betaM * mPhase;
  	vec3 Lin = pow(sunE * ((betaRTheta + betaMTheta) / (betaR + betaM)) * (1.0 - Fex),vec3(1.5));
  	Lin *= mix(vec3(1.0),pow(sunE * ((betaRTheta + betaMTheta) / (betaR + betaM)) * Fex,vec3(1.0/2.0)),clamp(pow(1.0-dot(up, sunDirection),5.0),0.0,1.0));
  	vec3 direction = normalize(v_position.xyz - cameraPos);
  	float theta = acos(direction.y); // elevation --> y-axis, [-pi/2, pi/2]
  	float phi = atan(direction.z/direction.x); // azimuth --> x-axis [-pi/2, pi/2]
  	vec3 L0 = vec3(0.1) * Fex;
  	float sundisk = smoothstep(sunAngularDiameterCos,sunAngularDiameterCos+0.001,cosTheta);
  	L0 += (sunE * 19000.0 * Fex)*sundisk;
  	vec3 texColor = (Lin+L0);
  	texColor *= 0.04;
  	texColor += vec3(0.0,0.001,0.0025)*0.3;
  	vec3 color = (log2(2.0/pow(luminance,4.0)))*texColor;
  	vec3 retColor = pow(color,vec3(1.0/(1.2+(1.2*sunfade))));
  	retColor = mix(retColor * 0.75, retColor, clamp(dot(direction, up) * 0.5 + 0.5, 0.0, 1.0));
  	retColor = pow(retColor * 0.75, vec3(2.2));
  	retColor *= exp2(-1.);
  	vec3 white = Tonemap_ACES(vec3(1000.0));
  	retColor = Tonemap_ACES(retColor)*white;
  	return vec4(retColor, 1.0);
  }
  ]])
end
