#pragma header
uniform float iTime;
uniform float strength;

void main()
{
vec2 uv = openfl_TextureCoordv.xy;
vec2 fragCoord = openfl_TextureCoordv*openfl_TextureSize;
vec2 iResolution = openfl_TextureSize;
    vec2 pixel_count = max(floor(iResolution.xy * vec2((cos(strength) + 1.0) / 2.0)), 1.0);
    vec2 pixel_size = iResolution.xy / pixel_count;
    vec2 pixel = (pixel_size * floor(fragCoord / pixel_size)) + (pixel_size / 1.0);
    vec2 uv2 = pixel.xy / iResolution.xy;
 
    gl_FragColor = vec4(flixel_texture2D(bitmap, uv2).xyz, 1.0);
}