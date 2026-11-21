shader_type spatial;

uniform vec4 base : source_color = vec4(0.5, 0.48, 0.43, 1.0);
uniform int surface_kind = 0;
varying vec3 point_world;
varying vec3 normal_world;

float hash_cell(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_grid(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1, 0)), f.x),
               mix(hash_cell(cell + vec2(0, 1)), hash_cell(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
    point_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec2 p = point_world.xz;
    if (abs(normal_world.y) < 0.55) {
        p = vec2(abs(normal_world.x) > abs(normal_world.z) ? point_world.z : point_world.x, point_world.y);
    }
    float base_noise = noise_grid(p * 2.8) - 0.5;
    float grain = noise_grid(p * 36.0) - 0.5;
    float color_factor = 1.0 + base_noise * 0.14 + grain * 0.10;
    if (surface_kind == 0) {
        float patches = noise_grid(p * 0.27);
        color_factor -= smoothstep(0.56, 0.82, patches) * 0.19;
        color_factor -= smoothstep(0.68, 0.91, noise_grid(p * vec2(1.1, 0.075))) * 0.14;
    } else {
        vec2 tile = p / (surface_kind == 1 ? vec2(0.52, 0.30) : vec2(0.95, 0.32));
        tile.x += mod(floor(tile.y), 2.0) * 0.5;
        vec2 edge = min(fract(tile), 1.0 - fract(tile));
        float joint = 1.0 - smoothstep(0.015, 0.048, min(edge.x, edge.y));
        color_factor += (hash_cell(floor(tile)) - 0.5) * 0.24;
        color_factor -= joint * 0.23;
    }
    ALBEDO = base.rgb * color_factor;
    ROUGHNESS = 0.94;
    SPECULAR = 0.22;
}
