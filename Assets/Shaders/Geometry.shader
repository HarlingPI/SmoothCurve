// 创建者:   Harling
// 创建时间: 2025-03-11 14:43:59
// 备注:     由PIToolKit工具生成

Shader "LineTest/Geometry" 
{
	Properties 
    { 
        _MainTex ("MainTex", 2D) = "white" {} 
		_Color("Color",color)=(1,1,1,1)
		_Tess("Tess",Range(2,1024))=2

		_Radius("Radius",range(0,0.5))=0.4
    } 
	CGINCLUDE
	#pragma target 4.0
	#pragma multi_compile_instancing

	#include "UnityCG.cginc"
	#include "UnityGBuffer.cginc"
    
	sampler2D _MainTex; 
    float4 _MainTex_ST; 
    int _Tess; 
	float _Radius;
	UNITY_INSTANCING_BUFFER_START(Props)
	UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
	UNITY_INSTANCING_BUFFER_END(Props)
	
	struct v2g
	{ 
		float3 OBPos:NORMAL0;
		UNITY_VERTEX_OUTPUT_STEREO
		UNITY_VERTEX_INPUT_INSTANCE_ID 
    }; 
    struct g2f 
    { 
		float4 Pos:SV_POSITION;
		UNITY_VERTEX_OUTPUT_STEREO
		UNITY_VERTEX_INPUT_INSTANCE_ID 
    };  
             
    void Vert (appdata_base adb,uint id:SV_INSTANCEID,uint vid : SV_VertexID,out v2g o) 
    { 
		UNITY_SETUP_INSTANCE_ID(adb);
		UNITY_TRANSFER_INSTANCE_ID(adb, o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		o.OBPos=adb.vertex;
    } 
	//定义每次调用图元着色器所允许输出的最大顶点数目
    [maxvertexcount(204)] 
    void Geom(line v2g input[2],uint tid: SV_PrimitiveID,inout LineStream<g2f> outStream)
	{ 
		UNITY_SETUP_INSTANCE_ID(input[0]);


		for(int i=0;i<=_Tess;i++)
		{
			float ratio=((float)i)/_Tess;

			float3 pos=lerp(input[0].OBPos,input[1].OBPos,ratio);

			float3 center=float3(0,0,0);
			pos=normalize(pos-center)*_Radius+center;

			g2f o;

			o.Pos=UnityObjectToClipPos(pos);

			UNITY_TRANSFER_INSTANCE_ID(input[0], o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(0);

			outStream.Append(o); 
		}

		//表示当前图元构建完毕，下一次调用开始绘制新图元
        outStream.RestartStrip(); 
    }
    void WriteDataToGbuffer(UnityStandardData data, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
	{
		outGBuffer0 = half4(data.diffuseColor, data.occlusion);

		outGBuffer1 = half4(data.specularColor, data.smoothness);

		outGBuffer2 = half4(data.normalWorld * 0.5f + 0.5f, 1.0f);
	}
    void FragForward(g2f data,out fixed4 col:SV_TARGET)
	{
		UNITY_SETUP_INSTANCE_ID(data);
		col=UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
	}
	void FragDeferred(g2f data,
	out half4 outGBuffer0 : SV_Target0,//RGB存储漫反射颜色，A通道存储遮罩
	out half4 outGBuffer1 : SV_Target1,//RGB存储高光(镜面)反射颜色，A通道存储平滑度
	out half4 outGBuffer2 : SV_Target2,//RGB通道存储世界空间法线，A通道空置
	out half4 outEmission : SV_Target3)//自发光 + 光照 + 光照贴图 + 反射探头
	{
		UnityStandardData usd;
		usd.diffuseColor   = 0;
		usd.occlusion      = 0;
		usd.specularColor  = 1;
		usd.smoothness     = 0;
		usd.normalWorld    = 0;

		WriteDataToGbuffer(usd, outGBuffer0, outGBuffer1, outGBuffer2);

		outEmission = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
	}
	ENDCG

    SubShader 
    { 
		Tags {"RenderType" = "Opaque" "Queue"="Geometry" "DisableBatching"="False"}
        Pass 
        { 
			Tags {"LightMode" = "ForwardBase"}
			Name "FORWARD"
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Back
			ZWrite On
			ZTest LEqual
			Offset 0, 0
			ColorMask RGBA
            CGPROGRAM 
            #pragma vertex Vert 
			#pragma geometry Geom 
			#pragma fragment FragForward 
            ENDCG 
        } 
		pass
		{
			Tags {"LightMode" = "Deferred"}
			Name "DEFERRED"
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Back
			ZWrite On
			ZTest LEqual
			Offset 0, 0
			ColorMask RGBA
			CGPROGRAM
			#pragma vertex Vert
			#pragma geometry Geom 
			#pragma fragment FragDeferred
			ENDCG
		}
    } 
	//FallBack "Diffuse"
}
