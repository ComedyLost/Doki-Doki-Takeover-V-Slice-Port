#pragma header
uniform float iTime;

//For AMD, uniform cannot have anything after its been assigned. 
uniform float warp; // simulate curvature of CRT monitor
uniform float scan; // simulate darkness between scanlines

void main()
	{
	// squared distance from center
	vec2 uv = openfl_TextureCoordv.xy;
    vec2 fragCoord = openfl_TextureCoordv*openfl_TextureSize;
    vec2 iResolution = openfl_TextureSize;

	vec2 uv2 = fragCoord/iResolution.xy;
	vec2 dc = abs(0.5-uv2);
	dc *= dc;
	
	// warp the fragment coordinates
	uv2.x -= 0.5; uv2.x *= 1.0+(dc.y*(0.7*warp)); uv2.x += 0.5;
   	uv2.y -= 0.5; uv2.y *= 1.0+(dc.x*(0.9*warp)); uv2.y += 0.5;

	// sample inside boundaries, otherwise set to black
	if (uv2.y > 1.0 || uv2.x < 0.0 || uv2.x > 1.0 || uv2.y < 0.0)
		gl_FragColor = vec4(0.0,0.0,0.0,1.0);
	else
		{
		// determine if we are drawing in a scanline
		float apply = abs(sin(fragCoord.y)*0.5*scan);
		// sample the texture
		gl_FragColor = vec4(mix(flixel_texture2D(bitmap,uv2).rgb,vec3(0.0),apply),1.0);
		}
	}
