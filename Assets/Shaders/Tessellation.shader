// 创建者:   Harling
// 创建时间: 2025-03-11 16:57:37
// 备注:     由PIToolKit工具生成

Shader "LineTest/Tessellation" 
{
	Properties 
	{
		_MainTex("MainTex",2D)="white"{}
		_Color("Color",color)=(1,1,1,1)
		_Tess("Tessellation",Range(1,64))=1
		_Radius("Radius",range(0,0.5))=0.4
	}

	CGINCLUDE

	#pragma target 4.6
	#pragma multi_compile_instancing
	
	#include "UnityCG.cginc"
	#include "UnityGBuffer.cginc"

	sampler2D _MainTex;
	float4 _MainTex_ST;

	float _Tess;
	float _Radius;
	UNITY_INSTANCING_BUFFER_START(Props)
	UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
	UNITY_INSTANCING_BUFFER_END(Props)

	struct LineFactors 
	{	
		//线段条数与线段段数
		float edge[2] : SV_TessFactor;
	};
	struct TessBase 
	{
		float4 vertex : INTERNALTESSPOS;
		float3 normal : NORMAL;
		float4 texcoord : TEXCOORD0;
		UNITY_VERTEX_OUTPUT_STEREO
		UNITY_VERTEX_INPUT_INSTANCE_ID 
	};

	struct d2g
	{
		float2 UV:TEXCOORD0;
		float4 Vertex:SV_POSITION;
		float3 Normal:NORMAL0;
		UNITY_VERTEX_OUTPUT_STEREO
		UNITY_VERTEX_INPUT_INSTANCE_ID 
	};
	struct g2f
	{
		float2 UV:TEXCOORD0;
		float4 Vertex:SV_POSITION;
		float3 Normal:NORMAL0;
		UNITY_VERTEX_OUTPUT_STEREO
		UNITY_VERTEX_INPUT_INSTANCE_ID 
	};
    void Vert (appdata_tan adt,uint id:SV_INSTANCEID,uint vid : SV_VertexID,out TessBase data) 
	{
		UNITY_SETUP_INSTANCE_ID(adt);
		UNITY_TRANSFER_INSTANCE_ID(adt, data);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(data);

        data.vertex = adt.vertex;
        data.normal = adt.normal;
        data.texcoord = adt.texcoord;
		data.texcoord.xy=data.texcoord.xy* _MainTex_ST.xy + _MainTex_ST.zw;
    }
	//计算具体的细分
    void hsconst (InputPatch<TessBase,2> v,out LineFactors fators) 
	{
		//线细分
        fators.edge[0] = _Tess; 
		fators.edge[1] = _Tess; 
    }
	//细分控制
	//指定patch类型(tri,qua,isoline)
    [UNITY_domain("isoline")]
	//不同的分割方式(integer,fractional_even,fractional_odd)
    [UNITY_partitioning("integer")]
	//不同的输出方式(triangle_cw,triangle_ccw,line)
    [UNITY_outputtopology("line")]
	//指定细分计算方法
    [UNITY_patchconstantfunc("hsconst")]
	//输出控制点数量(不一定与输入数量相同)
    [UNITY_outputcontrolpoints(3)]
	//InputPatch->hsconst方法必须与这里相同(line-2,tri-3,quad-4)
	//SV_OutputControlPointID 输出控制点ID取[0,patch类型)
	//SV_PrimitiveID path的ID
    TessBase HS (InputPatch<TessBase,2> patch, uint id : SV_OutputControlPointID,uint patchId : SV_PrimitiveID) 
	{
        return patch[id];
    }
	//细分计算
	//SV_DomainLocation：hs传递的细分顶点位置参数(tri是重心坐标,line与quad为UV坐标)
	//OutputPatch:第二个参数必须与patch对应
    [UNITY_domain("isoline")]
    void DS (LineFactors factors, const OutputPatch<TessBase,2> patch, float2 uv : SV_DomainLocation,out d2g o) 
	{
        appdata_base adb;
		UNITY_INITIALIZE_OUTPUT(appdata_base,adb);
        adb.vertex =lerp(patch[0].vertex,patch[1].vertex,uv.x);
        adb.normal =lerp(patch[0].normal,patch[1].normal,uv.x);
        adb.texcoord =lerp(patch[0].texcoord,patch[1].texcoord,uv.x);

		UNITY_SETUP_INSTANCE_ID(patch[0]);
		UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		o.Vertex=adb.vertex;
		o.Normal=adb.normal;
		o.UV=adb.texcoord.xy;
    }
	[maxvertexcount(2)] 
    void Geom(line d2g input[2],uint tid: SV_PrimitiveID,inout LineStream<g2f> outStream)
	{ 
		UNITY_SETUP_INSTANCE_ID(input[0]);
        for(int i=0;i<2;i++)
		{ 
            g2f o=(g2f)0; 
            o.UV=input[i].UV; 
			o.Normal=input[i].Normal;

			float3 center=float3(0,0,0);
			float3 pos=normalize(input[i].Vertex-center)*_Radius+center;

			o.Vertex=UnityObjectToClipPos(pos);
					
			UNITY_TRANSFER_INSTANCE_ID(input[i], o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					
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
	fixed4 FragSample(float2 uv)
	{
		fixed4 col=UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
		col*=tex2D(_MainTex,uv);
		clip(col.a-0.01);
		return col;
	}
	void FragForward(g2f data,out fixed4 col:SV_TARGET)
	{
		UNITY_SETUP_INSTANCE_ID(data);

		col=FragSample(data.UV);
	}
	void FragDeferred(g2f data,
	out half4 outGBuffer0 : SV_Target0,//RGB存储漫反射颜色，A通道存储遮罩
	out half4 outGBuffer1 : SV_Target1,//RGB存储高光(镜面)反射颜色，A通道存储平滑度
	out half4 outGBuffer2 : SV_Target2,//RGB通道存储世界空间法线，A通道空置
	out half4 outEmission : SV_Target3)//自发光 + 光照 + 光照贴图 + 反射探头
	{
		UNITY_SETUP_INSTANCE_ID(data);
		UnityStandardData usd;
		fixed4 col=FragSample(data.UV);
		usd.diffuseColor   = col.rgb;
		usd.occlusion      = col.a;
		usd.specularColor  = 0;
		usd.smoothness     = 0;
		usd.normalWorld    = data.Normal;

		WriteDataToGbuffer(usd, outGBuffer0, outGBuffer1, outGBuffer2);

		outEmission = half4(col.rgb,1);
	}
	ENDCG

	SubShader 
	{
		Tags {"RenderType" = "Opaque" "Queue"="Geometry" "DisableBatching"="False"}
		pass
		{
			Tags {"LightMode" = "ForwardBase"}
			Name "FORWARD"
			Blend Off
			Cull Back
			ZWrite On
			ZTest LEqual
			Offset 0, 0
			ColorMask RGBA
			CGPROGRAM
			#pragma vertex Vert
			#pragma hull HS
            #pragma domain DS
			#pragma geometry Geom 
			#pragma fragment FragForward
			ENDCG
		}
		pass
		{
			Tags {"LightMode" = "Deferred"}
			Name "DEFERRED"
			Blend Off
			Cull Back
			ZWrite On
			ZTest LEqual
			Offset 0, 0
			ColorMask RGBA
			CGPROGRAM
			#pragma vertex Vert
			#pragma hull HS
            #pragma domain DS
			#pragma geometry Geom 
			#pragma fragment FragDeferred
			ENDCG
		}
	}
	//FallBack "Diffuse"
}
