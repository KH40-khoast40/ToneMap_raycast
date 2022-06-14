////////////////////////////////////////////////////////////////////////////////////////////////
//
// Ray-cast's tone map as a standalone effect
//
// Original code by: Rui (Ray-cast)
// References for the tone map's variations are listed below
// Ported to standalone effect by: KH40
//
////////////////////////////////////////////////////////////////////////////////////////////////

#define TONEMAP 4

// https://docs.unrealengine.com/latest/INT/Engine/Rendering/PostProcessEffects/ColorGrading/index.html
// 0 : Linear
// 1 : Reinhard     // color keeping based on luminance
// 2 : Hable	    // white point at 4 http://filmicworlds.com/blog/filmic-tonemapping-operators/
// 3 : Uncharted2   // white point at 8
// 4 : Hejl2015     // https://twitter.com/jimhejl/status/633777619998130176
// 5 : ACES-sRGB    // https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve
// 6 : NaughtyDog

//The Tr box controls how much the tone map affects the scene

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A16B16G16R16F" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_ToneMap( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) 
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float3 TonemapACES(float3 x)
{
	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
	return (x * (A * x + B)) / (x * (C * x + D) + E);
}

float3 TonemapHejl2015(float3 hdr, float whitePt) 
{
	float4 vh = float4(hdr, whitePt);
	float4 va = 1.425 * vh + 0.05;
	float4 vf = (vh * va + 0.004) / (vh * (va + 0.55) + 0.0491) - 0.0821;
	return vf.rgb / vf.www;
}

float4 TonemapHable(float4 x) 
{
	float A = 0.22;
	float B = 0.30;
	float C = 0.10;
	float D = 0.20;
	float E = 0.01;
	float F = 0.30;
	return ((x*(A*x+C*B)+D*E) / (x*(A*x+B)+D*F)) - E / F;
}

float3 TonemapNaughtyDog(float3 x)
{		
	float A = -2586.3655;
	float B =  0.6900;
	float C = -767.6706;
	float D = -8.5706;
	float E =  2.8784;
	float F =  107.4683;
	return ((x*(A*x+C*B)+D*E) / (x*(A*x+B)+D*F)) - E / F;
}

float3 TonemapReinhardLumaBased(float3 color, float whitePt)
{
	float luma = dot(color, float3(0.299f, 0.587f, 0.114f));
	float toneMappedLuma = luma * (1 + luma / (whitePt * whitePt))/ (1 + luma);
	color *= toneMappedLuma / luma;
	return color;
}

float3 ColorToneMapping(float3 color)
{
#if TONEMAP == 1
	float3 curr = TonemapReinhardLumaBased(color, 4.0);
	return saturate(curr);
#elif TONEMAP == 2
	float4 curr = TonemapHable(float4(color * 2, 4.0));
	curr = curr / curr.w;
	return saturate(curr.rgb);
#elif TONEMAP == 3
	float4 curr = TonemapHable(float4(color * 2, 8.0));
	curr = curr / curr.w;
	return saturate(curr.rgb);
#elif TONEMAP == 4
	float3 curr = TonemapHejl2015(color, 4.0);
	return saturate(curr);
#elif TONEMAP == 5
	float3 curr = TonemapACES(color);
	return saturate(curr);
#elif TONEMAP == 6
	float3 curr = TonemapNaughtyDog(color);
	return saturate(curr);
#else
	return saturate(color);
#endif
}

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_ToneMap( float2 Tex: TEXCOORD0 ) : COLOR 
{   
    float4 scene = tex2D(ScnSamp,Tex);
	float3 scene_tone = ColorToneMapping(scene.rgb);
	scene.rgb = lerp(scene.rgb,scene_tone,Tr);
    return scene;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

technique Main <
    string Script = 
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
		
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=ToneMap;"
    ; 
> {
    pass ToneMap < string Script= "Draw=Buffer;"; > 
	{
        VertexShader = compile vs_2_0 VS_ToneMap();
        PixelShader  = compile ps_2_0 PS_ToneMap();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
