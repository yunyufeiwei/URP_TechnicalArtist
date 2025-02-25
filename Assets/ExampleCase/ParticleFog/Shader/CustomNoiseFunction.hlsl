#ifndef CUSTOMNOISEFUNCTION_INCLUDE
#define CUSTOMNOISEFUNCTION_INCLUDE

inline float noise_randomValue (float2 uv) { return frac(sin(dot(uv, float2(12.9898, 78.233)))*43758.5453); }
inline float noise_interpolate (float a, float b, float t) { return (1.0-t)*a + (t*b); }
inline float valueNoise (float2 uv)
{
	float2 i = floor(uv);
	float2 f = frac( uv );
	f = f* f * (3.0 - 2.0 * f);
	uv = abs( frac(uv) - 0.5);
	float2 c0 = i + float2( 0.0, 0.0 );
	float2 c1 = i + float2( 1.0, 0.0 );
	float2 c2 = i + float2( 0.0, 1.0 );
	float2 c3 = i + float2( 1.0, 1.0 );
	float r0 = noise_randomValue( c0 );
	float r1 = noise_randomValue( c1 );
	float r2 = noise_randomValue( c2 );
	float r3 = noise_randomValue( c3 );
	float bottomOfGrid = noise_interpolate( r0, r1, f.x );
	float topOfGrid = noise_interpolate( r2, r3, f.x );
	float t = noise_interpolate( bottomOfGrid, topOfGrid, f.y );
	return t;
}

//计算一个噪声纹理，需要传入一个uv
float SimpleNoise(float2 UV)
{
	float t = 0.0;
	float freq = pow( 2.0, float( 0 ) );
	float amp = pow( 0.5, float( 3 - 0 ) );
	t += valueNoise( UV/freq )*amp;
	freq = pow(2.0, float(1));
	amp = pow(0.5, float(3-1));
	t += valueNoise( UV/freq )*amp;
	freq = pow(2.0, float(2));
	amp = pow(0.5, float(3-2));
	t += valueNoise( UV/freq )*amp;
	return t;
}

float3 mod3D289( float3 x ) { return x - floor( x / 289.0 ) * 289.0; }
float4 mod3D289( float4 x ) { return x - floor( x / 289.0 ) * 289.0; }
float4 permute( float4 x ) { return mod3D289( ( x * 34.0 + 1.0 ) * x ); }
float4 taylorInvSqrt( float4 r ) { return 1.79284291400159 - r * 0.85373472095314; }
float snoise( float3 v )
{
	const float2 C = float2( 1.0 / 6.0, 1.0 / 3.0 );
	float3 i = floor( v + dot( v, C.yyy ) );
	float3 x0 = v - i + dot( i, C.xxx );
	float3 g = step( x0.yzx, x0.xyz );
	float3 l = 1.0 - g;
	float3 i1 = min( g.xyz, l.zxy );
	float3 i2 = max( g.xyz, l.zxy );
	float3 x1 = x0 - i1 + C.xxx;
	float3 x2 = x0 - i2 + C.yyy;
	float3 x3 = x0 - 0.5;
	i = mod3D289( i);
	float4 p = permute( permute( permute( i.z + float4( 0.0, i1.z, i2.z, 1.0 ) ) + i.y + float4( 0.0, i1.y, i2.y, 1.0 ) ) + i.x + float4( 0.0, i1.x, i2.x, 1.0 ) );
	float4 j = p - 49.0 * floor( p / 49.0 );  // mod(p,7*7)
	float4 x_ = floor( j / 7.0 );
	float4 y_ = floor( j - 7.0 * x_ );  // mod(j,N)
	float4 x = ( x_ * 2.0 + 0.5 ) / 7.0 - 1.0;
	float4 y = ( y_ * 2.0 + 0.5 ) / 7.0 - 1.0;
	float4 h = 1.0 - abs( x ) - abs( y );
	float4 b0 = float4( x.xy, y.xy );
	float4 b1 = float4( x.zw, y.zw );
	float4 s0 = floor( b0 ) * 2.0 + 1.0;
	float4 s1 = floor( b1 ) * 2.0 + 1.0;
	float4 sh = -step( h, 0.0 );
	float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	float3 g0 = float3( a0.xy, h.x );
	float3 g1 = float3( a0.zw, h.y );
	float3 g2 = float3( a1.xy, h.z );
	float3 g3 = float3( a1.zw, h.w );
	float4 norm = taylorInvSqrt( float4( dot( g0, g0 ), dot( g1, g1 ), dot( g2, g2 ), dot( g3, g3 ) ) );
	g0 *= norm.x;
	g1 *= norm.y;
	g2 *= norm.z;
	g3 *= norm.w;
	float4 m = max( 0.6 - float4( dot( x0, x0 ), dot( x1, x1 ), dot( x2, x2 ), dot( x3, x3 ) ), 0.0 );
	m = m* m;
	m = m* m;
	float4 px = float4( dot( x0, g0 ), dot( x1, g1 ), dot( x2, g2 ), dot( x3, g3 ) );
	return 42.0 * dot( m, px);
}

float2 voronoihash2( float2 p )
{
	
	p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
	return frac( sin( p ) *43758.5453);
}

float voronoi2( float2 v, float time, inout float2 id, inout float2 mr, float smoothness, inout float2 smoothId )
{
	float2 n = floor( v );
	float2 f = frac( v );
	float F1 = 8.0;
	float F2 = 8.0; float2 mg = 0;
	for ( int j = -1; j <= 1; j++ )
	{
		for ( int i = -1; i <= 1; i++ )
		{
			float2 g = float2( i, j );
			float2 o = voronoihash2( n + g );
			o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
			float d = 0.5 * dot( r, r );
			if( d<F1 ) {
				F2 = F1;
				F1 = d; mg = g; mr = r; id = o;
			} else if( d<F2 ) {
				F2 = d;
	
			}
		}
	}
	return (F2 + F1) * 0.5;
}

#endif
