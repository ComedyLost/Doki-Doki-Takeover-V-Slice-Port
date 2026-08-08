	#pragma header

	uniform vec3 color1;
	uniform vec3 color2;

	void main()
	{
		vec4 texture = flixel_texture2D(bitmap, openfl_TextureCoordv.xy) / openfl_Alphav;
		float alpha = texture.g * openfl_Alphav;

		vec3 color1 = color1;
		vec3 color2 = color2;

		gl_FragColor = vec4(mix(color1, color2, vec3(texture.r)) * alpha, alpha);
	}
