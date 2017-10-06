return function()
  return lovr.graphics.newShader([[
    out vec3 lightDirection;
    out vec3 normalDirection;

    uniform vec3 lightPosition = vec3(0, 10, 10);

    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      vec4 vVertex = transform * vec4(lovrPosition, 1.);
      vec4 vLight = lovrView * vec4(lightPosition, 1.);

      lightDirection = normalize(vec3(vLight - vVertex));
      normalDirection = normalize(lovrNormalMatrix * lovrNormal);

      return projection * transform * vertex;
    }
  ]], [[
    in vec3 lightDirection;
    in vec3 normalDirection;

    vec3 cAmbient = vec3(.3);
    vec3 cDiffuse = vec3(.8);
    vec3 cSpecular = vec3(.3);

    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
      float diffuse = max(dot(normalDirection, lightDirection), 0.);
      float specular = 0.;

      if (diffuse > 0.) {
        vec3 r = reflect(lightDirection, normalDirection);
        vec3 viewDirection = normalize(-vec3(gl_FragCoord));

        float specularAngle = max(dot(r, viewDirection), 0.);
        specular = pow(specularAngle, 5.);
      }

      vec3 cFinal = vec3(diffuse) * cDiffuse + vec3(specular) * cSpecular;
      cFinal = clamp(cFinal, cAmbient, vec3(1.));
      cFinal = pow(cFinal, vec3(.4545));
      return vec4(cFinal, 1.) * graphicsColor * texture(image, uv);
    }
  ]])
end
